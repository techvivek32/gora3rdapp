import { ForbiddenException, Injectable, Logger } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { ConfigService } from '@nestjs/config';
import { User, UserDocument } from '../../database/schemas/user.schema';
import { RequirementsService } from '../requirements/requirements.service';
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
].join('\n');

@Injectable()
export class WhatsappService {
  private readonly logger = new Logger(WhatsappService.name);

  constructor(
    @InjectModel(User.name) private userModel: Model<UserDocument>,
    private readonly requirementsService: RequirementsService,
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

      const parsed = this.parseBooking(text);
      if (!parsed) {
        await this.sendReply(from, `Sorry, I couldn't read that. ${HELP}`);
        return;
      }

      // Map the sender's WhatsApp number to a registered Gora member.
      const user = await this.findUserByPhone(from);
      if (!user) {
        await this.sendReply(
          from,
          "This number isn't registered on Gora Taxi Partner yet. Please install the app and register with this number, then send your booking again.",
        );
        return;
      }

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
        notes: `Booked via WhatsApp (+${from})`,
      };

      const res = await this.requirementsService.create(user._id.toString(), dto);
      const bookingId = (res as any)?.data?.bookingId ?? '';
      await this.sendReply(
        from,
        `✅ Booking posted!\n${bookingId ? `ID: ${bookingId}\n` : ''}${parsed.pickupCity} → ${parsed.dropCity}\n${this.fmtDate(parsed.travelDate)} ${parsed.travelTime}\n${this.vehicleLabel(parsed.vehicleType)}\n\nIt's now live in the Gora Taxi Partner app.`,
      );
      this.logger.log(`WhatsApp booking created for ${user._id} from +${from} (${bookingId})`);
    } catch (e: any) {
      this.logger.error(`WhatsApp webhook error: ${e?.message ?? e}`);
      // Swallow — always 200 to Meta so it doesn't retry endlessly.
    }
  }

  // ─── Parsing (fixed format) ──────────────────────────────────────────────────
  private parseBooking(text: string): {
    pickupCity: string; dropCity: string; vehicleType: VehicleType; tripType: TripType;
    travelDate: Date; travelTime: string;
  } | null {
    const fields: Record<string, string> = {};
    for (const line of text.split('\n')) {
      const m = line.match(/^\s*([a-zA-Z ]+?)\s*[:\-]\s*(.+?)\s*$/);
      if (m) fields[m[1].trim().toLowerCase()] = m[2].trim();
    }

    const pickupCity = fields['from'] || fields['pickup'];
    const dropCity = fields['to'] || fields['drop'];
    if (!pickupCity || !dropCity) return null;

    const travelDate = this.parseDate(fields['date'] || fields['travel date'] || '');
    if (!travelDate) return null;
    const travelTime = this.normalizeTime(fields['time'] || fields['travel time'] || '09:00 AM');

    return {
      pickupCity,
      dropCity,
      vehicleType: this.mapVehicle(fields['car'] || fields['vehicle'] || fields['cab'] || ''),
      tripType: this.mapTrip(fields['trip'] || fields['trip type'] || ''),
      travelDate,
      travelTime,
    };
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
