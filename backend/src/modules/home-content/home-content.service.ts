import { Injectable, NotFoundException } from '@nestjs/common';
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
  constructor(
    @InjectModel(HomeShowcase.name) private readonly showcaseModel: Model<HomeShowcaseDocument>,
    @InjectModel(CityImage.name) private readonly cityImageModel: Model<CityImageDocument>,
    @InjectModel(CabCategory.name) private readonly cabCategoryModel: Model<CabCategoryDocument>,
  ) {}

  // ─── Customer: fetch the whole home payload for a city ───────────────────────
  async getForCustomer(city?: string): Promise<{ message: string; data: any }> {
    const cityLc = (city ?? '').toLowerCase().trim();
    const hero = cityLc
      ? await this.cityImageModel.findOne({ city: cityLc, isActive: true }).lean()
      : null;

    const items = await this.showcaseModel
      .find({ isActive: true, $or: [{ city: '' }, { city: cityLc }] })
      .sort({ order: 1, createdAt: -1 })
      .lean();

    const bySection = (s: HomeSectionType) => items.filter((i) => i.section === s);
    return {
      message: 'Home content',
      data: {
        heroImage: hero?.imageUrl ?? '',
        travel: bySection(HomeSectionType.TRAVEL),
        offers: bySection(HomeSectionType.OFFERS),
        explore: bySection(HomeSectionType.EXPLORE),
      },
    };
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
    const item = await this.cityImageModel.findOneAndUpdate(
      { city },
      { $set: { city, imageUrl: dto.imageUrl ?? '', isActive: dto.isActive ?? true } },
      { new: true, upsert: true },
    );
    return { message: 'Saved', data: item };
  }

  async deleteCityImage(id: string) {
    const res = await this.cityImageModel.findByIdAndDelete(id);
    if (!res) throw new NotFoundException('City image not found');
    return { message: 'Deleted', data: { id } };
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
