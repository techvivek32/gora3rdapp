import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document, Types } from 'mongoose';

export type PoolRideDocument = PoolRide & Document;

export enum PoolRideStatus {
  ACTIVE = 'active', // posted, accepting bookings
  STARTED = 'started', // ride in progress
  COMPLETED = 'completed',
  CANCELLED = 'cancelled',
}

export enum SeatBookingStatus {
  CONFIRMED = 'confirmed',
  PICKED = 'picked', // passenger picked up
  COMPLETED = 'completed',
  CANCELLED = 'cancelled',
}

/// One passenger's seat booking on a pool ride (embedded subdoc; _id used as bookingId).
@Schema({ _id: true, timestamps: true })
export class SeatBooking {
  @Prop({ type: Types.ObjectId, ref: 'User', required: true })
  passengerId: Types.ObjectId;

  @Prop({ default: '' }) passengerName: string;
  @Prop({ default: '' }) passengerMobile: string;
  @Prop({ default: '' }) passengerImage: string;

  @Prop({ default: 1 }) seats: number;
  @Prop({ default: 0 }) amount: number; // seats * pricePerSeat snapshot
  @Prop({ default: '' }) pickupPoint: string;

  @Prop({ type: String, enum: SeatBookingStatus, default: SeatBookingStatus.CONFIRMED })
  status: SeatBookingStatus;

  @Prop({ min: 0, max: 5 }) rating: number;
  @Prop({ default: '' }) review: string;
}
export const SeatBookingSchema = SchemaFactory.createForClass(SeatBooking);

@Schema({ timestamps: true, collection: 'poolRides' })
export class PoolRide {
  @Prop({ required: true, unique: true, index: true }) rideId: string;

  @Prop({ type: Types.ObjectId, ref: 'User', required: true, index: true })
  driverId: Types.ObjectId;

  @Prop({ type: Object }) from: { address?: string; lat?: number; lng?: number };
  @Prop({ type: Object }) to: { address?: string; lat?: number; lng?: number };
  @Prop({ default: '', index: true }) fromCity: string;
  @Prop({ default: '', index: true }) toCity: string;

  @Prop() travelDate: Date;
  @Prop({ default: '' }) departureTime: string;

  @Prop({ default: 1 }) totalSeats: number;
  @Prop({ default: 1 }) seatsAvailable: number;
  @Prop({ default: 0 }) pricePerSeat: number;

  @Prop({ default: '' }) vehicle: string;
  @Prop({ default: '' }) vehicleNumber: string;

  @Prop({ default: 0 }) distanceKm: number;
  @Prop({ default: '' }) notes: string;

  @Prop({ type: String, enum: PoolRideStatus, default: PoolRideStatus.ACTIVE, index: true })
  status: PoolRideStatus;

  @Prop({ type: [SeatBookingSchema], default: [] }) bookings: SeatBooking[];

  @Prop({ type: Object })
  driverSnapshot: { name?: string; phone?: string; rating?: number; vehicle?: string; vehicleNumber?: string };

  @Prop() startedAt: Date;
  @Prop() completedAt: Date;
  @Prop({ default: 0 }) distanceTravelled: number; // km, set on complete
  @Prop({ default: 0 }) totalEarning: number; // computed on completion (report only)
  @Prop() expiresAt: Date;
}
export const PoolRideSchema = SchemaFactory.createForClass(PoolRide);
PoolRideSchema.index({ driverId: 1, createdAt: -1 });
PoolRideSchema.index({ status: 1, travelDate: 1 });
PoolRideSchema.index({ fromCity: 1, toCity: 1, status: 1 });
