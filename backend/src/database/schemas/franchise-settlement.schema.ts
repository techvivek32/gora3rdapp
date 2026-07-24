import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document, Types } from 'mongoose';

export type FranchiseSettlementDocument = FranchiseSettlement & Document;

/**
 * A payout the admin has made to a franchise against its earned commission.
 * The franchise's "pending" balance = earned commission − sum(settlements).
 */
@Schema({ timestamps: true, collection: 'franchise_settlements' })
export class FranchiseSettlement {
  @Prop({ type: Types.ObjectId, ref: 'Franchise', required: true, index: true })
  franchiseId: Types.ObjectId;

  /** Amount paid to the franchise, in rupees. */
  @Prop({ required: true, min: 0 })
  amount: number;

  @Prop({ trim: true, default: '' })
  note: string;

  /** The admin who recorded the settlement. */
  @Prop({ type: Types.ObjectId, ref: 'User' })
  paidBy: Types.ObjectId;
}

export const FranchiseSettlementSchema = SchemaFactory.createForClass(FranchiseSettlement);
FranchiseSettlementSchema.index({ franchiseId: 1, createdAt: -1 });
