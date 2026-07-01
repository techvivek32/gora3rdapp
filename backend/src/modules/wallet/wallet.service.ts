import { Injectable, BadRequestException, NotFoundException, Logger } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { ConfigService } from '@nestjs/config';
import Razorpay from 'razorpay';
import * as crypto from 'crypto';
import { User, UserDocument } from '../../database/schemas/user.schema';
import { WalletTransaction, WalletTransactionDocument } from '../../database/schemas/wallet-transaction.schema';
import { AdjustWalletDto, CreateTopUpDto, VerifyTopUpDto } from './dto/wallet.dto';

@Injectable()
export class WalletService {
  private readonly logger = new Logger(WalletService.name);

  constructor(
    @InjectModel(User.name) private userModel: Model<UserDocument>,
    @InjectModel(WalletTransaction.name) private txModel: Model<WalletTransactionDocument>,
    private configService: ConfigService,
  ) {}

  private getRazorpay(): Razorpay {
    const keyId = this.configService.get<string>('razorpay.keyId');
    const keySecret = this.configService.get<string>('razorpay.keySecret');
    if (!keyId || !keySecret) {
      this.logger.error('Razorpay credentials are not configured (RAZORPAY_KEY_ID / RAZORPAY_KEY_SECRET).');
      throw new BadRequestException('Payment gateway is not configured. Please contact support.');
    }
    return new Razorpay({ key_id: keyId, key_secret: keySecret });
  }

  async getWallet(userId: string) {
    const [user, transactions] = await Promise.all([
      this.userModel.findById(userId).select('walletBalance').lean(),
      // Only completed transactions — pending (abandoned/cancelled) ones are hidden.
      this.txModel
        .find({ userId: new Types.ObjectId(userId), status: 'success' })
        .sort({ createdAt: -1 })
        .limit(20)
        .lean(),
    ]);
    return {
      message: 'Wallet retrieved',
      data: { balance: user?.walletBalance ?? 0, transactions },
    };
  }

  async createTopUpOrder(userId: string, dto: CreateTopUpDto) {
    const amount = Math.round(dto.amount);
    if (amount < 1) throw new BadRequestException('Enter a valid amount');

    let order;
    try {
      order = await this.getRazorpay().orders.create({
        amount: amount * 100, // paise
        currency: 'INR',
        receipt: `wallet_${Date.now()}`,
        notes: { userId, type: 'wallet_topup' },
      });
    } catch (e: any) {
      this.logger.error(`Razorpay order creation failed: ${e?.error?.description ?? e?.message ?? e}`);
      throw new BadRequestException('Could not start payment. Please try again later.');
    }

    await this.txModel.create({
      userId: new Types.ObjectId(userId),
      amount,
      type: 'credit',
      status: 'pending',
      razorpayOrderId: order.id,
      note: 'Wallet top-up',
    });

    return {
      message: 'Top-up order created',
      data: {
        orderId: order.id,
        amount: amount * 100,
        currency: 'INR',
        keyId: this.configService.get('razorpay.keyId'),
      },
    };
  }

  async verifyTopUp(userId: string, dto: VerifyTopUpDto) {
    const keySecret = this.configService.get('razorpay.keySecret');
    const expected = crypto
      .createHmac('sha256', keySecret)
      .update(`${dto.razorpayOrderId}|${dto.razorpayPaymentId}`)
      .digest('hex');

    if (expected !== dto.razorpaySignature) {
      await this.txModel.findOneAndUpdate(
        { razorpayOrderId: dto.razorpayOrderId },
        { status: 'failed' },
      );
      throw new BadRequestException('Payment verification failed');
    }

    const tx = await this.txModel.findOneAndUpdate(
      { razorpayOrderId: dto.razorpayOrderId, status: 'pending' },
      { status: 'success', razorpayPaymentId: dto.razorpayPaymentId },
      { new: true },
    );
    if (!tx) throw new NotFoundException('Transaction not found or already processed');

    const user = await this.userModel.findByIdAndUpdate(
      userId,
      { $inc: { walletBalance: tx.amount } },
      { new: true },
    ).select('walletBalance');

    return {
      message: 'Wallet credited successfully',
      data: { balance: user?.walletBalance ?? 0, amount: tx.amount },
    };
  }

  // ─── Admin ───────────────────────────────────────────────────────────────

  /** Paginated list of users with their wallet balance (admin wallet management). */
  async getAllWalletsForAdmin(query: { page?: number; limit?: number; search?: string }) {
    const page = Math.max(1, Number(query.page) || 1);
    const limit = Math.min(100, Math.max(1, Number(query.limit) || 20));
    const skip = (page - 1) * limit;

    const filter: Record<string, unknown> = {};
    const search = (query.search || '').trim();
    if (search) {
      const rx = new RegExp(search.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'i');
      filter.$or = [{ fullName: rx }, { mobile: rx }, { email: rx }, { agencyName: rx }];
    }

    const [users, total] = await Promise.all([
      this.userModel
        .find(filter)
        .select('fullName mobile email agencyName city walletBalance membershipType')
        .sort({ walletBalance: -1, createdAt: -1 })
        .skip(skip)
        .limit(limit)
        .lean(),
      this.userModel.countDocuments(filter),
    ]);

    return {
      message: 'Wallets retrieved',
      data: {
        data: users,
        meta: { total, page, limit, totalPages: Math.ceil(total / limit) },
      },
    };
  }

  /** Manually add (credit) or cut (debit) a user's wallet balance with a reason. */
  async adjustWallet(adminId: string, userId: string, dto: AdjustWalletDto) {
    const amount = Math.round(dto.amount);
    if (amount < 1) throw new BadRequestException('Enter a valid amount');

    const user = await this.userModel.findById(userId).select('walletBalance fullName');
    if (!user) throw new NotFoundException('User not found');

    const current = user.walletBalance ?? 0;
    if (dto.type === 'debit' && amount > current) {
      throw new BadRequestException(
        `Cannot cut ₹${amount}. User's balance is only ₹${current}.`,
      );
    }

    const delta = dto.type === 'credit' ? amount : -amount;

    // Record the transaction first (visible in the user's app wallet history).
    await this.txModel.create({
      userId: new Types.ObjectId(userId),
      amount,
      type: dto.type,
      status: 'success',
      note: dto.reason,
      source: 'admin',
      adminId: new Types.ObjectId(adminId),
    });

    const updated = await this.userModel
      .findByIdAndUpdate(userId, { $inc: { walletBalance: delta } }, { new: true })
      .select('walletBalance');

    return {
      message: dto.type === 'credit'
        ? `Added ₹${amount} to ${user.fullName}'s wallet`
        : `Cut ₹${amount} from ${user.fullName}'s wallet`,
      data: { balance: updated?.walletBalance ?? 0 },
    };
  }
}
