import { Injectable, Logger } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { Notification, NotificationDocument, NotificationType } from '../../database/schemas/notification.schema';
import { User, UserDocument } from '../../database/schemas/user.schema';
import { FirebaseService } from '../firebase/firebase.service';
import { UserRole } from '../../common/enums/user-role.enum';
import { getPaginationParams, buildPaginatedResult } from '../../common/utils/pagination.util';

/**
 * SILENT high-importance channel shared by the three "new work" alerts: a new
 * requirement, a new customer booking and a newly listed available vehicle.
 * All three ring + show the popup card, and the app plays the user's chosen
 * ringtone itself, so the channel must not also play a sound.
 */
const BOOKING_CHANNEL_ID = 'gora_cabs_notifications_v4';

/** Paid tiers — only these get a contact number in an alert payload. */
const PAID_TIERS = ['active', 'verified', 'premium', 'golden'];

/** Service labels for a customer booking's push title/body. */
const SERVICE_LABEL: Record<string, string> = {
  cab: 'cab',
  hire_driver: 'driver',
  luxury: 'luxury car',
  car_pool: 'car pool',
};

const titleCase = (s: any) =>
  `${s ?? ''}`.replace(/_/g, ' ').split(' ').filter(Boolean)
    .map((w) => w[0].toUpperCase() + w.slice(1)).join(' ');

/**
 * Alert push titles are shouted — "GORA TAXI BOOKING ONE WAY TRIP". They land
 * in a crowded notification tray next to every other app, and all-caps is what
 * makes ours findable at a glance. Only the TITLE: the body keeps its normal
 * casing so the route and car type stay readable.
 *
 * `titleCase` still runs first on the interpolated parts, because it is what
 * turns `one_way` into `One Way` — without it the title would read ONE_WAY.
 */
const shout = (s: string) => s.toUpperCase();

const fmtDate = (d: any) => {
  if (!d) return '';
  const dt = new Date(d);
  const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
  return `${dt.getUTCDate()} ${months[dt.getUTCMonth()]} ${dt.getUTCFullYear()}`;
};

const fmtTime = (t: any) => {
  const parts = `${t ?? ''}`.split(':');
  if (parts.length < 2) return '';
  let h = parseInt(parts[0], 10);
  const m = parts[1].padStart(2, '0');
  const ampm = h >= 12 ? 'pm' : 'am';
  h = h % 12 === 0 ? 12 : h % 12;
  return `${h}:${m}${ampm}`;
};

@Injectable()
export class NotificationsService {
  private readonly logger = new Logger(NotificationsService.name);

  constructor(
    @InjectModel(Notification.name) private notificationModel: Model<NotificationDocument>,
    @InjectModel(User.name) private userModel: Model<UserDocument>,
    private firebaseService: FirebaseService,
  ) {}

  /** Generic single-user notification (in-app row + push). Used by the customer
   *  booking flow (offer received, booking confirmed, trip started/completed…). */
  async notifyUser(userId: string | Types.ObjectId, title: string, body: string, data: Record<string, string> = {}) {
    try {
      const uid = new Types.ObjectId(userId as any);
      await this.notificationModel.create({
        userId: uid, title, body, type: NotificationType.SYSTEM,
        data, isSent: true, sentAt: new Date(),
      });
      const user = await this.userModel.findById(uid).select('fcmTokens').lean();
      const tokens = ((user as any)?.fcmTokens ?? []).filter(Boolean);
      if (tokens.length) {
        await this.firebaseService.sendPushNotification(tokens, { title, body, data });
      }
    } catch (e: any) {
      this.logger.warn(`notifyUser failed: ${e?.message ?? e}`);
    }
  }

  // ─── Shared plumbing for the three "new work" alerts ──────────────────────

