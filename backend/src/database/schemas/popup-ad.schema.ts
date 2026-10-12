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

  /**
   * Who sees this ad. Driver/vendor mode and Customer mode each get their own
   * active ad, so the two sides can run different campaigns at the same time.
   * Existing rows have no value — they default to 'driver', which is where the
   * popup already appeared before this split.
   */
  @Prop({ default: 'driver', enum: ['driver', 'customer'], index: true })
  audience: string;

  /** Only the active ad is shown in the app (one active per audience). */
  @Prop({ default: false, index: true })
  isActive: boolean;

  @Prop({ default: 0 })
  sortOrder: number;
}

export const PopupAdSchema = SchemaFactory.createForClass(PopupAd);

// The app's only read: the one active ad for the caller's side.
PopupAdSchema.index({ audience: 1, isActive: 1 });
