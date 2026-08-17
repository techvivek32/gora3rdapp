import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';

export type RingtoneDocument = Ringtone & Document;

@Schema({ timestamps: true, collection: 'ringtones' })
export class Ringtone {
  @Prop({ required: true, trim: true })
  title: string;

  /** Public URL of the uploaded audio file. */
  @Prop({ required: true })
  audioUrl: string;

  /** The one ringtone the app should use (only one active at a time). */
  @Prop({ default: false, index: true })
  isActive: boolean;

  @Prop({ default: 0 })
  sortOrder: number;
}

export const RingtoneSchema = SchemaFactory.createForClass(Ringtone);