  /** Multicast in 500-token batches on the silent booking channel. One failed
   *  batch is logged and never stops the rest. */
  private async sendAlertPush(
    tokens: string[],
    payload: { title: string; body: string; data: Record<string, string> },
  ): Promise<void> {
    const batchSize = 500;
    for (let i = 0; i < tokens.length; i += batchSize) {
      try {
        await this.firebaseService.sendPushNotification(tokens.slice(i, i + batchSize), {
          ...payload,
          // Silent booking channel — the app plays the user's chosen ring itself.
          channelId: BOOKING_CHANNEL_ID,
        });
      } catch (error: any) {
        this.logger.error(`FCM batch send failed: ${error?.message ?? error}`);
      }
    }
  }

  /**
   * Everyone who should get a "new work" alert for something touching `cities`.
   *
   * City targeting matches notifyNewRequirement: a user who picked business
   * cities hears only about those, a user who picked none counts as "all
   * cities". `notificationsEnabled` is the master booking-alert switch, so an
   * opted-out user is never pushed. With no cities at all the filter is skipped
   * and everyone eligible is included.
   */
  private async alertAudience(opts: { cities: string[]; excludeUserId?: any; roles?: string[] }) {
    const filter: any = {
      notificationsEnabled: true,
      isActive: true,
      isBlocked: false,
      fcmTokens: { $exists: true, $ne: [] },
    };
    if (opts.cities.length) {
      filter.$or = [
        { businessCities: { $in: opts.cities } }, // picked cities → only those
        { businessCities: { $size: 0 } },         // picked none → all cities
        { businessCities: { $exists: false } },
      ];
    }
    if (opts.roles?.length) filter.role = { $in: opts.roles };
    if (opts.excludeUserId) filter._id = { $ne: opts.excludeUserId };
    return this.userModel
      .find(filter)
      .select('fcmTokens _id alertVehicleTypes alertTripTypes membershipType isPremium')
      .lean();
  }

  private isPaidTier(u: any): boolean {
    return PAID_TIERS.includes(u?.membershipType) || !!u?.isPremium;
  }

  private tokensOf(users: any[]): string[] {
    return users.flatMap((u) => u.fcmTokens ?? []).filter(Boolean);
  }

