import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';

export type PopupAdDocument = PopupAd & Document;

@Schema({ timestamps: true, collection: 'popup_ads' })
export class PopupAd {
  /** Public URL of the ad image shown in the popup. */
  @Prop({ required: true })
  imageUrl: string;

  /** Optional URL opened when the user taps the ad / the Open button. */
  @Prop({ default: '' })
  linkUrl: string;

  /** Only the active ad is shown in the app (one active at a time). */
  @Prop({ default: false, index: true })
  isActive: boolean;

  @Prop({ default: 0 })
  sortOrder: number;
}

export const PopupAdSchema = SchemaFactory.createForClass(PopupAd);
