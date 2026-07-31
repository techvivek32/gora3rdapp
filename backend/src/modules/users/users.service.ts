import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { User, UserDocument } from '../../database/schemas/user.schema';
import { AvailableVehicle, AvailableVehicleDocument } from '../../database/schemas/available-vehicle.schema';
import { Requirement, RequirementDocument } from '../../database/schemas/requirement.schema';
import { Rating, RatingDocument } from '../../database/schemas/rating.schema';
import {
  AccountDeletionRequest,
  AccountDeletionRequestDocument,
} from '../../database/schemas/account-deletion-request.schema';
import { ConflictException } from '@nestjs/common';
import { UpdateProfileDto } from './dto/update-profile.dto';
import { RateUserDto } from './dto/rate-user.dto';
import { SubmitVerificationDto } from './dto/submit-verification.dto';
import { VerificationStatus } from '../../common/enums/user-role.enum';
import { getPaginationParams, buildPaginatedResult } from '../../common/utils/pagination.util';

// Public-facing profile fields (no credentials / private data).
const PUBLIC_PROFILE_SELECT =
  'fullName agencyName profileImage coverImage membershipType isVerified verificationStatus rating totalRatings lastActive lastLocationAddress lastLocationAt city state mobile role businessCities requirementsPosted vehiclesPosted walletBalance createdAt';

// Paid membership tiers (mirrors the app's `canContactPosters` gate) — used to
// decide whether the VIEWER may see another user's last location.
const PAID_TIERS = ['active', 'verified', 'premium', 'golden'];

@Injectable()
export class UsersService {
  constructor(
    @InjectModel(User.name) private userModel: Model<UserDocument>,
    @InjectModel(AvailableVehicle.name) private vehicleModel: Model<AvailableVehicleDocument>,
    @InjectModel(Requirement.name) private requirementModel: Model<RequirementDocument>,
    @InjectModel(Rating.name) private ratingModel: Model<RatingDocument>,
    @InjectModel(AccountDeletionRequest.name)
    private deletionRequestModel: Model<AccountDeletionRequestDocument>,
  ) {}

  // One-time rating of another user. Recomputes the rated user's average.
  async rateUser(raterId: string, ratedUserId: string, dto: RateUserDto) {
    if (raterId === ratedUserId) {
      throw new BadRequestException('You cannot rate yourself');
    }
    const target = await this.userModel.findById(ratedUserId).select('_id');
    if (!target) throw new NotFoundException('User not found');

    const existing = await this.ratingModel.findOne({ rater: raterId, ratedUser: ratedUserId });
    if (existing) throw new ConflictException('You have already rated this user');

    await this.ratingModel.create({
      rater: new Types.ObjectId(raterId),
      ratedUser: new Types.ObjectId(ratedUserId),
      stars: dto.stars,
      review: dto.review,
    });

    // Recompute average + count.
    const agg = await this.ratingModel.aggregate([
      { $match: { ratedUser: new Types.ObjectId(ratedUserId) } },
      { $group: { _id: null, avg: { $avg: '$stars' }, count: { $sum: 1 } } },
    ]);
    const avg = agg[0]?.avg ?? dto.stars;
    const count = agg[0]?.count ?? 1;
    await this.userModel.findByIdAndUpdate(ratedUserId, {
      rating: Math.round(avg * 10) / 10,
      totalRatings: count,
    });

    return { message: 'Rating submitted', data: { rating: Math.round(avg * 10) / 10, totalRatings: count } };
  }

  async getRatingStatus(raterId: string, ratedUserId: string) {
    const existing = await this.ratingModel.findOne({ rater: raterId, ratedUser: ratedUserId }).lean();
    return { message: 'Rating status', data: { hasRated: !!existing, stars: existing?.stars ?? null } };
  }

  async getReviews(ratedUserId: string) {
    // Match by the string form of ratedUser so it works whether the field was stored
    // as an ObjectId (normal) or as a plain string (legacy/seeded data) — otherwise a
    // type mismatch silently returns zero reviews even when the rating average exists.
    const reviews = await this.ratingModel
      .find({ $expr: { $eq: [{ $toString: '$ratedUser' }, ratedUserId] } })
      .populate('rater', 'fullName profileImage')
      .sort({ createdAt: -1 })
      .lean();
    return { message: 'Reviews retrieved', data: reviews };
  }

