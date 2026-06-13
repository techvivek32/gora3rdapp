import { Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { Banner, BannerDocument } from '../../database/schemas/banner.schema';

@Injectable()
export class BannersService {
  constructor(@InjectModel(Banner.name) private bannerModel: Model<BannerDocument>) {}

  async getActiveBanners(membershipType?: string) {
    const now = new Date();
    const filter: any = {
      isActive: true,
      $or: [{ startDate: null }, { startDate: { $lte: now } }],
      $and: [{ $or: [{ endDate: null }, { endDate: { $gte: now } }] }],
    };

    const banners = await this.bannerModel.find(filter).sort({ sortOrder: 1 }).lean();

    await this.bannerModel.updateMany(
      { _id: { $in: banners.map((b) => b._id) } },
      { $inc: { viewCount: 1 } },
    );

    return { message: 'Banners retrieved', data: banners };
  }

  async trackClick(id: string) {
    await this.bannerModel.findByIdAndUpdate(id, { $inc: { clickCount: 1 } });
    return { message: 'Click tracked' };
  }
}
