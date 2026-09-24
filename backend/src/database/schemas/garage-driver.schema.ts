import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document, Types } from 'mongoose';

export type GarageDriverDocument = GarageDriver & Document;

/**
 * A driver saved in a user's "My Drivers" list (sits beside "My Vehicles" in the
 * garage). A reusable profile of a driver the owner employs, so they can pick one
 * when posting/assigning rather than retyping the details.
 */
@Schema({ timestamps: true, collection: 'garageDrivers' })
export class GarageDriver {
  @Prop({ type: Types.ObjectId, ref: 'User', required: true, index: true })
  userId: Types.ObjectId;

  @Prop({ required: true, trim: true })
  fullName: string;

  @Prop({ trim: true })
  phone: string;

  /** Driving licence number. */
  @Prop({ trim: true, uppercase: true })
  dlNumber: string;

  /** Aadhaar number. */
  @Prop({ trim: true })
  aadharNumber: string;

  @Prop({ trim: true })
  address: string;

  /** Driver's photo (uploaded image URL). */
  @Prop({ trim: true })
  photo: string;

  /** Driving licence document images (front & back). */
  @Prop({ trim: true })
  dlFrontImage: string;

  @Prop({ trim: true })
  dlBackImage: string;

  /** Aadhaar document images (front & back). */
  @Prop({ trim: true })
  aadharFrontImage: string;

  @Prop({ trim: true })
  aadharBackImage: string;

  @Prop({ trim: true })
  notes: string;
}

export const GarageDriverSchema = SchemaFactory.createForClass(GarageDriver);

GarageDriverSchema.index({ userId: 1, createdAt: -1 });