  // Attaches the user's active vehicle listings so a profile shows "My Vehicles".
  private async withVehicles(user: any) {
    const vehicles = await this.vehicleModel
      .find({ postedBy: user._id, isDeleted: false })
      .select('listingId vehicleType vehicleNumber vehicleModel vehicleColor currentCity currentState status driverName driverRating')
      .sort({ createdAt: -1 })
      .limit(20)
      .lean();
    return { ...user, vehicles };
  }

  async lookupByMobile(mobile: string) {
    const digits = (mobile || '').replace(/\D/g, '');
    if (digits.length < 10) {
      throw new BadRequestException('Enter a valid mobile number');
    }
    const last10 = digits.slice(-10);
    const user = await this.userModel
      .findOne({ mobile: new RegExp(`${last10}$`), isActive: true })
      .select(PUBLIC_PROFILE_SELECT)
      .lean();
    if (!user) throw new NotFoundException('No user found with this number');

    return { message: 'User found', data: await this.withVehicles(user) };
  }

  async getProfile(userId: string) {
    const user = await this.userModel
      .findById(userId)
      .select('-password -refreshToken -fcmTokens -loginAttempts -lockUntil')
      .lean();

    if (!user) throw new NotFoundException('User not found');
    return { message: 'Profile retrieved', data: user };
  }

  // Referral code + how many users this person invited (+ the invited list).
  async getReferralInfo(userId: string) {
    const user = await this.userModel.findById(userId).select('mobile referralCode referralCount');
    if (!user) throw new NotFoundException('User not found');

    // The code is the user's mobile number. Older accounts still carry a random
    // GORAxxxxxx code, so migrate them on read — otherwise the code they share
    // wouldn't be the one shown here.
    if (user.mobile && user.referralCode !== user.mobile) {
      await this.userModel.findByIdAndUpdate(userId, { referralCode: user.mobile });
    }

    const invited = await this.userModel
      .find({ referredBy: new Types.ObjectId(userId) })
      .select('fullName agencyName profileImage city createdAt')
      .sort({ createdAt: -1 })
      .limit(100)
      .lean();

    return {
      message: 'Referral info retrieved',
      data: {
        code: user.mobile ?? '',
        count: user.referralCount ?? 0,
        invited,
      },
    };
  }

  /** 'all' (default) | 'YYYY-MM' (a month) | 'YYYY' (a year). */
  private periodRange(period?: string): { start: Date; end: Date } | null {
    const p = (period || 'all').trim();
    if (!p || p === 'all') return null;

    const month = /^(\d{4})-(\d{2})$/.exec(p);
    if (month) {
      const y = +month[1];
      const m = +month[2] - 1;
      return { start: new Date(y, m, 1), end: new Date(y, m + 1, 1) };
    }
    const year = /^(\d{4})$/.exec(p);
    if (year) {
      const y = +year[1];
      return { start: new Date(y, 0, 1), end: new Date(y + 1, 0, 1) };
    }
    return null;
  }

  // Leaderboard ranked by how many users each person referred. Users who haven't
  // invited anyone still appear (with 0) for the all-time board, so it's never
  // empty. Admins are excluded.
  async getReferralLeaderboard(currentUserId?: string, period?: string) {
    const select = 'fullName agencyName profileImage city referralCount';
    const notAdmin = { role: { $nin: ['admin', 'super_admin'] } };
    const range = this.periodRange(period);

    // All time: the stored lifetime counter. No limit — the whole board is shown.
    if (!range) {
      const users = await this.userModel
        .find(notAdmin)
        .select(select)
        .sort({ referralCount: -1, createdAt: 1 })
        .lean();

      return {
        message: 'Leaderboard retrieved',
        data: users.map((u, i) => ({
          rank: i + 1,
          _id: u._id,
          name: u.fullName || u.agencyName || 'User',
          city: u.city ?? '',
          profileImage: u.profileImage ?? '',
          count: u.referralCount ?? 0,
          isMe: currentUserId ? u._id.toString() === currentUserId : false,
        })),
      };
    }

    // A month/year: referralCount is a lifetime total with no time dimension, so
    // count the invitees who actually SIGNED UP inside the window instead.
    const grouped = await this.userModel.aggregate([
      { $match: { referredBy: { $ne: null, $exists: true }, createdAt: { $gte: range.start, $lt: range.end } } },
      { $group: { _id: '$referredBy', count: { $sum: 1 } } },
      { $sort: { count: -1 } },
    ]);

    if (grouped.length === 0) return { message: 'Leaderboard retrieved', data: [] };

    const counts = new Map<string, number>(grouped.map((g: any) => [String(g._id), g.count]));
    const referrers = await this.userModel
      .find({ ...notAdmin, _id: { $in: grouped.map((g: any) => g._id) } })
      .select(select)
      .lean();

    const data = referrers
      .map((u: any) => ({
        _id: u._id,
        name: u.fullName || u.agencyName || 'User',
        city: u.city ?? '',
        profileImage: u.profileImage ?? '',
        count: counts.get(String(u._id)) ?? 0,
        isMe: currentUserId ? u._id.toString() === currentUserId : false,
      }))
      .sort((a, b) => b.count - a.count)
      .map((u, i) => ({ rank: i + 1, ...u }));

    return { message: 'Leaderboard retrieved', data };
  }

