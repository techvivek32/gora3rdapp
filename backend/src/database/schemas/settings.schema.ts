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
   * Customer-booking commitment: the % of the fare a driver/vendor must HOLD in
   * their wallet to apply for a customer booking (e.g. 5 → ₹500 hold on ₹10,000).
   */
  @Prop({ default: 5, min: 0, max: 100 })
  bookingCommitmentPercent: number;

  /**
   * Customer-facing cancellation policy text, shown on offers and booking
   * details so the customer knows the terms before selecting a driver.
   */
  @Prop({ default: 'Free cancellation before the driver starts the trip. After the trip starts, charges may apply as per driver terms.' })
  bookingCancellationPolicy: string;

  /**
   * When a driver cancels AFTER being selected, this % of their settled
   * commitment is kept as a penalty (not refunded). 100 = full forfeit (default),
   * 0 = fully refunded.
   */
  @Prop({ default: 100, min: 0, max: 100 })
  driverCancelPenaltyPercent: number;

  /**
   * Minimum billable distance (km) for customer CAB bookings, applied to ALL cabs.
   * If a trip is shorter, the fare is charged for this many km. 0 = no minimum.
   */
  @Prop({ default: 0, min: 0 })
  minBillKm: number;
}

export const PlatformSettingsSchema = SchemaFactory.createForClass(PlatformSettings);