  async notifyNewRequirement(requirement: any) {
    // Match on the clean city names first (e.g. "Rajkot"), falling back to the
    // detailed addresses, so a user who selected only "Rajkot" is notified.
    const cities = [
      requirement.pickupCityName,
      requirement.dropCityName,
      requirement.pickupCity,
      requirement.dropCity,
    ].filter(Boolean);

    // City targeting: a user who selected business cities is notified only for those
    // cities; a user who selected NO city (empty/absent businessCities) is treated as
    // "all cities" and notified for every requirement.
    const candidates = await this.userModel
      .find({
        $or: [
          { businessCities: { $in: cities } }, // selected → only matching cities
          { businessCities: { $size: 0 } },    // selected nothing → all cities
          { businessCities: { $exists: false } },
        ],
        notificationsEnabled: true,
        isActive: true,
        isBlocked: false,
        _id: { $ne: requirement.postedBy },
        fcmTokens: { $exists: true, $ne: [] },
      })
      .select('fcmTokens _id alertVehicleTypes alertTripTypes membershipType isPremium')
      .lean();

    // Respect each user's alert filters — an empty filter means "all".
    const reqVehicle = requirement.vehicleType;
    const reqTrip = requirement.tripType;
    const targetUsers = candidates.filter((u) => {
      const vOk = !u.alertVehicleTypes?.length || u.alertVehicleTypes.includes(reqVehicle);
      const tOk = !u.alertTripTypes?.length || u.alertTripTypes.includes(reqTrip);
      return vOk && tOk;
    });

    if (targetUsers.length === 0) return;

    // Poster contact info for the notification (Call / WhatsApp actions).
    const poster = await this.userModel
      .findById(requirement.postedBy)
      .select('mobile fullName agencyName')
      .lean();

    // Push format:
    //   GORA TAXI BOOKING ONE WAY TRIP
    //   Jodhpur → Surat
    //   Car type - Innova Crysta
    //   Date time - 4 July 2026 | 5:00am
    const title = shout(`Gora Taxi booking ${titleCase(requirement.tripType)} trip`);
    const body = `${requirement.pickupCity} → ${requirement.dropCity}\nCar type - ${titleCase(requirement.vehicleType)}\nDate time - ${fmtDate(requirement.travelDate)} | ${fmtTime(requirement.travelTime)}`;

    // No in-app notification rows for new requirements: they're delivered as a push
    // + overlay/alert card, and the requirement feed is the place to browse them.
    // Writing one row per targeted user per requirement only flooded that list.

    // Contact (Call/WhatsApp) is a premium feature: only premium members get the
    // poster's mobile in the overlay payload; others get an empty number so the
    // overlay's Call/WhatsApp buttons stay disabled.
    const isPremiumUser = (u: any) =>
      ['active', 'verified', 'premium', 'golden'].includes(u.membershipType) || u.isPremium;
    const premiumTokens = targetUsers.filter(isPremiumUser).flatMap((u) => u.fcmTokens).filter(Boolean);
    const basicTokens = targetUsers.filter((u) => !isPremiumUser(u)).flatMap((u) => u.fcmTokens).filter(Boolean);

    const baseData = {
      requirementId: requirement._id.toString(),
      bookingId: `${requirement.bookingId ?? ''}`,
      type: NotificationType.NEW_REQUIREMENT,
      pickupCity: `${requirement.pickupCity ?? ''}`,
      dropCity: `${requirement.dropCity ?? ''}`,
      vehicleType: `${requirement.vehicleType ?? ''}`,
      tripType: `${requirement.tripType ?? ''}`,
      travelDate: `${requirement.travelDate ? new Date(requirement.travelDate).toISOString() : ''}`,
      travelTime: `${requirement.travelTime ?? ''}`,
      posterName: `${poster?.agencyName || poster?.fullName || ''}`,
      // Intermediate stops (addresses), one per line, shown between A and B.
      stops: `${(requirement.stops ?? [])
        .map((s: any) => `${s?.address ?? ''}`.trim())
        .filter(Boolean)
        .join('\n')}`,
    };
    const sendToTokens = (tokens: string[], posterMobile: string) =>
      this.sendAlertPush(tokens, { title, body, data: { ...baseData, posterMobile } });

    // WhatsApp-imported bookings carry the customer's number in contactMobile;
    // use it for the popup/notification Call & WhatsApp buttons, else the poster's.
    const contactNumber = `${requirement.contactMobile || poster?.mobile || ''}`;
    await sendToTokens(premiumTokens, contactNumber);
    await sendToTokens(basicTokens, ''); // non-premium: no contact number
  }

  // "Requirement posted" / "Vehicle listed" self-confirmations are no longer
  // written: the inbox is for admin messages, and the user just saw the success
  // screen after posting. Kept as no-ops so callers don't need to change.
  async notifyRequirementPosted(_requirement: any) {}

  async notifyVehiclePosted(_vehicle: any) {}

