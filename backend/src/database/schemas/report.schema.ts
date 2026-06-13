import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document, Types } from 'mongoose';

export enum ReportReason {
  SPAM = 'spam',
  FAKE_REQUIREMENT = 'fake_requirement',
  FAKE_VEHICLE = 'fake_vehicle',
  FRAUD_USER = 'fraud_user',
  ABUSE = 'abuse',
  INAPPROPRIATE = 'inappropriate',
  OTHER = 'other',
}

export enum ReportStatus {
  PENDING = 'pending',
  INVESTIGATING = 'investigating',
  RESOLVED = 'resolved',
  DISMISSED = 'dismissed',
}

export enum ReportTargetType {
  USER = 'user',
  REQUIREMENT = 'requirement',
  VEHICLE = 'vehicle',
  MESSAGE = 'message',
}

export type ReportDocument = Report & Document;

@Schema({ timestamps: true, collection: 'reports' })
export class Report {
  @Prop({ type: Types.ObjectId, ref: 'User', required: true })
  reportedBy: Types.ObjectId;

  @Prop({ type: Types.ObjectId, required: true })
  targetId: Types.ObjectId;

  @Prop({ type: String, enum: ReportTargetType, required: true })
  targetType: ReportTargetType;

  @Prop({ type: String, enum: ReportReason, required: true })
  reason: ReportReason;

  @Prop()
  description: string;

  @Prop({ type: [String], default: [] })
  evidenceUrls: string[];

  @Prop({ type: String, enum: ReportStatus, default: ReportStatus.PENDING })
  status: ReportStatus;

  @Prop({ type: Types.ObjectId, ref: 'User' })
  reviewedBy: Types.ObjectId;

  @Prop()
  reviewedAt: Date;

  @Prop()
  adminNotes: string;

  @Prop()
  actionTaken: string;
}

export const ReportSchema = SchemaFactory.createForClass(Report);

ReportSchema.index({ reportedBy: 1, status: 1 });
ReportSchema.index({ targetId: 1, targetType: 1 });
ReportSchema.index({ status: 1, createdAt: -1 });