  async updateProfile(userId: string, dto: UpdateProfileDto) {
    const user = await this.userModel.findById(userId).select('isActive isBlocked');
    if (!user) throw new NotFoundException('User not found');
    if (!user.isActive) throw new BadRequestException('Your account is inactive. Please contact support.');
    if (user.isBlocked) throw new BadRequestException('Your account is blocked. Please contact support.');

    // Check if there's a pending deletion request
    const deletionRequest = await this.deletionRequestModel.findOne({ userId, status: 'pending' }).lean();
    if (deletionRequest) {
      throw new BadRequestException('Your account deletion is pending. You cannot modify your profile.');
    }

    const updated = await this.userModel.findByIdAndUpdate(
      userId,
      { $set: dto },
      { new: true, runValidators: true },
    ).select('-password -refreshToken -fcmTokens');

    return { message: 'Profile updated', data: updated };
  }

  async submitVerification(userId: string, dto: SubmitVerificationDto) {
    // Once submitted, documents are locked while pending or after being verified —
    // only a rejected (or never-submitted) user may (re)submit.
    const current = await this.userModel.findById(userId).select('verificationStatus documents');
    if (
      current?.verificationStatus === VerificationStatus.PENDING ||
      current?.verificationStatus === VerificationStatus.VERIFIED
    ) {
      throw new BadRequestException(
        current.verificationStatus === VerificationStatus.VERIFIED
          ? 'Your documents are already verified and cannot be changed.'
          : 'Your documents are under review and cannot be changed until it is complete.',
      );
    }

    const { agencyName, ...documents } = dto;

    // Keep only the document entries that were actually provided (front and/or back).
    const cleanedDocuments = Object.fromEntries(
      Object.entries(documents).filter(
        ([, value]) => value && (value.number || value.image || value.backImage),
      ),
    );

    // Merge rather than overwrite. An admin may have approved the Aadhaar and
    // rejected only the PAN — replacing `documents` wholesale would drop the
    // Aadhaar's approval and force the user to redo a document that was fine.
    const existing: Record<string, any> = { ...(current?.documents ?? {}) };
    const merged: Record<string, any> = { ...existing };

    for (const [key, value] of Object.entries(cleanedDocuments)) {
      // An already-approved document is final and cannot be resubmitted.
      if (existing[key]?.status === 'approved') continue;
      merged[key] = { ...(value as any), status: 'pending', rejectionReason: null };
    }

    // Anything still approved stays approved; if that's now everything, there is
    // nothing left for an admin to review.
    const submitted = Object.values(merged).filter(
      (d: any) => d && (d.image || d.backImage || d.number),
    );
    const allApproved = submitted.length > 0 && submitted.every((d: any) => d.status === 'approved');

    const update: Record<string, any> = {
      documents: merged,
      verificationStatus: allApproved ? VerificationStatus.VERIFIED : VerificationStatus.PENDING,
      verificationSubmittedAt: new Date(),
      verificationRejectionReason: null,
      isVerified: allApproved,
      isAdminApproved: allApproved,
    };
    if (agencyName) update.agencyName = agencyName;

    const user = await this.userModel
      .findByIdAndUpdate(userId, update, { new: true })
      .select('-password -refreshToken -fcmTokens');

    if (!user) throw new NotFoundException('User not found');
    return { message: 'Verification submitted', data: user };
  }