  /**
   * Fan a brand-new CUSTOMER BOOKING out to eligible drivers/vendors as a loud
   * alert — the same treatment a new requirement gets: a silent-channel push
   * carrying the whole trip, so the app rings and shows its popup card (and the
   * floating overlay when it arrives in the background).
   *
   * The payload deliberately reuses the requirement alert's key names
   * (pickupCity / dropCity / vehicleType / tripType / travelDate / travelTime /
   * stops / notes), because the popup and the overlay read those keys — one
   * alert UI then renders every alert kind.
   *
   * No per-driver inbox rows: like new requirements, writing one row per
   * targeted user per booking only floods that list, and the Bookings feed is
   * where these are browsed.
   */
  async notifyNewCustomerBooking(booking: any) {
    try {
      const cities = [booking.pickupCity, booking.dropCity].filter(Boolean);
      const targets = await this.alertAudience({
        cities,
        excludeUserId: booking.customerId,
        roles: [UserRole.DRIVER, UserRole.TRAVEL_AGENCY, UserRole.FLEET_OWNER],
      });
      // The per-user alertVehicleTypes / alertTripTypes filters are NOT applied
      // here on purpose: a customer booking's vehicleType is an admin-managed cab
      // CATEGORY NAME ("Innova Crysta"), not the VehicleType enum those filters
      // hold, and subType is free-form per service — matching on either would
      // silence everyone. City + the opt-in switch are the gates.
      if (!targets.length) return;

      const label = SERVICE_LABEL[booking.serviceType] || 'ride';
      const route = [booking.pickupCity, booking.dropCity].filter(Boolean).join(' \→ ');
      const title = shout(`Gora Taxi customer ${label} booking`);
      const bodyLines = [
        route || 'New customer booking',
        booking.vehicleType ? `Car type - ${titleCase(booking.vehicleType)}` : '',
        `Date time - ${fmtDate(booking.travelDate)} | ${fmtTime(booking.travelTime)}`,
      ].filter(Boolean);

      const data: Record<string, string> = {
        type: 'customer_booking_new',
        customerBookingId: `${booking._id ?? ''}`,
        bookingId: `${booking.bookingId ?? ''}`,
        serviceType: `${booking.serviceType ?? ''}`,
        pickupCity: `${booking.pickupCity ?? ''}`,
        dropCity: `${booking.dropCity ?? ''}`,
        vehicleType: `${booking.vehicleType ?? ''}`,
        // The card's trip tag: the booking's own sub-option (One Way / Round
        // Trip / Local / Hourly…), falling back to the service name.
        tripType: `${booking.subType || titleCase(label)}`,
        travelDate: `${booking.travelDate ? new Date(booking.travelDate).toISOString() : ''}`,
        travelTime: `${booking.travelTime ?? ''}`,
        notes: `${booking.notes ?? ''}`,
        stops: `${(booking.stops ?? [])
          .map((s: any) => `${s?.address ?? ''}`.trim())
          .filter(Boolean)
          .join('\n')}`,
        // Empty on purpose: a customer's number stays hidden until a driver is
        // actually assigned (the booking has a contact-reveal window), so the
        // popup's Call / WhatsApp buttons stay disabled for these.
        posterMobile: '',
        posterName: '',
      };

      await this.sendAlertPush(this.tokensOf(targets), { title, body: bodyLines.join('\n'), data });
      this.logger.log(`Customer booking ${booking.bookingId}: alerted ${targets.length} drivers`);
    } catch (e: any) {
      this.logger.warn(`notifyNewCustomerBooking failed: ${e?.message ?? e}`);
    }
  }

