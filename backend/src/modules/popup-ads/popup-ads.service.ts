import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { PopupAd, PopupAdDocument } from '../../database/schemas/popup-ad.schema';
import { StorageService } from '../storage/storage.service';

@Injectable()
export class PopupAdsService {
  constructor(
    @InjectModel(PopupAd.name) private adModel: Model<PopupAdDocument>,
    private readonly storageService: StorageService,
  ) {}

  /** 'customer' or 'driver' — anything unrecognised falls back to driver. */
  private audienceOf(value?: string): string {
    return value === 'customer' ? 'customer' : 'driver';
  }

  /**
   * Match on audience INCLUDING rows saved before the field existed. Those have
   * no `audience` at all and have always been driver-side ads, so a driver query
   * must still find them — otherwise adding this field would silently switch off
   * whatever ad is currently live.
   */
  private audienceFilter(value?: string): any {
    const audience = this.audienceOf(value);
    return audience === 'driver' ? { $in: ['driver', null] } : audience;
  }

  async create(data: { imageUrl?: string; linkUrl?: string; audience?: string }) {
    const imageUrl = (data.imageUrl || '').trim();
    if (!imageUrl) throw new BadRequestException('Upload an ad image first');
    const audience = this.audienceOf(data.audience);
    // One ad is active per audience — a new one takes over its own side only,
    // so a customer campaign never switches off the driver one.
    await this.adModel.updateMany(
      { audience: this.audienceFilter(audience) },
      { $set: { isActive: false } },
    );
    const ad = await this.adModel.create({
      imageUrl,
      linkUrl: (data.linkUrl || '').trim(),
      audience,
      isActive: true,
    });
    return { message: 'Ad added', data: ad };
  }

  /** Admin list. `audience` narrows it to one side; omitted returns both. */
  async findAll(audience?: string) {
    const filter: any = {};
    if (audience) filter.audience = this.audienceFilter(audience);
    const data = await this.adModel.find(filter).sort({ createdAt: -1 }).lean();
    return { message: 'Ads', data };
  }

  /** The one ad the app should show on open for this side, or null. */
  async getActive(audience?: string) {
    const data = await this.adModel
      .findOne({ isActive: true, audience: this.audienceFilter(audience) })
      .sort({ createdAt: -1 })
      .lean();
    return { message: 'Active ad', data: data || null };
  }

  async update(id: string, data: { linkUrl?: string; isActive?: boolean; audience?: string }) {
    const existing = await this.adModel.findById(id).lean();
    if (!existing) throw new NotFoundException('Ad not found');

    const update: any = {};
    if (data.linkUrl !== undefined) update.linkUrl = (data.linkUrl || '').trim();
    // The side this ad will belong to once this update lands.
    const audience = data.audience !== undefined
      ? this.audienceOf(data.audience)
      : this.audienceOf((existing as any).audience);
    if (data.audience !== undefined) update.audience = audience;

    if (data.isActive === true) {
      // Deactivate only the other ads on the SAME side.
      await this.adModel.updateMany(
        { _id: { $ne: id }, audience: this.audienceFilter(audience) },
        { $set: { isActive: false } },
      );
      update.isActive = true;
    } else if (data.isActive === false) {
      update.isActive = false;
    }
    const ad = await this.adModel.findByIdAndUpdate(id, { $set: update }, { new: true });
    if (!ad) throw new NotFoundException('Ad not found');
    return { message: 'Ad updated', data: ad };
  }

  async remove(id: string) {
    const ad = await this.adModel.findByIdAndDelete(id);
    if (!ad) throw new NotFoundException('Ad not found');
    this.storageService.deleteFile(ad.imageUrl).catch(() => {});
    return { message: 'Ad deleted', data: { _id: id } };
  }
}
