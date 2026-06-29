import { Injectable, BadRequestException, NotFoundException } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { ConfigService } from '@nestjs/config';
import Razorpay from 'razorpay';
import * as crypto from 'crypto';
import { User, UserDocument } from '../../database/schemas/user.schema';
import { WalletTransaction, WalletTransactionDocument } from '../../database/schemas/wallet-transaction.schema';
import { CreateTopUpDto, VerifyTopUpDto } from './dto/wallet.dto';

@Injectable()
export class WalletService {
  private razorpay: Razorpay;

  constructor(
    @InjectModel(User.name) private userModel: Model<UserDocument>,
    @InjectModel(WalletTransaction.name) private txModel: Model<WalletTransactionDocument>,
    private configService: ConfigService,
  ) {
    this.razorpay = new Razorpay({
      key_id: configService.get('razorpay.keyId'),
      key_secret: configService.get('razorpay.keySecret'),
    });
  }

  async getWallet(userId: string) {
    const [user, transactions] = await Promise.all([
      this.userModel.findById(userId).select('walletBalance').lean(),
      this.txModel.find({ userId: new Types.ObjectId(userId) }).sort({ createdAt: -1 }).limit(20).lean(),
    ]);
    return {
      message: 'Wallet retrieved',
      data: { balance: user?.walletBalance ?? 0, transactions },
    };
  }

  async createTopUpOrder(userId: string, dto: CreateTopUpDto) {
    const amount = Math.round(dto.amount);
    if (amount < 1) throw new BadRequestException('Enter a valid amount');

    const order = await this.razorpay.orders.create({
      amount: amount * 100, // paise
      currency: 'INR',
      receipt: `wallet_${Date.now()}`,
      notes: { userId, type: 'wallet_topup' },
    });

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
}