  /**
   * Fan a newly listed AVAILABLE VEHICLE out as a loud alert, same as a new
   * requirement — agents watching for an empty car get the ring + popup card.
   *
   * A listing's `vehicleType` and `tripType` ARE the same enums the per-user
   * alert filters hold, so unlike customer bookings both filters are honoured
   * here (an empty filter means "all").
   */
  async notifyNewVehicle(vehicle: any) {
    try {
      const cities = [vehicle.currentCity, vehicle.destinationCity].filter(Boolean);
      const candidates = await this.alertAudience({ cities, excludeUserId: vehicle.postedBy });
      const targets = candidates.filter((u: any) => {
        const vOk = !u.alertVehicleTypes?.length || u.alertVehicleTypes.includes(vehicle.vehicleType);
        const tOk = !u.alertTripTypes?.length || u.alertTripTypes.includes(vehicle.tripType);
        return vOk && tOk;
      });
      if (!targets.length) return;

      const poster: any = await this.userModel
        .findById(vehicle.postedBy)
        .select('mobile fullName agencyName')
        .lean();

      const route = [vehicle.currentCity, vehicle.destinationCity].filter(Boolean).join(' \→ ');
      const title = shout(`Car available \— ${titleCase(vehicle.tripType)}`);
      const body = [
        route || 'New car available',
        `Car type - ${titleCase(vehicle.vehicleType)}`,
        `Date time - ${fmtDate(vehicle.availableDate)} | ${fmtTime(vehicle.availableTime)}`,
      ].join('\n');

      // Same key names as the requirement alert (see notifyNewCustomerBooking):
      // currentCity / destinationCity are mapped onto pickupCity / dropCity so the
      // one popup card renders an A \→ B route for a listing too.
      const baseData: Record<string, string> = {
        type: NotificationType.NEW_VEHICLE,
        vehicleId: `${vehicle._id ?? ''}`,
        bookingId: `${vehicle.listingId ?? ''}`,
        pickupCity: `${vehicle.currentCity ?? ''}`,
        dropCity: `${vehicle.destinationCity ?? ''}`,
        vehicleType: `${vehicle.vehicleType ?? ''}`,
        tripType: `${vehicle.tripType ?? ''}`,
        travelDate: `${vehicle.availableDate ? new Date(vehicle.availableDate).toISOString() : ''}`,
        travelTime: `${vehicle.availableTime ?? ''}`,
        notes: `${vehicle.notes ?? ''}`,
        stops: '',
        posterName: `${poster?.agencyName || poster?.fullName || ''}`,
      };

      // Contact is a paid feature, exactly as for requirements: only paid tiers
      // get a number, everyone else sees Call / WhatsApp disabled.
      const contact = `${vehicle.driverMobile || poster?.mobile || ''}`;
      const paid = targets.filter((u) => this.isPaidTier(u));
      const basic = targets.filter((u) => !this.isPaidTier(u));
      await this.sendAlertPush(this.tokensOf(paid), { title, body, data: { ...baseData, posterMobile: contact } });
      await this.sendAlertPush(this.tokensOf(basic), { title, body, data: { ...baseData, posterMobile: '' } });
      this.logger.log(`Vehicle ${vehicle.listingId}: alerted ${targets.length} users`);
    } catch (e: any) {
      this.logger.warn(`notifyNewVehicle failed: ${e?.message ?? e}`);
    }
  }

  /**
   * Tell the driver a booking was handed to them: an inbox row they'll see next
   * time they open the app, plus a push if they have a device registered.
   */
  async notifyRequirementAssigned(requirement: any) {
    const driverId = requirement?.assignedDriver?._id ?? requirement?.assignedDriver;
    if (!driverId) return;

    const poster = requirement.postedBy ?? {};
    const posterName = poster.agencyName || poster.fullName || 'A partner';

    const title = '🚕 New booking assigned to you';
    const body = `${posterName} assigned you Booking #${requirement.bookingId} | ${requirement.pickupCity} → ${requirement.dropCity}`;
    // Tapping it opens My Requirements on the Assigned tab.
    const actionUrl = '/my-requirements?tab=2';
    const data = {
      requirementId: requirement._id.toString(),
      bookingId: `${requirement.bookingId ?? ''}`,
      type: NotificationType.REQUIREMENT_ASSIGNED,
      actionUrl,
    };

    // The inbox row is the reliable channel — a driver with no FCM token (fresh
    // login, web) would otherwise never learn about the assignment.
    await this.notificationModel.create({
      userId: driverId,
      title,
      body,
      type: NotificationType.REQUIREMENT_ASSIGNED,
      actionUrl,
      isSent: true,
      sentAt: new Date(),
      data,
    });

    const driver = await this.userModel.findById(driverId).select('fcmTokens').lean();
    if (!driver?.fcmTokens?.length) return;

    await this.firebaseService.sendPushNotification(driver.fcmTokens, { title, body, data });
  }

