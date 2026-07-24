import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';

export type FranchiseDocument = Franchise & Document;

/** One KYC document: id number + front/back image URLs. */
class FranchiseDoc {
  number?: string;
  frontImage?: string;
  backImage?: string;
}

/** A payout destination — a franchise may keep several (bank + multiple UPIs). */
class PayoutAccount {
  type: 'bank' | 'upi';
  label?: string; // e.g. "HDFC personal"
  // UPI
  upiId?: string;
  accountHolderName?: string;
  // Bank
  bankName?: string;
  accountNumber?: string;
  ifsc?: string;
}

@Schema({ timestamps: true, collection: 'franchises' })
export class Franchise {
  @Prop({ required: true, trim: true })
  name: string;

  @Prop({ type: Date })
  dob: Date;

  @Prop({ trim: true })
  city: string;

  @Prop({ trim: true })
  state: string;

  @Prop({ trim: true, lowercase: true })
  email: string;

  @Prop({ required: true, trim: true })
  phone: string;

  @Prop({ trim: true })
  agencyName: string;

  // Hashed with bcrypt; never returned by default.
  @Prop({ select: false })
  password: string;

  // Hashed refresh token (bcrypt); never returned by default.
  @Prop({ select: false })
  refreshToken?: string;

  @Prop({ default: 0, min: 0, max: 100 })
  commissionPercent: number;

  @Prop({ type: Object, default: {} })
  documents: {
    aadhar?: FranchiseDoc;
    pan?: FranchiseDoc;
    drivingLicense?: FranchiseDoc;
  };

  @Prop({ type: [Object], default: [] })
  payoutAccounts: PayoutAccount[];

  @Prop({ default: true })
  isActive: boolean;
}

export const FranchiseSchema = SchemaFactory.createForClass(Franchise);

FranchiseSchema.index({ email: 1 }, { unique: true, sparse: true });
FranchiseSchema.index({ phone: 1 });
FranchiseSchema.index({ createdAt: -1 });
