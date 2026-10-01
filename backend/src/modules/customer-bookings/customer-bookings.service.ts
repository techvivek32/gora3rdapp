import { Injectable, Logger, NotFoundException, BadRequestException, ForbiddenException } from '@nestjs/common';
import * as crypto from 'crypto';
import { Cron, CronExpression } from '@nestjs/schedule';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import {
  CustomerBooking,
  CustomerBookingDocument,
  CustomerBookingStatus,
} from '../../database/schemas/customer-booking.schema';
import { User, UserDocument } from '../../database/schemas/user.schema';
import { WalletTransaction, WalletTransactionDocument } from '../../database/schemas/wallet-transaction.schema';
import { CabCategory, CabCategoryDocument } from '../../database/schemas/home-content.schema';
import { Payment, PaymentDocument, PaymentStatus } from '../../database/schemas/payment.schema';
import { generatePaymentOrderId } from '../../common/utils/booking-id.util';
import Razorpay from 'razorpay';
import { NotificationsService } from '../notifications/notifications.service';
import { SettingsService } from '../settings/settings.service';
import { UserRole } from '../../common/enums/user-role.enum';
import { buildInvoicePdf } from './invoice.util';
import {
  CreateCustomerBookingDto,
  UpdateCustomerBookingDto,
  ApplyBookingDto,
  RateBookingDto,
} from './dto/customer-booking.dto';

@Injectable()
export class CustomerBookingsService {
  private readonly logger = new Logger(CustomerBookingsService.name);

  constructor(
    @InjectModel(CustomerBooking.name) private bookingModel: Model<CustomerBookingDocument>,
    @InjectModel(User.name) private userModel: Model<UserDocument>,
    @InjectModel(WalletTransaction.name) private txModel: Model<WalletTransactionDocument>,
    @InjectModel(CabCategory.name) private cabCategoryModel: Model<CabCategoryDocument>,
    @InjectModel(Payment.name) private paymentModel: Model<PaymentDocument>,
    private readonly notifications: NotificationsService,
    private readonly settings: SettingsService,
  ) {}

  // ─── Advance payment (customer pays 10% / 100% to the platform) ─────────────

  /** Build the Razorpay client from the admin-set keys (env fallback). */
  private async getRazorpay(): Promise<Razorpay> {
    const keys = await this.settings.getRazorpayKeys();
    if (!keys.keyId || !keys.keySecret) {
      throw new BadRequestException('Payment gateway is not configured. Please contact support.');
    }
    return new Razorpay({ key_id: keys.keyId, key_secret: keys.keySecret });
  }

  /** Load a booking that belongs to this customer + compute the advance amount (₹). */
  private async advanceContext(customerId: string, id: string, percent: number) {
    const p = Math.round(percent);
    if (![10, 100].includes(p)) throw new BadRequestException('Advance must be 10% or 100%');
    if (!Types.ObjectId.isValid(id)) throw new NotFoundException('Booking not found');
    const booking = await this.bookingModel.findById(id);
    if (!booking) throw new NotFoundException('Booking not found');
    if (booking.customerId.toString() !== customerId) throw new ForbiddenException('Not your booking');
    if (booking.advanceStatus === 'paid') throw new BadRequestException('Advance already paid for this booking');
    const fare = booking.finalFare || booking.estimatedFare || 0;
    const rupees = Math.max(1, Math.round((fare * p) / 100));
    return { booking, percent: p, rupees, amountPaise: rupees * 100 };
  }

  /** In-app Razorpay checkout order for a booking advance. */
  async createAdvanceOrder(customerId: string, id: string, percent: number) {
    const { booking, percent: p, rupees, amountPaise } = await this.advanceContext(customerId, id, percent);
    const orderId = generatePaymentOrderId();
    let order: any;
    try {
      order = await (await this.getRazorpay()).orders.create({
        amount: amountPaise, currency: 'INR', receipt: orderId,
        notes: { bookingId: booking.bookingId, customerId, percent: `${p}` },
      });
    } catch (e: any) {
      const reason = e?.error?.description || e?.message || 'unknown error';
      throw new BadRequestException(`Payment could not start: ${reason}`);
    }
    const payment = await this.paymentModel.create({
      orderId, userId: new Types.ObjectId(customerId), bookingRef: booking._id,
      amount: rupees, status: PaymentStatus.PENDING, razorpayOrderId: order.id,
      metadata: { purpose: 'booking_advance', percent: p, bookingId: booking.bookingId },
    });
    const keys = await this.settings.getRazorpayKeys();
    return { message: 'Advance order created', data: {
      orderId: order.id, amount: amountPaise, currency: 'INR', keyId: keys.keyId,
      paymentId: payment._id, percent: p, rupees,
    } };
  }

  /** UPI QR for a booking advance (scan & pay from any UPI app). */
  async createAdvanceQr(customerId: string, id: string, percent: number) {
    const { booking, percent: p, rupees, amountPaise } = await this.advanceContext(customerId, id, percent);
    const orderId = generatePaymentOrderId();
    let qr: any;
    try {
      qr = await (await this.getRazorpay()).qrCode.create({
        type: 'upi_qr', name: 'Gora Cabs', usage: 'single_use', fixed_amount: true,
        payment_amount: amountPaise, description: `Advance ${p}% • ${booking.bookingId}`,
        notes: { bookingId: booking.bookingId, customerId, orderId, percent: `${p}` },
      } as any);
    } catch (e: any) {
      const reason = e?.error?.description || e?.message || 'unknown error';
      throw new BadRequestException(`QR could not be created: ${reason}`);
    }
    const payment = await this.paymentModel.create({
      orderId, userId: new Types.ObjectId(customerId), bookingRef: booking._id,
      amount: rupees, status: PaymentStatus.PENDING, razorpayQrId: qr.id,
      metadata: { purpose: 'booking_advance', percent: p, bookingId: booking.bookingId },
    });
    return { message: 'QR created', data: {
      qrId: qr.id, imageUrl: qr.image_url, amount: amountPaise, currency: 'INR',
      paymentId: payment._id, percent: p, rupees,
    } };
  }

  /** Mark a paid advance payment onto its booking (idempotent). */
  private async applyAdvanceToBooking(payment: PaymentDocument) {
    if (!payment.bookingRef) return;
    const percent = Number(payment.metadata?.percent) || 0;
    await this.bookingModel.updateOne(
      { _id: payment.bookingRef, advanceStatus: { $ne: 'paid' } },
      { $set: { advanceStatus: 'paid', advanceAmount: payment.amount, advancePercent: percent, advancePaymentId: payment._id } },
    );
  }

  /** Verify the in-app checkout signature, then credit the booking advance. */
  async verifyAdvance(customerId: string, data: { razorpayOrderId: string; razorpayPaymentId: string; razorpaySignature: string }) {
    const keys = await this.settings.getRazorpayKeys();
    const expected = crypto.createHmac('sha256', keys.keySecret)
      .update(`${data.razorpayOrderId}|${data.razorpayPaymentId}`).digest('hex');
    if (expected !== data.razorpaySignature) {
      await this.paymentModel.findOneAndUpdate({ razorpayOrderId: data.razorpayOrderId }, { status: PaymentStatus.FAILED });
      throw new BadRequestException('Payment verification failed');
    }
    const payment = await this.paymentModel.findOneAndUpdate(
      { razorpayOrderId: data.razorpayOrderId, status: { $ne: PaymentStatus.SUCCESS } },
      { status: PaymentStatus.SUCCESS, razorpayPaymentId: data.razorpayPaymentId, razorpaySignature: data.razorpaySignature },
      { new: true },
    );
    if (!payment) {
      const existing = await this.paymentModel.findOne({ razorpayOrderId: data.razorpayOrderId });
      if (existing?.status === PaymentStatus.SUCCESS) return { message: 'Advance already paid' };
      throw new NotFoundException('Payment not found');
    }
    await this.applyAdvanceToBooking(payment);
    return { message: 'Advance paid', data: { advanceAmount: payment.amount } };
  }

  /** Poll a QR advance: reconcile with Razorpay, credit the booking when paid. */
  async advancePaymentStatus(paymentId: string, customerId: string) {
    if (!Types.ObjectId.isValid(paymentId)) throw new NotFoundException('Payment not found');
    const payment = await this.paymentModel.findById(paymentId);
    if (!payment || payment.userId?.toString() !== customerId) throw new NotFoundException('Payment not found');
    if (payment.status === PaymentStatus.PENDING && payment.razorpayQrId) {
      try {
        const qr: any = await (await this.getRazorpay()).qrCode.fetch(payment.razorpayQrId);
        const received = Number(qr?.payments_amount_received || 0);
        const count = Number(qr?.payments_count_received || 0);
        if (count > 0 || (received > 0 && received >= Number(payment.amount || 0) * 100)) {
          payment.status = PaymentStatus.SUCCESS;
          await payment.save();
          await this.applyAdvanceToBooking(payment);
        }
      } catch (e: any) {
        this.logger.warn(`Advance QR reconcile failed ${paymentId}: ${e?.message}`);
      }
    }
    const fresh = await this.paymentModel.findById(paymentId).select('status').lean();
    return { message: 'ok', data: { status: fresh?.status, paid: fresh?.status === PaymentStatus.SUCCESS } };
  }

