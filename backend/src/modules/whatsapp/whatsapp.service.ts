import { ForbiddenException, Injectable, Logger } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { ConfigService } from '@nestjs/config';
import { User, UserDocument } from '../../database/schemas/user.schema';
import { RequirementsService } from '../requirements/requirements.service';
import { PlacesService } from '../places/places.service';
import { SettingsService } from '../settings/settings.service';
import { WhatsappAiService } from './whatsapp-ai.service';
import { VehicleType, TripType } from '../../common/enums/vehicle-type.enum';

const HELP = [
  'To post a booking, send it like this 👇',
  '',
  'Booking',
  'From: Jaipur',
  'To: Udaipur',
  'Date: 15/07/2026',
  'Time: 09:00 PM',
  'Car: Sedan',
  'Trip: One Way',
  'Driver Earning: 5000',
  'Commission: 500',
].join('\n');

@Injectable()
export class WhatsappService {
  private readonly logger = new Logger(WhatsappService.name);

  constructor(
    @InjectModel(User.name) private userModel: Model<UserDocument>,
    private readonly requirementsService: RequirementsService,
    private readonly placesService: PlacesService,
    private readonly settingsService: SettingsService,
    private readonly aiService: WhatsappAiService,
    private readonly config: ConfigService,
  ) {}

  /** GET webhook verification handshake (Meta calls this once when you save the webhook). */
  verify(mode?: string, token?: string, challenge?: string): string {
    const expected = this.config.get<string>('whatsapp.verifyToken') || process.env.WHATSAPP_VERIFY_TOKEN;
    if (mode === 'subscribe' && token && token === expected) {
      return challenge || '';
    }
    throw new ForbiddenException('Verification failed');
  }

  /** POST webhook: turn an inbound WhatsApp text into a booking. Best-effort; never throws. */
  async handleWebhook(body: any): Promise<void> {
    try {
      const value = body?.entry?.[0]?.changes?.[0]?.value;
      const msg = value?.messages?.[0];
      if (!msg || msg.type !== 'text') return; // status callbacks / non-text → ignore
      const from: string = msg.from; // e.g. "919587090620"
      const text: string = (msg.text?.body ?? '').trim();
      if (!text) return;

      // 1) Try AI parsing (understands any free-form / Hindi-English message).
      // Falls back to the strict fixed-format parser when AI is unavailable.
      let parsed: any = await this.aiParse(text);
      if (parsed?.kind === 'available') {
        await this.sendReply(
          from,
          '🚕 This looks like an *available car* post. Auto-posting availability from WhatsApp is coming soon — please post it in the Gora app for now.',
        );
        return;
      }
      if (!parsed) parsed = this.parseBooking(text) as any;
      if (!parsed) {
        await this.sendReply(from, `Sorry, I couldn't read that. ${HELP}`);
        return;
      }

      // Map the sender's WhatsApp number to a registered Gora member (the agent
      // forwarding the booking, or the customer messaging directly).
      const user = await this.findUserByPhone(from);
      if (!user) {
        await this.sendReply(
          from,
          "This number isn't registered on Gora Taxi Partner yet. Please install the app and register with this number, then send your booking again.",
        );
        return;
      }

      // Contact for the Call / WhatsApp buttons: the number written INSIDE the
      // message (the original customer) wins — AI-extracted first, then a plain
      // regex scan of the text as a backstop; only if none is found do we fall
      // back to the sender's own number.
      const contactMobile =
        this.normalizeMobile(parsed.contactNumber) ||
        this.extractNumberFromText(text) ||
        this.normalizeMobile(from) ||
        '';

      const dto: any = {
        pickupCity: parsed.pickupCity,
        dropCity: parsed.dropCity,
        pickupCityName: parsed.pickupCity,
        dropCityName: parsed.dropCity,
        vehicleType: parsed.vehicleType,
        tripType: parsed.tripType,
        fuelType: 'any',
        travelDate: parsed.travelDate,
        travelTime: parsed.travelTime,
        numberOfVehicles: 1,
        source: 'whatsapp',
        contactMobile: contactMobile || undefined,
        notes: parsed.notes ? `${parsed.notes} (via WhatsApp)` : `Booked via WhatsApp (+${from})`,
      };

      // Fill in the same app-suggested distance / fare / commission / total an
      // in-app booking would have (best-effort — skip silently if it can't be
      // computed so the booking still posts).
      await this.applyPricing(dto, parsed);

      const res = await this.requirementsService.create(user._id.toString(), dto);
      const bookingId = (res as any)?.data?.bookingId ?? '';
      const pricingLines =
        dto.fare > 0
          ? `${dto.estimatedDistance ? `Distance: ${dto.estimatedDistance} km\n` : ''}Driver's Earning: ₹${dto.fare}\nCommission: ₹${dto.commission}\nTotal: ₹${dto.totalAmount}\n`
          : '';
      await this.sendReply(
        from,
        `✅ Booking posted!\n${bookingId ? `ID: ${bookingId}\n` : ''}${parsed.pickupCity} → ${parsed.dropCity}\n${this.fmtDate(parsed.travelDate)} ${parsed.travelTime}\n${this.vehicleLabel(parsed.vehicleType)}\n${pricingLines}\nIt's now live in the Gora Taxi Partner app.`,
      );
      this.logger.log(`WhatsApp booking created for ${user._id} from +${from} (${bookingId})`);
    } catch (e: any) {
      this.logger.error(`WhatsApp webhook error: ${e?.message ?? e}`);
      // Swallow — always 200 to Meta so it doesn't retry endlessly.
    }
  }

