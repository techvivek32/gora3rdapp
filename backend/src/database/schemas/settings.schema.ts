import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';

export type PlatformSettingsDocument = PlatformSettings & Document;

// Default per-vehicle prices (₹/km)
export const DEFAULT_VEHICLE_PRICES: Record<string, number> = {
  hatchback: 12,
  eeco: 13,
  sedan: 15,
  ertiga: 18,
  rumion: 18,
  carens: 18,
  innova: 20,
  crysta: 22,
  hycross: 24,
  tempo_traveller: 28,
  urbania: 30,
  trax_cruiser: 28,
  small_coach: 35,
  luxury_coach: 45,
  premium: 25,
};

@Schema({ timestamps: true, collection: 'platform_settings' })
export class PlatformSettings {
  @Prop({ required: true, unique: true, default: 'global' })
  key: string;

  @Prop({ default: 20, min: 1 })
  pricePerKm: number;

  @Prop({ default: 10, min: 0, max: 100 })
  commissionPercent: number;

  @Prop({ type: Object, default: DEFAULT_VEHICLE_PRICES })
  vehiclePrices: Record<string, number>;

  @Prop({ default: '' })
  razorpayKeyId: string;

  @Prop({ default: '' })
  razorpayKeySecret: string;

  @Prop({ default: '' })
  razorpayWebhookSecret: string;

  @Prop({ default: '' })
  supportPhone: string;

  /** Fallback call number, shown on About Us when the primary line is busy. */
  @Prop({ default: '' })
  supportPhone2: string;

  @Prop({ default: '' })
  supportWhatsapp: string;

  /** Shown on the app's About Us page alongside supportPhone. */
  @Prop({ default: '', trim: true, lowercase: true })
  supportEmail: string;

  // ─── Wallet limits (₹) — enforced on the wallet actions, shown in the app ───
  /** Minimum amount a user can add to their wallet in one go. */
  @Prop({ default: 1, min: 0 })
  minDeposit: number;

  /** Minimum amount a user can request to withdraw. */
  @Prop({ default: 1, min: 0 })
  minWithdrawal: number;

  /** Minimum amount a user can transfer to another wallet. */
  @Prop({ default: 1, min: 0 })
  minTransfer: number;

  /**
   * Auto-mark a WhatsApp booking as "Booked" this many minutes after it was
   * posted. 0 = disabled (never auto-book). Applies to WhatsApp posts only.
   */
  @Prop({ default: 0, min: 0 })
  whatsappAutoBookMinutes: number;

  /**
   * When true the app shows the "App Suggested Fare" on booking cards. When
   * false that line is hidden — cards show a fare only if the poster entered a
   * manual driver-earning + commission.
   */
  @Prop({ default: true })
  appSuggestedFareEnabled: boolean;

  /** When true the app shows the "N views" count on booking/available cards. */
  @Prop({ default: true })
  viewsEnabled: boolean;

  /**
   * Minimum billable distance (km) for customer CAB bookings, applied to ALL cabs.
   * If a trip is shorter, the fare is charged for this many km. 0 = no minimum.
   */
  @Prop({ default: 0, min: 0 })
  minBillKm: number;

  /**
   * Estimated toll + state-tax per km (₹), used for the "All Inclusive" fare ONLY
   * when Google's Routes API returns no toll amount for a route (common on long
   * Indian inter-state routes, and Google never includes state tax). 0 = disabled.
   */
  @Prop({ default: 0, min: 0 })
  tollTaxPerKm: number;

  /** GST percent added to the "All Inclusive" cab fare (0 = no GST). */
  @Prop({ default: 0, min: 0, max: 100 })
  gstPercent: number;

  /** Hire-a-Driver per-day rate (₹). Total = this × number of days. 0 = not set. */
  @Prop({ default: 0, min: 0 })
  driverHirePerDay: number;

  /**
   * Minimum wallet balance (₹) a Golden driver/vendor must have to ACCEPT a
   * customer booking. Nothing is deducted — it's only an eligibility check.
   * 0 = no minimum (anyone Golden can accept).
   */
  @Prop({ default: 0, min: 0 })
  minWalletToAccept: number;

  /**
   * How many hours BEFORE the pickup time the driver↔customer phone numbers are
   * revealed to each other on a confirmed customer cab booking (one-way / round
   * trip / local). Before this window the contact stays hidden for both sides.
   * Default 1 hour. 0 = reveal immediately on confirmation.
   */
  @Prop({ default: 1, min: 0 })
  contactRevealHoursBeforePickup: number;
}

export const PlatformSettingsSchema = SchemaFactory.createForClass(PlatformSettings);
