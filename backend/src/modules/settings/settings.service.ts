import { UserRole } from '../../common/enums/user-role.enum';
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
    const user = await this.userModel.findById(userId).select('city role').lean();

    // A franchise is a city partner that looks after the DRIVERS in its city,
    // so a partner asking for support should reach them. Customers get their
    // own line instead - one number, every city, never a franchise.
    if ((user as any)?.role === UserRole.CUSTOMER) {
      const csPhone = (settings as any).customerServicePhone?.trim() || '';
      const csWhatsapp = (settings as any).customerServiceWhatsapp?.trim() || '';
      return {
        data: {
          phone: csPhone || globalContact.phone,
          whatsapp: csWhatsapp || csPhone || globalContact.whatsapp,
          source: 'global' as const,
        },
      };
    }

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
      return {
        data: {
          phone: fPhone || globalContact.phone,
          whatsapp: fWhatsapp || fPhone || globalContact.whatsapp,
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

  // Admin settings for the dashboard. SECURITY: never send the actual Razorpay
  // secrets to the browser — a stolen admin session / XSS / browser extension
  // would otherwise leak the payment-gateway secret. We expose only whether each
  // secret is configured; writes still accept new values via PUT /settings.
  async getAdminSettings(): Promise<
    Partial<PlatformSettings> & {
      razorpayKeySecretSet: boolean;
      razorpayWebhookSecretSet: boolean;
      verifyClientSecretSet: boolean;
    }
  > {
    const s = await this.getSettings();
    const { razorpayKeySecret, razorpayWebhookSecret, verifyClientSecret, ...safe } = s as any;
    return {
      ...safe,
      razorpayKeySecret: '',
      razorpayWebhookSecret: '',
      // Never send a provider secret back to a browser - only whether it is set.
      verifyClientSecret: '',
      razorpayKeySecretSet: !!(razorpayKeySecret || process.env.RAZORPAY_KEY_SECRET),
      razorpayWebhookSecretSet: !!(razorpayWebhookSecret || process.env.RAZORPAY_WEBHOOK_SECRET),
      verifyClientSecretSet: !!verifyClientSecret,
    };
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
    customerServicePhone?: string;
    customerServiceWhatsapp?: string;
    supportWhatsapp?: string;
    supportEmail?: string;
    minDeposit?: number;
    minWithdrawal?: number;
    minTransfer?: number;
    whatsappAutoBookMinutes?: number;
    appSuggestedFareEnabled?: boolean;
    viewsEnabled?: boolean;
    minBillKm?: number;
    tollTaxPerKm?: number;
    gstPercent?: number;
    platformCommissionPercent?: number;
    driverHirePerDay?: number;
    verifyClientId?: string;
    verifyClientSecret?: string;
    verifySandbox?: boolean;
    verifyEnforceNameMatch?: boolean;
    driverHireKmPerDay?: number;
    driverHireExtraKmPrice?: number;
    driverHireFoodPerDay?: number;
    driverHireReturnByCustomer?: boolean;
    minWalletToAccept?: number;
    contactRevealHoursBeforePickup?: number;
  }): Promise<PlatformSettings> {
    // Don't let a blank secret field (the admin form now loads secrets masked as '')
    // wipe a configured secret — only overwrite when a real value is sent.
    const clean: any = { ...data };
    if (!clean.razorpayKeySecret) delete clean.razorpayKeySecret;
    if (!clean.razorpayWebhookSecret) delete clean.razorpayWebhookSecret;
    if (!clean.verifyClientSecret) delete clean.verifyClientSecret;
    const settings = await this.settingsModel.findOneAndUpdate(
      { key: 'global' },
      { $set: clean },
      { new: true, upsert: true },
    ).lean();
    return settings;
  }

  /** Wallet minimums (₹) used to validate deposit/withdraw/transfer amounts. */
  async getWalletLimits(): Promise<{ minDeposit: number; minWithdrawal: number; minTransfer: number }> {
    const s = await this.getSettings();
    return {
      minDeposit: Math.max(1, s.minDeposit ?? 1),
      minWithdrawal: Math.max(1, s.minWithdrawal ?? 1),
      minTransfer: Math.max(1, s.minTransfer ?? 1),
    };
  }
}
