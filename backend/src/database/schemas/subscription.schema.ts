import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document, Types } from 'mongoose';
import { MembershipType } from '../../common/enums/user-role.enum';

export type SubscriptionPlanDocument = SubscriptionPlan & Document;

export enum PlanDuration {
  MONTHLY = 'monthly',
  QUARTERLY = 'quarterly',
  HALF_YEARLY = 'half_yearly',
  YEARLY = 'yearly',
}

@Schema({ timestamps: true, collection: 'subscriptionPlans' })
export class SubscriptionPlan {
  @Prop({ required: true, trim: true })
  name: string;

  @Prop({ trim: true })
  description: string;

  @Prop({ type: String, enum: MembershipType, required: true })
  membershipType: MembershipType;

  // Free-form duration label (e.g. '1_day', '1_month', '3_months'). Not enum-
  // constrained: the actual validity is driven by `durationDays`, and the admin
  // can create any duration — including a 24-hour (1-day) plan.
  @Prop({ type: String, required: true })
  duration: string;

  @Prop({ required: true, min: 0 })
  price: number;

  @Prop({ default: 0 })
  discountedPrice: number;

  @Prop({ required: true })
  durationDays: number;

  @Prop({ type: [String], default: [] })
  features: string[];

  @Prop({ default: true })
  isActive: boolean;

  @Prop({ default: false })
  isPopular: boolean;

  @Prop({ default: 0 })
  sortOrder: number;

  @Prop({ type: Object })
  razorpayPlanId: string;
}

export const SubscriptionPlanSchema = SchemaFactory.createForClass(SubscriptionPlan);

export type SubscriptionDocument = Subscription & Document;

export enum SubscriptionStatus {
  ACTIVE = 'active',
  EXPIRED = 'expired',
  CANCELLED = 'cancelled',
  PENDING = 'pending',
}

@Schema({ timestamps: true, collection: 'subscriptions' })
export class Subscription {
  @Prop({ type: Types.ObjectId, ref: 'User', required: true })
  userId: Types.ObjectId;

  @Prop({ type: Types.ObjectId, ref: 'SubscriptionPlan', required: true })
  planId: Types.ObjectId;

  @Prop({ type: String, enum: SubscriptionStatus, default: SubscriptionStatus.PENDING })
  status: SubscriptionStatus;

  @Prop({ required: true, type: Date })
  startDate: Date;

  @Prop({ required: true, type: Date })
  endDate: Date;

  @Prop({ required: true })
  amount: number;

  @Prop({ type: Types.ObjectId, ref: 'Payment' })
  paymentId: Types.ObjectId;

  @Prop()
  razorpaySubscriptionId: string;

  @Prop({ type: String, enum: MembershipType })
  membershipType: MembershipType;

  @Prop({ default: false })
  isAutoRenew: boolean;
}

export const SubscriptionSchema = SchemaFactory.createForClass(Subscription);

SubscriptionSchema.index({ userId: 1, status: 1 });
SubscriptionSchema.index({ endDate: 1, status: 1 });
SubscriptionSchema.index({ userId: 1, endDate: -1 });
