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
import { MIN_WALLET_BALANCE } from '../../common/constants/wallet.constant';
import Razorpay from 'razorpay';
import { ConfigService } from '@nestjs/config';
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
  ) {}

  // Lazily build the Razorpay client so missing credentials produce a clear
  // error instead of crashing the whole service at startup.
  private getRazorpay(): Razorpay {
    const keyId = this.configService.get<string>('razorpay.keyId');
    const keySecret = this.configService.get<string>('razorpay.keySecret');
    if (!keyId || !keySecret) {
      this.logger.error('Razorpay credentials are not configured (RAZORPAY_KEY_ID / RAZORPAY_KEY_SECRET).');
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
    const user = await this.userModel.findById(userId).select('walletBalance');
    if (!user || (user.walletBalance ?? 0) < MIN_WALLET_BALANCE) {
      throw new BadRequestException(
        `You need a minimum wallet balance of ₹${MIN_WALLET_BALANCE} to buy a plan. Please add money to your wallet.`,
      );
    }

    const plan = await this.planModel.findById(planId);
    if (!plan) throw new NotFoundException('Plan not found');

    const amount = (plan.discountedPrice || plan.price) * 100; // Razorpay uses paise
    const orderId = generatePaymentOrderId();

    let razorpayOrder;
    try {
      razorpayOrder = await this.getRazorpay().orders.create({
        amount,
        currency: 'INR',
        receipt: orderId,
        notes: { planId: planId.toString(), userId },
      });
    } catch (e: any) {
      this.logger.error(`Razorpay order creation failed: ${e?.error?.description ?? e?.message ?? e}`);
      throw new BadRequestException('Could not start payment. Please try again later.');
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
        amount,
        currency: 'INR',
        keyId: this.configService.get('razorpay.keyId'),
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
    const keySecret = this.configService.get('razorpay.keySecret');
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

  private async activateSubscription(userId: string, planId: string, paymentId: string) {
    const plan = await this.planModel.findById(planId);
    if (!plan) return;

    const startDate = new Date();
    const endDate = new Date();
    endDate.setDate(endDate.getDate() + plan.durationDays);

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
    const user = await this.userModel.findById(userId).select('walletBalance');
    if (!user || (user.walletBalance ?? 0) < MIN_WALLET_BALANCE) {
      throw new BadRequestException(
        `You need a minimum wallet balance of ₹${MIN_WALLET_BALANCE} to buy a plan. Please add money to your wallet.`,
      );
    }

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
