import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document, Types } from 'mongoose';

export enum NotificationType {
  NEW_REQUIREMENT = 'new_requirement',
  NEW_VEHICLE = 'new_vehicle',
  REQUIREMENT_POSTED = 'requirement_posted',
  VEHICLE_POSTED = 'vehicle_posted',
  REQUIREMENT_ACCEPTED = 'requirement_accepted',
  VEHICLE_BOOKED = 'vehicle_booked',
  NEW_MESSAGE = 'new_message',
  MEMBERSHIP_EXPIRY = 'membership_expiry',
  MEMBERSHIP_RENEWED = 'membership_renewed',
  PAYMENT_SUCCESS = 'payment_success',
  PAYMENT_FAILED = 'payment_failed',
  PROFILE_VERIFIED = 'profile_verified',
  SYSTEM = 'system',
  PROMOTIONAL = 'promotional',
}

export type NotificationDocument = Notification & Document;

@Schema({ timestamps: true, collection: 'notifications' })
export class Notification {
  @Prop({ type: Types.ObjectId, ref: 'User' })
  userId: Types.ObjectId;

  @Prop({ required: true })
  title: string;

  @Prop({ required: true })
  body: string;

  @Prop({ type: String, enum: NotificationType, required: true })
  type: NotificationType;

  @Prop({ type: Object, default: {} })
  data: Record<string, any>;

  @Prop({ default: false })
  isRead: boolean;

  @Prop()
  readAt: Date;

  @Prop({ default: false })
  isSent: boolean;

  @Prop()
  sentAt: Date;

  @Prop({ type: [String], default: [] })
  targetTokens: string[];

  @Prop({ default: false })
  isGlobal: boolean;

  @Prop({ type: [String], default: [] })
  targetCities: string[];

  @Prop({ type: [String], default: [] })
  targetMemberships: string[];

  /** Audience roles ('driver' | 'travel_agency'). Empty = every role. */
  @Prop({ type: [String], default: [] })
  targetRoles: string[];

  @Prop()
  imageUrl: string;

  @Prop()
  actionUrl: string;

  @Prop({ type: Date })
  scheduledAt: Date;
}

export const NotificationSchema = SchemaFactory.createForClass(Notification);

NotificationSchema.index({ userId: 1, isRead: 1, createdAt: -1 });
NotificationSchema.index({ type: 1, createdAt: -1 });
NotificationSchema.index({ isGlobal: 1, isSent: 1 });
NotificationSchema.index({ userId: 1, createdAt: -1 });
NotificationSchema.index({ scheduledAt: 1, isSent: 1 });
