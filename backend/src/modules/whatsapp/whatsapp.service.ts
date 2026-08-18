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
      // When the message omits a date/time we fall back to the moment it was
      // sent (subah/urgent/blank time → the send time; no date → the send date).
      const msgDate = this.messageDate(msg);

      // 1) Try AI parsing (understands any free-form / Hindi-English message).
      // Falls back to the strict fixed-format parser when AI is unavailable.
      let parsed: any = await this.aiParse(text, msgDate);
      if (parsed?.kind === 'available') {
        await this.sendReply(
          from,
          '🚕 This looks like an *available car* post. Auto-posting availability from WhatsApp is coming soon — please post it in the Gora app for now.',
        );
        return;
      }
      if (!parsed) parsed = this.parseBooking(text, msgDate) as any;
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

      // Don't post a booking whose date has already passed (a mis-read or a
      // genuinely old/forwarded message). Same-day is still allowed.
      if (this.isPastBooking(parsed.travelDate)) {
        await this.sendReply(
          from,
          "⚠️ This booking's date has already passed, so it wasn't posted. Please resend it with today's or a future date.",
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
        whatsappMessageId: msg.id, // wamid — idempotency key against redelivery
        contactMobile: contactMobile || undefined,
        notes: parsed.notes ? `${parsed.notes} (via WhatsApp)` : `Booked via WhatsApp (+${from})`,
      };

      // Fill in the same app-suggested distance / fare / commission / total an
      // in-app booking would have (best-effort — skip silently if it can't be
      // computed so the booking still posts).
      await this.applyPricing(dto, parsed);

      const res = await this.requirementsService.create(user._id.toString(), dto);
      const bookingId = (res as any)?.data?.bookingId ?? '';
      const distanceLine = dto.estimatedDistance ? `Distance: ${dto.estimatedDistance} km\n` : '';
      const pricingLines =
        dto.fare > 0
          ? dto.isAppSuggested
            ? `${distanceLine}App Suggested Fare: ₹${dto.totalAmount}\n`
            : `${distanceLine}Driver's Earning: ₹${dto.fare}\nCommission: ₹${dto.commission}\nTotal: ₹${dto.totalAmount}\n`
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
        // No price/commission written in the message → show it as the single
        // "App Suggested Fare" line (distance × ₹/km), exactly like an in-app
        // app-suggested booking — not the Driver's Earning / Commission breakdown.
        const settings: any = await this.settingsService.getSettings();
        const rate =
          (settings?.vehiclePrices && settings.vehiclePrices[parsed.vehicleType]) ||
          settings?.pricePerKm ||
          20;
        const fare = Math.round(distanceKm * rate);
        dto.fare = fare;
        dto.commission = 0;
        dto.totalAmount = fare;
        dto.isAppSuggested = true;
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
  private async aiParse(text: string, msgDate: Date): Promise<any | null> {
    if (!this.aiService.enabled) return null;
    const ai = await this.aiService.parse(text);
    if (!ai) return null;
    if (ai.kind === 'available') return { kind: 'available' };
    if (ai.kind !== 'requirement' || !ai.pickupCity || !ai.dropCity) return null;
    const { travelDate, travelTime } = this.resolveDateTime(ai.date, ai.time || '', msgDate, text);
    return {
      kind: 'requirement',
      pickupCity: ai.pickupCity,
      dropCity: ai.dropCity,
      vehicleType: this.mapVehicle(ai.vehicle || ''),
      tripType: this.mapTrip(ai.tripType || ''),
      travelDate,
      travelTime,
      fare: this.parseAmount(ai.driverEarning),
      commission: this.parseAmount(ai.commission),
      contactNumber: ai.contactNumber || '',
      notes: ai.notes || '',
    };
  }

  private defaultTravelDate(): Date {
    // "Today" in IST at noon. Using the server-local `new Date()` here made
    // late-night IST messages (server is UTC) resolve aaj/kal to the PREVIOUS
    // day — the "back date" the client reported.
    return this.istTravelDate(new Date());
  }

  /** YYYYMMDD for a date; `istOffset` shifts the instant into IST first. */
  private dayNumber(d: Date, istOffset: boolean): number {
    const x = istOffset ? new Date(d.getTime() + 5.5 * 60 * 60 * 1000) : d;
    return x.getUTCFullYear() * 10000 + (x.getUTCMonth() + 1) * 100 + x.getUTCDate();
  }

  /** Minutes since midnight for a "hh:MM AM/PM" string, or null. */
  private timeToMinutes(t: string): number | null {
    const m = (t || '').match(/(\d{1,2}):(\d{2})\s*(AM|PM)?/i);
    if (!m) return null;
    let h = parseInt(m[1], 10);
    const min = parseInt(m[2], 10);
    const ap = (m[3] || '').toUpperCase();
    if (ap === 'PM' && h < 12) h += 12;
    if (ap === 'AM' && h === 12) h = 0;
    return h * 60 + min;
  }

  /** The message's own time-of-day in IST, minutes since midnight. */
  private istMinutes(d: Date): number {
    const ist = new Date(d.getTime() + 5.5 * 60 * 60 * 1000);
    return ist.getUTCHours() * 60 + ist.getUTCMinutes();
  }

  /**
   * Travel date for a message. Uses the written date if any; otherwise the day
   * the message was sent — rolled to the NEXT day when the requested clock time
   * has already passed today (e.g. "6 AM" sent at 9:32 PM means tomorrow 6 AM).
   */
  private resolveTravelDate(rawDate: string, travelTime: string, msgDate: Date): Date {
    const parsed = this.parseDate(rawDate);
    if (parsed) return parsed;
    const base = this.istTravelDate(msgDate);
    const tMin = this.timeToMinutes(travelTime);
    if (tMin != null && tMin < this.istMinutes(msgDate)) {
      base.setDate(base.getDate() + 1); // that time already passed today → tomorrow
    }
    return base;
  }

  /**
   * Resolve BOTH the travel date and time from a message's raw date/time text.
   *
   * Special case — a bare hour with NO am/pm, NO period word and NO written date
   * (e.g. "3 bje"): we pick the SOONEST upcoming "3 o'clock" after the message,
   * which decides both am/pm and the date. Examples (bare "3"):
   *   now 1 PM → today 3 PM · now 4 PM → tomorrow 3 AM · now 6 AM → today 3 PM.
   * Everything else keeps the existing behaviour (explicit am/pm, subah/shaam,
   * written dates, or no time → message time).
   */
  private resolveDateTime(rawDate: string, rawTime: string, msgDate: Date, fullText = ''): { travelDate: Date; travelTime: string } {
    const periodRe = /\b(subah|subha|savere|sabah|morning|dopahar|afternoon|noon|shaam|sham|evening|raat|night)\b/i;
    let t = rawTime || '';
    const hasDigit = /\d/.test(t);
    const hasAmPm = /(?:^|[\s\d.])(am|pm)\b/i.test(t);
    let hasPeriod = periodRe.test(t);

    // The AI sometimes drops the period word ("Sham 7 baje" → time "7"), losing
    // the AM/PM. Recover it from the full message text so "shaam 7" stays 7 PM.
    if (hasDigit && !hasAmPm && !hasPeriod && fullText) {
      const m = fullText.match(periodRe);
      if (m) {
        t = `${t} ${m[0]}`;
        hasPeriod = true;
      }
    }

    if (hasDigit && !hasAmPm && !hasPeriod && !this.parseDate(rawDate)) {
      return this.nextOccurrenceOfBareHour(t, msgDate);
    }

    const travelTime = this.hasTimeInfo(t) ? this.normalizeTime(t) : this.istTravelTime(msgDate);
    return { travelDate: this.resolveTravelDate(rawDate, travelTime, msgDate), travelTime };
  }

  /** For a bare "H[:MM]" with no am/pm, find the next H AM or H PM after the message. */
  private nextOccurrenceOfBareHour(rawTime: string, msgDate: Date): { travelDate: Date; travelTime: string } {
    const m = rawTime.match(/(\d{1,2})\s*[:.\s]?\s*(\d{2})?/);
    const hRaw = m ? parseInt(m[1], 10) : 0;
    const min = m && m[2] ? parseInt(m[2], 10) : 0;
    const h12 = hRaw % 12; // 0..11 (12 → 0)
    const nowMin = this.istMinutes(msgDate);
    const amMin = h12 * 60 + min;        // e.g. 3 → 03:00
    const pmMin = (h12 + 12) * 60 + min; // e.g. 3 → 15:00

    // Each candidate: today if still ahead, else tomorrow. Pick the soonest.
    const candidates = [
      { min: amMin, addDay: amMin > nowMin ? 0 : 1, ap: 'AM' as const },
      { min: pmMin, addDay: pmMin > nowMin ? 0 : 1, ap: 'PM' as const },
    ].sort((a, b) => a.addDay - b.addDay || a.min - b.min);
    const pick = candidates[0];

    const base = this.istTravelDate(msgDate);
    if (pick.addDay === 1) base.setDate(base.getDate() + 1);

    const hh = h12 === 0 ? 12 : h12;
    const travelTime = `${String(hh).padStart(2, '0')}:${String(min).padStart(2, '0')} ${pick.ap}`;
    return { travelDate: base, travelTime };
  }

  /** True when the booking's calendar day is before today (IST). */
  private isPastBooking(travelDate: any): boolean {
    const d = new Date(travelDate);
    if (isNaN(d.getTime())) return false; // unknown date → don't block
    // travelDate is stored at noon of its day, so its UTC day == the intended day.
    return this.dayNumber(d, false) < this.dayNumber(new Date(), true);
  }

  /**
   * True when the time text carries usable info: a digit (a real clock time) or
   * a period word (subah/shaam/dopahar/raat…). False for blank / "urgent" /
   * anything else — in which case the caller uses the message's send time.
   */
  private hasTimeInfo(raw?: string): boolean {
    const t = (raw || '').toLowerCase();
    if (/\d/.test(t)) return true;
    return /\b(subah|subha|savere|sabah|morning|dopahar|afternoon|noon|shaam|sham|evening|raat|night|am|pm)\b/.test(t);
  }

  /** The instant the WhatsApp message was sent (epoch seconds → Date). */
  private messageDate(msg: any): Date {
    const ts = Number(msg?.timestamp);
    return ts && !isNaN(ts) ? new Date(ts * 1000) : new Date();
  }

  /** IST calendar date (noon) for an instant — used when no date was written. */
  private istTravelDate(d: Date): Date {
    const ist = new Date(d.getTime() + 5.5 * 60 * 60 * 1000); // UTC+5:30
    return new Date(ist.getUTCFullYear(), ist.getUTCMonth(), ist.getUTCDate(), 12, 0, 0, 0);
  }

  /** IST clock time "hh:MM AM/PM" for an instant — used when no time was written. */
  private istTravelTime(d: Date): string {
    const ist = new Date(d.getTime() + 5.5 * 60 * 60 * 1000); // UTC+5:30
    let h = ist.getUTCHours();
    const min = ist.getUTCMinutes();
    const ap = h >= 12 ? 'PM' : 'AM';
    h = h % 12;
    if (h === 0) h = 12;
    return `${String(h).padStart(2, '0')}:${String(min).padStart(2, '0')} ${ap}`;
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
  private parseBooking(text: string, msgDate: Date): {
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

    const { travelDate, travelTime } = this.resolveDateTime(
      fields['date'] || fields['travel date'] || '',
      fields['time'] || fields['travel time'] || '',
      msgDate,
      text,
    );

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

  /** Parse DD/MM/YYYY, DD-MM-YYYY, DD/MM, or natural words (today/kal/tomorrow). */
  private parseDate(raw: string): Date | null {
    const s = (raw || '').trim();
    if (!s) return null;

    // Natural date words common in group messages.
    const l = s.toLowerCase();
    const addDays = (n: number) => {
      const d = this.defaultTravelDate();
      d.setDate(d.getDate() + n);
      return d;
    };
    if (/\b(today|aaj|abhi|aj)\b/.test(l)) return addDays(0);
    if (/\b(tomorrow|tmrw|tmw|kal|kl)\b/.test(l)) return addDays(1);
    if (/\b(day after|parso|parson|parsu)\b/.test(l)) return addDays(2);

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

  /**
   * Normalise free-form time text to "HH:MM AM/PM".
   * Handles colon/dot/space separators ("6.30", "6 30", "6:30"), am/pm written
   * anywhere, and Hindi period words. When only a period word is given (no
   * digits) it maps to that slot's default: subah→09:00 AM, dopahar→12:00 PM,
   * shaam→06:00 PM, raat→09:00 PM. Example: "6.30 pm" → "06:30 PM".
   */
  private normalizeTime(raw: string): string {
    const s = (raw || '').toLowerCase();

    // Detect the period word, if any — drives both AM/PM and the wordless default.
    let ap = '';
    let periodDefault = ''; // used only when no numeric time is present
    if (/\b(raat|night)\b/.test(s)) { ap = 'PM'; periodDefault = '09:00 PM'; }
    else if (/\b(shaam|sham|evening)\b/.test(s)) { ap = 'PM'; periodDefault = '06:00 PM'; }
    else if (/\b(dopahar|afternoon|noon)\b/.test(s)) { ap = 'PM'; periodDefault = '12:00 PM'; }
    else if (/\b(subah|subha|savere|sabah|morning)\b/.test(s)) { ap = 'AM'; periodDefault = '09:00 AM'; }
    // "pm"/"am" may be stuck to the digit ("9pm"): allow a digit/space/dot before.
    else if (/(?:^|[\s\d.])pm\b/.test(s)) ap = 'PM';
    else if (/(?:^|[\s\d.])am\b/.test(s)) ap = 'AM';

    // Hour + optional minutes with any separator (":", ".", or space).
    const m = s.match(/(\d{1,2})\s*[:.\s]?\s*(\d{2})?/);
    if (!m) {
      // No numeric time at all — use the period's default slot.
      return periodDefault || '09:00 AM';
    }

    let h = parseInt(m[1], 10);
    const min = m[2] ? m[2] : '00';
    if (!ap) ap = h >= 12 ? 'PM' : 'AM';
    if (h > 12) h -= 12;
    if (h === 0) h = 12;
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
    if (/small|mini|wagon|alto|swift|celerio|santro|i10|i20|kwid/.test(v)) return VehicleType.HATCHBACK;
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
