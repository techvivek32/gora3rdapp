import { Injectable, Logger, NotFoundException, BadRequestException, ForbiddenException } from '@nestjs/common';
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
import { NotificationsService } from '../notifications/notifications.service';
import { SettingsService } from '../settings/settings.service';
import { UserRole } from '../../common/enums/user-role.enum';
import {
  CreateCustomerBookingDto,
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
    private readonly notifications: NotificationsService,
    private readonly settings: SettingsService,
  ) {}

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

  /** Move `amount` from HELD back to AVAILABLE (application not selected / cancelled). */
  private async releaseHold(driverId: Types.ObjectId, amount: number, bookingRef: Types.ObjectId): Promise<void> {
    if (amount <= 0) return;
    await this.userModel.updateOne(
      { _id: driverId },
      { $inc: { heldBalance: -amount, walletBalance: amount } },
    );
    await this.txModel.create({
      userId: driverId, amount, type: 'credit', status: 'success',
      source: 'release', bookingRef, note: 'Booking hold released',
    });
  }

  /** Consume `amount` from HELD as final settlement/commission (leaves the wallet). */
  private async settleHold(driverId: Types.ObjectId, amount: number, bookingRef: Types.ObjectId): Promise<void> {
    if (amount <= 0) return;
    await this.userModel.updateOne(
      { _id: driverId },
      { $inc: { heldBalance: -amount } },
    );
    await this.txModel.create({
      userId: driverId, amount, type: 'debit', status: 'success',
      source: 'settle', bookingRef, note: 'Booking commission settled',
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
    for (const booking of stale) {
      try {
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
    this.logger.log(`Expired ${stale.length} stale customer bookings (holds released)`);
  }

  // ─── Customer side ─────────────────────────────────────────────────────────

  async create(customerId: string, dto: CreateCustomerBookingDto) {
    const commitmentPercent = (await this.settings.getSettings())?.bookingCommitmentPercent ?? 5;
    const travelDate = dto.travelDate ? new Date(dto.travelDate) : undefined;
    const expiresAt = travelDate ? new Date(travelDate.getTime() + 24 * 60 * 60 * 1000) : undefined;

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
      commitmentPercent,
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
    return { message: 'My bookings', data };
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

  private async withOfferProfiles(booking: any) {
    // Configurable cancellation policy shown to the customer before they pick.
    const settings: any = await this.settings.getSettings().catch(() => null);
    const cancellationPolicy = settings?.bookingCancellationPolicy || '';
    // Surface an active trip OTP to the customer only; strip the raw stored fields.
    const otpActive = booking.tripOtp && booking.tripOtpExpiresAt && new Date(booking.tripOtpExpiresAt).getTime() > Date.now();
    const tripOtp = otpActive ? booking.tripOtp : '';
    const tripOtpAction = otpActive ? booking.tripOtpAction : '';
    delete booking.tripOtp; delete booking.tripOtpExpiresAt;
    booking = { ...booking, tripOtp, tripOtpAction };
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

  async cancelByCustomer(customerId: string, id: string, reason?: string) {
    const booking = await this.bookingModel.findById(id);
    if (!booking) throw new NotFoundException('Booking not found');
    if (booking.customerId.toString() !== customerId) throw new ForbiddenException('Not your booking');
    if ([CustomerBookingStatus.COMPLETED, CustomerBookingStatus.CANCELLED].includes(booking.status)) {
      throw new BadRequestException('Booking already closed');
    }

    // Release every still-held application (not yet in final settlement).
    for (const o of booking.offers) {
      if (o.status === 'applied') {
        await this.releaseHold(o.driverId, o.holdAmount, booking._id);
        o.status = 'released';
      }
    }
    booking.status = CustomerBookingStatus.CANCELLED;
    booking.cancelledAt = new Date();
    booking.cancelledBy = 'customer';
    booking.cancelReason = reason || '';
    await booking.save();

    if (booking.selectedDriverId) {
      this.notifications.notifyUser(booking.selectedDriverId, 'Booking Cancelled',
        `Booking ${booking.bookingId} was cancelled by the customer.`,
        { type: 'customer_booking_cancelled', bookingId: booking.bookingId }).catch(() => {});
    }
    return { message: 'Booking cancelled', data: booking };
  }

  async rate(customerId: string, id: string, dto: RateBookingDto) {
    const booking = await this.bookingModel.findById(id);
    if (!booking) throw new NotFoundException('Booking not found');
    if (booking.customerId.toString() !== customerId) throw new ForbiddenException('Not your booking');
    if (booking.status !== CustomerBookingStatus.COMPLETED) {
      throw new BadRequestException('You can rate only after the trip is completed');
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
    const driver = await this.userModel.findById(driverId).select('businessCities').lean();
    const cities = ((driver as any)?.businessCities ?? []).filter(Boolean);
    const filter: any = {
      status: CustomerBookingStatus.OPEN,
      customerId: { $ne: new Types.ObjectId(driverId) },
    };
    if (serviceType) filter.serviceType = serviceType;
    if (cities.length) {
      filter.$or = [
        { pickupCity: { $in: cities } },
        { dropCity: { $in: cities } },
      ];
    }
    const bookings = await this.bookingModel.find(filter).sort({ createdAt: -1 }).limit(100).lean();
    const uid = driverId;
    // Hide other drivers' quotes; only flag whether THIS driver already applied.
    const data = bookings.map((b: any) => ({
      ...b,
      offerCount: (b.offers ?? []).filter((o: any) => o.status !== 'released').length,
      alreadyApplied: (b.offers ?? []).some((o: any) => o.driverId.toString() === uid && o.status !== 'released'),
      offers: undefined,
    }));
    return { message: 'Available bookings', data };
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

    const held = await this.holdFunds(dId, holdAmount, booking._id);
    if (!held) {
      throw new BadRequestException(
        `Insufficient wallet balance. You need ₹${holdAmount} available to apply for this booking.`,
      );
    }

    booking.offers.push({
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
    } as any);
    await booking.save();

    this.notifications.notifyUser(booking.customerId, '🚕 New Offer Received',
      `A driver applied for your ${booking.serviceType} booking ${booking.bookingId}.`,
      { type: 'customer_booking_offer', bookingId: booking.bookingId }).catch(() => {});

    return { message: 'Applied successfully', data: { holdAmount } };
  }

  async getMyApplications(driverId: string) {
    const data = await this.bookingModel
      .find({ 'offers.driverId': new Types.ObjectId(driverId) })
      .sort({ createdAt: -1 })
      .populate('customerId', 'fullName mobile')
      .lean();
    // Attach this driver's own offer/status; hide other applicants' offers.
    const mapped = data.map((b: any) => {
      const mine = (b.offers ?? []).find((o: any) => o.driverId.toString() === driverId);
      const isSelected = b.selectedDriverId && b.selectedDriverId.toString() === driverId;
      // Reveal the customer's contact ONLY to the selected driver (privacy).
      const c: any = b.customerId;
      const customer = isSelected && c && typeof c === 'object'
        ? { name: c.fullName || 'Customer', mobile: c.mobile || '' }
        : null;
      return {
        ...b,
        customerId: c && typeof c === 'object' ? c._id : c,
        customer,
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

  async cancelByDriver(driverId: string, id: string, reason?: string) {
    const booking = await this.bookingModel.findById(id);
    if (!booking) throw new NotFoundException('Booking not found');
    this.assertSelectedDriver(booking, driverId);
    if ([CustomerBookingStatus.COMPLETED, CustomerBookingStatus.CANCELLED].includes(booking.status)) {
      throw new BadRequestException('Booking already closed');
    }
    // Driver cancels after being selected. Their commitment was already settled;
    // refund the non-penalty portion per the configurable penalty policy.
    const penaltyPercent = (await this.settings.getSettings())?.driverCancelPenaltyPercent ?? 100;
    const chosen: any = (booking.offers as any[]).find(
      (o) => o.status === 'selected' && o.driverId.toString() === driverId,
    );
    if (chosen && chosen.holdAmount > 0 && penaltyPercent < 100) {
      const refund = Math.round((chosen.holdAmount * (100 - penaltyPercent)) / 100);
      if (refund > 0) {
        await this.userModel.updateOne({ _id: chosen.driverId }, { $inc: { walletBalance: refund } });
        await this.txModel.create({
          userId: chosen.driverId, amount: refund, type: 'credit', status: 'success',
          source: 'release', bookingRef: booking._id, note: 'Partial refund on driver cancel',
        });
      }
    }
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
