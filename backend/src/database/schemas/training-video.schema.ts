import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';

export type TrainingVideoDocument = TrainingVideo & Document;

/** A training video the admin adds (title + link) and the app lists. */
@Schema({ timestamps: true, collection: 'trainingVideos' })
export class TrainingVideo {
  @Prop({ required: true, trim: true })
  title: string;

  @Prop({ required: true, trim: true })
  url: string;

  @Prop({ default: true })
  isActive: boolean;

  @Prop({ default: 0 })
  sortOrder: number;
}

export const TrainingVideoSchema = SchemaFactory.createForClass(TrainingVideo);

TrainingVideoSchema.index({ isActive: 1, sortOrder: 1 });
