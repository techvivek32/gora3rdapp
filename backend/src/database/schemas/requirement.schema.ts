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

  // Clean city name (e.g. "Ahmedabad") used for business-city matching, distinct
  // from pickupCity which holds the detailed display address.
  @Prop({ trim: true })
  pickupCityName: string;

  @Prop({ trim: true })
  dropCityName: string;

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

  @Prop({ type: String, default: 'any' })
  fuelType: string;

  @Prop({ required: true, type: Date })
  travelDate: Date;

  @Prop({ required: true })
  travelTime: string;

  // Round-trip return date/time (optional).
  @Prop({ type: Date })
  returnDate: Date;

  @Prop()
  returnTime: string;

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

  // true when the poster used the app-suggested fare (vs typing a custom one).
  @Prop({ type: Boolean })
  isAppSuggested: boolean;

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

  /** The driver the owner handed this booking to. Set via POST :id/assign. */
  @Prop({ type: Types.ObjectId, ref: 'User', index: true })
  assignedDriver: Types.ObjectId;

  @Prop({ type: Date })
  assignedAt: Date;

  /**
   * Trip lifecycle for an assigned booking. The driver requests an OTP, it is
   * delivered to the *owner*, who reads it out; the driver enters it to proceed.
   *   pending → started → completed
   */
  @Prop({ type: String, enum: ['pending', 'started', 'completed'], default: 'pending' })
  tripStatus: string;

  /**
   * The OTP currently awaiting entry, and which action it authorises.
   *
   * `select: false` is load-bearing, not tidiness: the driver reads this very
   * document from /assigned-to-me, so a returned OTP would let them start the
   * trip without ever speaking to the owner — defeating the whole handshake.
   * Server-side reads must opt in with .select('+tripOtp').
   */
  @Prop({ select: false })
  tripOtp: string;

  @Prop({ type: String, enum: ['start', 'end'], select: false })
  tripOtpAction: string;

  @Prop({ type: Date, select: false })
  tripOtpExpiresAt: Date;

  @Prop({ type: Date })
  tripStartedAt: Date;

  @Prop({ type: Date })
  tripCompletedAt: Date;

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
