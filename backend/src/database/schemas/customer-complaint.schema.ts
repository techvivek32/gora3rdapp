import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document, Types } from 'mongoose';

export type CustomerComplaintDocument = CustomerComplaint & Document;

/** Fixed set of complaint reasons the customer can pick (spec §18). */
export enum ComplaintCategory {
  DRIVER_NO_SHOW = 'driver_no_show',
  OVERCHARGED = 'overcharged',
  VEHICLE_PROBLEM = 'vehicle_problem',
  BOOKING_CANCELLED = 'booking_cancelled',
  PAYMENT_PROBLEM = 'payment_problem',
  WRONG_FARE = 'wrong_fare',
  OTHER = 'other',
}

export enum ComplaintStatus {
  OPEN = 'open',
  IN_PROGRESS = 'in_progress',
  RESOLVED = 'resolved',
}

@Schema({ timestamps: true, collection: 'customerComplaints' })
export class CustomerComplaint {
  @Prop({ type: Types.ObjectId, ref: 'User', required: true, index: true })
  customerId: Types.ObjectId;

  @Prop({ type: String, enum: ComplaintCategory, required: true })
  category: ComplaintCategory;

  @Prop({ default: '' })
  message: string;

  /** Optional booking this complaint is about. */
  @Prop({ type: Types.ObjectId, ref: 'CustomerBooking' })
  bookingRef: Types.ObjectId;

  @Prop({ default: '' })
  bookingId: string;

  @Prop({ type: String, enum: ComplaintStatus, default: ComplaintStatus.OPEN, index: true })
  status: ComplaintStatus;

  /** Admin's reply/resolution note. */
  @Prop({ default: '' })
  adminNote: string;
}

export const CustomerComplaintSchema = SchemaFactory.createForClass(CustomerComplaint);
