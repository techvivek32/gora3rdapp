import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';

export type CityDocument = City & Document;

@Schema({ timestamps: true, collection: 'cities' })
export class City {
  @Prop({ required: true, trim: true })
  name: string;

  @Prop({ required: true, trim: true })
  state: string;

  @Prop({ required: true, trim: true, lowercase: true })
  slug: string;

  @Prop({ type: Object })
  coordinates: {
    lat: number;
    lng: number;
  };

  @Prop({ default: true })
  isActive: boolean;

  @Prop({ default: false })
  isFeatured: boolean;

  @Prop({ default: 0 })
  requirementCount: number;

  @Prop({ default: 0 })
  vehicleCount: number;

  @Prop({ default: 0 })
  userCount: number;

  @Prop()
  imageUrl: string;

  @Prop({ type: [String], default: [] })
  aliases: string[];

  @Prop({ default: 0 })
  sortOrder: number;
}

export const CitySchema = SchemaFactory.createForClass(City);

CitySchema.index({ slug: 1 }, { unique: true });
CitySchema.index({ name: 1, state: 1 });
CitySchema.index({ isActive: 1, sortOrder: 1 });
CitySchema.index({ state: 1, isActive: 1 });
CitySchema.index({ name: 'text', state: 'text' });