  /**
   * Send the trip OTP to the requirement's OWNER (not the driver). The owner
   * reads it out to the driver, who types it in — that's the proof the two are
   * actually together. It goes in the inbox so it survives a missed push.
   */
  async notifyTripOtp(requirement: any, driver: any, otp: string, action: 'start' | 'end') {
    const ownerId = requirement?.postedBy?._id ?? requirement?.postedBy;
    if (!ownerId) return;

    const driverName = driver?.agencyName || driver?.fullName || 'Your driver';
    const verb = action === 'start' ? 'start' : 'end';

    const title = `🔐 OTP to ${verb} trip: ${otp}`;
    const body =
      `${driverName} wants to ${verb} Booking #${requirement.bookingId}.\n` +
      `Share this OTP only when you're with them: ${otp}\n` +
      `Valid for 15 minutes.`;

    const data = {
      requirementId: requirement._id.toString(),
      bookingId: `${requirement.bookingId ?? ''}`,
      type: NotificationType.TRIP_OTP,
      otp,
      action,
    };

    await this.notificationModel.create({
      userId: ownerId,
      title,
      body,
      type: NotificationType.TRIP_OTP,
      isSent: true,
      sentAt: new Date(),
      data,
    });

    const owner = await this.userModel.findById(ownerId).select('fcmTokens').lean();
    if (!owner?.fcmTokens?.length) return;
    await this.firebaseService.sendPushNotification(owner.fcmTokens, { title, body, data });
  }

  /** Tell the owner the trip actually started / finished. */
  async notifyTripStatus(requirement: any, action: 'start' | 'end') {
    const ownerId = requirement?.postedBy?._id ?? requirement?.postedBy;
    if (!ownerId) return;

    const driver = requirement.assignedDriver ?? {};
    const driverName = driver.agencyName || driver.fullName || 'Your driver';
    const started = action === 'start';

    const title = started ? '🚗 Trip started' : '✅ Trip completed';
    const body = `${driverName} ${started ? 'started' : 'completed'} Booking #${requirement.bookingId} | ${requirement.pickupCity} → ${requirement.dropCity}`;

    const data = {
      requirementId: requirement._id.toString(),
      bookingId: `${requirement.bookingId ?? ''}`,
      type: started ? NotificationType.TRIP_STARTED : NotificationType.TRIP_COMPLETED,
    };

    await this.notificationModel.create({
      userId: ownerId,
      title,
      body,
      type: data.type,
      isSent: true,
      sentAt: new Date(),
      data,
    });

    const owner = await this.userModel.findById(ownerId).select('fcmTokens').lean();
    if (!owner?.fcmTokens?.length) return;
    await this.firebaseService.sendPushNotification(owner.fcmTokens, { title, body, data });
  }

  /** Push only — the poster gets a device notification, not an inbox row. */
  async notifyRequirementAccepted(requirement: any, acceptingUser: any) {
    const poster = await this.userModel.findById(requirement.postedBy).select('fcmTokens _id');
    if (!poster?.fcmTokens?.length) return;

    const title = '✅ Someone accepted your booking!';
    const body = `${acceptingUser.fullName || acceptingUser.agencyName} is interested in Booking #${requirement.bookingId}`;

    await this.firebaseService.sendPushNotification(poster.fcmTokens, {
      title,
      body,
      data: {
        requirementId: requirement._id.toString(),
        bookingId: `${requirement.bookingId ?? ''}`,
        type: NotificationType.REQUIREMENT_ACCEPTED,
      },
    });
  }

  async sendGlobalNotification(title: string, body: string, data?: Record<string, string>) {
    return this.sendAdminNotification({ title, body, data });
  }

