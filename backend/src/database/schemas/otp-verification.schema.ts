import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';

export type OtpVerificationDocument = OtpVerification & Document;

@Schema({ timestamps: true, collection: 'otpVerifications' })
export class OtpVerification {
  @Prop({ required: true, index: true })
  mobile: string;

  @Prop({ required: true })
  otpHash: string;

  @Prop({ default: 0 })
  attempts: number;

  @Prop({ required: true, type: Date })
  expiresAt: Date;
}

export const OtpVerificationSchema = SchemaFactory.createForClass(OtpVerification);

// TTL index: documents are removed automatically once expiresAt passes.
OtpVerificationSchema.index({ expiresAt: 1 }, { expireAfterSeconds: 0 });
OtpVerificationSchema.index({ mobile: 1 }, { unique: true });
