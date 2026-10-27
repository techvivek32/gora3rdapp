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

/** A user has two independent wallets on one account: 'main' is the
 *  driver/vendor wallet, 'customer' the customer-mode one. Money never crosses
 *  between them, and only 'main' counts towards MIN_WALLET_BALANCE. Every
 *  balance read and write below is scoped to exactly one of the two. */
export type WalletScope = 'main' | 'customer';

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

  // ─── Franchise scoping helpers (see AdminService for the rationale) ──────────
  // `franchiseCity` is a SCOPE OBJECT `{ cities, states }` (from the JWT), matching
  // users whose city OR state falls within it. Empty scope matches nothing.
  private cityRx(city: string) {
    return new RegExp(`^${city.trim().replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}$`, 'i');
  }
  private rxList(vals?: string[]): RegExp[] {
    return (vals || []).map((v) => (v || '').trim()).filter(Boolean).map((v) => this.cityRx(v));
  }
  private userScopeMatch(scope?: any): Record<string, any> | null {
    if (!scope) return null;
    const cityRxs = this.rxList(scope.cities);
    const stateRxs = this.rxList(scope.states);
    const or: any[] = [];
    if (cityRxs.length) or.push({ city: { $in: cityRxs } });
    if (stateRxs.length) or.push({ state: { $in: stateRxs } });
    return or.length ? { $or: or } : { _id: { $in: [] } };
  }
  private userInScope(user: any, scope?: any): boolean {
    if (!scope) return true;
    const city = (user?.city || '').trim().toLowerCase();
    const state = (user?.state || '').trim().toLowerCase();
    const inCity = !!city && (scope.cities || []).some((c: string) => (c || '').trim().toLowerCase() === city);
    const inState = !!state && (scope.states || []).some((s: string) => (s || '').trim().toLowerCase() === state);
    return inCity || inState;
  }
  /** Throws unless the target user is in the franchise's scope. No-op for admins. */
  private async assertUserInCity(userId: string, franchiseCity?: any) {
    if (!franchiseCity) return;
    if (!Types.ObjectId.isValid(userId)) throw new NotFoundException('Not found');
    const u = await this.userModel.findById(userId).select('city state').lean();
    if (!u || !this.userInScope(u, franchiseCity)) {
      throw new NotFoundException('Not found');
    }
  }
  private async cityUserIds(scope?: any): Promise<Types.ObjectId[]> {
    const cond = this.userScopeMatch(scope);
    if (!cond) return [];
    const rows = await this.userModel.find(cond).select('_id').lean();
    return rows.map((r) => r._id as Types.ObjectId);
  }

  // ─── Wallet scoping helpers ─────────────────────────────────────────────────

  /** The User field holding this wallet's available balance. */
  private balanceField(scope: WalletScope): 'walletBalance' | 'customerWalletBalance' {
    return scope === 'customer' ? 'customerWalletBalance' : 'walletBalance';
  }

  /** Transaction / withdrawal filter for one wallet. Rows written before the
   *  customer wallet existed carry no `wallet` field, so the main wallet matches
   *  "not customer" rather than "== main" — that way no backfill is needed. */
  private walletFilter(scope: WalletScope): Record<string, unknown> {
    return scope === 'customer' ? { wallet: 'customer' } : { wallet: { $ne: 'customer' } };
  }

  /** This wallet's available balance off a (possibly lean) user doc. */
  private balanceOf(user: unknown, scope: WalletScope): number {
    return ((user as any)?.[this.balanceField(scope)] as number) ?? 0;
  }

  /** The scope a stored row belongs to, tolerating legacy rows with no field. */
  private scopeOf(row: unknown): WalletScope {
    return (row as any)?.wallet === 'customer' ? 'customer' : 'main';
  }

  /** Human label used in messages, so a user knows which wallet moved. */
  private scopeLabel(scope: WalletScope): string {
    return scope === 'customer' ? 'customer wallet' : 'wallet';
  }

  // Read Razorpay keys from admin settings (DB), so admin can set them dynamically.
  private async getRazorpay(): Promise<Razorpay> {
    const { keyId, keySecret } = await this.settingsService.getRazorpayKeys();
    if (!keyId || !keySecret) {
      this.logger.error('Razorpay credentials are not configured (set them in admin Settings).');
      throw new BadRequestException('Payment gateway is not configured. Please contact support.');
    }
    return new Razorpay({ key_id: keyId, key_secret: keySecret });
  }

  /**
   * Settle top-ups that Razorpay took the money for but nobody credited.
   *
   * The app credits a top-up by calling `verifyTopUp` right after checkout. If
   * that call never lands — network drops, the app is killed or backgrounded,
   * the user closes it — the payment sits captured at Razorpay and the row
   * stays `pending` forever. That is the "paid but the balance did not update"
   * report.
   *
   * The webhook now covers this too, but it is NOT configured in the Razorpay
   * dashboard (nginx has never seen a single webhook request), and relying on
   * someone remembering to set it up is how this stays broken. So the wallet
   * also heals itself: every time it is opened, any recent pending top-up is
   * checked against Razorpay and credited if it was actually paid.
   *
   * Deliberately cheap: only rows from the last 24h that have an order id, at
   * most 5 at a time — in the normal case there are none and this costs one
   * indexed query. Best-effort throughout; reading a wallet must never fail
   * because Razorpay is slow.
   */
  private async reconcilePendingTopUps(userId: string): Promise<void> {
    try {
      const since = new Date(Date.now() - 24 * 60 * 60 * 1000);
      const pending = await this.txModel
        .find({
          userId: new Types.ObjectId(userId),
          status: 'pending',
          razorpayOrderId: { $exists: true, $nin: [null, ''] },
          createdAt: { $gte: since },
        })
        .select('razorpayOrderId')
        .limit(5)
        .lean();
      if (!pending.length) return;

      const razorpay = await this.getRazorpay();
      for (const tx of pending) {
        try {
          const res: any = await razorpay.orders.fetchPayments((tx as any).razorpayOrderId);
          const captured = (res?.items ?? []).find((p: any) => p?.status === 'captured');
          if (captured) {
            await this.creditTopUpByOrderId((tx as any).razorpayOrderId, captured.id);
          }
        } catch (e: any) {
          this.logger.warn(`Top-up reconcile failed for ${(tx as any).razorpayOrderId}: ${e?.message ?? e}`);
        }
      }
    } catch (e: any) {
      this.logger.warn(`Top-up reconcile skipped: ${e?.message ?? e}`);
    }
  }

  async getWallet(userId: string, franchiseCity?: any, scope: WalletScope = 'main') {
    await this.assertUserInCity(userId, franchiseCity);
    // Catch anything Razorpay charged for but never credited, before the
    // balance below is read — otherwise the customer sees the stale figure.
    await this.reconcilePendingTopUps(userId);
    const field = this.balanceField(scope);
    const [user, transactions] = await Promise.all([
      this.userModel.findById(userId).select(`${field} heldBalance`).lean(),
      // Only completed transactions — pending (abandoned/cancelled) ones are hidden.
      // Also hide the intermediate booking 'hold' and 'release' ledger rows: a
      // commitment shows to the user only once, as the final 'settle' (commission)
      // if the driver won, or not at all if it was released (net-zero). The amount
      // currently locked is already shown as the wallet's Held balance.
      // Transfers carry the other party so the app can show their name/number.
      // Scoped to ONE wallet, so the two sides never show each other's history.
      this.txModel
        .find({
          userId: new Types.ObjectId(userId),
          status: 'success',
          source: { $nin: ['hold', 'release'] },
          ...this.walletFilter(scope),
        })
        .populate('counterpartyId', 'fullName agencyName mobile')
        .sort({ createdAt: -1 })
        .limit(20)
        .lean(),
    ]);
    return {
      message: 'Wallet retrieved',
      data: {
        balance: this.balanceOf(user, scope),
        // Holds are a driver's booking commitments — the customer wallet has none.
        heldBalance: scope === 'customer' ? 0 : ((user as any)?.heldBalance ?? 0),
        transactions,
      },
    };
  }

  async createTopUpOrder(userId: string, dto: CreateTopUpDto, scope: WalletScope = 'main') {
    const amount = Math.round(dto.amount);
    const { minDeposit } = await this.settingsService.getWalletLimits();
    if (amount < minDeposit) throw new BadRequestException(`Minimum amount to add is ₹${minDeposit}`);

    let order;
    try {
      order = await (await this.getRazorpay()).orders.create({
        amount: amount * 100, // paise (wallet amount is entered in rupees)
        currency: 'INR',
        receipt: `wallet_${Date.now()}`,
        notes: { userId, type: 'wallet_topup', wallet: scope },
      });
    } catch (e: any) {
      const reason = e?.error?.description || e?.description || e?.message || 'unknown error';
      this.logger.error(`Razorpay order creation failed: ${reason}`);
      throw new BadRequestException(`Payment could not start: ${reason}`);
    }

    // The scope is stored on the pending row, so verifyTopUp credits the wallet
    // the money was actually added to without having to be told again.
    await this.txModel.create({
      userId: new Types.ObjectId(userId),
      wallet: scope,
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

  /**
   * "Pay by QR" top-up: a single-use Razorpay UPI QR for `amount`.
   *
   * Unlike the in-app checkout there is no success callback to trust, so the
   * app polls `topUpQrStatus` and the SERVER decides, by asking Razorpay what
   * it actually received. The wallet scope rides on the pending transaction so
   * the money lands in the wallet the customer started from.
   */
  async createTopUpQr(userId: string, dto: CreateTopUpDto, scope: WalletScope = 'main') {
    const amount = Math.round(dto.amount);
    const { minDeposit } = await this.settingsService.getWalletLimits();
    if (amount < minDeposit) throw new BadRequestException(`Minimum amount to add is ₹${minDeposit}`);

    let qr: any;
    try {
      qr = await (await this.getRazorpay()).qrCode.create({
        type: 'upi_qr',
        name: 'Gora Cabs',
        usage: 'single_use',
        fixed_amount: true,
        payment_amount: amount * 100, // paise
        description: 'Wallet top-up',
        notes: { userId, type: 'wallet_topup', wallet: scope },
      } as any);
    } catch (e: any) {
      const reason = e?.error?.description || e?.description || e?.message || 'unknown error';
      this.logger.error(`Razorpay wallet QR creation failed (amount=${amount}): ${reason}`);
      throw new BadRequestException(`QR could not be created: ${reason}`);
    }

    const tx = await this.txModel.create({
      userId: new Types.ObjectId(userId),
      wallet: scope,
      amount,
      type: 'credit',
      status: 'pending',
      razorpayQrId: qr.id,
      note: 'Wallet top-up (QR)',
    });

    return {
      message: 'QR created',
      data: { qrId: qr.id, imageUrl: qr.image_url, amount, currency: 'INR', paymentId: tx._id },
    };
  }

  /**
   * Poll a QR top-up: reconcile with Razorpay and credit the wallet once paid.
   *
   * Bound to the caller, so one user can never poll (or trigger a credit on)
   * another's transaction. The status flip is a conditional update, so two
   * polls racing can only credit the wallet once.
   */
  async topUpQrStatus(userId: string, txId: string) {
    if (!Types.ObjectId.isValid(txId)) throw new NotFoundException('Transaction not found');
    const tx = await this.txModel.findById(txId);
    if (!tx || tx.userId.toString() !== userId) throw new NotFoundException('Transaction not found');

    if (tx.status === 'success') {
      return { message: 'Paid', data: { status: 'success', amount: tx.amount } };
    }
    if (tx.status !== 'pending' || !tx.razorpayQrId) {
      return { message: 'Pending', data: { status: tx.status } };
    }

    let paid = false;
    try {
      const qr: any = await (await this.getRazorpay()).qrCode.fetch(tx.razorpayQrId);
      const received = Number(qr?.payments_amount_received || 0);
      const count = Number(qr?.payments_count_received || 0);
      paid = count > 0 || (received > 0 && received >= Number(tx.amount || 0) * 100);
    } catch (e: any) {
      this.logger.warn(`Wallet QR fetch failed: ${e?.message ?? e}`);
      return { message: 'Pending', data: { status: 'pending' } };
    }
    if (!paid) return { message: 'Pending', data: { status: 'pending' } };

    // Claim the transaction before touching the balance — a second poll that
    // loses this race must not credit the wallet twice.
    const claimed = await this.txModel.findOneAndUpdate(
      { _id: tx._id, status: 'pending' },
      { status: 'success' },
      { new: true },
    );
    if (!claimed) return { message: 'Paid', data: { status: 'success', amount: tx.amount } };

    const walletScope = this.scopeOf(claimed);
    const field = this.balanceField(walletScope);
    const user = await this.userModel
      .findByIdAndUpdate(claimed.userId, { $inc: { [field]: claimed.amount } }, { new: true })
      .select(field);

    return {
      message: 'Wallet credited successfully',
      data: { status: 'success', amount: claimed.amount, balance: this.balanceOf(user, walletScope) },
    };
  }

  /**
   * Credit a top-up straight from the Razorpay WEBHOOK, by order id.
   *
   * The app normally calls `verifyTopUp` right after checkout, but that call is
   * the only thing that credits the wallet — so if it never lands (network
   * drops, the app is killed or backgrounded, the user closes it), Razorpay has
   * the money and the wallet stays empty with nothing to reconcile it. That is
   * the "paid but balance did not update" report.
   *
   * No signature is checked here because there is none to check: the webhook's
   * own body HMAC was already verified by the controller, which is what makes
   * this order authentic. Never expose this on a route.
   *
   * Idempotent: the status flip is a conditional update, so a webhook retry (or
   * a late `verifyTopUp` racing it) can only credit the wallet once.
   */
  async creditTopUpByOrderId(razorpayOrderId: string, razorpayPaymentId?: string): Promise<void> {
    const claimed = await this.txModel.findOneAndUpdate(
      { razorpayOrderId, status: 'pending' },
      { status: 'success', ...(razorpayPaymentId ? { razorpayPaymentId } : {}) },
      { new: true },
    );
    // Not a wallet order, or already credited — either way nothing to do.
    if (!claimed) return;

    const scope = this.scopeOf(claimed);
    await this.userModel.findByIdAndUpdate(claimed.userId, {
      $inc: { [this.balanceField(scope)]: claimed.amount },
    });
    this.logger.log(`Wallet credited ₹${claimed.amount} via webhook for order ${razorpayOrderId}`);
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
      // Bind to the caller so you can only verify your OWN order — a valid
      // signature for someone else's order can't credit your wallet.
      { razorpayOrderId: dto.razorpayOrderId, userId, status: 'pending' },
      { status: 'success', razorpayPaymentId: dto.razorpayPaymentId },
      { new: true },
    );
    if (!tx) throw new NotFoundException('Transaction not found or already processed');

    // Credit the order's owner (== caller, enforced above), in the wallet the
    // top-up was started from — carried on the pending row, never from the client.
    const scope = this.scopeOf(tx);
    const field = this.balanceField(scope);
    const user = await this.userModel.findByIdAndUpdate(
      tx.userId,
      { $inc: { [field]: tx.amount } },
      { new: true },
    ).select(field);

    return {
      message: 'Wallet credited successfully',
      data: { balance: this.balanceOf(user, scope), amount: tx.amount },
    };
  }

  // ─── Admin ───────────────────────────────────────────────────────────────

  /** Paginated list of users with their wallet balance (admin wallet management). */
  async getAllWalletsForAdmin(query: { page?: number; limit?: number; search?: string }, franchiseCity?: any) {
    const page = Math.max(1, Number(query.page) || 1);
    const limit = Math.min(100, Math.max(1, Number(query.limit) || 20));
    const skip = (page - 1) * limit;

    const filter: Record<string, unknown> = {};
    if (franchiseCity) filter._id = { $in: await this.cityUserIds(franchiseCity) };
    const search = (query.search || '').trim();
    if (search) {
      const rx = new RegExp(search.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'i');
      filter.$or = [{ fullName: rx }, { mobile: rx }, { email: rx }, { agencyName: rx }];
    }
    // Period filter (year/month/week) → user account createdAt window.
    Object.assign(filter, dateRangeFilter(query));

    const [users, total] = await Promise.all([
      this.userModel
        .find(filter)
        .select('fullName mobile email agencyName city walletBalance customerWalletBalance membershipType')
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

  /** Manually add (credit) or cut (debit) a user's wallet balance with a reason.
   *  `dto.wallet` picks which of the user's two wallets to touch (default main). */
  async adjustWallet(adminId: string, userId: string, dto: AdjustWalletDto, franchiseCity?: any) {
    await this.assertUserInCity(userId, franchiseCity);
    const amount = Math.round(dto.amount);
    if (amount < 1) throw new BadRequestException('Enter a valid amount');

    const scope: WalletScope = dto.wallet === 'customer' ? 'customer' : 'main';
    const field = this.balanceField(scope);
    const user = await this.userModel.findById(userId).select(`${field} fullName`);
    if (!user) throw new NotFoundException('User not found');

    const current = this.balanceOf(user, scope);
    if (dto.type === 'debit' && amount > current) {
      throw new BadRequestException(
        `Cannot cut ₹${amount}. User's ${this.scopeLabel(scope)} balance is only ₹${current}.`,
      );
    }

    const delta = dto.type === 'credit' ? amount : -amount;

    // Record the transaction first (visible in the user's app wallet history).
    await this.txModel.create({
      userId: new Types.ObjectId(userId),
      wallet: scope,
      amount,
      type: dto.type,
      status: 'success',
      note: dto.reason,
      source: 'admin',
      adminId: new Types.ObjectId(adminId),
    });

    const updated = await this.userModel
      .findByIdAndUpdate(userId, { $inc: { [field]: delta } }, { new: true })
      .select(field);

    return {
      message: dto.type === 'credit'
        ? `Added ₹${amount} to ${user.fullName}'s ${this.scopeLabel(scope)}`
        : `Cut ₹${amount} from ${user.fullName}'s ${this.scopeLabel(scope)}`,
      data: { balance: this.balanceOf(updated, scope) },
    };
  }

  // ─── Withdrawals ───────────────────────────────────────────────────────────

  /** User requests a withdrawal. Amount is debited immediately and held until an
   *  admin approves (kept) or rejects (refunded). */
  async requestWithdrawal(userId: string, dto: RequestWithdrawalDto, scope: WalletScope = 'main') {
    const amount = Math.round(dto.amount);
    const { minWithdrawal } = await this.settingsService.getWalletLimits();
    if (amount < minWithdrawal) throw new BadRequestException(`Minimum withdrawal is ₹${minWithdrawal}`);

    // Atomic, conditional debit — the `$gte` guard makes this safe against
    // concurrent withdrawal requests that would otherwise each pass a stale
    // read-check and drive the balance negative / over-withdraw.
    const field = this.balanceField(scope);
    const updated = await this.userModel
      .findOneAndUpdate(
        { _id: userId, [field]: { $gte: amount } },
        { $inc: { [field]: -amount } },
        { new: true },
      )
      .select(field);
    if (!updated) {
      const u = await this.userModel.findById(userId).select(field);
      if (!u) throw new NotFoundException('User not found');
      throw new BadRequestException(`You can withdraw at most ₹${this.balanceOf(u, scope)}.`);
    }

    // Record the debit only after it actually succeeded (held against the request).
    await this.txModel.create({
      userId: new Types.ObjectId(userId),
      wallet: scope,
      amount,
      type: 'debit',
      status: 'success',
      note: 'Withdrawal request',
      source: 'withdrawal',
    });

    // Store only the fields that belong to the chosen payout method. The wallet
    // is stored too, so a rejection refunds the money where it came from.
    const method = dto.method ?? 'bank';
    const request = await this.withdrawalModel.create({
      userId: new Types.ObjectId(userId),
      wallet: scope,
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
      data: { balance: this.balanceOf(updated, scope), request },
    };
  }

  // ─── Wallet-to-wallet transfer ─────────────────────────────────────────────

  /** Send money from the current user's wallet to another user, found by mobile.
   *  Fails (without moving anything) when the sender's balance is short.
   *
   *  Stays INSIDE one wallet scope: a customer-wallet transfer lands in the
   *  recipient's customer wallet, never in their driver wallet. That keeps the
   *  two balances separate even when both users have both. */
  async transferFunds(userId: string, dto: TransferFundsDto, franchiseCity?: any, scope: WalletScope = 'main') {
    // The sender (:id) must be in the franchise's city. The recipient may be anywhere.
    await this.assertUserInCity(userId, franchiseCity);
    const amount = Math.round(dto.amount);
    const { minTransfer } = await this.settingsService.getWalletLimits();
    if (amount < minTransfer) throw new BadRequestException(`Minimum transfer is ₹${minTransfer}`);

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

    const field = this.balanceField(scope);
    const sender = await this.userModel.findById(userId).select(`${field} fullName`);
    if (!sender) throw new NotFoundException('User not found');
    const balance = this.balanceOf(sender, scope);
    if (amount > balance) {
      throw new BadRequestException(`Insufficient balance. You have ₹${balance}.`);
    }

    // Debit conditionally so two concurrent transfers can't overdraw the wallet.
    const debited = await this.userModel
      .findOneAndUpdate(
        { _id: new Types.ObjectId(userId), [field]: { $gte: amount } },
        { $inc: { [field]: -amount } },
        { new: true },
      )
      .select(field);
    if (!debited) throw new BadRequestException('Insufficient balance');

    try {
      await this.userModel.findByIdAndUpdate(recipient._id, { $inc: { [field]: amount } });
    } catch (e) {
      // Put the money back — never leave it debited without a matching credit.
      await this.userModel.findByIdAndUpdate(userId, { $inc: { [field]: amount } });
      this.logger.error(`Wallet transfer credit failed: ${e?.message ?? e}`);
      throw new BadRequestException('Transfer failed. Please try again.');
    }

    const toName = (recipient.agencyName || '').trim() || recipient.fullName;
    const note = dto.note?.trim();
    await this.txModel.create([
      {
        userId: new Types.ObjectId(userId),
        wallet: scope,
        counterpartyId: recipient._id,
        amount,
        type: 'debit',
        status: 'success',
        source: 'transfer',
        note: note || '', // the counterparty is stored separately, so keep the user's note as-is
      },
      {
        userId: recipient._id,
        wallet: scope,
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
      data: { balance: this.balanceOf(debited, scope), to: { name: toName, mobile: recipient.mobile } },
    };
  }

  /** Admin: list withdrawal requests (optionally filtered by status). */
  async getWithdrawals(query: any = {}, franchiseCity?: any) {
    const status = typeof query === 'string' ? query : query?.status;
    const filter: any = { ...dateRangeFilter(query) };
    if (status && ['pending', 'approved', 'rejected'].includes(status)) filter.status = status;
    // Franchise: only withdrawals raised by this city's users (ANDed with any search).
    if (franchiseCity) filter.userId = { $in: await this.cityUserIds(franchiseCity) };

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
      .populate('userId', 'fullName mobile email agencyName city walletBalance customerWalletBalance')
      .sort({ createdAt: -1 })
      .limit(200)
      .lean();
    return { message: 'Withdrawal requests', data: requests };
  }

  /** Admin: approve a pending withdrawal (amount was already debited). */
  async approveWithdrawal(adminId: string, id: string, franchiseCity?: any) {
    const request = await this.withdrawalModel.findById(id);
    if (!request) throw new NotFoundException('Withdrawal request not found');
    await this.assertUserInCity(request.userId.toString(), franchiseCity);
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
  async rejectWithdrawal(adminId: string, id: string, dto: RejectWithdrawalDto, franchiseCity?: any) {
    const request = await this.withdrawalModel.findById(id);
    if (!request) throw new NotFoundException('Withdrawal request not found');
    await this.assertUserInCity(request.userId.toString(), franchiseCity);
    if (request.status !== 'pending') {
      throw new BadRequestException(`This request is already ${request.status}.`);
    }

    // Refund the held amount back to the SAME wallet it was debited from.
    const scope = this.scopeOf(request);
    await this.txModel.create({
      userId: request.userId,
      wallet: scope,
      amount: request.amount,
      type: 'credit',
      status: 'success',
      note: `Withdrawal rejected: ${dto.reason}`,
      source: 'refund',
      adminId: new Types.ObjectId(adminId),
    });
    await this.userModel.findByIdAndUpdate(request.userId, {
      $inc: { [this.balanceField(scope)]: request.amount },
    });

    request.status = 'rejected';
    request.rejectionReason = dto.reason;
    request.processedBy = new Types.ObjectId(adminId);
    request.processedAt = new Date();
    await request.save();

    return { message: 'Withdrawal rejected and amount refunded', data: request };
  }
}