  /**
   * Admin broadcast: saves an in-app notification row per matched user and pushes
   * it over FCM. Every target list is "empty = no restriction", so leaving all of
   * them blank reaches every active, notifiable user.
   */
  async sendAdminNotification(input: {
    title: string;
    body: string;
    imageUrl?: string;
    actionUrl?: string;
    type?: string;
    targetRoles?: string[];
    targetCities?: string[];
    targetMemberships?: string[];
    data?: Record<string, string>;
  }) {
    const { title, body, imageUrl, actionUrl } = input;
    const roles = (input.targetRoles ?? []).filter(Boolean);
    const cities = (input.targetCities ?? []).filter(Boolean);
    const memberships = (input.targetMemberships ?? []).filter(Boolean);
    const type = Object.values(NotificationType).includes(input.type as NotificationType)
      ? (input.type as NotificationType)
      : NotificationType.SYSTEM;

    // Audience = who the message is for. notificationsEnabled is deliberately NOT
    // part of this: it's a "don't buzz my phone" preference, so those users still
    // get the message in their in-app inbox — they're just skipped for push below.
    const filter: any = { isActive: true, isBlocked: { $ne: true } };
    // Admins aren't app users — never broadcast to them.
    filter.role = roles.length ? { $in: roles } : { $nin: ['admin', 'super_admin'] };
    if (memberships.length) filter.membershipType = { $in: memberships };
    // A user who picked no business city counts as "all cities", same as requirement alerts.
    if (cities.length) {
      filter.$or = [
        { businessCities: { $in: cities } },
        { businessCities: { $size: 0 } },
        { businessCities: { $exists: false } },
      ];
    }

    const users = await this.userModel.find(filter).select('fcmTokens _id notificationsEnabled').lean();
    if (users.length === 0) return { message: 'No users matched this audience' };

    // One id shared by every row of this send, so the admin panel can group them
    // back together and report sent/read/clicked counts.
    const campaignId = new Types.ObjectId().toString();
    const sentAt = new Date();

    // Everything in an FCM data payload must be a string.
    const payload: Record<string, string> = {
      ...(input.data ?? {}),
      type,
      campaignId,
      ...(actionUrl ? { actionUrl } : {}),
      ...(imageUrl ? { imageUrl } : {}),
    };

    await this.notificationModel.insertMany(
      users.map((u) => ({
        userId: u._id,
        title,
        body,
        type,
        campaignId,
        isGlobal: !roles.length && !cities.length && !memberships.length,
        targetRoles: roles,
        targetCities: cities,
        targetMemberships: memberships,
        imageUrl,
        actionUrl,
        isSent: true,
        sentAt,
        data: payload,
      })),
    );

    // Push to every matched user who has a device token. NOTE: this is NOT gated
    // by notificationsEnabled — that flag is the booking-alert (ring/popup) opt-in,
    // which is off by default for everyone; gating admin broadcasts on it silently
    // stopped ALL admin push. Admin announcements go to the whole audience.
    const allTokens = users
      .flatMap((u) => u.fcmTokens ?? [])
      .filter(Boolean);
    const batchSize = 500;
    for (let i = 0; i < allTokens.length; i += batchSize) {
      try {
        await this.firebaseService.sendPushNotification(allTokens.slice(i, i + batchSize), {
          title,
          body,
          data: payload,
          imageUrl,
        });
      } catch (error) {
        this.logger.error('Admin push batch failed:', error.message);
      }
    }

    return { message: `Notification sent to ${users.length} users` };
  }

  /**
   * What the in-app inbox shows: admin broadcasts, plus notices the user must act
   * on (a booking assigned to them). The noisy self-confirmations (requirement
   * posted / vehicle listed / new requirement) are no longer written, but rows
   * from before that change still exist — this allowlist keeps them out of both
   * the list and the unread badge without needing a migration.
   */
  private static readonly INBOX_TYPES = [
    NotificationType.SYSTEM,
    NotificationType.PROMOTIONAL,
    NotificationType.REQUIREMENT_ASSIGNED,
    NotificationType.TRIP_OTP,
    NotificationType.TRIP_STARTED,
    NotificationType.TRIP_COMPLETED,
  ];

