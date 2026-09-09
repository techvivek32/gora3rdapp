import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document, Types } from 'mongoose';

export type CustomerBookingDocument = CustomerBooking & Document;

/** Service families a customer can book. New services (hotel, bus, rental…) are
 *  added here without touching the booking flow — everything is keyed by this. */
export enum CustomerServiceType {
  CAB = 'cab',
  HIRE_DRIVER = 'hire_driver',
  LUXURY = 'luxury',
  CAR_POOL = 'car_pool',
}

export enum CustomerBookingStatus {
  OPEN = 'open', // waiting for driver/vendor offers
  CONFIRMED = 'confirmed', // customer selected one
  ONGOING = 'ongoing', // trip started
  COMPLETED = 'completed',
  CANCELLED = 'cancelled',
  EXPIRED = 'expired',
}

/** A driver/vendor application (quote), each backed by a wallet hold. */
@Schema({ _id: true, timestamps: true })
export class BookingOffer {
  @Prop({ type: Types.ObjectId, ref: 'User', required: true })
  driverId: Types.ObjectId;

  @Prop({ default: 0 })
  quotedFare: number;

  /** Amount held in the driver's wallet against this application. */
  @Prop({ default: 0 })
  holdAmount: number;

  @Prop({ default: '' })
  vehicle: string;

  @Prop({ default: '' })
  vehicleNumber: string;

  /** Optional photo of the offered vehicle, shown to the customer. */
  @Prop({ default: '' })
  vehicleImage: string;

  @Prop({ default: '' })
  message: string;

  // Car Pooling: per-seat pricing + how many seats this driver can offer.
  @Prop({ default: 0 })
  farePerSeat: number;

  @Prop({ default: 0 })
  seatsAvailable: number;

  @Prop({ type: String, enum: ['applied', 'selected', 'released'], default: 'applied' })
  status: string;
}
export const BookingOfferSchema = SchemaFactory.createForClass(BookingOffer);

@Schema({ timestamps: true, collection: 'customerBookings' })
export class CustomerBooking {
  @Prop({ required: true, unique: true, index: true })
  bookingId: string;

  @Prop({ type: Types.ObjectId, ref: 'User', required: true, index: true })
  customerId: Types.ObjectId;

  @Prop({ type: String, enum: CustomerServiceType, required: true, index: true })
  serviceType: CustomerServiceType;

  /** Sub-option within a service (one_way / round_trip / airport / local, or
   *  hourly / full_day / outstation…). Free-form so services stay configurable. */
  @Prop({ default: '' })
  subType: string;

  @Prop({ type: Object }) pickup: { address?: string; lat?: number; lng?: number };
  @Prop({ type: Object }) drop: { address?: string; lat?: number; lng?: number };
  @Prop({ type: [{ type: Object }], default: [] })
  stops: { address?: string; lat?: number; lng?: number }[];

  @Prop() pickupCity: string;
  @Prop() dropCity: string;

  @Prop() travelDate: Date;
  @Prop() travelTime: string;

  @Prop({ default: 1 }) passengers: number;
  @Prop({ default: '' }) vehicleType: string;
  @Prop({ default: 0 }) durationHours: number; // Hire-a-Driver
  @Prop({ default: '' }) notes: string;

  @Prop({ default: 0 }) estimatedFare: number;
  @Prop({ default: 0 }) estimatedDistance: number;

  @Prop({ type: String, enum: CustomerBookingStatus, default: CustomerBookingStatus.OPEN, index: true })
  status: CustomerBookingStatus;

  @Prop({ type: [BookingOfferSchema], default: [] })
  offers: BookingOffer[];

  // Set once the customer picks a driver.
  @Prop({ type: Types.ObjectId, ref: 'User' }) selectedDriverId: Types.ObjectId;
  @Prop() finalFare: number;

  // Commitment snapshot (percent of fare a driver must hold to apply).
  @Prop({ default: 0 }) commitmentPercent: number;

  // Driver contact snapshot shown to the customer after confirm.
  @Prop({ type: Object })
  driverSnapshot: { name?: string; phone?: string; vehicle?: string; vehicleNumber?: string; rating?: number };

  // Trip start/end OTP handshake: the driver requests an OTP, it's shown to the
  // CUSTOMER (in-app), the customer reads it out, the driver enters it. That
  // proves the two are actually together. `select:false` so it never leaks into
  // driver-facing responses.
  @Prop({ select: false }) tripOtp: string;
  @Prop({ select: false }) tripOtpAction: string; // 'start' | 'end'
  @Prop({ select: false }) tripOtpExpiresAt: Date;

  @Prop() confirmedAt: Date;
  @Prop() driverArrivedAt: Date; // set when the driver marks "arriving"
  @Prop() startedAt: Date;
  @Prop() completedAt: Date;
  @Prop() cancelledAt: Date;
  @Prop() cancelledBy: string; // 'customer' | 'driver'
  @Prop({ default: '' }) cancelReason: string;

  @Prop({ min: 0, max: 5 }) rating: number;
  @Prop({ default: '' }) review: string;

  @Prop() expiresAt: Date;
}

export const CustomerBookingSchema = SchemaFactory.createForClass(CustomerBooking);
CustomerBookingSchema.index({ customerId: 1, createdAt: -1 });
CustomerBookingSchema.index({ serviceType: 1, status: 1, createdAt: -1 });
