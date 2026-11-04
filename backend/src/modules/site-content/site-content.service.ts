import { BadRequestException, Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { SiteText, SiteTextDocument } from '../../database/schemas/site-text.schema';
import { SITE_TEXT_DEFAULTS, SITE_TEXT_KEYS, siteTextKey } from './site-text.keys';

@Injectable()
export class SiteContentService {
  constructor(
    @InjectModel(SiteText.name) private readonly model: Model<SiteTextDocument>,
  ) {}

  /**
   * What the website reads: every known key with its current value.
   *
   * Defaults first, overrides on top — so a key nobody has edited still
   * comes back with the copy the site ships with, and a page never has to
   * cope with a missing string.
   */
  async getPublic() {
    const rows = await this.model.find().lean();
    const data: Record<string, string> = { ...SITE_TEXT_DEFAULTS };
    for (const r of rows) {
      // An override to the empty string is a real choice — it hides the
      // caution banner — so it is kept, not treated as "unset".
      if (Object.prototype.hasOwnProperty.call(data, r.key)) data[r.key] = r.value ?? '';
    }
    return { message: 'Site text', data };
  }

  /**
   * What the admin form renders from: the field definitions and the values.
   * The panel should not need its own copy of the labels or the defaults.
   */
  async getForAdmin() {
    const rows = await this.model.find().lean();
    const saved = new Map(rows.map((r) => [r.key, r.value ?? '']));
    return {
      message: 'Site text',
      data: SITE_TEXT_KEYS.map((k) => ({
        ...k,
        value: saved.has(k.key) ? saved.get(k.key) : k.fallback,
        isOverridden: saved.has(k.key),
      })),
    };
  }

  /** Bulk save. One request for the whole form rather than one per field. */
  async update(items: { key: string; value: string }[]) {
    if (!Array.isArray(items) || items.length === 0) {
      throw new BadRequestException('Nothing to save');
    }
    for (const it of items) {
      const def = siteTextKey(it.key);
      // An unknown key would write a row nothing reads, and the operator
      // would never find out why their edit did nothing.
      if (!def) throw new BadRequestException(`Unknown text key: ${it.key}`);
      if (typeof it.value !== 'string') {
        throw new BadRequestException(`${def.label} must be text`);
      }
      if (it.value.length > def.maxLength) {
        throw new BadRequestException(`${def.label} must be ${def.maxLength} characters or fewer`);
      }
    }

    await this.model.bulkWrite(
      items.map((it) => ({
        updateOne: {
          filter: { key: it.key },
          update: { $set: { key: it.key, value: it.value } },
          upsert: true,
        },
      })),
    );
    return this.getForAdmin();
  }

  /** Drop the override for one key, so it falls back to the shipped copy. */
  async reset(key: string) {
    const def = siteTextKey(key);
    if (!def) throw new BadRequestException(`Unknown text key: ${key}`);
    await this.model.deleteOne({ key });
    return { message: 'Reset to the default', data: { key, value: def.fallback } };
  }
}