  private genBookingId(): string {
    return `CB${Date.now().toString().slice(-7)}${Math.floor(100 + Math.random() * 900)}`;
  }

  // ─── Wallet ledger (atomic available ↔ held ↔ settled) ─────────────────────

  /** Move `amount` from a driver's AVAILABLE to HELD. Returns false if short. */
  private async holdFunds(driverId: Types.ObjectId, amount: number, bookingRef: Types.ObjectId): Promise<boolean> {
    if (amount <= 0) return true;
    const res = await this.userModel.updateOne(
      { _id: driverId, walletBalance: { $gte: amount } },
      { $inc: { walletBalance: -amount, heldBalance: amount } },
    );
    if (!res.modifiedCount) return false;
    await this.txModel.create({
      userId: driverId, amount, type: 'debit', status: 'success',
      source: 'hold', bookingRef, note: 'Booking commitment hold',
    });
    return true;
  }

  /** Move `amount` from HELD back to AVAILABLE (application not selected / cancelled).
   * Guarded by heldBalance >= amount so a double-release can't drive held negative
   * or credit the wallet twice; the ledger row is only written when the move applies. */
  private async releaseHold(driverId: Types.ObjectId, amount: number, bookingRef: Types.ObjectId): Promise<void> {
    if (amount <= 0) return;
    const res = await this.userModel.updateOne(
      { _id: driverId, heldBalance: { $gte: amount } },
      { $inc: { heldBalance: -amount, walletBalance: amount } },
    );
    if (!res.modifiedCount) {
      this.logger.warn(`releaseHold skipped (held<${amount}) for ${driverId} on ${bookingRef}`);
      return;
    }
    await this.txModel.create({
      userId: driverId, amount, type: 'credit', status: 'success',
      source: 'release', bookingRef, note: 'Booking hold released',
    });
  }

  /** Consume `amount` from HELD as final settlement/commission (leaves the wallet).
   * Guarded so it can only ever settle once per hold. */
  private async settleHold(driverId: Types.ObjectId, amount: number, bookingRef: Types.ObjectId): Promise<void> {
    if (amount <= 0) return;
    const res = await this.userModel.updateOne(
      { _id: driverId, heldBalance: { $gte: amount } },
      { $inc: { heldBalance: -amount } },
    );
    if (!res.modifiedCount) {
      this.logger.warn(`settleHold skipped (held<${amount}) for ${driverId} on ${bookingRef}`);
      return;
    }
    await this.txModel.create({
      userId: driverId, amount, type: 'debit', status: 'success',
      source: 'settle', bookingRef, note: 'Booking commission settled',
    });
  }

  /** Refund `amount` straight to AVAILABLE (e.g. customer cancels an already-confirmed
   * booking — the selected driver is blameless, so their settled commitment comes back). */
  private async refundToWallet(driverId: Types.ObjectId, amount: number, bookingRef: Types.ObjectId, note: string): Promise<void> {
    if (amount <= 0) return;
    await this.userModel.updateOne({ _id: driverId }, { $inc: { walletBalance: amount } });
    await this.txModel.create({
      userId: driverId, amount, type: 'credit', status: 'success',
      source: 'refund', bookingRef, note,
    });
  }

  // ─── Auto-expiry: release holds on OPEN bookings past their expiry ──────────

  /**
   * Every 10 minutes, close OPEN bookings whose expiry has passed: release every
   * applicant's held commitment back to their wallet and mark the booking EXPIRED.
   * This is the safety net for bookings the customer never selected or cancelled.
   */
  @Cron(CronExpression.EVERY_10_MINUTES)
  async expireStaleBookings() {
    const now = new Date();
    const stale = await this.bookingModel
      .find({ status: CustomerBookingStatus.OPEN, expiresAt: { $lte: now } })
      .limit(200);
    if (!stale.length) return;
    let expired = 0;
    for (const booking of stale) {
      try {
        // Atomically claim OPEN → EXPIRED so overlapping cron runs (or a
        // simultaneous select/cancel) can't release the same holds twice.
        const claimed = await this.bookingModel.findOneAndUpdate(
          { _id: booking._id, status: CustomerBookingStatus.OPEN },
          { $set: { status: CustomerBookingStatus.EXPIRED } },
        );
        if (!claimed) continue; // another process already handled it
        expired++;
        for (const o of booking.offers as any[]) {
          if (o.status === 'applied') {
            await this.releaseHold(o.driverId, o.holdAmount, booking._id);
            o.status = 'released';
          }
        }
        booking.status = CustomerBookingStatus.EXPIRED;
        await booking.save();
        this.notifications.notifyUser(booking.customerId, 'Booking Expired',
          `Your ${booking.serviceType} booking ${booking.bookingId} expired with no driver selected.`,
          { type: 'customer_booking_expired', bookingId: booking.bookingId }).catch(() => {});
      } catch (e: any) {
        this.logger.warn(`expireStaleBookings ${booking.bookingId}: ${e?.message}`);
      }
    }
    if (expired) this.logger.log(`Expired ${expired} stale customer bookings (holds released)`);
  }

  // ─── Admin ─────────────────────────────────────────────────────────────────

  /** Read-only list of all customer bookings for the admin panel. */
  async listAllForAdmin(filters: { status?: string; serviceType?: string }) {
    const q: any = {};
    if (filters.status) q.status = filters.status;
    if (filters.serviceType) q.serviceType = filters.serviceType;
    const rows = await this.bookingModel
      .find(q)
      .sort({ createdAt: -1 })
      .limit(500)
      .populate('customerId', 'fullName mobile city')
      .populate('selectedDriverId', 'fullName mobile')
      .lean();
    // Expose how many drivers have accepted (so the list can badge OPEN rows) but
    // never leak the offer array itself.
    const data = rows.map((b: any) => ({
      ...b,
      acceptedCount: (b.offers ?? []).filter((o: any) => o.status !== 'released').length,
      offers: undefined,
    }));
    return { message: 'All customer bookings', data };
  }

  // ─── Customer side ─────────────────────────────────────────────────────────

  async create(customerId: string, dto: CreateCustomerBookingDto) {
    const travelDate = dto.travelDate ? new Date(dto.travelDate) : undefined;
    // Always set an expiry so the auto-release cron can never leave holds stuck:
    // 24h after travel if known, else 7 days from creation as a safety net.
    const expiresAt = travelDate
        ? new Date(travelDate.getTime() + 24 * 60 * 60 * 1000)
        : new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);

    const booking = await this.bookingModel.create({
      bookingId: this.genBookingId(),
      customerId: new Types.ObjectId(customerId),
      serviceType: dto.serviceType,
      subType: dto.subType || '',
      pickup: dto.pickup || {},
      drop: dto.drop || {},
      stops: dto.stops || [],
      pickupCity: dto.pickupCity || dto.pickup?.address || '',
      dropCity: dto.dropCity || dto.drop?.address || '',
      travelDate,
      travelTime: dto.travelTime || '',
      passengers: dto.passengers || 1,
      vehicleType: dto.vehicleType || '',
      durationHours: dto.durationHours || 0,
      notes: dto.notes || '',
      estimatedFare: dto.estimatedFare || 0,
      estimatedDistance: dto.estimatedDistance || 0,
      // Round-trip rental snapshot from the chosen cab (0 = no extra-km tracking).
      dailyKmLimit: dto.dailyKmLimit || 0,
      extraKmPrice: dto.extraKmPrice || 0,
      includedKm: dto.includedKm || 0,
      // Local hourly-package snapshot (0 = not a Local package booking).
      packageHours: dto.packageHours || 0,
      extraHourPrice: dto.extraHourPrice || 0,
      status: CustomerBookingStatus.OPEN,
      expiresAt,
    });

    // Fan the new request out to eligible drivers/vendors so they can apply.
    this.notifyEligibleDrivers(booking).catch(() => {});

