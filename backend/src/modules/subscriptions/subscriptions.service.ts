import { Injectable, NotFoundException, BadRequestException, Logger } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import {
  SubscriptionPlan,
  SubscriptionPlanDocument,
  Subscription,
  SubscriptionDocument,
  SubscriptionStatus,
} from '../../database/schemas/subscription.schema';
import { Payment, PaymentDocument, PaymentStatus } from '../../database/schemas/payment.schema';
import { User, UserDocument } from '../../database/schemas/user.schema';
import { MembershipType } from '../../common/enums/user-role.enum';
import { generatePaymentOrderId } from '../../common/utils/booking-id.util';
import Razorpay from 'razorpay';
import { ConfigService } from '@nestjs/config';
import { SettingsService } from '../settings/settings.service';
import * as crypto from 'crypto';

@Injectable()
export class SubscriptionsService {
  private readonly logger = new Logger(SubscriptionsService.name);

  constructor(
    @InjectModel(SubscriptionPlan.name) private planModel: Model<SubscriptionPlanDocument>,
    @InjectModel(Subscription.name) private subscriptionModel: Model<SubscriptionDocument>,
    @InjectModel(Payment.name) private paymentModel: Model<PaymentDocument>,
    @InjectModel(User.name) private userModel: Model<UserDocument>,
    private configService: ConfigService,
    private settingsService: SettingsService,
  ) {}

  // Lazily build the Razorpay client — reads keys from DB first, falls back to env.
  private async getRazorpay(): Promise<Razorpay> {
    const keys = await this.settingsService.getRazorpayKeys();
    const keyId = keys.keyId;
    const keySecret = keys.keySecret;
    if (!keyId || !keySecret) {
      this.logger.error('Razorpay credentials are not configured.');
      throw new BadRequestException('Payment gateway is not configured. Please contact support.');
    }
    return new Razorpay({ key_id: keyId, key_secret: keySecret });
  }

  async getActivePlans() {
    const plans = await this.planModel
      .find({ isActive: true })
      .sort({ sortOrder: 1, price: 1 })
      .lean();
    return { message: 'Plans retrieved', data: plans };
  }

  async createPaymentOrder(userId: string, planId: string) {
    const plan = await this.planModel.findById(planId);
    if (!plan) throw new NotFoundException('Plan not found');

    // Plan prices are stored in rupees; multiply by 100 for Razorpay (paise).
    const priceInRupees = plan.discountedPrice || plan.price;
    const amountInPaise = priceInRupees * 100;
    const orderId = generatePaymentOrderId();

    let razorpayOrder;
    try {
      razorpayOrder = await (await this.getRazorpay()).orders.create({
        amount: amountInPaise,
        currency: 'INR',
        receipt: orderId,
        notes: { planId: planId.toString(), userId },
      });
    } catch (e: any) {
      // Surface Razorpay's real reason so misconfig (bad key/secret, live account
      // not activated, amount too small) is diagnosable instead of a generic 400.
      const reason = e?.error?.description || e?.description || e?.message || 'unknown error';
      this.logger.error(`Razorpay order creation failed (amount=${amount}): ${reason}`);
      throw new BadRequestException(`Payment could not start: ${reason}`);
    }

    const payment = await this.paymentModel.create({
      orderId,
      userId: new Types.ObjectId(userId),
      planId: new Types.ObjectId(planId),
      amount: plan.discountedPrice || plan.price,
      status: PaymentStatus.PENDING,
      razorpayOrderId: razorpayOrder.id,
    });

    return {
      message: 'Payment order created',
      data: {
        orderId: razorpayOrder.id,
        amount: amountInPaise,
        currency: 'INR',
        keyId: (await this.settingsService.getRazorpayKeys()).keyId,
        paymentId: payment._id,
        plan: {
          name: plan.name,
          membershipType: plan.membershipType,
          duration: plan.duration,
          durationDays: plan.durationDays,
        },
      },
    };
  }

  async verifyPayment(userId: string | null, data: {
    razorpayOrderId: string;
    razorpayPaymentId: string;
    razorpaySignature: string;
  }) {
    const keys = await this.settingsService.getRazorpayKeys();
    const keySecret = keys.keySecret;
    const expectedSignature = crypto
      .createHmac('sha256', keySecret)
      .update(`${data.razorpayOrderId}|${data.razorpayPaymentId}`)
      .digest('hex');

    if (expectedSignature !== data.razorpaySignature) {
      await this.paymentModel.findOneAndUpdate(
        { razorpayOrderId: data.razorpayOrderId },
        { status: PaymentStatus.FAILED },
      );
      throw new Error('Payment verification failed');
    }

    const payment = await this.paymentModel.findOneAndUpdate(
      { razorpayOrderId: data.razorpayOrderId },
      {
        status: PaymentStatus.SUCCESS,
        razorpayPaymentId: data.razorpayPaymentId,
        razorpaySignature: data.razorpaySignature,
      },
      { new: true },
    );

    if (!payment) throw new NotFoundException('Payment not found');

    const effectiveUserId = userId || payment.userId?.toString();
    if (!effectiveUserId) throw new NotFoundException('User not found for payment');
    await this.activateSubscription(effectiveUserId, payment.planId.toString(), payment._id.toString());

    return { message: 'Payment verified and subscription activated' };
  }

