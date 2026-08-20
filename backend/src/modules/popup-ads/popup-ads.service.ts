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

  async create(data: { imageUrl?: string; linkUrl?: string }) {
    const imageUrl = (data.imageUrl || '').trim();
    if (!imageUrl) throw new BadRequestException('Upload an ad image first');
    // Only one ad is active at a time — a new one becomes the active ad.
    await this.adModel.updateMany({}, { $set: { isActive: false } });
    const ad = await this.adModel.create({
      imageUrl,
      linkUrl: (data.linkUrl || '').trim(),
      isActive: true,
    });
    return { message: 'Ad added', data: ad };
  }

  async findAll() {
    const data = await this.adModel.find().sort({ createdAt: -1 }).lean();
    return { message: 'Ads', data };
  }

  /** The one ad the app should show on open, or null. */
  async getActive() {
    const data = await this.adModel.findOne({ isActive: true }).sort({ createdAt: -1 }).lean();
    return { message: 'Active ad', data: data || null };
  }

  async update(id: string, data: { linkUrl?: string; isActive?: boolean }) {
    const update: any = {};
    if (data.linkUrl !== undefined) update.linkUrl = (data.linkUrl || '').trim();
    if (data.isActive === true) {
      await this.adModel.updateMany({ _id: { $ne: id } }, { $set: { isActive: false } });
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
