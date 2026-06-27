import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document, Types } from 'mongoose';

export type RatingDocument = Rating & Document;

@Schema({ timestamps: true, collection: 'ratings' })
export class Rating {
  @Prop({ type: Types.ObjectId, ref: 'User', required: true })
  rater: Types.ObjectId;

  @Prop({ type: Types.ObjectId, ref: 'User', required: true })
  ratedUser: Types.ObjectId;

  @Prop({ required: true, min: 1, max: 5 })
  stars: number;

  @Prop({ trim: true })
  review: string;
}

export const RatingSchema = SchemaFactory.createForClass(Rating);

// One rating per (rater -> ratedUser) pair.
RatingSchema.index({ rater: 1, ratedUser: 1 }, { unique: true });
RatingSchema.index({ ratedUser: 1 });