  private visibleFor(userId: string) {
    return {
      userId: new Types.ObjectId(userId),
      type: { $in: NotificationsService.INBOX_TYPES },
    };
  }

  async getUserNotifications(userId: string, page = 1, limit = 20) {
    const { skip, sort } = getPaginationParams({ page, limit, sortBy: 'createdAt', sortOrder: 'desc' });
    const base = this.visibleFor(userId);

    const [notifications, total, unreadCount] = await Promise.all([
      this.notificationModel.find(base).sort(sort).skip(skip).limit(limit).lean(),
      this.notificationModel.countDocuments(base),
      this.notificationModel.countDocuments({ ...base, isRead: false }),
    ]);

    return buildPaginatedResult({ notifications, unreadCount } as any, total, page, limit);
  }

  async markAsRead(userId: string, notificationId?: string) {
    const filter: any = { userId: new Types.ObjectId(userId) };
    if (notificationId) filter._id = new Types.ObjectId(notificationId);

    await this.notificationModel.updateMany(filter, { isRead: true, readAt: new Date() });
    return { message: 'Notifications marked as read' };
  }

  /** The user followed this notification's action URL. Only the first tap counts. */
  async markClicked(userId: string, notificationId: string) {
    await this.notificationModel.updateOne(
      { _id: new Types.ObjectId(notificationId), userId: new Types.ObjectId(userId), isClicked: { $ne: true } },
      { isClicked: true, clickedAt: new Date(), isRead: true, readAt: new Date() },
    );
    return { message: 'Click recorded' };
  }

  /**
   * Admin history: one row per broadcast, with how many users it reached, how many
   * opened it, and how many followed its action URL.
   */
  async getSentNotifications(page = 1, limit = 20) {
    const skip = (Math.max(1, +page) - 1) * Math.max(1, +limit);
    const perLimit = Math.max(1, +limit);

    const match = { campaignId: { $exists: true, $ne: null } };
    const group = [
      {
        $group: {
          _id: '$campaignId',
          title: { $first: '$title' },
          body: { $first: '$body' },
          type: { $first: '$type' },
          imageUrl: { $first: '$imageUrl' },
          actionUrl: { $first: '$actionUrl' },
          targetRoles: { $first: '$targetRoles' },
          targetCities: { $first: '$targetCities' },
          targetMemberships: { $first: '$targetMemberships' },
          sentAt: { $first: '$sentAt' },
          createdAt: { $first: '$createdAt' },
          recipients: { $sum: 1 },
          readCount: { $sum: { $cond: ['$isRead', 1, 0] } },
          clickCount: { $sum: { $cond: ['$isClicked', 1, 0] } },
        },
      },
    ];

    const [rows, totals] = await Promise.all([
      this.notificationModel.aggregate([
        { $match: match },
        ...group,
        { $sort: { sentAt: -1, createdAt: -1 } },
        { $skip: skip },
        { $limit: perLimit },
        { $project: { _id: 0, campaignId: '$_id', title: 1, body: 1, type: 1, imageUrl: 1, actionUrl: 1, targetRoles: 1, targetCities: 1, targetMemberships: 1, sentAt: 1, createdAt: 1, recipients: 1, readCount: 1, clickCount: 1 } },
      ]),
      this.notificationModel.aggregate([
        { $match: match },
        ...group,
        { $count: 'total' },
      ]),
    ]);

    const total = totals[0]?.total ?? 0;
    return {
      message: 'Sent notifications',
      data: {
        notifications: rows,
        pagination: { page: +page, limit: perLimit, total, totalPages: Math.ceil(total / perLimit) },
      },
    };
  }

  async getUnreadCount(userId: string) {
    const count = await this.notificationModel.countDocuments({
      ...this.visibleFor(userId),
      isRead: false,
    });
    return { data: { count } };
  }
}
