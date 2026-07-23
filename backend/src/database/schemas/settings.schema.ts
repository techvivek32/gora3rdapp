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
}

export const PlatformSettingsSchema = SchemaFactory.createForClass(PlatformSettings);