    return { message: 'Booking request created', data: booking };
  }

  private static readonly SERVICE_LABEL: Record<string, string> = {
    cab: 'cab ride',
    hire_driver: 'driver',
    luxury: 'luxury car',
    car_pool: 'car pool ride',
  };

  /**
   * Push a "New Customer Booking" alert to every eligible driver/vendor whose
   * business city matches the trip, so the request shows up for them to quote.
   * Fire-and-forget — never blocks booking creation.
   */
  private async notifyEligibleDrivers(booking: any) {
    try {
      const cities = [booking.pickupCity, booking.dropCity].filter(Boolean);
      const filter: any = {
        role: { $in: [UserRole.DRIVER, UserRole.TRAVEL_AGENCY, UserRole.FLEET_OWNER] },
        isBlocked: { $ne: true },
        _id: { $ne: booking.customerId },
      };
      // Prefer city-matched drivers; if the trip has no city, skip the filter.
      if (cities.length) filter.businessCities = { $in: cities };
      const drivers = await this.userModel.find(filter).select('_id').limit(500).lean();
      const label = CustomerBookingsService.SERVICE_LABEL[booking.serviceType] || 'ride';
      const from = booking.pickupCity || 'a nearby area';
      for (const d of drivers) {
        this.notifications.notifyUser(
          d._id,
          '🚕 New Customer Booking',
          `A customer needs a ${label} from ${from}. Open "Customer Rides" to send your offer.`,
          { type: 'customer_booking_new', bookingId: booking.bookingId },
        ).catch(() => {});
      }
      this.logger.log(`Customer booking ${booking.bookingId}: notified ${drivers.length} eligible drivers`);
    } catch (e: any) {
      this.logger.warn(`notifyEligibleDrivers failed: ${e?.message}`);
    }
  }

  async getMyBookings(customerId: string, status?: string) {
    const filter: any = { customerId: new Types.ObjectId(customerId) };
    if (status) filter.status = status;
    const data = await this.bookingModel.find(filter).sort({ createdAt: -1 }).lean();
    // Hide the assigned driver's phone until the reveal window (admin setting).
    const revealHours = await this.getContactRevealHours();
    const gated = (data as any[]).map((b) => {
      if (!b.driverSnapshot || !b.selectedDriverId) return b;
      const revealed = this.contactRevealed(b, revealHours);
      return {
        ...b,
        driverSnapshot: { ...b.driverSnapshot, phone: revealed ? (b.driverSnapshot.phone || '') : '' },
        contactLocked: !revealed,
        contactRevealHours: revealHours,
      };
    });
    return { message: 'My bookings', data: gated };
  }

  /** Full booking with offer driver profiles resolved (customer view). */
  async getBookingForCustomer(customerId: string, id: string) {
    // Opt into the select:false OTP fields — the customer is allowed to see the
    // active trip OTP (they read it out to the driver).
    const booking = await this.bookingModel
      .findById(id)
      .select('+tripOtp +tripOtpAction +tripOtpExpiresAt')
      .lean();
    if (!booking) throw new NotFoundException('Booking not found');
    if (booking.customerId.toString() !== customerId) throw new ForbiddenException('Not your booking');
    return { message: 'Booking', data: await this.withOfferProfiles(booking) };
  }

  /**
   * Build a PDF invoice for a COMPLETED booking. Access: the booking's customer,
   * its selected driver, or an admin. Returns the raw PDF bytes + a filename.
   */
  async getInvoice(userId: string, roles: string[], id: string): Promise<{ buffer: Buffer; filename: string }> {
    if (!Types.ObjectId.isValid(id)) throw new NotFoundException('Booking not found');
    const booking: any = await this.bookingModel.findById(id).lean();
    if (!booking) throw new NotFoundException('Booking not found');

    this.assertInvoiceAccess(booking, userId, roles);
    return this.buildInvoiceForBooking(booking);
  }

  /** Access check shared by the direct download and the tokenized link. */
  private assertInvoiceAccess(booking: any, userId: string, roles: string[]) {
    const isAdmin = (roles || []).some((r) => r === UserRole.ADMIN || r === UserRole.SUPER_ADMIN);
    const isCustomer = booking.customerId?.toString() === userId;
    const isDriver = booking.selectedDriverId?.toString() === userId;
    if (!isAdmin && !isCustomer && !isDriver) throw new ForbiddenException('Not allowed');
    if (booking.status !== CustomerBookingStatus.COMPLETED) {
      throw new BadRequestException('Invoice is available only after the trip is completed');
    }
  }

  // ── Tokenized invoice link (lets the app open the PDF in the browser, so it
  // works without the path_provider/share_plus plugins on the device) ──────────
  private invoiceSecret(): string {
    return process.env.JWT_SECRET || process.env.ENCRYPTION_KEY || 'gora-invoice';
  }

  private makeInvoiceToken(id: string): string {
    const exp = Date.now() + 15 * 60 * 1000; // valid 15 minutes
    const payload = `${id}.${exp}`;
    const sig = crypto.createHmac('sha256', this.invoiceSecret()).update(payload).digest('hex');
    return Buffer.from(`${payload}.${sig}`).toString('base64url');
  }

  private verifyInvoiceToken(token: string): string {
    let decoded = '';
    try {
      decoded = Buffer.from(token, 'base64url').toString('utf8');
    } catch {
      throw new BadRequestException('Invalid invoice link');
    }
    const [id, expStr, sig] = decoded.split('.');
    if (!id || !expStr || !sig) throw new BadRequestException('Invalid invoice link');
    const expected = crypto.createHmac('sha256', this.invoiceSecret()).update(`${id}.${expStr}`).digest('hex');
    if (expected !== sig) throw new ForbiddenException('Invalid or tampered invoice link');
    if (Date.now() > Number(expStr)) throw new BadRequestException('Invoice link expired — please try again');
    return id;
  }

  /** Access-checked → returns a short-lived token the app opens as a public URL. */
  async getInvoiceLink(userId: string, roles: string[], id: string): Promise<{ token: string }> {
    if (!Types.ObjectId.isValid(id)) throw new NotFoundException('Booking not found');
    const booking: any = await this.bookingModel.findById(id).lean();
    if (!booking) throw new NotFoundException('Booking not found');
    this.assertInvoiceAccess(booking, userId, roles);
    return { token: this.makeInvoiceToken(id) };
  }

  /** Public: serve the PDF for a valid signed token (no login header needed). */
  async getInvoiceByToken(token: string): Promise<{ buffer: Buffer; filename: string }> {
    const id = this.verifyInvoiceToken(token);
    if (!Types.ObjectId.isValid(id)) throw new NotFoundException('Booking not found');
    const booking: any = await this.bookingModel.findById(id).lean();
    if (!booking) throw new NotFoundException('Booking not found');
    if (booking.status !== CustomerBookingStatus.COMPLETED) {
      throw new BadRequestException('Invoice is available only after the trip is completed');
    }
    return this.buildInvoiceForBooking(booking);
  }

  private async buildInvoiceForBooking(booking: any): Promise<{ buffer: Buffer; filename: string }> {
    const customer: any = await this.userModel
      .findById(booking.customerId)
      .select('fullName mobile')
      .lean();

    const fare = booking.finalFare || booking.estimatedFare || 0;
    // Toll was concatenated into `notes` client-side (there's no discrete field);
    // best-effort extract so the breakdown can show it, otherwise it's folded in.
    let tollAmount = 0;
    const m = /toll[^0-9]{0,12}(\d+)/i.exec(booking.notes || '');
    if (m) tollAmount = Math.min(Number(m[1]) || 0, fare);
    const fareMode = /all\s*inclusive/i.test(booking.notes || '') ? 'All Inclusive' : undefined;

    // Car details for the invoice: match the booked class (vehicleType is the cab
    // category name) and read its class/seats/bags/per-km rate from the admin panel.
    const fuelMatch = /fuel[:\s-]*([a-zA-Z]+)/i.exec(booking.notes || '');
    const fuel = fuelMatch ? fuelMatch[1] : '';
    // Round-trip return date lives only in notes ("Return date: dd-MM-yyyy").
    const retMatch = /Return date:\s*(\d{2}-\d{2}-\d{4})/i.exec(booking.notes || '');
    const returnDate = retMatch ? retMatch[1] : '';
    let carClass = '';
    let carSeats = 0;
    let carBags = '';
    let ratePerKm = 0;
    try {
      if (booking.vehicleType) {
        const cat: any = await this.cabCategoryModel
          .findOne({ name: new RegExp(`^${booking.vehicleType}$`, 'i') })
          .lean();
        if (cat) {
          carClass = cat.vehicleClass || '';
          carSeats = cat.seats || 0;
          carBags = cat.bags || '';
          const f = fuel.toLowerCase();
          ratePerKm =
            (f === 'diesel' ? cat.pricePerKmDiesel : f === 'cng' ? cat.pricePerKmCng : f === 'petrol' ? cat.pricePerKmPetrol : 0) ||
            cat.pricePerKm ||
            0;
        }
      }
    } catch {
      /* best-effort — invoice still renders without car details */
    }

    const buffer = await buildInvoicePdf({
      bookingId: booking.bookingId,
      serviceType: booking.serviceType,
      subType: booking.subType,
      customerName: customer?.fullName || 'Customer',
      customerMobile: customer?.mobile || '',
      driverName: booking.driverSnapshot?.name || 'Driver',
      driverPhone: booking.driverSnapshot?.phone || '',
      vehicle: booking.driverSnapshot?.vehicle || booking.vehicleType || '',
      vehicleNumber: booking.driverSnapshot?.vehicleNumber || '',
      carName: booking.vehicleType || '',
      carClass,
      carSeats,
      carBags,
      carFuel: fuel,
      ratePerKm,
      dailyKmLimit: booking.dailyKmLimit || 0,
      pickup: booking.pickup?.address || '',
      drop: booking.drop?.address || '',
      pickupCity: booking.pickupCity || '',
      dropCity: booking.dropCity || '',
      travelDate: booking.travelDate,
      travelTime: booking.travelTime,
      returnDate,
      startedAt: booking.startedAt,
      completedAt: booking.completedAt,
      distanceKm: booking.estimatedDistance || 0,
      passengers: booking.passengers || 0,
      fare,
      tollAmount,
      fareMode,
      includedKm: booking.includedKm || 0,
      trackedKm: booking.trackedKm || 0,
      extraKm: booking.extraKm || 0,
      extraKmPrice: booking.extraKmPrice || 0,
      extraCharge: booking.extraCharge || 0,
      // Local hourly package.
      packageHours: booking.packageHours || 0,
      extraHourPrice: booking.extraHourPrice || 0,
      extraHours: booking.extraHours || 0,
      extraHourCharge: booking.extraHourCharge || 0,
      paymentMode: 'Cash — paid directly to the driver',
    });

    return { buffer, filename: `Gora-Invoice-${booking.bookingId}.pdf` };
  }

  /** Static cancellation policy shown to the customer (no longer admin-configurable). */
  private static readonly CANCELLATION_POLICY =
    'Free cancellation before the driver starts the trip. After the trip starts, charges may apply as per driver terms.';

  /**
   * Pickup instant for a customer booking. travelDate is stored at UTC-midnight of
   * the pickup day; travelTime is a free-form IST display string ("5:30 PM" or
   * "17:30"). Combine them into a real instant; null if unparseable.
   */
  private pickupInstant(booking: any): Date | null {
    if (!booking?.travelDate) return null;
    const d = new Date(booking.travelDate);
    if (isNaN(d.getTime())) return null;
    let hours = 0;
    let mins = 0;
    const m = /^(\d{1,2}):(\d{2})\s*(AM|PM)?/i.exec((booking.travelTime || '').trim());
    if (m) {
      hours = parseInt(m[1], 10) % 24;
      mins = parseInt(m[2], 10);
      const ap = m[3] ? m[3].toUpperCase() : '';
      if (ap === 'PM' && hours < 12) hours += 12;
      if (ap === 'AM' && hours === 12) hours = 0;
    }
    const IST_OFFSET = 5.5 * 60 * 60 * 1000;
    const istWall = Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate(), hours, mins);
    return new Date(istWall - IST_OFFSET);
  }

  /**
   * Whether the driver↔customer phone numbers may be shown for this booking yet.
   * Hidden until `contactRevealHoursBeforePickup` hours before pickup (admin setting).
   * 0 hours = always revealed; an unparseable pickup time also reveals (don't block).
   */
  private contactRevealed(booking: any, revealHours: number): boolean {
    if (!revealHours || revealHours <= 0) return true;
    const pickup = this.pickupInstant(booking);
    if (!pickup) return true;
    return Date.now() >= pickup.getTime() - revealHours * 3600000;
  }

  private async getContactRevealHours(): Promise<number> {
    const s: any = await this.settings.getSettings();
    return s?.contactRevealHoursBeforePickup ?? 1;
  }

  private async withOfferProfiles(booking: any) {
    const cancellationPolicy = CustomerBookingsService.CANCELLATION_POLICY;
    // Surface an active trip OTP to the customer only; strip the raw stored fields.
    const otpActive = booking.tripOtp && booking.tripOtpExpiresAt && new Date(booking.tripOtpExpiresAt).getTime() > Date.now();
    const tripOtp = otpActive ? booking.tripOtp : '';
    const tripOtpAction = otpActive ? booking.tripOtpAction : '';
    delete booking.tripOtp; delete booking.tripOtpExpiresAt;
    booking = { ...booking, tripOtp, tripOtpAction };
    // Hide the assigned driver's phone from the customer until the reveal window
    // (admin: contactRevealHoursBeforePickup). The driver's name/vehicle still show.
    const revealHours = await this.getContactRevealHours();
    const revealed = this.contactRevealed(booking, revealHours);
    if (booking.driverSnapshot && booking.selectedDriverId) {
      booking = {
        ...booking,
        driverSnapshot: { ...booking.driverSnapshot, phone: revealed ? (booking.driverSnapshot.phone || '') : '' },
        contactLocked: !revealed,
        contactRevealHours: revealHours,
      };
    }
    const ids = (booking.offers ?? []).map((o: any) => o.driverId);
    if (!ids.length) return { ...booking, offers: [], cancellationPolicy };
    const drivers = await this.userModel
      .find({ _id: { $in: ids } })
      .select('fullName agencyName profileImage rating totalRatings mobile city vehicles membershipType isVerified createdAt')
      .lean();
    const byId = new Map(drivers.map((d: any) => [d._id.toString(), d]));
    // The customer must NEVER see wallet balances — only profile + quote.
    const offers = (booking.offers ?? [])
      .filter((o: any) => o.status !== 'released')
      .map((o: any) => {
        const d: any = byId.get(o.driverId.toString()) || {};
        return {
          offerId: o._id,
          driverId: o.driverId,
          name: d.agencyName || d.fullName || 'Driver',
          profileImage: d.profileImage || '',
          rating: d.rating || 0,
          totalRatings: d.totalRatings || 0,
          isVerified: d.isVerified || false,
          city: d.city || '',
          memberSince: d.createdAt ? new Date(d.createdAt).getFullYear() : null,
          quotedFare: o.quotedFare,
          vehicle: o.vehicle,
          vehicleNumber: o.vehicleNumber,
          vehicleImage: o.vehicleImage || '',
          farePerSeat: o.farePerSeat || 0,
          seatsAvailable: o.seatsAvailable || 0,
          message: o.message,
          status: o.status,
        };
      });
    return { ...booking, offers, cancellationPolicy };
  }

  async selectDriver(customerId: string, id: string, offerId: string) {
    const booking = await this.bookingModel.findById(id);
    if (!booking) throw new NotFoundException('Booking not found');
    if (booking.customerId.toString() !== customerId) throw new ForbiddenException('Not your booking');
    if (booking.status !== CustomerBookingStatus.OPEN) {
      throw new BadRequestException('This booking is no longer open');
    }
    const chosen: any = booking.offers.find((o: any) => o._id.toString() === offerId);
    if (!chosen) throw new NotFoundException('Offer not found');

    // Atomically claim the OPEN → CONFIRMED transition so only ONE select (and
    // not a concurrent cancel/expiry) can settle/release these holds.
    const claimed = await this.bookingModel.findOneAndUpdate(
      { _id: booking._id, status: CustomerBookingStatus.OPEN },
      { $set: { status: CustomerBookingStatus.CONFIRMED } },
    );
    if (!claimed) throw new BadRequestException('This booking is no longer open');

    // Selected driver's hold → settlement; every other applicant's hold → released.
    await this.settleHold(chosen.driverId, chosen.holdAmount, booking._id);
    chosen.status = 'selected';
    for (const o of booking.offers as any[]) {
      if (o._id.toString() !== offerId && o.status === 'applied') {
        await this.releaseHold(o.driverId, o.holdAmount, booking._id);
        o.status = 'released';
      }
    }

    const driver = await this.userModel
      .findById(chosen.driverId)
      .select('fullName agencyName mobile rating')
      .lean();

    booking.selectedDriverId = chosen.driverId;
    booking.finalFare = chosen.quotedFare || booking.estimatedFare;
    booking.status = CustomerBookingStatus.CONFIRMED;
    booking.confirmedAt = new Date();
    booking.driverSnapshot = {
      name: (driver as any)?.agencyName || (driver as any)?.fullName || 'Driver',
      phone: (driver as any)?.mobile || '',
      vehicle: chosen.vehicle,
      vehicleNumber: chosen.vehicleNumber,
      rating: (driver as any)?.rating || 0,
    };
    await booking.save();

    this.notifications.notifyUser(chosen.driverId, '🎉 You got the booking!',
      `Customer selected you for ${booking.bookingId}. Contact & start the trip.`,
      { type: 'customer_booking_selected', bookingId: booking.bookingId }).catch(() => {});
    this.notifications.notifyUser(booking.customerId, '✅ Booking Confirmed',
      `Your ${booking.serviceType} booking is confirmed with ${booking.driverSnapshot.name}.`,
      { type: 'customer_booking_confirmed', bookingId: booking.bookingId }).catch(() => {});

    return { message: 'Driver selected — booking confirmed', data: booking };
  }

  /**
   * Customer edits an OPEN booking. Because drivers quoted against the OLD trip
   * details, every existing hold is released and their offers cleared, so they
   * can re-apply for the updated request.
   */
  async updateByCustomer(customerId: string, id: string, dto: UpdateCustomerBookingDto) {
    const booking = await this.bookingModel.findById(id);
    if (!booking) throw new NotFoundException('Booking not found');
    if (booking.customerId.toString() !== customerId) throw new ForbiddenException('Not your booking');
    if (booking.status !== CustomerBookingStatus.OPEN) {
      throw new BadRequestException('Only an open booking (no driver selected yet) can be edited');
    }

    // Release every current applicant — their quote was for the old details.
    for (const o of booking.offers as any[]) {
      if (o.status === 'applied') {
        await this.releaseHold(o.driverId, o.holdAmount, booking._id);
        this.notifications.notifyUser(o.driverId, 'Booking Updated',
          `Booking ${booking.bookingId} was edited by the customer. Your hold is released — review and re-apply.`,
          { type: 'customer_booking_updated', bookingId: booking.bookingId }).catch(() => {});
      }
    }
    booking.offers = [] as any;

    // Apply the editable fields (serviceType stays fixed).
    if (dto.subType !== undefined) booking.subType = dto.subType;
    if (dto.pickup !== undefined) booking.pickup = dto.pickup as any;
    if (dto.drop !== undefined) booking.drop = dto.drop as any;
    if (dto.stops !== undefined) booking.stops = dto.stops as any;
    if (dto.pickupCity !== undefined) booking.pickupCity = dto.pickupCity;
    if (dto.dropCity !== undefined) booking.dropCity = dto.dropCity;
    if (dto.travelTime !== undefined) booking.travelTime = dto.travelTime;
    if (dto.passengers !== undefined) booking.passengers = dto.passengers;
    if (dto.vehicleType !== undefined) booking.vehicleType = dto.vehicleType;
    if (dto.durationHours !== undefined) booking.durationHours = dto.durationHours;
    if (dto.notes !== undefined) booking.notes = dto.notes;
    if (dto.estimatedFare !== undefined) booking.estimatedFare = dto.estimatedFare;
    if (dto.estimatedDistance !== undefined) booking.estimatedDistance = dto.estimatedDistance;
    // Pricing snapshots (round-trip km + Local hourly) must follow an edit too.
    if (dto.dailyKmLimit !== undefined) booking.dailyKmLimit = dto.dailyKmLimit;
    if (dto.extraKmPrice !== undefined) booking.extraKmPrice = dto.extraKmPrice;
    if (dto.includedKm !== undefined) booking.includedKm = dto.includedKm;
    if (dto.packageHours !== undefined) booking.packageHours = dto.packageHours;
    if (dto.extraHourPrice !== undefined) booking.extraHourPrice = dto.extraHourPrice;
    if (dto.travelDate !== undefined) {
      const td = dto.travelDate ? new Date(dto.travelDate) : undefined;
      booking.travelDate = td as any;
      booking.expiresAt = td
        ? new Date(td.getTime() + 24 * 60 * 60 * 1000)
        : new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);
    }
    await booking.save();

    // Re-notify eligible drivers about the refreshed request.
    this.notifyEligibleDrivers(booking).catch(() => {});
    return { message: 'Booking updated', data: booking };
  }

  async cancelByCustomer(customerId: string, id: string, reason?: string) {
    const booking = await this.bookingModel.findById(id);
    if (!booking) throw new NotFoundException('Booking not found');
    if (booking.customerId.toString() !== customerId) throw new ForbiddenException('Not your booking');
    // Atomically claim the cancel so a concurrent select/expiry can't also run.
    // findOneAndUpdate returns the PRE-update doc, so `claimed.status` is the prior status.
    const claimed = await this.bookingModel.findOneAndUpdate(
      { _id: booking._id, status: { $in: [CustomerBookingStatus.OPEN, CustomerBookingStatus.CONFIRMED, CustomerBookingStatus.ONGOING] } },
      { $set: { status: CustomerBookingStatus.CANCELLED } },
    );
    if (!claimed) throw new BadRequestException('Booking already closed');
    const priorStatus = claimed.status;

    // Re-fetch AFTER the claim so we act on the final offer set (an offer pushed
    // just before the claim is included; no new offer can arrive now that the
    // status is terminal, so this save() can't drop a concurrent offer).
    const fresh = await this.bookingModel.findById(id).select('+tripOtp +tripOtpAction +tripOtpExpiresAt');
    if (fresh) {
      // Release every still-held application (not yet in final settlement).
      for (const o of fresh.offers as any[]) {
        if (o.status === 'applied') {
          await this.releaseHold(o.driverId, o.holdAmount, fresh._id);
          o.status = 'released';
          this.notifications.notifyUser(o.driverId, 'Booking Cancelled',
            `Booking ${fresh.bookingId} was cancelled — your commitment hold has been released.`,
            { type: 'customer_booking_cancelled', bookingId: fresh.bookingId }).catch(() => {});
        }
      }
      // The customer cancelled an already-confirmed/ongoing trip: the selected
      // driver is blameless, so refund their settled commitment.
      if (priorStatus === CustomerBookingStatus.CONFIRMED || priorStatus === CustomerBookingStatus.ONGOING) {
        const sel = (fresh.offers as any[]).find((o) => o.status === 'selected');
        if (sel && sel.holdAmount > 0) {
          await this.refundToWallet(sel.driverId, sel.holdAmount, fresh._id, 'Commitment refunded — booking cancelled by customer');
        }
      }
      fresh.status = CustomerBookingStatus.CANCELLED;
      fresh.cancelledAt = new Date();
      fresh.cancelledBy = 'customer';
      fresh.cancelReason = reason || '';
      fresh.tripOtp = undefined as any;
      fresh.tripOtpAction = undefined as any;
      fresh.tripOtpExpiresAt = undefined as any;
      await fresh.save();
    }

    if (claimed.selectedDriverId) {
      this.notifications.notifyUser(claimed.selectedDriverId, 'Booking Cancelled',
        `Booking ${claimed.bookingId} was cancelled by the customer.`,
        { type: 'customer_booking_cancelled', bookingId: claimed.bookingId }).catch(() => {});
    }
    return { message: 'Booking cancelled', data: fresh ?? claimed };
  }

  async rate(customerId: string, id: string, dto: RateBookingDto) {
    const booking = await this.bookingModel.findById(id);
    if (!booking) throw new NotFoundException('Booking not found');
    if (booking.customerId.toString() !== customerId) throw new ForbiddenException('Not your booking');
    if (booking.status !== CustomerBookingStatus.COMPLETED) {
      throw new BadRequestException('You can rate only after the trip is completed');
    }
    if (booking.rating && booking.rating > 0) {
      throw new BadRequestException('You have already rated this trip');
    }
    booking.rating = Math.max(0, Math.min(5, dto.rating));
    booking.review = dto.review || '';
    await booking.save();

    // Fold into the driver's aggregate rating.
    if (booking.selectedDriverId) {
      const driver = await this.userModel.findById(booking.selectedDriverId).select('rating totalRatings');
      if (driver) {
        const total = (driver.totalRatings || 0) + 1;
        const avg = ((driver.rating || 0) * (driver.totalRatings || 0) + booking.rating) / total;
        await this.userModel.updateOne({ _id: driver._id }, { $set: { rating: avg, totalRatings: total } });
      }
    }
    return { message: 'Thanks for your feedback', data: booking };
  }

  // ─── Driver / vendor side ──────────────────────────────────────────────────

  /** Open bookings a driver can apply to (not their own, not expired, city match). */
  async listAvailable(driverId: string, serviceType?: string) {
    const driver = await this.userModel
      .findById(driverId)
      .select('businessCities isGolden membershipType membershipExpiresAt')
      .lean();
    // Everyone can SEE customer-app bookings; only Golden members can ACCEPT them.
    // `canAccept` drives whether the app shows the Accept button or a
    // "Golden membership required" note in its place.
    const canAccept = this.isGoldenActive(driver);
    const cities = ((driver as any)?.businessCities ?? []).filter(Boolean);
    // Keep confirmed/booked ones visible (with a BOOKED stamp) for 7 days after
    // they were taken, like the requirements feed — then they drop off.
    const sevenDaysAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
    const statusCond = {
      $or: [
        { status: CustomerBookingStatus.OPEN },
        {
          status: { $in: [CustomerBookingStatus.CONFIRMED, CustomerBookingStatus.ONGOING, CustomerBookingStatus.COMPLETED] },
          confirmedAt: { $gte: sevenDaysAgo },
        },
      ],
    };
    const filter: any = {
      customerId: { $ne: new Types.ObjectId(driverId) },
      $and: [statusCond],
    };
    if (serviceType) filter.serviceType = serviceType;
    if (cities.length) {
      filter.$and.push({
        $or: [
          { pickupCity: { $in: cities } },
          { dropCity: { $in: cities } },
        ],
      });
    }
    const bookings = await this.bookingModel.find(filter).sort({ createdAt: -1 }).limit(100).lean();
    const uid = driverId;
    // Hide other drivers' quotes; only flag whether THIS driver already applied.
    const data = bookings.map((b: any) => ({
      ...b,
      offerCount: (b.offers ?? []).filter((o: any) => o.status !== 'released').length,
      alreadyApplied: (b.offers ?? []).some((o: any) => o.driverId.toString() === uid && o.status !== 'released'),
      // Per-item so it survives the response interceptor (which keeps only `data`).
      canAccept,
      offers: undefined,
    }));
    return { message: 'Available bookings', data, canAccept, goldenRequired: !canAccept };
  }

  async apply(driverId: string, id: string, dto: ApplyBookingDto) {
    const booking = await this.bookingModel.findById(id);
    if (!booking) throw new NotFoundException('Booking not found');
    if (booking.status !== CustomerBookingStatus.OPEN) {
      throw new BadRequestException('This booking is no longer open');
    }
    if (booking.customerId.toString() === driverId) {
      throw new BadRequestException('You cannot apply to your own booking');
    }
    const dId = new Types.ObjectId(driverId);
    // Duplicate-application guard: one active offer per driver per booking.
    if (booking.offers.some((o: any) => o.driverId.toString() === driverId && o.status !== 'released')) {
      throw new BadRequestException('You have already applied to this booking');
    }

    // Car Pooling: the driver quotes a per-seat fare; the total = perSeat × seats.
    const seats = booking.passengers || 1;
    let fare = dto.quotedFare && dto.quotedFare > 0 ? dto.quotedFare : booking.estimatedFare;
    if (booking.serviceType === 'car_pool' && dto.farePerSeat && dto.farePerSeat > 0) {
      fare = Math.round(dto.farePerSeat * seats);
    }
    const holdAmount = Math.round((fare * (booking.commitmentPercent || 0)) / 100);

    // Hold first (atomic on the wallet), then attempt an ATOMIC conditional push:
    // the offer is only added if the booking is still OPEN and this driver has no
    // active (non-released) offer. This closes the concurrent double-hold / double
    // -apply / status-revert races that a load→mutate→save() would allow.
    const held = await this.holdFunds(dId, holdAmount, booking._id);
    if (!held) {
      throw new BadRequestException(
        `Insufficient wallet balance. You need ₹${holdAmount} available to apply for this booking.`,
      );
    }

    const offer = {
      driverId: dId,
      quotedFare: fare,
      holdAmount,
      vehicle: dto.vehicle || '',
      vehicleNumber: dto.vehicleNumber || '',
      vehicleImage: dto.vehicleImage || '',
      message: dto.message || '',
      farePerSeat: dto.farePerSeat || 0,
      seatsAvailable: dto.seatsAvailable || 0,
      status: 'applied',
    };
    const pushed = await this.bookingModel.findOneAndUpdate(
      {
        _id: booking._id,
        status: CustomerBookingStatus.OPEN,
        offers: { $not: { $elemMatch: { driverId: dId, status: { $ne: 'released' } } } },
      },
      { $push: { offers: offer as any } },
    );
    if (!pushed) {
      // Booking closed or a concurrent apply won the race — roll the hold back.
      await this.releaseHold(dId, holdAmount, booking._id);
      throw new BadRequestException('This booking is no longer open, or you have already applied.');
    }

    this.notifications.notifyUser(booking.customerId, '🚕 New Offer Received',
      `A driver applied for your ${booking.serviceType} booking ${booking.bookingId}.`,
      { type: 'customer_booking_offer', bookingId: booking.bookingId }).catch(() => {});

    return { message: 'Applied successfully', data: { holdAmount } };
  }

  /** A user is an active Golden member (flag or tier, and not expired). */
  private isGoldenActive(u: any): boolean {
    if (!u) return false;
    const golden = u.isGolden === true || u.membershipType === 'golden';
    if (!golden) return false;
    if (u.membershipExpiresAt && new Date(u.membershipExpiresAt) <= new Date()) return false;
    return true;
  }

  /**
   * Golden driver/vendor ACCEPTS an open booking → registers their interest only.
   * It does NOT assign the driver: the booking stays OPEN and an admin later picks
   * one of the accepted drivers to assign (see `adminAssign`). Nothing is held or
   * charged — the driver only needs the admin-set minimum wallet balance to be
   * eligible. Multiple drivers can accept the same booking.
   */
  async acceptDirect(
    driverId: string,
    id: string,
    selection?: { vehicle?: string; vehicleNumber?: string; vehicleImage?: string; driverName?: string; driverPhone?: string },
  ) {
    const driver = await this.userModel
      .findById(driverId)
      .select('isGolden membershipType membershipExpiresAt fullName agencyName mobile rating walletBalance')
      .lean();
    if (!this.isGoldenActive(driver)) {
      throw new ForbiddenException('Only Golden members can accept customer bookings.');
    }

    // Eligibility only: the driver must keep a minimum wallet balance (set by
    // admin). Nothing is deducted or held.
    const settings: any = await this.settings.getSettings();
    const minWallet = Math.max(0, Math.round(settings?.minWalletToAccept || 0));
    const balance = (driver as any)?.walletBalance || 0;
    if (minWallet > 0 && balance < minWallet) {
      throw new BadRequestException(
        `A minimum wallet balance of ₹${minWallet} is required to accept bookings. Your balance is ₹${Math.round(balance)}. Please recharge.`,
      );
    }

    const booking = await this.bookingModel.findById(id);
    if (!booking) throw new NotFoundException('Booking not found');
    if (booking.status !== CustomerBookingStatus.OPEN) throw new BadRequestException('This booking is no longer open');
    if (booking.customerId.toString() === driverId) throw new BadRequestException('You cannot accept your own booking');

    const dId = new Types.ObjectId(driverId);
    const fare = booking.estimatedFare || 0;

    // Register interest with an ATOMIC conditional push: the offer is added only
    // if the booking is still OPEN and this driver has no active offer already.
    // This closes the concurrent double-accept race without any wallet hold.
    const offer = {
      driverId: dId,
      quotedFare: fare,
      holdAmount: 0,
      vehicle: selection?.vehicle || '',
      vehicleNumber: selection?.vehicleNumber || '',
      vehicleImage: selection?.vehicleImage || '',
      assignedDriverName: selection?.driverName || '',
      assignedDriverPhone: selection?.driverPhone || '',
      message: '',
      farePerSeat: 0,
      seatsAvailable: 0,
      status: 'applied',
    };
    // Local (in-city hourly): accept = INSTANT assign to this driver. There's no
    // admin-assign step for Local — the first Golden driver to accept gets it and
    // the booking is confirmed straight away. Atomic OPEN→CONFIRMED so a concurrent
    // accept loses the race cleanly.
    if (booking.subType === 'Local') {
      const snapshot = {
        name: selection?.driverName || (driver as any)?.agencyName || (driver as any)?.fullName || 'Driver',
        phone: selection?.driverPhone || (driver as any)?.mobile || '',
        vehicle: selection?.vehicle || booking.vehicleType || '',
        vehicleNumber: selection?.vehicleNumber || '',
        rating: (driver as any)?.rating || 0,
      };
      const claimed = await this.bookingModel.findOneAndUpdate(
        { _id: booking._id, status: CustomerBookingStatus.OPEN },
        {
          $set: {
            status: CustomerBookingStatus.CONFIRMED,
            selectedDriverId: dId,
            confirmedAt: new Date(),
            finalFare: fare,
            driverSnapshot: snapshot,
          },
          $push: { offers: { ...offer, status: 'selected' } as any },
        },
      );
      if (!claimed) {
        throw new BadRequestException('This booking is no longer open, or you have already accepted it.');
      }
      this.notifications.notifyUser(dId, '🎉 You got the booking!',
        `Local booking ${booking.bookingId} is assigned to you. Contact the customer and start the trip.`,
        { type: 'customer_booking_selected', bookingId: booking.bookingId }).catch(() => {});
      this.notifications.notifyUser(booking.customerId, '✅ Booking Confirmed',
        `Your local booking ${booking.bookingId} is confirmed with ${snapshot.name}.`,
        { type: 'customer_booking_confirmed', bookingId: booking.bookingId }).catch(() => {});
      return { message: 'Booking confirmed — assigned to you', data: { accepted: true, confirmed: true } };
    }

    const pushed = await this.bookingModel.findOneAndUpdate(
      {
        _id: booking._id,
        status: CustomerBookingStatus.OPEN,
        offers: { $not: { $elemMatch: { driverId: dId, status: { $ne: 'released' } } } },
      },
      { $push: { offers: offer as any } },
    );
    if (!pushed) {
      throw new BadRequestException('This booking is no longer open, or you have already accepted it.');
    }

    this.notifications.notifyUser(booking.customerId, '🚕 A driver accepted your booking',
      `A partner accepted your ${booking.serviceType} booking ${booking.bookingId}. Our team will assign the driver shortly.`,
      { type: 'customer_booking_offer', bookingId: booking.bookingId }).catch(() => {});

    return { message: 'Accepted — our team will assign the driver shortly', data: { accepted: true } };
  }

  // ─── Admin assignment ────────────────────────────────────────────────────────

  /**
   * Admin view of ONE customer booking with the full review of every driver who
   * accepted (rating, car/RC, membership, wallet, city, completed trips), so the
   * admin can compare and assign one.
   */
  async getAdminBookingDetail(id: string) {
    if (!Types.ObjectId.isValid(id)) throw new NotFoundException('Booking not found');
    const booking: any = await this.bookingModel
      .findById(id)
      .populate('customerId', 'fullName mobile city')
      .populate('selectedDriverId', 'fullName mobile')
      .lean();
    if (!booking) throw new NotFoundException('Booking not found');

    const activeOffers = (booking.offers ?? []).filter((o: any) => o.status !== 'released');
    const ids = activeOffers.map((o: any) => o.driverId);
    let acceptedDrivers: any[] = [];
    if (ids.length) {
      const drivers = await this.userModel
        .find({ _id: { $in: ids } })
        .select('fullName agencyName profileImage mobile city rating totalRatings membershipType isGolden isVerified walletBalance businessCities documents')
        .lean();
      const byId = new Map(drivers.map((d: any) => [d._id.toString(), d]));
      acceptedDrivers = await Promise.all(
        activeOffers.map(async (o: any) => {
          const d: any = byId.get(o.driverId.toString()) || {};
          const rc: any = d.documents?.vehicleRc || {};
          const completedTrips = await this.bookingModel.countDocuments({
            selectedDriverId: d._id,
            status: CustomerBookingStatus.COMPLETED,
          }).catch(() => 0);
          return {
            offerId: o._id,
            driverId: o.driverId,
            name: d.agencyName || d.fullName || 'Driver',
            fullName: d.fullName || '',
            profileImage: d.profileImage || '',
            mobile: d.mobile || '',
            city: d.city || '',
            businessCities: d.businessCities || [],
            rating: d.rating || 0,
            totalRatings: d.totalRatings || 0,
            membershipType: d.membershipType || 'new',
            isGolden: !!d.isGolden,
            isVerified: !!d.isVerified,
            walletBalance: Math.round(d.walletBalance || 0),
            // The vehicle + driver the owner picked from their garage on accept.
            offerVehicle: o.vehicle || '',
            offerVehicleNumber: o.vehicleNumber || '',
            offerVehicleImage: o.vehicleImage || '',
            assignedDriverName: o.assignedDriverName || '',
            assignedDriverPhone: o.assignedDriverPhone || '',
            // Fallback identity/vehicle from the account's own KYC.
            vehicleNumber: rc.number || rc.documentNumber || '',
            vehicleRcImage: rc.image || '',
            completedTrips,
            status: o.status,
            acceptedAt: o.createdAt,
          };
        }),
      );
    }
    delete booking.offers;
    return { message: 'Booking detail', data: { ...booking, acceptedDrivers } };
  }

  /**
   * Admin assigns one of the accepted drivers to an OPEN booking → CONFIRMED.
   * The chosen driver's offer becomes 'selected', the rest 'released'. No wallet
   * holds are involved. Both the driver and the customer are notified.
   */
  async adminAssign(id: string, driverId: string) {
    if (!Types.ObjectId.isValid(id)) throw new NotFoundException('Booking not found');
    if (!driverId || !Types.ObjectId.isValid(driverId)) throw new BadRequestException('Invalid driver');

    const booking = await this.bookingModel.findById(id);
    if (!booking) throw new NotFoundException('Booking not found');
    if (booking.status !== CustomerBookingStatus.OPEN) {
      throw new BadRequestException('Only an open booking can be assigned');
    }
    const chosen: any = (booking.offers as any[]).find(
      (o) => o.driverId.toString() === driverId && o.status !== 'released',
    );
    if (!chosen) throw new BadRequestException('That driver has not accepted this booking');

    // Atomically claim OPEN → CONFIRMED so a concurrent assign/cancel/expiry can't
    // also run against the same booking.
    const claimed = await this.bookingModel.findOneAndUpdate(
      { _id: booking._id, status: CustomerBookingStatus.OPEN },
      { $set: { status: CustomerBookingStatus.CONFIRMED } },
    );
    if (!claimed) throw new BadRequestException('This booking is no longer open');

    const driver: any = await this.userModel
      .findById(chosen.driverId)
      .select('fullName agencyName mobile rating documents')
      .lean();
    const rc: any = driver?.documents?.vehicleRc || {};

    // Mark the chosen offer selected, the rest released.
    for (const o of booking.offers as any[]) {
      o.status = o.driverId.toString() === driverId ? 'selected' : 'released';
    }

    booking.selectedDriverId = chosen.driverId;
    booking.finalFare = chosen.quotedFare || booking.estimatedFare;
    booking.status = CustomerBookingStatus.CONFIRMED;
    booking.confirmedAt = new Date();
    // Prefer the actual driver + vehicle the owner chose from their garage; fall
    // back to the account holder's own name / KYC vehicle.
    booking.driverSnapshot = {
      name: chosen.assignedDriverName || driver?.agencyName || driver?.fullName || 'Driver',
      phone: chosen.assignedDriverPhone || driver?.mobile || '',
      vehicle: chosen.vehicle || booking.vehicleType || '',
      vehicleNumber: chosen.vehicleNumber || rc.number || rc.documentNumber || '',
      rating: driver?.rating || 0,
    };
    await booking.save();

    this.notifications.notifyUser(chosen.driverId, '🎉 You got the booking!',
      `Our team assigned booking ${booking.bookingId} to you. Contact the customer and start the trip.`,
      { type: 'customer_booking_selected', bookingId: booking.bookingId }).catch(() => {});
    this.notifications.notifyUser(booking.customerId, '✅ Booking Confirmed',
      `Your ${booking.serviceType} booking is confirmed with ${booking.driverSnapshot.name}.`,
      { type: 'customer_booking_confirmed', bookingId: booking.bookingId }).catch(() => {});

    return { message: 'Driver assigned — booking confirmed', data: booking };
  }

  async getMyApplications(driverId: string) {
    const data = await this.bookingModel
      .find({ 'offers.driverId': new Types.ObjectId(driverId) })
      .sort({ createdAt: -1 })
      .populate('customerId', 'fullName mobile')
      .lean();
    // Reveal the customer's contact ONLY to the selected driver, AND only once the
    // reveal window opens (admin: contactRevealHoursBeforePickup before pickup).
    const revealHours = await this.getContactRevealHours();
    const mapped = data.map((b: any) => {
      const mine = (b.offers ?? []).find((o: any) => o.driverId.toString() === driverId);
      const isSelected = b.selectedDriverId && b.selectedDriverId.toString() === driverId;
      const revealed = isSelected && this.contactRevealed(b, revealHours);
      const c: any = b.customerId;
      const customer = revealed && c && typeof c === 'object'
        ? { name: c.fullName || 'Customer', mobile: c.mobile || '' }
        : null;
      return {
        ...b,
        customerId: c && typeof c === 'object' ? c._id : c,
        customer,
        // Selected driver, but the number isn't shown yet → let the app explain why.
        contactLocked: isSelected && !revealed,
        contactRevealHours: revealHours,
        myOffer: mine || null,
        offers: undefined,
      };
    });
    return { message: 'My applications', data: mapped };
  }

  private assertSelectedDriver(booking: any, driverId: string) {
    if (!booking.selectedDriverId || booking.selectedDriverId.toString() !== driverId) {
      throw new ForbiddenException('You are not the selected driver for this booking');
    }
  }

  /** Driver marks that they're arriving at the pickup — notifies the customer. */
  async driverArrived(driverId: string, id: string) {
    const booking = await this.bookingModel.findById(id);
    if (!booking) throw new NotFoundException('Booking not found');
    this.assertSelectedDriver(booking, driverId);
    if (booking.status !== CustomerBookingStatus.CONFIRMED) {
      throw new BadRequestException('You can only mark arriving on a confirmed booking');
    }
    booking.driverArrivedAt = new Date();
    await booking.save();
    this.notifications.notifyUser(booking.customerId, '🚗 Your Driver is Arriving',
      `Your driver is arriving for trip ${booking.bookingId}. Please be ready at the pickup point.`,
      { type: 'customer_driver_arriving', bookingId: booking.bookingId }).catch(() => {});
    return { message: 'Customer notified', data: booking };
  }

  private static readonly TRIP_OTP_TTL_MS = 15 * 60 * 1000; // 15 minutes

  /**
   * Driver taps Start/Complete → we mint a 6-digit OTP and show it to the
   * CUSTOMER (in-app + push). The driver never sees it; the customer reads it
   * out and the driver enters it via verifyTripOtp. This proves they're together.
   */
  async requestTripOtp(driverId: string, id: string, action: 'start' | 'end') {
    if (action !== 'start' && action !== 'end') throw new BadRequestException('Invalid action');
    const booking = await this.bookingModel.findById(id);
    if (!booking) throw new NotFoundException('Booking not found');
    this.assertSelectedDriver(booking, driverId);
    if (action === 'start' && booking.status !== CustomerBookingStatus.CONFIRMED) {
      throw new BadRequestException(
        booking.status === CustomerBookingStatus.ONGOING ? 'Trip already started' : 'Trip can start only after confirmation',
      );
    }
    if (action === 'end' && booking.status !== CustomerBookingStatus.ONGOING) {
      throw new BadRequestException('Start the trip first');
    }

    const otp = `${Math.floor(100000 + Math.random() * 900000)}`;
    await this.bookingModel.findByIdAndUpdate(id, {
      tripOtp: otp,
      tripOtpAction: action,
      tripOtpExpiresAt: new Date(Date.now() + CustomerBookingsService.TRIP_OTP_TTL_MS),
    });

    const verb = action === 'start' ? 'start' : 'end';
    this.notifications.notifyUser(booking.customerId,
      `🔐 Trip ${action === 'start' ? 'Start' : 'End'} OTP: ${otp}`,
      `Share OTP ${otp} with your driver to ${verb} trip ${booking.bookingId}. Do not share it with anyone else.`,
      { type: 'customer_trip_otp', bookingId: booking.bookingId, action, otp }).catch(() => {});

    return { message: 'OTP sent to the customer', data: { action } };
  }

  /** Driver enters the OTP the customer read out. Starts / completes the trip. */
  async verifyTripOtp(driverId: string, id: string, action: 'start' | 'end', otp: string) {
    const booking = await this.bookingModel
      .findById(id)
      .select('+tripOtp +tripOtpAction +tripOtpExpiresAt');
    if (!booking) throw new NotFoundException('Booking not found');
    this.assertSelectedDriver(booking, driverId);
    // Status precondition — a cancelled/expired/completed booking can never be
    // revived by an old OTP.
    const required = action === 'start' ? CustomerBookingStatus.CONFIRMED : CustomerBookingStatus.ONGOING;
    if (booking.status !== required) {
      throw new BadRequestException(
        action === 'start' ? 'This booking is not ready to start' : 'Start the trip first',
      );
    }
    if (!booking.tripOtp || booking.tripOtpAction !== action) {
      throw new BadRequestException('No OTP requested. Tap the button again.');
    }
    if (!booking.tripOtpExpiresAt || booking.tripOtpExpiresAt.getTime() < Date.now()) {
      throw new BadRequestException('OTP expired. Request a new one.');
    }
    if (booking.tripOtp !== `${otp}`.trim()) {
      throw new BadRequestException('Incorrect OTP');
    }

    booking.tripOtp = undefined as any;
    booking.tripOtpAction = undefined as any;
    booking.tripOtpExpiresAt = undefined as any;
    if (action === 'start') {
      booking.status = CustomerBookingStatus.ONGOING;
      booking.startedAt = new Date();
    } else {
      booking.status = CustomerBookingStatus.COMPLETED;
      booking.completedAt = new Date();
      // Finalise the fare: base + any extra-km (round trip) + any extra-hours (Local).
      let finalFare = booking.finalFare || booking.estimatedFare || 0;
      // Round-trip / rental extra-km billing: GPS-measured km beyond the included allowance.
      if ((booking.includedKm || 0) > 0 && (booking.extraKmPrice || 0) > 0) {
        const extraKm = Math.max(0, Math.round((booking.trackedKm || 0) - booking.includedKm));
        booking.extraKm = extraKm;
        booking.extraCharge = Math.round(extraKm * booking.extraKmPrice);
        finalFare += booking.extraCharge;
      }
      // Local hourly-package extra-hours billing: wall-clock hours beyond the package,
      // measured start→complete and rounded UP to the next hour.
      if ((booking.packageHours || 0) > 0 && (booking.extraHourPrice || 0) > 0 && booking.startedAt) {
        const usedMs = booking.completedAt.getTime() - new Date(booking.startedAt).getTime();
        const usedHours = Math.max(0, Math.ceil(usedMs / 3600000));
        const extraHours = Math.max(0, usedHours - booking.packageHours);
        booking.extraHours = extraHours;
        booking.extraHourCharge = Math.round(extraHours * booking.extraHourPrice);
        finalFare += booking.extraHourCharge;
      }
      booking.finalFare = Math.round(finalFare);
      // Release the customer's advance (paid to the platform) into the driver's
      // wallet now that the trip is complete. Guarded so it runs only once.
      if (booking.advanceStatus === 'paid' && (booking.advanceAmount || 0) > 0 && booking.selectedDriverId && !booking.advanceReleasedAt) {
        booking.advanceReleasedAt = new Date();
        await this.refundToWallet(booking.selectedDriverId, booking.advanceAmount, booking._id,
          `Advance released for completed booking ${booking.bookingId}`);
        this.notifications.notifyUser(booking.selectedDriverId, '💰 Advance credited',
          `₹${booking.advanceAmount} advance for booking ${booking.bookingId} has been added to your wallet.`,
          { type: 'customer_booking_advance', bookingId: booking.bookingId }).catch(() => {});
      }
    }
    await booking.save();

    if (action === 'start') {
      this.notifications.notifyUser(booking.customerId, '🚕 Your Trip Has Started',
        `Your driver has started trip ${booking.bookingId}.`,
        { type: 'customer_trip_started', bookingId: booking.bookingId }).catch(() => {});
    } else {
      this.notifications.notifyUser(booking.customerId, '✅ Trip Completed',
        `Trip ${booking.bookingId} is complete. Please rate your driver.`,
        { type: 'customer_trip_completed', bookingId: booking.bookingId }).catch(() => {});
    }
    return { message: action === 'start' ? 'Trip started' : 'Trip completed', data: booking };
  }

  /**
   * The selected driver reports the running GPS-measured distance (km) during an
   * ongoing trip. We keep the max so retries / out-of-order pings never lower it.
   */
  async trackTrip(driverId: string, id: string, km: number) {
    if (!Types.ObjectId.isValid(id)) throw new NotFoundException('Booking not found');
    const value = Number(km);
    if (!isFinite(value) || value < 0) throw new BadRequestException('Invalid distance');
    const booking = await this.bookingModel
      .findOne({ _id: id, selectedDriverId: new Types.ObjectId(driverId), status: CustomerBookingStatus.ONGOING })
      .select('trackedKm includedKm');
    if (!booking) throw new BadRequestException('Trip is not active');
    if (value > (booking.trackedKm || 0)) {
      booking.trackedKm = Math.round(value * 10) / 10;
      await booking.save();
    }
    return { message: 'ok', data: { trackedKm: booking.trackedKm, includedKm: booking.includedKm } };
  }

  async cancelByDriver(driverId: string, id: string, reason?: string) {
    const booking = await this.bookingModel.findById(id);
    if (!booking) throw new NotFoundException('Booking not found');
    this.assertSelectedDriver(booking, driverId);
    if ([CustomerBookingStatus.COMPLETED, CustomerBookingStatus.CANCELLED].includes(booking.status)) {
      throw new BadRequestException('Booking already closed');
    }
    // No wallet holds/commitment on customer bookings anymore, so a driver cancel
    // just releases the booking back — nothing to settle or refund.
    booking.status = CustomerBookingStatus.CANCELLED;
    booking.cancelledAt = new Date();
    booking.cancelledBy = 'driver';
    booking.cancelReason = reason || '';
    await booking.save();
    this.notifications.notifyUser(booking.customerId, 'Booking Cancelled',
      `Your driver cancelled booking ${booking.bookingId}. Please book again.`,
      { type: 'customer_booking_cancelled', bookingId: booking.bookingId }).catch(() => {});
    return { message: 'Booking cancelled', data: booking };
  }
}
