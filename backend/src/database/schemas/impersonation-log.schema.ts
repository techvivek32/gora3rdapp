import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document, Types } from 'mongoose';

export type ImpersonationLogDocument = ImpersonationLog & Document;

/**
 * Audit trail for "Login As Franchise" (super-admin impersonation). One row per
 * session: created when impersonation starts, closed (endTime + duration) when the
 * admin exits (or is auto-closed on the next start for the same pair as a fallback).
 */
@Schema({ timestamps: true, collection: 'impersonation_logs' })
export class ImpersonationLog {
  @Prop({ type: Types.ObjectId, ref: 'User', required: true, index: true })
  adminId: Types.ObjectId;

  @Prop({ trim: true })
  adminName: string;

  @Prop({ type: Types.ObjectId, ref: 'Franchise', required: true, index: true })
  franchiseId: Types.ObjectId;

  @Prop({ trim: true })
  franchiseName: string;

  @Prop({ trim: true })
  ipAddress: string;

  @Prop({ trim: true })
  browser: string;

  @Prop({ trim: true })
  os: string;

  @Prop({ trim: true })
  userAgent: string;

  @Prop({ type: Date, default: Date.now })
  startTime: Date;

  @Prop({ type: Date })
  endTime?: Date;

  /** Session length in seconds, filled when the session is closed. */
  @Prop({ type: Number })
  durationSeconds?: number;

  /** True while the impersonation session is open (no endTime yet). */
  @Prop({ default: true, index: true })
  active: boolean;
}

export const ImpersonationLogSchema = SchemaFactory.createForClass(ImpersonationLog);