  /**
   * Mutates `dto` with estimatedDistance / fare / commission / totalAmount +
   * pickup/drop coordinates. Driver's Earning and Commission come from what the
   * customer typed in the message; if they typed nothing, we fall back to the
   * app-suggested fare (distance × the vehicle's ₹/km rate). `isAppSuggested` is
   * false so the app shows the full Driver's Earning / Commission / Total breakdown.
   * Best-effort throughout — the booking still posts if any step fails.
   */
  private async applyPricing(
    dto: any,
    parsed: { pickupCity: string; dropCity: string; vehicleType: VehicleType; fare?: number; commission?: number },
  ): Promise<void> {
    // 1) Distance + coordinates for the km display + map (best-effort).
    let distanceKm = 0;
    try {
      const route = await this.placesService.routeByAddress(parsed.pickupCity, parsed.dropCity);
      if (route?.distanceKm) {
        distanceKm = route.distanceKm;
        dto.estimatedDistance = Math.round(route.distanceKm);
        if (route.pickup?.lat) {
          dto.pickupCoordinates = { lat: route.pickup.lat, lng: route.pickup.lng, address: parsed.pickupCity };
        }
        if (route.drop?.lat) {
          dto.dropCoordinates = { lat: route.drop.lat, lng: route.drop.lng, address: parsed.dropCity };
        }
      }
    } catch (e: any) {
      this.logger.warn(`distance lookup skipped: ${e?.message ?? e}`);
    }

    // 2) Money: prefer the amounts the customer typed; otherwise auto-suggest.
    try {
      if (parsed.fare != null) {
        const fare = parsed.fare;
        const commission = parsed.commission ?? 0;
        dto.fare = fare;
        dto.commission = commission;
        dto.totalAmount = fare + commission;
        dto.isAppSuggested = false;
      } else if (distanceKm > 0) {
        const settings: any = await this.settingsService.getSettings();
        const rate =
          (settings?.vehiclePrices && settings.vehiclePrices[parsed.vehicleType]) ||
          settings?.pricePerKm ||
          20;
        const commissionPercent = typeof settings?.commissionPercent === 'number' ? settings.commissionPercent : 10;
        const fare = Math.round(distanceKm * rate);
        const commission = Math.round((fare * commissionPercent) / 100);
        dto.fare = fare;
        dto.commission = commission;
        dto.totalAmount = fare + commission;
        dto.isAppSuggested = false;
      }
    } catch (e: any) {
      this.logger.warn(`fare calc skipped: ${e?.message ?? e}`);
    }
  }

