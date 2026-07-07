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
        razorpayKeyId: process.env.RAZORPAY_KEY_ID || '',
        razorpayKeySecret: process.env.RAZORPAY_KEY_SECRET || '',
        razorpayWebhookSecret: process.env.RAZORPAY_WEBHOOK_SECRET || '',
      });
    }
    if (!settings.vehiclePrices || Object.keys(settings.vehiclePrices).length === 0) {
      settings = await this.settingsModel.findOneAndUpdate(
        { key: 'global' },
        { $set: { vehiclePrices: DEFAULT_VEHICLE_PRICES } },
        { new: true },
      ).lean();
    }
    return settings;
  }

  // Returns only the public key — safe to expose to mobile clients
  async getPublicSettings(): Promise<Partial<PlatformSettings>> {
    const s = await this.getSettings();
    const { razorpayKeySecret, razorpayWebhookSecret, ...pub } = s as any;
    return pub;
  }

  // Returns full settings including secrets — admin only
  async getRazorpayKeys(): Promise<{ keyId: string; keySecret: string; webhookSecret: string }> {
    const s = await this.getSettings();
    return {
      keyId: s.razorpayKeyId || process.env.RAZORPAY_KEY_ID || '',
      keySecret: s.razorpayKeySecret || process.env.RAZORPAY_KEY_SECRET || '',
      webhookSecret: s.razorpayWebhookSecret || process.env.RAZORPAY_WEBHOOK_SECRET || '',
    };
  }

  async updateSettings(data: {
    pricePerKm?: number;
    commissionPercent?: number;
    vehiclePrices?: Record<string, number>;
    razorpayKeyId?: string;
    razorpayKeySecret?: string;
    razorpayWebhookSecret?: string;
    supportPhone?: string;
    supportWhatsapp?: string;
  }): Promise<PlatformSettings> {
    const settings = await this.settingsModel.findOneAndUpdate(
      { key: 'global' },
      { $set: data },
      { new: true, upsert: true },
    ).lean();
    return settings;
  }
}
