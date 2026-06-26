import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document, Types } from 'mongoose';
import { VehicleType, TripType, BookingStatus } from '../../common/enums/vehicle-type.enum';

export type RequirementDocument = Requirement & Document;

@Schema({ timestamps: true, collection: 'requirements' })
export class Requirement {
  @Prop({ required: true, unique: true })
  bookingId: string;

  @Prop({ required: true, unique: true })
  requirementId: string;

  @Prop({ type: Types.ObjectId, ref: 'User', required: true })
  postedBy: Types.ObjectId;

  @Prop({ required: true, trim: true })
  pickupCity: string;

  @Prop({ required: true, trim: true })
  dropCity: string;

  @Prop()
  pickupState: string;

  @Prop()
  dropState: string;

  @Prop({ type: Object })
  pickupCoordinates: {
    lat: number;
    lng: number;
    address: string;
  };

  @Prop({ type: Object })
  dropCoordinates: {
    lat: number;
    lng: number;
    address: string;
  };

  // Intermediate stops between pickup and drop.
  @Prop({ type: [Object], default: [] })
  stops: { address?: string; lat?: number; lng?: number }[];

  @Prop({ type: String, enum: VehicleType, required: true })
  vehicleType: VehicleType;

  @Prop({ type: String, enum: TripType, required: true })
  tripType: TripType;

  @Prop({ required: true, type: Date })
  travelDate: Date;

  @Prop({ required: true })
  travelTime: string;

  @Prop({ default: 1, min: 1 })
  numberOfVehicles: number;

  @Prop({ type: Number })
  estimatedDistance: number;

  @Prop({ type: Number, default: 0 })
  fare: number;

  @Prop({ type: Number, default: 0 })
  commission: number;

  @Prop({ type: Number, default: 0 })
  totalAmount: number;

  @Prop({ trim: true })
  notes: string;

  @Prop({ type: String, enum: BookingStatus, default: BookingStatus.ACTIVE })
  status: BookingStatus;

  @Prop({ default: false })
  isFeatured: boolean;

  @Prop({ default: 0 })
  viewCount: number;

  @Prop({ default: 0 })
  contactViewCount: number;

  @Prop({ type: [{ type: Types.ObjectId, ref: 'User' }], default: [] })
  acceptedBy: Types.ObjectId[];

  @Prop({ type: [{ type: Types.ObjectId, ref: 'User' }], default: [] })
  interestedUsers: Types.ObjectId[];

  @Prop({ type: Date })
  expiresAt: Date;

  @Prop()
  voiceNoteUrl: string;

  @Prop({ default: false })
  isDeleted: boolean;

  @Prop()
  deletedAt: Date;

  @Prop({ type: String })
  deletedBy: string;

  @Prop()
  cancellationReason: string;

  @Prop()
  cancelledAt: Date;
}

export const RequirementSchema = SchemaFactory.createForClass(Requirement);

RequirementSchema.index({ bookingId: 1 }, { unique: true });
RequirementSchema.index({ requirementId: 1 }, { unique: true });
RequirementSchema.index({ postedBy: 1, status: 1 });
RequirementSchema.index({ pickupCity: 1, status: 1, travelDate: 1 });
RequirementSchema.index({ dropCity: 1, status: 1 });
RequirementSchema.index({ vehicleType: 1, tripType: 1 });
RequirementSchema.index({ status: 1, createdAt: -1 });
RequirementSchema.index({ travelDate: 1, status: 1 });
RequirementSchema.index({ isDeleted: 1, status: 1 });
RequirementSchema.index({ isFeatured: -1, createdAt: -1 });
RequirementSchema.index({ pickupCity: 'text', dropCity: 'text', notes: 'text' });
