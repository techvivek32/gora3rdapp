import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import {
  CabCategory,
  CabCategoryDocument,
  CityImage,
  CityImageDocument,
  HomeSectionType,
  HomeShowcase,
  HomeShowcaseDocument,
  WEBSITE_HERO_KEY,
} from '../../database/schemas/home-content.schema';
import {
  CreateCabCategoryDto,
  CreateShowcaseDto,
  UpdateCabCategoryDto,
  UpdateShowcaseDto,
  UpsertCityImageDto,
} from './dto/home-content.dto';

@Injectable()
export class HomeContentService {
  private readonly logger = new Logger(HomeContentService.name);
  // Re-resolve a city's auto image at most this often (Google photo URLs are cached).
  private static readonly HERO_TTL_MS = 30 * 24 * 60 * 60 * 1000; // 30 days

  constructor(
    @InjectModel(HomeShowcase.name) private readonly showcaseModel: Model<HomeShowcaseDocument>,
    @InjectModel(CityImage.name) private readonly cityImageModel: Model<CityImageDocument>,
    @InjectModel(CabCategory.name) private readonly cabCategoryModel: Model<CabCategoryDocument>,
  ) {}

  // ─── Customer: fetch the whole home payload for a city ───────────────────────
  async getForCustomer(city?: string): Promise<{ message: string; data: any }> {
    const cityLc = (city ?? '').toLowerCase().trim();
    // No city means the website, which has no city to show a picture of
    // until someone types a pickup. It gets the operator's own hero image,
    // stored under the reserved key.
    const heroImage = cityLc ? await this.resolveCityHero(cityLc) : await this.websiteHero();

    const items = await this.showcaseModel
      .find({ isActive: true, $or: [{ city: '' }, { city: cityLc }] })
      .sort({ order: 1, createdAt: -1 })
      .lean();

    const bySection = (s: HomeSectionType) => items.filter((i) => i.section === s);
    return {
      message: 'Home content',
      data: {
        heroImage,
        travel: bySection(HomeSectionType.TRAVEL),
        offers: bySection(HomeSectionType.OFFERS),
        explore: bySection(HomeSectionType.EXPLORE),
      },
    };
  }

  /** The hero image an operator set for the website itself. */
  private async websiteHero(): Promise<string> {
    const row = await this.cityImageModel
      .findOne({ city: WEBSITE_HERO_KEY, isActive: true })
      .lean();
    return row?.imageUrl ?? '';
  }

  /**
   * Fully-automatic city hero image. Returns a cached image if it's still fresh,
   * otherwise resolves the city's top attraction photo from Google Places and
   * caches it. Falls back to any stale cached URL (or '') if the fetch fails.
   */
  private async resolveCityHero(cityLc: string): Promise<string> {
    const cached = await this.cityImageModel.findOne({ city: cityLc }).lean();
    // Someone chose this one. The TTL does not apply to it.
    if (cached?.isManual && cached.imageUrl) return cached.imageUrl;
    const fresh =
      !!cached?.imageUrl &&
      !!cached?.fetchedAt &&
      Date.now() - new Date(cached.fetchedAt).getTime() < HomeContentService.HERO_TTL_MS;
    if (fresh) return cached!.imageUrl;

    const url = await this.fetchCityHero(cityLc);
    if (!url) return cached?.imageUrl ?? ''; // keep stale image rather than blank
    await this.cityImageModel.findOneAndUpdate(
      { city: cityLc },
      { $set: { city: cityLc, imageUrl: url, isActive: true, fetchedAt: new Date() } },
      { upsert: true },
    );
    return url;
  }

  /**
   * Google Places: find the city's top tourist attraction and resolve its photo
   * to a public image URL (the 302 Location), so the API key is never exposed.
   */
  private async fetchCityHero(city: string): Promise<string> {
    const key = process.env.GOOGLE_MAPS_API_KEY;
    if (!key || key === 'your-google-maps-api-key') return '';
    try {
      const search = new URL('https://maps.googleapis.com/maps/api/place/textsearch/json');
      search.searchParams.set('query', `top tourist attractions in ${city}`);
      search.searchParams.set('language', 'en');
      search.searchParams.set('key', key);
      const sres = await fetch(search.toString());
      const sbody: any = await sres.json();
      const ref = (sbody?.results || [])
        .map((r: any) => r?.photos?.[0]?.photo_reference)
        .find((x: any) => typeof x === 'string' && x.length > 0);
      if (!ref) return '';

      const photo = new URL('https://maps.googleapis.com/maps/api/place/photo');
      photo.searchParams.set('maxwidth', '1000');
      photo.searchParams.set('photo_reference', ref);
      photo.searchParams.set('key', key);
      // Follow the 302 to the public CDN image URL, then read the final URL
      // (response.url) — the key stays in the request, never in what we store.
      const pres = await fetch(photo.toString());
      const finalUrl = pres.url || '';
      try {
        await pres.body?.cancel(); // don't download the image bytes, just the URL
      } catch {
        /* ignore */
      }
      // Only accept it if we actually landed on the CDN (not stuck on an error page).
      return finalUrl && !finalUrl.includes('maps.googleapis.com') ? finalUrl : '';
    } catch (e: any) {
      this.logger.warn(`fetchCityHero(${city}) failed: ${e?.message ?? e}`);
      return '';
    }
  }

