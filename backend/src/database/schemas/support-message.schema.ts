import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document, Types } from 'mongoose';

export type SupportMessageDocument = SupportMessage & Document;

// One support conversation per user (userId). Each message is either from the
// user or from an admin ("support"). `read` = whether the recipient has seen it.
@Schema({ timestamps: true, collection: 'supportMessages' })
export class SupportMessage {
  @Prop({ type: Types.ObjectId, ref: 'User', required: true, index: true })
  userId: Types.ObjectId;

  @Prop({ type: String, enum: ['user', 'admin'], required: true })
  sender: string;

  @Prop({ required: true, trim: true })
  text: string;

  @Prop({ default: false })
  read: boolean;
}

export const SupportMessageSchema = SchemaFactory.createForClass(SupportMessage);
SupportMessageSchema.index({ userId: 1, createdAt: 1 });
