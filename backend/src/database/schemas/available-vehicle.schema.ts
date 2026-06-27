import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document, Types } from 'mongoose';
import { VehicleType, AvailabilityStatus } from '../../common/enums/vehicle-type.enum';

export type AvailableVehicleDocument = AvailableVehicle & Document;

@Schema({ timestamps: true, collection: 'availableVehicles' })
export class AvailableVehicle {
  @Prop({ required: true, unique: true })
  listingId: string;

  @Prop({ type: Types.ObjectId, ref: 'User', required: true })
  postedBy: Types.ObjectId;

  @Prop({ required: true, trim: true })
  currentCity: string;

  @Prop({ trim: true })
  destinationCity: string;

  @Prop({ trim: true })
  currentState: string;

  @Prop({ type: String, enum: VehicleType, required: true })
  vehicleType: VehicleType;

  @Prop({ trim: true, uppercase: true })
  vehicleNumber: string;

  @Prop({ trim: true })
  driverName: string;

  @Prop({ trim: true })
  driverMobile: string;

  @Prop({ required: true, type: Date })
  availableDate: Date;

  @Prop({ required: true })
  availableTime: string;

  @Prop({ trim: true })
  notes: string;

  @Prop({ type: String, enum: AvailabilityStatus, default: AvailabilityStatus.AVAILABLE })
  status: AvailabilityStatus;

  @Prop({ default: false })
  isFeatured: boolean;

  @Prop({ default: 0 })
  viewCount: number;

  @Prop({ default: 0 })
  contactViewCount: number;

  @Prop({ type: Object })
  currentCoordinates: {
    lat: number;
    lng: number;
    address?: string;
  };

  @Prop({ type: Object })
  destinationCoordinates: {
    lat: number;
    lng: number;
    address?: string;
  };

  @Prop({ type: Number })
  estimatedDistance: number;

  @Prop({ type: Number, default: 0 })
  fare: number;

  @Prop({ type: Number, default: 0 })
  commission: number;

  @Prop({ type: Number, default: 0 })
  totalAmount: number;

  @Prop({ type: [{ type: Types.ObjectId, ref: 'User' }], default: [] })
  interestedUsers: Types.ObjectId[];

  @Prop({ type: [{ type: Types.ObjectId, ref: 'User' }], default: [] })
  acceptedBy: Types.ObjectId[];

  @Prop({ type: Date })
  expiresAt: Date;

  @Prop({ default: false })
  isDeleted: boolean;

  @Prop()
  deletedAt: Date;

  @Prop({ trim: true })
  cancellationReason: string;

  @Prop()
  cancelledAt: Date;

  @Prop()
  vehicleModel: string;

  @Prop()
  vehicleColor: string;

  @Prop({ default: 0, min: 0, max: 5 })
  driverRating: number;
}

export const AvailableVehicleSchema = SchemaFactory.createForClass(AvailableVehicle);

AvailableVehicleSchema.index({ listingId: 1 }, { unique: true });
AvailableVehicleSchema.index({ postedBy: 1, status: 1 });
AvailableVehicleSchema.index({ currentCity: 1, status: 1, availableDate: 1 });
AvailableVehicleSchema.index({ vehicleType: 1, status: 1 });
AvailableVehicleSchema.index({ vehicleNumber: 1 });
AvailableVehicleSchema.index({ status: 1, createdAt: -1 });
AvailableVehicleSchema.index({ isDeleted: 1, status: 1 });
AvailableVehicleSchema.index({ isFeatured: -1, createdAt: -1 });
AvailableVehicleSchema.index({ currentCity: 'text', destinationCity: 'text', driverName: 'text' });
