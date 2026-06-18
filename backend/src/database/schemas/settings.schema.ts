import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';

export type PlatformSettingsDocument = PlatformSettings & Document;

@Schema({ timestamps: true, collection: 'platform_settings' })
export class PlatformSettings {
  @Prop({ required: true, unique: true, default: 'global' })
  key: string;

  @Prop({ default: 20, min: 1 })
  pricePerKm: number;

  @Prop({ default: 10, min: 0, max: 100 })
  commissionPercent: number;
}

export const PlatformSettingsSchema = SchemaFactory.createForClass(PlatformSettings);
