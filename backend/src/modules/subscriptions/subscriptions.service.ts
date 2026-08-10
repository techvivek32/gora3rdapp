import { Injectable, NotFoundException, BadRequestException, Logger, OnModuleInit } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
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
export class SubscriptionsService implements OnModuleInit {
  private readonly logger = new Logger(SubscriptionsService.name);

  // Run one sweep at boot so plans that expired while the server was down are
  // cleaned up right away, then keep sweeping on a schedule.
  async onModuleInit() {
    try {
      await this.expireMemberships();
    } catch (e) {
      this.logger.error('Initial expiry sweep failed', e as any);
    }
  }

  /**
   * Enforce plan expiry: any subscription past its end date becomes EXPIRED, and
   * any user whose membership has run out is downgraded to the free NEW tier (no
   * premium/golden). Without this, an expired plan kept showing "Premium" forever
   * because the premium checks only read the stored membershipType.
   */
  @Cron(CronExpression.EVERY_30_MINUTES)
  async expireMemberships() {
    const now = new Date();

    const subs = await this.subscriptionModel.updateMany(
      { status: SubscriptionStatus.ACTIVE, endDate: { $lt: now } },
      { $set: { status: SubscriptionStatus.EXPIRED } },
    );

    const users = await this.userModel.updateMany(
      { membershipExpiresAt: { $ne: null, $lt: now }, membershipType: { $ne: MembershipType.NEW } },
      { $set: { membershipType: MembershipType.NEW, isPremium: false, isGolden: false, membershipExpiresAt: null } },
    );

    const subCount = (subs as any).modifiedCount ?? 0;
    const userCount = (users as any).modifiedCount ?? 0;
    if (subCount > 0 || userCount > 0) {
      this.logger.log(`Expiry sweep: ${subCount} subscription(s) expired, ${userCount} user(s) downgraded`);
    }
  }

  /**
   * Safety net for "Pay by QR": every 2 minutes, take any pending QR payment
   * (1 min–24 h old) and ask Razorpay directly whether the QR was paid. If it
   * was, activate the membership. This catches payments where the user paid but
   * closed the screen, or the qr_code.credited webhook was missed/misconfigured.
   */
  @Cron('*/2 * * * *') // every 2 minutes
  async reconcilePendingQrPayments() {
    const now = Date.now();
    const pendings = await this.paymentModel
      .find({
        status: PaymentStatus.PENDING,
        razorpayQrId: { $exists: true, $nin: [null, ''] },
        createdAt: { $gt: new Date(now - 24 * 60 * 60 * 1000), $lt: new Date(now - 60 * 1000) },
      })
      .select('razorpayQrId amount')
      .limit(50)
      .lean();
    if (!pendings.length) return;

    let razorpay: any;
    try {
      razorpay = await this.getRazorpay();
    } catch {
      return; // Razorpay not configured
    }

    for (const p of pendings) {
      try {
        const qr: any = await razorpay.qrCode.fetch((p as any).razorpayQrId);
        const count = Number(qr?.payments_count_received || 0);
        const received = Number(qr?.payments_amount_received || 0);
        if (count > 0 || (received > 0 && received >= Number((p as any).amount || 0))) {
          await this.handleQrCredited((p as any).razorpayQrId);
        }
      } catch (e: any) {
        this.logger.warn(`QR reconcile fetch failed for ${(p as any).razorpayQrId}: ${e?.message ?? e}`);
      }
    }
  }

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

    // Plan prices are stored in paise; send directly to Razorpay.
    const amountInPaise = plan.discountedPrice || plan.price;
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
      this.logger.error(`Razorpay order creation failed (amount=${amountInPaise}): ${reason}`);
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

