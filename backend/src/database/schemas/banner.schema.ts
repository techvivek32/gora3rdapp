import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';

export type BannerDocument = Banner & Document;

@Schema({ timestamps: true, collection: 'banners' })
export class Banner {
  @Prop({ required: true })
  title: string;

  @Prop()
  subtitle: string;

  @Prop({ required: true })
  imageUrl: string;

  @Prop()
  actionUrl: string;

  @Prop()
  actionType: string;

  @Prop({ default: true })
  isActive: boolean;

  @Prop({ default: 0 })
  sortOrder: number;

  @Prop({ type: Date })
  startDate: Date;

  @Prop({ type: Date })
  endDate: Date;

  @Prop({ type: [String], default: [] })
  targetMemberships: string[];

  @Prop({ type: [String], default: [] })
  targetCities: string[];

  @Prop({ default: 0 })
  clickCount: number;

  @Prop({ default: 0 })
  viewCount: number;
}

export const BannerSchema = SchemaFactory.createForClass(Banner);

BannerSchema.index({ isActive: 1, sortOrder: 1 });
BannerSchema.index({ startDate: 1, endDate: 1, isActive: 1 });