  async updateBusinessCities(userId: string, cities: string[]) {
    if (!cities || !Array.isArray(cities)) {
      throw new BadRequestException('Cities must be an array');
    }

    const user = await this.userModel.findByIdAndUpdate(
      userId,
      { businessCities: cities },
      { new: true },
    ).select('businessCities');

    return { message: 'Business cities updated', data: user };
  }

  async getUserCard(userId: string, viewerId?: string) {
    if (!Types.ObjectId.isValid(userId)) throw new NotFoundException('User not found');

    const targetUser: any = await this.userModel
      .findById(userId)
      .select(PUBLIC_PROFILE_SELECT)
      .lean();
    if (!targetUser) throw new NotFoundException('User not found');

    // The last location is premium-gated: only paid members (or the profile owner)
    // may see where a user was. Strip it for everyone else so it never leaves the API.
    const isOwner = viewerId && viewerId === userId;
    const viewerPaid = isOwner || (viewerId ? await this.isPaidViewer(viewerId) : false);
    if (!viewerPaid) {
      delete targetUser.lastLocationAddress;
      delete targetUser.lastLocationAt;
    }

    const [withVeh, stats] = await Promise.all([
      this.withVehicles(targetUser),
      this.userActivityStats(userId),
    ]);
    return { message: 'User card retrieved', data: { ...withVeh, ...stats } };
  }

  /**
   * Booking (requirements) + availability (cabs) breakdown for a user's profile.
   * "Expired" counts posts whose date has already passed (still open, never
   * booked/cancelled) plus anything explicitly marked expired.
   */
  private async userActivityStats(userId: string) {
    const uid = new Types.ObjectId(userId);
    const now = new Date();
    const [
      bTotal, bBooked, bCancelled, bExpired,
      vTotal, vBooked, vAvailable, vExpired,
    ] = await Promise.all([
      // Bookings (requirements posted by this user).
      this.requirementModel.countDocuments({ postedBy: uid, isDeleted: false }),
      this.requirementModel.countDocuments({ postedBy: uid, isDeleted: false, status: { $in: ['accepted', 'completed'] } }),
      this.requirementModel.countDocuments({ postedBy: uid, isDeleted: false, status: 'cancelled' }),
      this.requirementModel.countDocuments({
        postedBy: uid, isDeleted: false,
        $or: [{ status: 'expired' }, { status: { $in: ['active', 'on_hold'] }, travelDate: { $lt: now } }],
      }),
      // Availability (cabs posted by this user).
      this.vehicleModel.countDocuments({ postedBy: uid, isDeleted: false }),
      this.vehicleModel.countDocuments({ postedBy: uid, isDeleted: false, status: 'booked' }),
      this.vehicleModel.countDocuments({ postedBy: uid, isDeleted: false, status: 'available', availableDate: { $gte: now } }),
      this.vehicleModel.countDocuments({
        postedBy: uid, isDeleted: false,
        $or: [{ status: 'expired' }, { status: 'available', availableDate: { $lt: now } }],
      }),
    ]);
    return {
      bookingStats: { total: bTotal, booked: bBooked, cancelled: bCancelled, expired: bExpired },
      availabilityStats: { total: vTotal, booked: vBooked, available: vAvailable, expired: vExpired },
    };
  }

  /** True if the viewer is on a paid tier (and not expired) — may see last location. */
  private async isPaidViewer(viewerId: string): Promise<boolean> {
    if (!Types.ObjectId.isValid(viewerId)) return false;
    const v: any = await this.userModel
      .findById(viewerId)
      .select('membershipType isPremium isGolden membershipExpiresAt')
      .lean();
    if (!v) return false;
    if (v.membershipExpiresAt && new Date(v.membershipExpiresAt) < new Date()) return false;
    return PAID_TIERS.includes((v.membershipType || '').toLowerCase()) || !!v.isPremium || !!v.isGolden;
  }

  /** Store the caller's last GPS location + a reverse-geocoded address. */
  async updateLocation(userId: string, lat: number, lng: number) {
    const la = Number(lat);
    const ln = Number(lng);
    if (!isFinite(la) || !isFinite(ln) || Math.abs(la) > 90 || Math.abs(ln) > 180) {
      throw new BadRequestException('Valid lat/lng are required');
    }
    const address = await this.reverseGeocode(la, ln);
    await this.userModel.findByIdAndUpdate(userId, {
      lastLat: la,
      lastLng: ln,
      ...(address ? { lastLocationAddress: address } : {}),
      lastLocationAt: new Date(),
      lastActive: new Date(),
    });
    return { message: 'Location updated', data: { address: address ?? null } };
  }

