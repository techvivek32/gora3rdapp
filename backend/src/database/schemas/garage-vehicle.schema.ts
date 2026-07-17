import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document, Types } from 'mongoose';

export type GarageVehicleDocument = GarageVehicle & Document;

/**
 * A vehicle saved in a user's "My Vehicles" garage. Distinct from AvailableVehicle
 * (a public listing for a specific trip) — this is a reusable profile of a car the
 * user owns, so they can pick it when posting rather than retyping the details.
 */
@Schema({ timestamps: true, collection: 'garageVehicles' })
export class GarageVehicle {
  @Prop({ type: Types.ObjectId, ref: 'User', required: true, index: true })
  userId: Types.ObjectId;

  /** One of kVehicleTypes / VehicleType values, e.g. "crysta". */
  @Prop({ required: true, trim: true })
  vehicleType: string;

  /** Free-text model, e.g. "Toyota Innova Crysta 2022". */
  @Prop({ trim: true })
  modelName: string;

  @Prop({ trim: true, uppercase: true })
  registrationNumber: string;

  /** any | petrol | diesel | cng | electric */
  @Prop({ trim: true, default: 'any' })
  fuelType: string;

  @Prop({ type: Number, min: 1, max: 60 })
  seatingCapacity: number;

  @Prop({ trim: true })
  color: string;

  @Prop({ trim: true })
  notes: string;
}

export const GarageVehicleSchema = SchemaFactory.createForClass(GarageVehicle);

GarageVehicleSchema.index({ userId: 1, createdAt: -1 });