  // ─── AI parsing (free-form) ──────────────────────────────────────────────────
  /**
   * Parse any free-form WhatsApp message via Claude, mapping its free-text fields
   * onto our enums/date types. Returns { kind: 'available' } for availability posts
   * (not auto-created yet), a full requirement object for bookings, or null to fall
   * back to the fixed-format parser.
   */
  private async aiParse(text: string): Promise<any | null> {
    if (!this.aiService.enabled) return null;
    const ai = await this.aiService.parse(text);
    if (!ai) return null;
    if (ai.kind === 'available') return { kind: 'available' };
    if (ai.kind !== 'requirement' || !ai.pickupCity || !ai.dropCity) return null;
    return {
      kind: 'requirement',
      pickupCity: ai.pickupCity,
      dropCity: ai.dropCity,
      vehicleType: this.mapVehicle(ai.vehicle || ''),
      tripType: this.mapTrip(ai.tripType || ''),
      travelDate: this.parseDate(ai.date) || this.defaultTravelDate(),
      travelTime: this.normalizeTime(ai.time || '09:00 AM'),
      fare: this.parseAmount(ai.driverEarning),
      commission: this.parseAmount(ai.commission),
      contactNumber: ai.contactNumber || '',
      notes: ai.notes || '',
    };
  }

  private defaultTravelDate(): Date {
    const d = new Date();
    d.setHours(12, 0, 0, 0);
    return d;
  }

  /** Keep a valid 10-digit Indian mobile from any messy input, else ''. */
  private normalizeMobile(raw?: string): string {
    const digits = (raw || '').replace(/\D/g, '').slice(-10);
    return /^[6-9]\d{9}$/.test(digits) ? digits : '';
  }

  /**
   * Pull the first Indian mobile number written in the message text (e.g.
   * "...contact 8888844444"). Handles an optional +91 / 91 prefix. Returns the
   * clean 10-digit number, or '' if none — so a forwarded booking's customer
   * number lands on the Call / WhatsApp buttons even when AI isn't running.
   */
  private extractNumberFromText(text: string): string {
    const matches = (text || '').match(/(?:\+?91[\s-]?)?[6-9]\d{9}/g) || [];
    for (const m of matches) {
      const n = this.normalizeMobile(m);
      if (n) return n;
    }
    return '';
  }

