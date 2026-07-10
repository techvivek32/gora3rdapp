import { Injectable, BadRequestException, NotFoundException, Logger } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { ConfigService } from '@nestjs/config';
import Razorpay from 'razorpay';
import * as crypto from 'crypto';
import { User, UserDocument } from '../../database/schemas/user.schema';
import { WalletTransaction, WalletTransactionDocument } from '../../database/schemas/wallet-transaction.schema';
import { WithdrawalRequest, WithdrawalRequestDocument } from '../../database/schemas/withdrawal-request.schema';
import { AdjustWalletDto, CreateTopUpDto, VerifyTopUpDto, RequestWithdrawalDto, RejectWithdrawalDto, TransferFundsDto } from './dto/wallet.dto';
import { SettingsService } from '../settings/settings.service';
import { dateRangeFilter } from '../../common/utils/pagination.util';

@Injectable()
export class WalletService {
  private readonly logger = new Logger(WalletService.name);

  constructor(
    @InjectModel(User.name) private userModel: Model<UserDocument>,
    @InjectModel(WalletTransaction.name) private txModel: Model<WalletTransactionDocument>,
    @InjectModel(WithdrawalRequest.name) private withdrawalModel: Model<WithdrawalRequestDocument>,
    private configService: ConfigService,
    private settingsService: SettingsService,
  ) {}

  // Read Razorpay keys from admin settings (DB), so admin can set them dynamically.
  private async getRazorpay(): Promise<Razorpay> {
    const { keyId, keySecret } = await this.settingsService.getRazorpayKeys();
    if (!keyId || !keySecret) {
      this.logger.error('Razorpay credentials are not configured (set them in admin Settings).');
      throw new BadRequestException('Payment gateway is not configured. Please contact support.');
    }
    return new Razorpay({ key_id: keyId, key_secret: keySecret });
  }

  async getWallet(userId: string) {
    const [user, transactions] = await Promise.all([
      this.userModel.findById(userId).select('walletBalance').lean(),
      // Only completed transactions — pending (abandoned/cancelled) ones are hidden.
      // Transfers carry the other party so the app can show their name/number.
      this.txModel
        .find({ userId: new Types.ObjectId(userId), status: 'success' })
        .populate('counterpartyId', 'fullName agencyName mobile')
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
      order = await (await this.getRazorpay()).orders.create({
        amount: amount * 100, // paise (wallet amount is entered in rupees)
        currency: 'INR',
        receipt: `wallet_${Date.now()}`,
        notes: { userId, type: 'wallet_topup' },
      });
    } catch (e: any) {
      const reason = e?.error?.description || e?.description || e?.message || 'unknown error';
      this.logger.error(`Razorpay order creation failed: ${reason}`);
      throw new BadRequestException(`Payment could not start: ${reason}`);
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
        keyId: (await this.settingsService.getRazorpayKeys()).keyId,
      },
    };
  }

