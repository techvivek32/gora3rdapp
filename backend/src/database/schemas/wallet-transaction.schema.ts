import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document, Types } from 'mongoose';

export type WalletTransactionDocument = WalletTransaction & Document;

@Schema({ timestamps: true, collection: 'walletTransactions' })
export class WalletTransaction {
  @Prop({ type: Types.ObjectId, ref: 'User', required: true, index: true })
  userId: Types.ObjectId;

  @Prop({ required: true }) // amount in rupees
  amount: number;

  @Prop({ type: String, enum: ['credit', 'debit'], default: 'credit' })
  type: string;

  @Prop({ type: String, enum: ['pending', 'success', 'failed'], default: 'pending' })
  status: string;

  @Prop()
  razorpayOrderId: string;

  @Prop()
  razorpayPaymentId: string;

  @Prop()
  note: string;

  // Set when the transaction is an admin manual adjustment (audit trail).
  @Prop({ type: Types.ObjectId, ref: 'User' })
  adminId: Types.ObjectId;

  // 'razorpay' (top-up), 'admin' (manual adjustment), 'withdrawal' (debit for a
  // withdrawal request), 'refund' (credit back on a rejected withdrawal) or
  // 'transfer' (wallet-to-wallet between users).
  @Prop({ type: String, enum: ['razorpay', 'admin', 'withdrawal', 'refund', 'transfer'], default: 'razorpay' })
  source: string;

  /** The other user in a wallet-to-wallet transfer (sender on a credit, recipient on a debit). */
  @Prop({ type: Types.ObjectId, ref: 'User' })
  counterpartyId: Types.ObjectId;
}

export const WalletTransactionSchema = SchemaFactory.createForClass(WalletTransaction);
WalletTransactionSchema.index({ userId: 1, createdAt: -1 });
