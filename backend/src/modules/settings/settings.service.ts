import { Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { PlatformSettings, PlatformSettingsDocument, DEFAULT_VEHICLE_PRICES } from '../../database/schemas/settings.schema';

@Injectable()
export class SettingsService {
  constructor(
    @InjectModel(PlatformSettings.name)
    private readonly settingsModel: Model<PlatformSettingsDocument>,
  ) {}

  async getSettings(): Promise<PlatformSettings> {
    let settings = await this.settingsModel.findOne({ key: 'global' }).lean();
    if (!settings) {
      settings = await this.settingsModel.create({
        key: 'global',
        pricePerKm: 20,
        commissionPercent: 10,
        vehiclePrices: DEFAULT_VEHICLE_PRICES,
      });
    }
    // Back-fill vehiclePrices for existing records that predate this field
    if (!settings.vehiclePrices || Object.keys(settings.vehiclePrices).length === 0) {
      settings = await this.settingsModel.findOneAndUpdate(
        { key: 'global' },
        { $set: { vehiclePrices: DEFAULT_VEHICLE_PRICES } },
        { new: true },
      ).lean();
    }
    return settings;
  }

  async updateSettings(data: {
    pricePerKm?: number;
    commissionPercent?: number;
    vehiclePrices?: Record<string, number>;
  }): Promise<PlatformSettings> {
    const settings = await this.settingsModel.findOneAndUpdate(
      { key: 'global' },
      { $set: data },
      { new: true, upsert: true },
    ).lean();
    return settings;
  }
}