  /**
   * "Pay by QR": create a single-use, fixed-amount Razorpay UPI QR for the plan.
   * The app displays the returned image; the customer scans it from any UPI app
   * (on another device) and pays. Confirmation arrives out-of-band via the
   * qr_code.credited webhook → handleQrCredited(). The app polls getPaymentStatus().
   */
  async createQrOrder(userId: string, planId: string) {
    const plan = await this.planModel.findById(planId);
    if (!plan) throw new NotFoundException('Plan not found');

    const amountInPaise = plan.discountedPrice || plan.price;
    const orderId = generatePaymentOrderId();

    let qr: any;
    try {
      qr = await (await this.getRazorpay()).qrCode.create({
        type: 'upi_qr',
        name: 'Gora Cabs',
        usage: 'single_use',
        fixed_amount: true,
        payment_amount: amountInPaise,
        description: plan.name,
        notes: { planId: planId.toString(), userId, orderId },
      } as any);
    } catch (e: any) {
      const reason = e?.error?.description || e?.description || e?.message || 'unknown error';
      this.logger.error(`Razorpay QR creation failed (amount=${amountInPaise}): ${reason}`);
      throw new BadRequestException(`QR could not be created: ${reason}`);
    }

    const payment = await this.paymentModel.create({
      orderId,
      userId: new Types.ObjectId(userId),
      planId: new Types.ObjectId(planId),
      amount: amountInPaise,
      status: PaymentStatus.PENDING,
      razorpayQrId: qr.id,
    });

    return {
      message: 'QR created',
      data: {
        qrId: qr.id,
        imageUrl: qr.image_url,
        amount: amountInPaise,
        currency: 'INR',
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

  /** Webhook path for qr_code.credited: match the QR back to its pending payment and activate. Idempotent. */
  async handleQrCredited(qrId: string, razorpayPaymentId?: string) {
    if (!qrId) return;
    const payment = await this.paymentModel.findOne({ razorpayQrId: qrId });
    if (!payment) {
      this.logger.warn(`QR credited but no matching payment for qr ${qrId}`);
      return;
    }
    if (payment.status === PaymentStatus.SUCCESS) return; // already handled
    payment.status = PaymentStatus.SUCCESS;
    if (razorpayPaymentId) payment.razorpayPaymentId = razorpayPaymentId;
    await payment.save();
    await this.activateSubscription(payment.userId.toString(), payment.planId.toString(), payment._id.toString());
    this.logger.log(`QR payment credited: user ${payment.userId}, qr ${qrId}, pay ${razorpayPaymentId ?? '-'}`);
  }

  /** Lightweight status for the app to poll after showing a QR. */
  async getPaymentStatus(paymentId: string, userId: string) {
    if (!Types.ObjectId.isValid(paymentId)) throw new NotFoundException('Payment not found');
    const payment = await this.paymentModel
      .findById(paymentId)
      .select('status userId razorpayQrId amount')
      .lean();
    if (!payment || payment.userId?.toString() !== userId) throw new NotFoundException('Payment not found');

    // Active reconcile: don't rely only on the qr_code.credited webhook. If this
    // is a still-pending QR payment, ask Razorpay directly whether the QR has been
    // paid — and if so, activate the membership right here. This makes the QR flow
    // work even when the webhook isn't configured or was missed.
    if (payment.status === PaymentStatus.PENDING && (payment as any).razorpayQrId) {
      try {
        const qr: any = await (await this.getRazorpay()).qrCode.fetch((payment as any).razorpayQrId);
        const received = Number(qr?.payments_amount_received || 0);
        const count = Number(qr?.payments_count_received || 0);
        if (count > 0 || (received > 0 && received >= Number(payment.amount || 0))) {
          await this.handleQrCredited((payment as any).razorpayQrId);
          const fresh = await this.paymentModel.findById(paymentId).select('status').lean();
          return { message: 'ok', data: { status: fresh?.status, paid: fresh?.status === PaymentStatus.SUCCESS } };
        }
      } catch (e: any) {
        this.logger.warn(`QR status reconcile failed for ${paymentId}: ${e?.message ?? e}`);
      }
    }

    return { message: 'ok', data: { status: payment.status, paid: payment.status === PaymentStatus.SUCCESS } };
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
