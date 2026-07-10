import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document, Types } from 'mongoose';

export type AccountDeletionRequestDocument = AccountDeletionRequest & Document;

@Schema({ timestamps: true, collection: 'accountDeletionRequests' })
export class AccountDeletionRequest {
  @Prop({ type: Types.ObjectId, ref: 'User', required: true })
  userId: Types.ObjectId;

  /** Why the user wants their account removed (typed in the app). */
  @Prop({ required: true, trim: true })
  reason: string;

  @Prop({ type: String, enum: ['pending', 'approved', 'rejected'], default: 'pending' })
  status: string;

  // Snapshot of the account, so the record stays readable after the user row is deleted.
  @Prop({ trim: true })
  fullName: string;

  @Prop({ trim: true })
  mobile: string;

  @Prop({ trim: true })
  email: string;

  @Prop({ type: Types.ObjectId, ref: 'User' })
  processedBy: Types.ObjectId;

  @Prop()
  processedAt: Date;

  /** Set when an admin rejects the request. */
  @Prop({ trim: true })
  rejectionReason: string;
}

export const AccountDeletionRequestSchema = SchemaFactory.createForClass(AccountDeletionRequest);

AccountDeletionRequestSchema.index({ status: 1, createdAt: -1 });
AccountDeletionRequestSchema.index({ userId: 1, status: 1 });