  async verifyTopUp(userId: string, dto: VerifyTopUpDto) {
    const keySecret = (await this.settingsService.getRazorpayKeys()).keySecret;
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

  // ─── Withdrawals ───────────────────────────────────────────────────────────

  /** User requests a withdrawal. Amount is debited immediately and held until an
   *  admin approves (kept) or rejects (refunded). */
  async requestWithdrawal(userId: string, dto: RequestWithdrawalDto) {
    const amount = Math.round(dto.amount);
    if (amount < 1) throw new BadRequestException('Enter a valid amount');

    const user = await this.userModel.findById(userId).select('walletBalance');
    if (!user) throw new NotFoundException('User not found');

    const current = user.walletBalance ?? 0;
    if (amount > current) {
      throw new BadRequestException(`You can withdraw at most ₹${current}.`);
    }

    // Debit the wallet now (held against the request).
    await this.txModel.create({
      userId: new Types.ObjectId(userId),
      amount,
      type: 'debit',
      status: 'success',
      note: 'Withdrawal request',
      source: 'withdrawal',
    });
    const updated = await this.userModel
      .findByIdAndUpdate(userId, { $inc: { walletBalance: -amount } }, { new: true })
      .select('walletBalance');

    // Store only the fields that belong to the chosen payout method.
    const method = dto.method ?? 'bank';
    const request = await this.withdrawalModel.create({
      userId: new Types.ObjectId(userId),
      amount,
      method,
      accountHolderName: dto.accountHolderName,
      ...(method === 'bank'
        ? { bankName: dto.bankName, accountNumber: dto.accountNumber, ifsc: dto.ifsc }
        : { upiId: dto.upiId }),
      status: 'pending',
    });

    return {
      message: 'Withdrawal request submitted. It will be processed after review.',
      data: { balance: updated?.walletBalance ?? 0, request },
    };
  }

  // ─── Wallet-to-wallet transfer ─────────────────────────────────────────────

  /** Send money from the current user's wallet to another user, found by mobile.
   *  Fails (without moving anything) when the sender's balance is short. */
  async transferFunds(userId: string, dto: TransferFundsDto) {
    const amount = Math.round(dto.amount);
    if (amount < 1) throw new BadRequestException('Enter a valid amount');

    // Resolve the recipient by the last 10 digits, same as the user lookup does.
    const digits = (dto.mobile || '').replace(/\D/g, '');
    if (digits.length < 10) throw new BadRequestException('Enter a valid mobile number');
    const recipient = await this.userModel
      .findOne({ mobile: new RegExp(`${digits.slice(-10)}$`), isActive: true, isBlocked: false })
      .select('_id fullName agencyName mobile');
    if (!recipient) throw new NotFoundException('No user found with this number');
    if (recipient._id.toString() === userId) {
      throw new BadRequestException('You cannot transfer money to yourself');
    }

    const sender = await this.userModel.findById(userId).select('walletBalance fullName');
    if (!sender) throw new NotFoundException('User not found');
    const balance = sender.walletBalance ?? 0;
    if (amount > balance) {
      throw new BadRequestException(`Insufficient balance. You have ₹${balance}.`);
    }

    // Debit conditionally so two concurrent transfers can't overdraw the wallet.
    const debited = await this.userModel
      .findOneAndUpdate(
        { _id: new Types.ObjectId(userId), walletBalance: { $gte: amount } },
        { $inc: { walletBalance: -amount } },
        { new: true },
      )
      .select('walletBalance');
    if (!debited) throw new BadRequestException('Insufficient balance');

    try {
      await this.userModel.findByIdAndUpdate(recipient._id, { $inc: { walletBalance: amount } });
    } catch (e) {
      // Put the money back — never leave it debited without a matching credit.
      await this.userModel.findByIdAndUpdate(userId, { $inc: { walletBalance: amount } });
      this.logger.error(`Wallet transfer credit failed: ${e?.message ?? e}`);
      throw new BadRequestException('Transfer failed. Please try again.');
    }

    const toName = (recipient.agencyName || '').trim() || recipient.fullName;
    const note = dto.note?.trim();
    await this.txModel.create([
      {
        userId: new Types.ObjectId(userId),
        counterpartyId: recipient._id,
        amount,
        type: 'debit',
        status: 'success',
        source: 'transfer',
        note: note || '', // the counterparty is stored separately, so keep the user's note as-is
      },
      {
        userId: recipient._id,
        counterpartyId: new Types.ObjectId(userId),
        amount,
        type: 'credit',
        status: 'success',
        source: 'transfer',
        note: note || '',
      },
    ]);

    return {
      message: `₹${amount} sent to ${toName}.`,
      data: { balance: debited.walletBalance ?? 0, to: { name: toName, mobile: recipient.mobile } },
    };
  }

  /** Admin: list withdrawal requests (optionally filtered by status). */
  async getWithdrawals(query: any = {}) {
    const status = typeof query === 'string' ? query : query?.status;
    const filter: any = { ...dateRangeFilter(query) };
    if (status && ['pending', 'approved', 'rejected'].includes(status)) filter.status = status;

    // Search by the requester's name / mobile, or the payout account details.
    const search = (query?.search || '').trim();
    if (search) {
      const rx = new RegExp(search.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'i');
      const matchedUsers = await this.userModel.find({ $or: [{ fullName: rx }, { mobile: rx }] }).select('_id').lean();
      filter.$or = [
        { userId: { $in: matchedUsers.map((u) => u._id) } },
        { accountHolderName: rx },
        { accountNumber: rx },
        { upiId: rx },
      ];
    }

    const requests = await this.withdrawalModel
      .find(filter)
      .populate('userId', 'fullName mobile email agencyName city walletBalance')
      .sort({ createdAt: -1 })
      .limit(200)
      .lean();
    return { message: 'Withdrawal requests', data: requests };
  }

  /** Admin: approve a pending withdrawal (amount was already debited). */
  async approveWithdrawal(adminId: string, id: string) {
    const request = await this.withdrawalModel.findById(id);
    if (!request) throw new NotFoundException('Withdrawal request not found');
    if (request.status !== 'pending') {
      throw new BadRequestException(`This request is already ${request.status}.`);
    }
    request.status = 'approved';
    request.processedBy = new Types.ObjectId(adminId);
    request.processedAt = new Date();
    await request.save();
    return { message: 'Withdrawal approved', data: request };
  }

  /** Admin: reject a pending withdrawal and refund the held amount. */
  async rejectWithdrawal(adminId: string, id: string, dto: RejectWithdrawalDto) {
    const request = await this.withdrawalModel.findById(id);
    if (!request) throw new NotFoundException('Withdrawal request not found');
    if (request.status !== 'pending') {
      throw new BadRequestException(`This request is already ${request.status}.`);
    }

    // Refund the held amount back to the user's wallet.
    await this.txModel.create({
      userId: request.userId,
      amount: request.amount,
      type: 'credit',
      status: 'success',
      note: `Withdrawal rejected: ${dto.reason}`,
      source: 'refund',
      adminId: new Types.ObjectId(adminId),
    });
    await this.userModel.findByIdAndUpdate(request.userId, { $inc: { walletBalance: request.amount } });

    request.status = 'rejected';
    request.rejectionReason = dto.reason;
    request.processedBy = new Types.ObjectId(adminId);
    request.processedAt = new Date();
    await request.save();

    return { message: 'Withdrawal rejected and amount refunded', data: request };
  }
}
