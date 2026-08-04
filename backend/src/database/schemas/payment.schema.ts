import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document, Types } from 'mongoose';

export enum PaymentStatus {
  PENDING = 'pending',
  SUCCESS = 'success',
  FAILED = 'failed',
  REFUNDED = 'refunded',
  CANCELLED = 'cancelled',
}

export enum PaymentMethod {
  UPI = 'upi',
  CARD = 'card',
  NETBANKING = 'netbanking',
  WALLET = 'wallet',
  MANUAL = 'manual',
  RAZORPAY = 'razorpay',
}

export type PaymentDocument = Payment & Document;

@Schema({ timestamps: true, collection: 'payments' })
export class Payment {
  @Prop({ required: true, unique: true })
  orderId: string;

  @Prop({ type: Types.ObjectId, ref: 'User', required: true })
  userId: Types.ObjectId;

  @Prop({ type: Types.ObjectId, ref: 'SubscriptionPlan' })
  planId: Types.ObjectId;

  @Prop({ required: true, min: 0 })
  amount: number;

  @Prop({ default: 'INR' })
  currency: string;

  @Prop({ type: String, enum: PaymentStatus, default: PaymentStatus.PENDING })
  status: PaymentStatus;

  @Prop({ type: String, enum: PaymentMethod })
  method: PaymentMethod;

  @Prop()
  razorpayOrderId: string;

  @Prop()
  razorpayPaymentId: string;

  @Prop()
  razorpaySignature: string;

  // Razorpay QR Code id (qr_xxx) for the "Pay by QR" flow. Payment is confirmed
  // out-of-band via the qr_code.credited webhook, matched back on this id.
  @Prop()
  razorpayQrId: string;

  @Prop({ type: Object })
  metadata: Record<string, any>;

  @Prop()
  failureReason: string;

  @Prop()
  refundId: string;

  @Prop()
  refundedAt: Date;

  @Prop()
  invoiceUrl: string;

  @Prop({ default: false })
  isManualApproval: boolean;

  @Prop({ type: Types.ObjectId, ref: 'User' })
  approvedBy: Types.ObjectId;

  @Prop()
  approvedAt: Date;

  @Prop()
  notes: string;
}

export const PaymentSchema = SchemaFactory.createForClass(Payment);

PaymentSchema.index({ orderId: 1 }, { unique: true });
PaymentSchema.index({ userId: 1, status: 1, createdAt: -1 });
PaymentSchema.index({ razorpayOrderId: 1 });
PaymentSchema.index({ razorpayPaymentId: 1 });
PaymentSchema.index({ razorpayQrId: 1 });
PaymentSchema.index({ status: 1, createdAt: -1 });