  /** lat/lng → a concise address like "Raghunathpura 313001, Rajasthan" (Google Geocoding). */
  private async reverseGeocode(lat: number, lng: number): Promise<string | null> {
    const key = process.env.GOOGLE_MAPS_API_KEY;
    if (!key || key === 'your-google-maps-api-key') return null;
    try {
      const url = `https://maps.googleapis.com/maps/api/geocode/json?latlng=${lat},${lng}&key=${key}&language=en&region=in`;
      const res = await fetch(url);
      const body: any = await res.json();
      if (body.status !== 'OK' || !body.results?.length) return null;
      const comps: any[] = body.results[0].address_components || [];
      const get = (type: string) => comps.find((c) => c.types?.includes(type))?.long_name;
      const area =
        get('sublocality_level_1') || get('sublocality') || get('locality') ||
        get('neighborhood') || get('administrative_area_level_2') || '';
      const pin = get('postal_code') || '';
      const state = get('administrative_area_level_1') || '';
      const line1 = [area, pin].filter(Boolean).join(' ');
      const label = [line1, state].filter(Boolean).join(', ');
      return label || body.results[0].formatted_address || null;
    } catch {
      return null;
    }
  }

  async toggleNotifications(
    userId: string,
    enabled: boolean,
    vehicleTypes?: string[],
    tripTypes?: string[],
  ) {
    const update: Record<string, unknown> = { notificationsEnabled: enabled };
    if (Array.isArray(vehicleTypes)) update.alertVehicleTypes = vehicleTypes;
    if (Array.isArray(tripTypes)) update.alertTripTypes = tripTypes;
    await this.userModel.findByIdAndUpdate(userId, update);
    return { message: `Notifications ${enabled ? 'enabled' : 'disabled'}` };
  }

  /** Self-service account deletion is now a *request*: the user gives a reason and an
   *  admin reviews it. The account stays usable until an admin approves, at which
   *  point it's removed from the database. */
  async requestAccountDeletion(userId: string, reason: string) {
    const user = await this.userModel.findById(userId).select('fullName mobile email');
    if (!user) throw new NotFoundException('User not found');

    const existing = await this.deletionRequestModel.findOne({ userId, status: 'pending' }).lean();
    if (existing) {
      throw new ConflictException('You already have a deletion request awaiting review.');
    }

    // Snapshot the identity so the request stays readable after the user is deleted.
    await this.deletionRequestModel.create({
      userId: new Types.ObjectId(userId),
      reason: reason.trim(),
      status: 'pending',
      fullName: user.fullName,
      mobile: user.mobile,
      email: user.email,
    });

    return { message: 'Your deletion request has been submitted for review.' };
  }

  /** Whether the current user already has a pending deletion request. */
  async getDeletionRequestStatus(userId: string) {
    const req = await this.deletionRequestModel
      .findOne({ userId })
      .sort({ createdAt: -1 })
      .select('status reason rejectionReason createdAt')
      .lean();
    return { message: 'Deletion request status', data: req ?? null };
  }

  async updateFcmToken(userId: string, fcmToken: string, action: 'add' | 'remove' = 'add') {
    const update = action === 'add'
      ? { $addToSet: { fcmTokens: fcmToken } }
      : { $pull: { fcmTokens: fcmToken } };

    await this.userModel.findByIdAndUpdate(userId, update);
    return { message: `FCM token ${action}ed` };
  }

  async searchUsers(query: string, page = 1, limit = 20) {
    const { skip, sort } = getPaginationParams({ page, limit });

    const filter = {
      isActive: true,
      isBlocked: false,
      $or: [
        { fullName: new RegExp(query, 'i') },
        { agencyName: new RegExp(query, 'i') },
        { city: new RegExp(query, 'i') },
      ],
    };

    const [users, total] = await Promise.all([
      this.userModel
        .find(filter)
        .select('fullName agencyName profileImage membershipType isVerified city state rating lastActive')
        .sort(sort)
        .skip(skip)
        .limit(limit)
        .lean(),
      this.userModel.countDocuments(filter),
    ]);

    return buildPaginatedResult(users, total, page, limit);
  }
}
