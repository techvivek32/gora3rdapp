import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';

export type SiteTextDocument = SiteText & Document;

/**
 * One piece of website copy an operator has overridden.
 *
 * Only keys the code knows about are ever stored — see
 * modules/site-content/site-text.keys.ts. A key with no row here falls back
 * to the default that ships with the site, so this collection holds the
 * DIFFERENCES rather than the whole of the copy.
 */
@Schema({ timestamps: true, collection: 'siteTexts' })
export class SiteText {
  @Prop({ required: true, unique: true, trim: true })
  key: string;

  @Prop({ default: '' })
  value: string;
}

export const SiteTextSchema = SchemaFactory.createForClass(SiteText);