  // ─── Parsing (fixed format) ──────────────────────────────────────────────────
  private parseBooking(text: string): {
    pickupCity: string; dropCity: string; vehicleType: VehicleType; tripType: TripType;
    travelDate: Date; travelTime: string; fare?: number; commission?: number;
  } | null {
    const fields: Record<string, string> = {};
    for (const line of text.split('\n')) {
      // Allow apostrophes in the label (e.g. "Driver's Earning"); strip them from the key.
      const m = line.match(/^\s*([a-zA-Z'’ ]+?)\s*[:\-]\s*(.+?)\s*$/);
      if (m) fields[m[1].trim().toLowerCase().replace(/['’]/g, '')] = m[2].trim();
    }

    const pickupCity = fields['from'] || fields['pickup'];
    const dropCity = fields['to'] || fields['drop'];
    if (!pickupCity || !dropCity) return null;

    const travelDate = this.parseDate(fields['date'] || fields['travel date'] || '');
    if (!travelDate) return null;
    const travelTime = this.normalizeTime(fields['time'] || fields['travel time'] || '09:00 AM');

    // Manually-entered money (customer types these in the message).
    const fare = this.parseAmount(
      fields['driver earning'] || fields['drivers earning'] || fields['earning'] ||
      fields['earnings'] || fields['driver'] || fields['fare'],
    );
    const commission = this.parseAmount(fields['commission'] || fields['comm']);

    return {
      pickupCity,
      dropCity,
      vehicleType: this.mapVehicle(fields['car'] || fields['vehicle'] || fields['cab'] || ''),
      tripType: this.mapTrip(fields['trip'] || fields['trip type'] || ''),
      travelDate,
      travelTime,
      fare,
      commission,
    };
  }

  /** Extract a whole-rupee amount from free text like "₹5,000", "5000/-", "5000". */
  private parseAmount(raw?: string): number | undefined {
    if (!raw) return undefined;
    const n = parseInt(String(raw).replace(/[^\d]/g, ''), 10);
    return isNaN(n) ? undefined : n;
  }

  /** Parse DD/MM/YYYY, DD-MM-YYYY, or DD/MM (year assumed). */
  private parseDate(raw: string): Date | null {
    const s = (raw || '').trim();
    if (!s) return null;
    const parts = s.split(/[/\-.]/).map((p) => p.trim());
    if (parts.length >= 2) {
      const dd = parseInt(parts[0], 10);
      const mm = parseInt(parts[1], 10);
      let yyyy = parts[2] ? parseInt(parts[2], 10) : new Date().getFullYear();
      if (yyyy < 100) yyyy += 2000;
      if (dd >= 1 && dd <= 31 && mm >= 1 && mm <= 12) {
        const d = new Date(yyyy, mm - 1, dd, 12, 0, 0, 0);
        if (!isNaN(d.getTime())) return d;
      }
    }
    const fallback = new Date(s);
    return isNaN(fallback.getTime()) ? null : fallback;
  }

  /** Keep the user's time text but tidy it, e.g. "9pm" → "09:00 PM". */
  private normalizeTime(raw: string): string {
    const m = (raw || '').match(/(\d{1,2})(?::(\d{2}))?\s*(am|pm)?/i);
    if (!m) return raw || '09:00 AM';
    let h = parseInt(m[1], 10);
    const min = m[2] ? m[2] : '00';
    let ap = (m[3] || '').toUpperCase();
    if (!ap) { ap = h >= 12 ? 'PM' : 'AM'; if (h > 12) h -= 12; }
    return `${String(h).padStart(2, '0')}:${min} ${ap}`;
  }

  private mapVehicle(raw: string): VehicleType {
    const v = raw.toLowerCase();
    if (/hatch/.test(v)) return VehicleType.HATCHBACK;
    if (/eeco/.test(v)) return VehicleType.EECO;
    if (/ertiga|xl6/.test(v)) return VehicleType.ERTIGA;
    if (/rumion/.test(v)) return VehicleType.RUMION;
    if (/carens/.test(v)) return VehicleType.CARENS;
    if (/crysta/.test(v)) return VehicleType.CRYSTA;
    if (/hycross/.test(v)) return VehicleType.HYCROSS;
    if (/innova/.test(v)) return VehicleType.INNOVA;
    if (/tempo|traveller/.test(v)) return VehicleType.TEMPO_TRAVELLER;
    if (/urbania/.test(v)) return VehicleType.URBANIA;
    if (/trax|cruiser/.test(v)) return VehicleType.TRAX_CRUISER;
    if (/suv/.test(v)) return VehicleType.ERTIGA; // generic SUV → closest
    return VehicleType.SEDAN; // sedan / dzire / etios / unknown
  }

  private mapTrip(raw: string): TripType {
    const t = raw.toLowerCase();
    if (/round/.test(t)) return TripType.ROUND_TRIP;
    if (/airport/.test(t)) return TripType.AIRPORT_TRANSFER;
    if (/local/.test(t)) return TripType.LOCAL;
    if (/outstation/.test(t)) return TripType.OUTSTATION;
    return TripType.ONE_WAY;
  }

  private vehicleLabel(v: VehicleType): string {
    return v.replace(/_/g, ' ').replace(/\b\w/g, (c) => c.toUpperCase());
  }

  private fmtDate(d: Date): string {
    return d.toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric' });
  }

  private async findUserByPhone(from: string): Promise<UserDocument | null> {
    const local10 = (from || '').replace(/\D/g, '').slice(-10);
    if (!local10) return null;
    // Match a stored mobile that ends with the same 10 digits (handles +91 / 91 prefixes).
    return this.userModel.findOne({ mobile: new RegExp(`${local10}$`) });
  }

  // ─── Outbound reply (WhatsApp Cloud API) ─────────────────────────────────────
  private async sendReply(to: string, message: string): Promise<void> {
    const token = this.config.get<string>('whatsapp.accessToken') || process.env.WHATSAPP_ACCESS_TOKEN;
    const phoneId = this.config.get<string>('whatsapp.phoneNumberId') || process.env.WHATSAPP_PHONE_NUMBER_ID;
    const version = this.config.get<string>('whatsapp.graphVersion') || process.env.WHATSAPP_GRAPH_VERSION || 'v21.0';
    if (!token || !phoneId) {
      this.logger.warn(`[WhatsApp reply skipped — token/phoneId not set] to +${to}: ${message}`);
      return;
    }
    try {
      const res = await fetch(`https://graph.facebook.com/${version}/${phoneId}/messages`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({
          messaging_product: 'whatsapp',
          to,
          type: 'text',
          text: { body: message.slice(0, 4000) },
        }),
      });
      if (!res.ok) this.logger.error(`WhatsApp reply failed (${res.status}): ${(await res.text()).slice(0, 300)}`);
    } catch (e: any) {
      this.logger.error(`WhatsApp reply error: ${e?.message ?? e}`);
    }
  }
}
