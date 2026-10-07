import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';

export type HomeShowcaseDocument = HomeShowcase & Document;
export type CityImageDocument = CityImage & Document;
export type CabCategoryDocument = CabCategory & Document;

export enum HomeSectionType {
  TRAVEL = 'travel', // "Travel Made Better" — Hotels / Restaurants / Business
  OFFERS = 'offers', // "Special Offers"
  EXPLORE = 'explore', // "Explore <city/state>" category chips
  // Cab-booking info tabs (title = one bullet line). All admin-managed.
  INCLUSIONS = 'inclusions', // what the fare covers
  EXCLUSIONS = 'exclusions', // what's not included
  FACILITIES = 'facilities', // car/service facilities
  TERMS = 'terms', // terms & conditions
}

/// One admin-managed card in a customer-home showcase section. `city=''` shows it
/// everywhere; a specific city limits it to that city. Everything (image, title,
/// link, category) is set from the admin panel.
@Schema({ timestamps: true, collection: 'homeShowcase' })
export class HomeShowcase {
  @Prop({ type: String, enum: HomeSectionType, required: true, index: true })
  section: HomeSectionType;

  @Prop({ default: '' }) title: string;
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
  // When the image was last auto-resolved from Google Places (cache TTL).
  @Prop({ default: null }) fetchedAt: Date;
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
  @Prop({ default: 0 }) pricePerKm: number; // fallback / default rate
  // Per-km rate by fuel type (customer picks fuel; 0 = fall back to pricePerKm).
  // These are the DEFAULT/base rates; per-state overrides live in statePricing.
  @Prop({ default: 0 }) pricePerKmPetrol: number;
  @Prop({ default: 0 }) pricePerKmDiesel: number;
  @Prop({ default: 0 }) pricePerKmCng: number;
  // State-wise per-km fuel rates. The app uses the PICKUP state's rate; a state
  // not listed (or a 0) falls back to the base pricePerKm<Fuel> above.
  @Prop({ type: [{ state: String, petrol: Number, diesel: Number, cng: Number }], default: [] })
  statePricing: { state: string; petrol: number; diesel: number; cng: number }[];
  // Per-cab discount shown in the app (original fare struck through + discounted).
  @Prop({ default: 0 }) discountPercent: number; // 0–100
  // ── Driver allowance (added to the One Way / Round Trip fare total) ──────────
  // Round Trip: allowance = trip days × allowanceDailyRate (distance ignored).
  @Prop({ default: 0 }) allowanceDailyRate: number;
  // One Way: distance ≤ threshold → base rate; distance > threshold → max rate.
  @Prop({ default: 0 }) allowanceDistanceThreshold: number; // km
  @Prop({ default: 0 }) allowanceBaseRate: number;  // flat, short one-way
  @Prop({ default: 0 }) allowanceMaxRate: number;   // flat cap, long one-way
  @Prop({ default: 4 }) seats: number;
  @Prop({ default: '' }) bags: string; // e.g. "1 Small bag"
  // Round-trip rental: included km PER DAY (0 = no per-day limit / unlimited).
  @Prop({ default: 0 }) dailyKmLimit: number;
  // ₹ charged per km beyond the included allowance (GPS-measured on the trip).
  @Prop({ default: 0 }) extraKmPrice: number;
  // ── Local (in-city hourly package) pricing ─────────────────────────────────
  // Km included per hour of a Local package (e.g. 10 → an 8-hour package = 80 km).
  // 0 = Local packages not offered for this cab. Package fare = includedKm × per-km rate.
  @Prop({ default: 0 }) packageKmPerHour: number;
  // ₹ charged per hour beyond the booked Local package (admin-managed).
  @Prop({ default: 0 }) extraHourPrice: number;
  // Per-cab info shown as tabs on the customer Confirm Booking screen.
  @Prop({ type: [String], default: [] }) inclusions: string[];
  @Prop({ type: [String], default: [] }) exclusions: string[];
  @Prop({ type: [String], default: [] }) facilities: string[];
  @Prop({ type: [String], default: [] }) terms: string[];
  @Prop({ default: 0 }) order: number;
  @Prop({ default: true }) isActive: boolean;
}
export const CabCategorySchema = SchemaFactory.createForClass(CabCategory);
CabCategorySchema.index({ isActive: 1, order: 1 });
