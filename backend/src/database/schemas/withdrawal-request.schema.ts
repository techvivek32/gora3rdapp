import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document, Types } from 'mongoose';

export type WithdrawalRequestDocument = WithdrawalRequest & Document;

@Schema({ timestamps: true, collection: 'withdrawalRequests' })
export class WithdrawalRequest {
  @Prop({ type: Types.ObjectId, ref: 'User', required: true, index: true })
  userId: Types.ObjectId;

  @Prop({ required: true }) // amount in rupees
  amount: number;

  /** Which wallet the amount was debited from, so a rejection refunds it to the
   *  right one. Requests raised before the customer wallet existed default to
   *  the main (driver/vendor) wallet. */
  @Prop({ type: String, enum: ['main', 'customer'], default: 'main' })
  wallet: string;

  /** How the payout should be made. Records created before this default to bank. */
  @Prop({ type: String, enum: ['bank', 'upi'], default: 'bank' })
  method: string;

  /** Always required — the name the money is paid out to. */
  @Prop({ required: true, trim: true })
  accountHolderName: string;

  // Bank payout details (method === 'bank').
  @Prop({ trim: true })
  bankName: string;

  @Prop({ trim: true })
  accountNumber: string;

  @Prop({ trim: true, uppercase: true })
  ifsc: string;

  // UPI payout detail (method === 'upi').
  @Prop({ trim: true })
  upiId: string;

  @Prop({ type: String, enum: ['pending', 'approved', 'rejected'], default: 'pending', index: true })
  status: string;

  // Reason shown to the user when a request is rejected (amount is refunded).
  @Prop({ trim: true })
  rejectionReason: string;

  @Prop({ type: Types.ObjectId, ref: 'User' })
  processedBy: Types.ObjectId;

  @Prop({ type: Date })
  processedAt: Date;
}

export const WithdrawalRequestSchema = SchemaFactory.createForClass(WithdrawalRequest);
WithdrawalRequestSchema.index({ status: 1, createdAt: -1 });
