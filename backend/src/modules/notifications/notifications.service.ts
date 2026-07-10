import { Injectable, Logger } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { Notification, NotificationDocument, NotificationType } from '../../database/schemas/notification.schema';
import { User, UserDocument } from '../../database/schemas/user.schema';
import { FirebaseService } from '../firebase/firebase.service';
import { getPaginationParams, buildPaginatedResult } from '../../common/utils/pagination.util';

@Injectable()
export class NotificationsService {
  private readonly logger = new Logger(NotificationsService.name);

  constructor(
    @InjectModel(Notification.name) private notificationModel: Model<NotificationDocument>,
    @InjectModel(User.name) private userModel: Model<UserDocument>,
    private firebaseService: FirebaseService,
  ) {}

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

    const titleCase = (s: any) =>
      `${s ?? ''}`.replace(/_/g, ' ').split(' ').filter(Boolean)
        .map((w) => w[0].toUpperCase() + w.slice(1)).join(' ');
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

    // Push format:
    //   Gora Taxi booking One Way trip
    //   Jodhpur → Surat
    //   Car type - Innova Crysta
    //   Date time - 4 July 2026 | 5:00am
    const title = `Gora Taxi booking ${titleCase(requirement.tripType)} trip`;
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
    const sendToTokens = async (tokens: string[], posterMobile: string) => {
      const batchSize = 500;
      for (let i = 0; i < tokens.length; i += batchSize) {
        const batch = tokens.slice(i, i + batchSize);
        try {
          await this.firebaseService.sendPushNotification(batch, {
            title,
            body,
            data: { ...baseData, posterMobile },
          });
        } catch (error) {
          this.logger.error('FCM batch send failed:', error.message);
        }
      }
    };

    await sendToTokens(premiumTokens, `${poster?.mobile ?? ''}`);
    await sendToTokens(basicTokens, ''); // non-premium: no contact number
  }

  async notifyRequirementPosted(requirement: any) {
    await this.notificationModel.create({
      userId: requirement.postedBy,
      title: '✅ Requirement Posted Successfully!',
      body: `Booking #${requirement.bookingId} | ${requirement.pickupCity} → ${requirement.dropCity} is now live.`,
      type: NotificationType.REQUIREMENT_POSTED,
      data: {
        requirementId: requirement._id.toString(),
        bookingId: requirement.bookingId,
      },
    });
  }

  async notifyVehiclePosted(vehicle: any) {
    await this.notificationModel.create({
      userId: vehicle.postedBy,
      title: '✅ Vehicle Listed Successfully!',
      body: `Listing #${vehicle.listingId} | ${vehicle.currentCity} → ${vehicle.destinationCity} is now live.`,
      type: NotificationType.VEHICLE_POSTED,
      data: {
        vehicleId: vehicle._id.toString(),
        listingId: vehicle.listingId,
      },
    });
  }

  async notifyRequirementAccepted(requirement: any, acceptingUser: any) {
    const poster = await this.userModel.findById(requirement.postedBy).select('fcmTokens _id');
    if (!poster?.fcmTokens?.length) return;

    const title = '✅ Someone accepted your requirement!';
    const body = `${acceptingUser.fullName || acceptingUser.agencyName} is interested in Booking #${requirement.bookingId}`;

    await this.notificationModel.create({
      userId: poster._id,
      title,
      body,
      type: NotificationType.REQUIREMENT_ACCEPTED,
      data: {
        requirementId: requirement._id.toString(),
        bookingId: requirement.bookingId,
        acceptingUserId: acceptingUser._id.toString(),
      },
    });

    await this.firebaseService.sendPushNotification(poster.fcmTokens, { title, body });
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

    const filter: any = { isActive: true, isBlocked: false, notificationsEnabled: true };
    if (roles.length) filter.role = { $in: roles };
    if (memberships.length) filter.membershipType = { $in: memberships };
    // A user who picked no business city counts as "all cities", same as requirement alerts.
    if (cities.length) {
      filter.$or = [
        { businessCities: { $in: cities } },
        { businessCities: { $size: 0 } },
        { businessCities: { $exists: false } },
      ];
    }

    const users = await this.userModel.find(filter).select('fcmTokens _id').lean();
    if (users.length === 0) return { message: 'No users matched this audience' };

    // Everything in an FCM data payload must be a string.
    const payload: Record<string, string> = {
      ...(input.data ?? {}),
      type,
      ...(actionUrl ? { actionUrl } : {}),
      ...(imageUrl ? { imageUrl } : {}),
    };

    await this.notificationModel.insertMany(
      users.map((u) => ({
        userId: u._id,
        title,
        body,
        type,
        isGlobal: !roles.length && !cities.length && !memberships.length,
        targetRoles: roles,
        targetCities: cities,
        targetMemberships: memberships,
        imageUrl,
        actionUrl,
        isSent: true,
        sentAt: new Date(),
        data: payload,
      })),
    );

    // Users without a device token still get the in-app row above; only push below.
    const allTokens = users.flatMap((u) => u.fcmTokens ?? []).filter(Boolean);
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
   * New-requirement alerts are no longer stored, but rows written before that
   * change still exist — keep them out of the list and the unread badge.
   */
  private visibleFor(userId: string) {
    return {
      userId: new Types.ObjectId(userId),
      type: { $ne: NotificationType.NEW_REQUIREMENT },
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

  async getUnreadCount(userId: string) {
    const count = await this.notificationModel.countDocuments({
      ...this.visibleFor(userId),
      isRead: false,
    });
    return { data: { count } };
  }
}
