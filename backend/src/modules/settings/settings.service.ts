import { Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { PlatformSettings, PlatformSettingsDocument, DEFAULT_VEHICLE_PRICES } from '../../database/schemas/settings.schema';
import { User, UserDocument } from '../../database/schemas/user.schema';
import { Franchise, FranchiseDocument } from '../../database/schemas/franchise.schema';

@Injectable()
export class SettingsService {
  constructor(
    @InjectModel(PlatformSettings.name)
    private readonly settingsModel: Model<PlatformSettingsDocument>,
    @InjectModel(User.name) private readonly userModel: Model<UserDocument>,
    @InjectModel(Franchise.name) private readonly franchiseModel: Model<FranchiseDocument>,
  ) {}

  /**
   * Support contact numbers for a given user. If the user's city has an active
   * franchise, its numbers are used (so users get their local franchise's support);
   * otherwise it falls back to the global Contact Us numbers from settings.
   */
  async resolveSupportContact(userId: string) {
    const settings = await this.getSettings();
    const globalContact = {
      phone: settings.supportPhone || '',
      whatsapp: settings.supportWhatsapp || '',
      source: 'global' as 'global' | 'franchise',
    };

    if (!userId || !Types.ObjectId.isValid(userId)) return { data: globalContact };
    const user = await this.userModel.findById(userId).select('city').lean();
    const city = (user as any)?.city?.trim();
    if (!city) return { data: globalContact };

    const rx = new RegExp(`^${city.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}$`, 'i');
    const franchise = await this.franchiseModel
      .findOne({ city: rx, isActive: true })
      .select('phone whatsappNumber')
      .lean();

    // Use the franchise only if it actually has a support number configured.
    const fPhone = (franchise as any)?.phone?.trim() || '';
    const fWhatsapp = (franchise as any)?.whatsappNumber?.trim() || '';
    if (franchise && (fPhone || fWhatsapp)) {
      // Per-field fallback to the GLOBAL settings number when the franchise hasn't
      // set that particular one — never a hard-coded value.
      return {
        data: {
          phone: fPhone || globalContact.phone,
          whatsapp: fWhatsapp || globalContact.whatsapp,
          source: 'franchise' as const,
        },
      };
    }
    return { data: globalContact };
  }

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
    supportPhone2?: string;
    supportWhatsapp?: string;
    supportEmail?: string;
  }): Promise<PlatformSettings> {
    const settings = await this.settingsModel.findOneAndUpdate(
      { key: 'global' },
      { $set: data },
      { new: true, upsert: true },
    ).lean();
    return settings;
  }
}
