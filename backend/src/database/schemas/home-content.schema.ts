import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';

export type HomeShowcaseDocument = HomeShowcase & Document;
export type CityImageDocument = CityImage & Document;
export type CabCategoryDocument = CabCategory & Document;

export enum HomeSectionType {
  TRAVEL = 'travel', // "Travel Made Better" — Hotels / Restaurants / Business
  OFFERS = 'offers', // "Special Offers"
  EXPLORE = 'explore', // "Explore <city/state>" category chips
}

/// One admin-managed card in a customer-home showcase section. `city=''` shows it
/// everywhere; a specific city limits it to that city. Everything (image, title,
/// link, category) is set from the admin panel.
@Schema({ timestamps: true, collection: 'homeShowcase' })
export class HomeShowcase {
  @Prop({ type: String, enum: HomeSectionType, required: true, index: true })
  section: HomeSectionType;

  @Prop({ required: true }) title: string;
  @Prop({ default: '' }) subtitle: string;
  @Prop({ default: '' }) imageUrl: string;
  @Prop({ default: '' }) actionUrl: string; // deep link / URL opened on tap
  @Prop({ default: '' }) category: string; // e.g. Hotels / Restaurants / Forts
  @Prop({ default: '', index: true }) city: string; // '' = all cities (stored lowercase)
  @Prop({ default: 0 }) order: number;
  @Prop({ default: true }) isActive: boolean;
}
export const HomeShowcaseSchema = SchemaFactory.createForClass(HomeShowcase);
HomeShowcaseSchema.index({ section: 1, city: 1, order: 1 });

/// Per-city hero image for the customer home header (Rajkot user → Rajkot photo).
@Schema({ timestamps: true, collection: 'cityImages' })
export class CityImage {
  @Prop({ required: true, unique: true, lowercase: true, trim: true }) city: string;
  @Prop({ default: '' }) imageUrl: string;
  @Prop({ default: true }) isActive: boolean;
}
export const CityImageSchema = SchemaFactory.createForClass(CityImage);

/// Admin-managed cab class shown on the "Explore Cabs" results screen. The fare
/// is computed as distanceKm × pricePerKm; everything (name, class, image, seats,
/// bags, per-km rate) is set from the admin panel.
@Schema({ timestamps: true, collection: 'cabCategories' })
export class CabCategory {
  @Prop({ required: true }) name: string; // e.g. "Wagon R or equivalent"
  @Prop({ default: '' }) vehicleClass: string; // e.g. "Compact" / "Sedan" / "SUV"
  @Prop({ default: '' }) imageUrl: string;
  @Prop({ default: 0 }) pricePerKm: number;
  @Prop({ default: 4 }) seats: number;
  @Prop({ default: '' }) bags: string; // e.g. "1 Small bag"
  @Prop({ default: 0 }) order: number;
  @Prop({ default: true }) isActive: boolean;
}
export const CabCategorySchema = SchemaFactory.createForClass(CabCategory);
CabCategorySchema.index({ isActive: 1, order: 1 });
