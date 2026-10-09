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

  // The actual person who will drive, chosen from the accepting owner's "My
  // Drivers" garage (may differ from the account holder who accepted).
  @Prop({ default: '' })
  assignedDriverName: string;

  @Prop({ default: '' })
  assignedDriverPhone: string;

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

  // Trip end (round-trip return / general trip end). Optional.
  @Prop() tripEndDate: Date;
  @Prop() tripEndTime: string;

  @Prop({ default: 1 }) passengers: number;
  @Prop({ default: '' }) vehicleType: string;
  @Prop({ default: 0 }) durationHours: number; // Hire-a-Driver
  @Prop({ default: '' }) notes: string;

  @Prop({ default: 0 }) estimatedFare: number; // customer-facing total (incl. GST)
  // Fare breakdown, snapshotted at booking time so the driver side can show a
  // GST-exclusive amount and later GST-% changes don't rewrite old bookings.
  @Prop({ default: 0 }) baseFare: number;
  @Prop({ default: 0 }) driverAllowance: number;
  @Prop({ default: 0 }) gstAmount: number;
  @Prop({ default: 0 }) estimatedDistance: number;

  // ── Round-trip GPS km tracking + extra-km billing ──────────────────────────
  // Snapshot of the cab's rental limits at accept time (so later admin edits
  // don't change an in-progress trip).
  @Prop({ default: 0 }) dailyKmLimit: number;
  @Prop({ default: 0 }) extraKmPrice: number;
  // Included allowance for this trip (dailyKmLimit × days). 0 = no extra tracking.
  @Prop({ default: 0 }) includedKm: number;
  // Live GPS-measured distance the driver has actually travelled (km).
  @Prop({ default: 0 }) trackedKm: number;
  // Finalised at trip completion.
  @Prop({ default: 0 }) extraKm: number;
  @Prop({ default: 0 }) extraCharge: number;

  // Trip-start verification photos the driver captures (camera only) right after
  // the start OTP: the car's front and the driver seated inside with the rider.
  @Prop({ default: '' }) startCarPhoto: string;
  @Prop({ default: '' }) startDriverPhoto: string;

  // ── Local (in-city hourly package) billing ─────────────────────────────────
  // Booked package length in hours (6/8/10/12). 0 = not a Local package booking.
  @Prop({ default: 0 }) packageHours: number;
  // ₹ charged per hour beyond the package (snapshot from the cab at booking time).
  @Prop({ default: 0 }) extraHourPrice: number;
  // Finalised at completion: hours used beyond the package × extraHourPrice.
  @Prop({ default: 0 }) extraHours: number;
  @Prop({ default: 0 }) extraHourCharge: number;

  // ── Driver-entered trip-end charges (cab bookings) ─────────────────────────
  // Entered by the driver on the final-bill screen after the drop OTP; each is
  // added to the balance the customer pays in cash. No tax line.
  @Prop({ default: 0 }) tollCharge: number;
  @Prop({ default: 0 }) parkingCharge: number;
  @Prop({ default: 0 }) otherCharge: number;
  // Agreed base fare captured at completion (before trip extras & driver charges)
  // so re-submitting charges recomputes finalFare deterministically.
  @Prop({ default: 0 }) tripFare: number;
  // Set when the driver saves the trip-end charges. Charges can be saved ONCE —
  // once this is set, further edits are rejected and the app shows them read-only.
  @Prop() tripChargesSavedAt: Date;

  @Prop({ type: String, enum: CustomerBookingStatus, default: CustomerBookingStatus.OPEN, index: true })
  status: CustomerBookingStatus;

  @Prop({ type: [BookingOfferSchema], default: [] })
  offers: BookingOffer[];

  // Set once the customer picks a driver.
  @Prop({ type: Types.ObjectId, ref: 'User' }) selectedDriverId: Types.ObjectId;
  // Last-10 digits of the actual driver's phone (the garage driver the owner
  // assigned — may differ from the accepting account, and may not have an account
  // yet). Lets that driver see & run the trip from their own login, matched by
  // phone, even if they register only after being assigned.
  @Prop({ default: '', index: true }) assignedDriverPhone: string;
  @Prop() finalFare: number;

  // Commitment snapshot (percent of fare a driver must hold to apply).
  @Prop({ default: 0 }) commitmentPercent: number;

  // ── Advance payment (customer pays 10% / 100% to the platform on booking) ──
  @Prop({ default: 0 }) advancePercent: number;   // 0 = pay later
  @Prop({ default: 0 }) advanceAmount: number;     // ₹ actually paid
  @Prop({ type: String, enum: ['none', 'paid'], default: 'none' }) advanceStatus: string;
  @Prop({ type: Types.ObjectId, ref: 'Payment' }) advancePaymentId: Types.ObjectId;
  // Set once the advance is released to the driver's wallet on trip completion.
  @Prop() advanceReleasedAt: Date;

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