  private readonly TIER_RANK: Record<string, number> = {
    new: 0, active: 1, verified: 2, premium: 3, golden: 4,
  };

  private async activateSubscription(userId: string, planId: string, paymentId: string) {
    const plan = await this.planModel.findById(planId);
    if (!plan) return;

    // Find current active subscription if any
    const currentSub = await this.subscriptionModel
      .findOne({ userId: new Types.ObjectId(userId), status: SubscriptionStatus.ACTIVE })
      .sort({ endDate: -1 })
      .lean();

    const currentUser = await this.userModel.findById(userId).select('membershipType membershipExpiresAt').lean();
    const currentTier = this.TIER_RANK[currentUser?.membershipType ?? 'new'] ?? 0;
    const newTier = this.TIER_RANK[plan.membershipType] ?? 0;

    const now = new Date();
    let startDate: Date;
    let endDate: Date;

    if (currentSub && currentSub.endDate > now) {
      if (newTier === currentTier) {
        // Same tier — extend from current end date
        startDate = new Date(currentSub.endDate);
        endDate = new Date(currentSub.endDate);
        endDate.setDate(endDate.getDate() + plan.durationDays);
        // Update old sub end date to now (replaced by extension)
        await this.subscriptionModel.findByIdAndUpdate(currentSub._id, { status: SubscriptionStatus.EXPIRED });
      } else if (newTier > currentTier) {
        // Higher tier — upgrade: carry remaining days into new plan
        const remainingMs = currentSub.endDate.getTime() - now.getTime();
        const remainingDays = Math.ceil(remainingMs / (1000 * 60 * 60 * 24));
        startDate = now;
        endDate = new Date(now);
        endDate.setDate(endDate.getDate() + plan.durationDays + remainingDays);
        await this.subscriptionModel.findByIdAndUpdate(currentSub._id, { status: SubscriptionStatus.EXPIRED });
      } else {
        // Lower tier — just replace
        startDate = now;
        endDate = new Date(now);
        endDate.setDate(endDate.getDate() + plan.durationDays);
        await this.subscriptionModel.findByIdAndUpdate(currentSub._id, { status: SubscriptionStatus.EXPIRED });
      }
    } else {
      // No active subscription — fresh start
      startDate = now;
      endDate = new Date(now);
      endDate.setDate(endDate.getDate() + plan.durationDays);
    }

    const subscription = await this.subscriptionModel.create({
      userId: new Types.ObjectId(userId),
      planId: new Types.ObjectId(planId),
      status: SubscriptionStatus.ACTIVE,
      startDate,
      endDate,
      amount: plan.discountedPrice || plan.price,
      paymentId: new Types.ObjectId(paymentId),
      membershipType: plan.membershipType,
    });

    await this.userModel.findByIdAndUpdate(userId, {
      membershipType: plan.membershipType,
      isPremium: [MembershipType.PREMIUM, MembershipType.GOLDEN].includes(plan.membershipType),
      isGolden: plan.membershipType === MembershipType.GOLDEN,
      membershipExpiresAt: endDate,
      activeSubscription: subscription._id,
    });
  }

  async getUserSubscription(userId: string) {
    const subscription = await this.subscriptionModel
      .findOne({ userId: new Types.ObjectId(userId), status: SubscriptionStatus.ACTIVE })
      .populate('planId')
      .sort({ createdAt: -1 })
      .lean();

    return { message: 'Subscription retrieved', data: subscription };
  }

  async testActivateSubscription(userId: string, planId: string) {
    const plan = await this.planModel.findById(planId);
    if (!plan) throw new Error('Plan not found');

    const payment = await this.paymentModel.create({
      orderId: `TEST_${Date.now()}`,
      userId: new Types.ObjectId(userId),
      planId: new Types.ObjectId(planId),
      amount: plan.discountedPrice || plan.price,
      status: 'success',
      razorpayOrderId: `TEST_ORDER_${Date.now()}`,
      razorpayPaymentId: `TEST_PAY_${Date.now()}`,
      razorpaySignature: 'TEST_SIG',
    });

    await this.activateSubscription(userId, planId, payment._id.toString());

    return { message: 'TEST: Subscription activated (no payment)', data: { plan, payment } };
  }
}
