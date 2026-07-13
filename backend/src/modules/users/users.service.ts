import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { User, UserDocument } from '../../database/schemas/user.schema';
import { AvailableVehicle, AvailableVehicleDocument } from '../../database/schemas/available-vehicle.schema';
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
  'fullName agencyName profileImage coverImage membershipType isVerified verificationStatus rating totalRatings lastActive city state mobile role businessCities requirementsPosted vehiclesPosted walletBalance createdAt';

@Injectable()
export class UsersService {
  constructor(
    @InjectModel(User.name) private userModel: Model<UserDocument>,
    @InjectModel(AvailableVehicle.name) private vehicleModel: Model<AvailableVehicleDocument>,
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

  // Leaderboard ranked by how many users each person referred. Users who haven't
  // invited anyone still appear (with 0), so the board is never empty. Admins are
  // excluded.
  async getReferralLeaderboard(currentUserId?: string) {
    const top = await this.userModel
      .find({ role: { $nin: ['admin', 'super_admin'] } })
      .select('fullName agencyName profileImage city referralCount')
      .sort({ referralCount: -1, createdAt: 1 })
      .limit(50)
      .lean();

    const leaderboard = top.map((u, i) => ({
      rank: i + 1,
      _id: u._id,
      name: u.fullName || u.agencyName || 'User',
      city: u.city ?? '',
      profileImage: u.profileImage ?? '',
      count: u.referralCount ?? 0,
      isMe: currentUserId ? u._id.toString() === currentUserId : false,
    }));

    return { message: 'Leaderboard retrieved', data: leaderboard };
  }

  async updateProfile(userId: string, dto: UpdateProfileDto) {
    const user = await this.userModel.findByIdAndUpdate(
      userId,
      { $set: dto },
      { new: true, runValidators: true },
    ).select('-password -refreshToken -fcmTokens');

    if (!user) throw new NotFoundException('User not found');
    return { message: 'Profile updated', data: user };
  }

  async submitVerification(userId: string, dto: SubmitVerificationDto) {
    // Once submitted, documents are locked while pending or after being verified —
    // only a rejected (or never-submitted) user may (re)submit.
    const current = await this.userModel.findById(userId).select('verificationStatus');
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

    const update: Record<string, any> = {
      documents: cleanedDocuments,
      verificationStatus: VerificationStatus.PENDING,
      verificationSubmittedAt: new Date(),
      verificationRejectionReason: null,
      // Re-submitting resets any prior approval until an admin reviews again.
      isVerified: false,
      isAdminApproved: false,
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

  async getUserCard(userId: string) {
    if (!Types.ObjectId.isValid(userId)) throw new NotFoundException('User not found');

    const targetUser = await this.userModel
      .findById(userId)
      .select(PUBLIC_PROFILE_SELECT)
      .lean();
    if (!targetUser) throw new NotFoundException('User not found');

    return { message: 'User card retrieved', data: await this.withVehicles(targetUser) };
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