  // ─── Admin: showcase CRUD ────────────────────────────────────────────────────
  async listShowcase(section?: string) {
    const q: any = {};
    if (section) q.section = section;
    const data = await this.showcaseModel.find(q).sort({ section: 1, order: 1, createdAt: -1 }).lean();
    return { message: 'Showcase items', data };
  }

  async createShowcase(dto: CreateShowcaseDto) {
    const item = await this.showcaseModel.create({ ...dto, city: (dto.city ?? '').toLowerCase().trim() });
    return { message: 'Created', data: item };
  }

  async updateShowcase(id: string, dto: UpdateShowcaseDto) {
    const patch: any = { ...dto };
    if (dto.city !== undefined) patch.city = (dto.city ?? '').toLowerCase().trim();
    const item = await this.showcaseModel.findByIdAndUpdate(id, { $set: patch }, { new: true });
    if (!item) throw new NotFoundException('Item not found');
    return { message: 'Updated', data: item };
  }

  async deleteShowcase(id: string) {
    const res = await this.showcaseModel.findByIdAndDelete(id);
    if (!res) throw new NotFoundException('Item not found');
    return { message: 'Deleted', data: { id } };
  }

  // ─── Admin: city hero images ─────────────────────────────────────────────────
  async listCityImages() {
    const data = await this.cityImageModel.find().sort({ city: 1 }).lean();
    return { message: 'City images', data };
  }

  async upsertCityImage(dto: UpsertCityImageDto) {
    const city = dto.city.toLowerCase().trim();
    const imageUrl = dto.imageUrl ?? '';
    const item = await this.cityImageModel.findOneAndUpdate(
      { city },
      {
        $set: {
          city,
          imageUrl,
          isActive: dto.isActive ?? true,
          // Picking a picture makes the row the operator's; clearing it hands
          // the city back to the automatic resolver.
          isManual: !!imageUrl,
          fetchedAt: new Date(),
        },
      },
      { new: true, upsert: true },
    );
    return { message: 'Saved', data: item };
  }

  async deleteCityImage(id: string) {
    const res = await this.cityImageModel.findByIdAndDelete(id);
    if (!res) throw new NotFoundException('City image not found');
    return { message: 'Deleted', data: { id } };
  }

  // ─── Customer: "All Inclusive" list (admin-managed via INCLUSIONS showcase) ──
  async listInclusions(): Promise<{ message: string; data: string[] }> {
    const data = await this.showcaseModel
      .find({ section: HomeSectionType.INCLUSIONS, isActive: true })
      .sort({ order: 1, createdAt: 1 })
      .lean();
    return { message: 'Inclusions', data: data.map((d) => d.title).filter(Boolean) };
  }

  // ─── Customer: cab-booking info tabs (inclusions/exclusions/facilities/terms) ──
  async listCabInfo(): Promise<{ message: string; data: Record<string, string[]> }> {
    const sections = [
      HomeSectionType.INCLUSIONS,
      HomeSectionType.EXCLUSIONS,
      HomeSectionType.FACILITIES,
      HomeSectionType.TERMS,
    ];
    const rows = await this.showcaseModel
      .find({ section: { $in: sections }, isActive: true })
      .sort({ order: 1, createdAt: 1 })
      .lean();
    const data: Record<string, string[]> = { inclusions: [], exclusions: [], facilities: [], terms: [] };
    for (const r of rows) {
      if (r.title) (data[r.section] ??= []).push(r.title);
    }
    return { message: 'Cab info', data };
  }

  // ─── Cab categories (Explore Cabs results) ───────────────────────────────────
  async listCabCategories(activeOnly = false) {
    const q: any = activeOnly ? { isActive: true } : {};
    const data = await this.cabCategoryModel.find(q).sort({ order: 1, createdAt: 1 }).lean();
    return { message: 'Cab categories', data };
  }

  async createCabCategory(dto: CreateCabCategoryDto) {
    const item = await this.cabCategoryModel.create(dto);
    return { message: 'Created', data: item };
  }

  async updateCabCategory(id: string, dto: UpdateCabCategoryDto) {
    const item = await this.cabCategoryModel.findByIdAndUpdate(id, { $set: dto }, { new: true });
    if (!item) throw new NotFoundException('Cab category not found');
    return { message: 'Updated', data: item };
  }

  async deleteCabCategory(id: string) {
    const res = await this.cabCategoryModel.findByIdAndDelete(id);
    if (!res) throw new NotFoundException('Cab category not found');
    return { message: 'Deleted', data: { id } };
  }
}
