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

  /**
   * The tone a user hears when they have NOT picked one themselves — set by the
   * admin, one per alert kind. Separate flags (rather than one field) so the
   * same tone can be the default for both, which is the common case.
   *
   * Without these every new install fell back to the bundled asset, so the
   * admin's uploaded tones only ever reached users who went and chose one.
   */
  @Prop({ default: false, index: true })
  isDefaultPopup: boolean;

  @Prop({ default: false, index: true })
  isDefaultNotification: boolean;

  @Prop({ default: 0 })
  sortOrder: number;
}

export const RingtoneSchema = SchemaFactory.createForClass(Ringtone);
