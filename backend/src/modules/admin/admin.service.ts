import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { User, UserDocument } from '../../database/schemas/user.schema';
import { Requirement, RequirementDocument } from '../../database/schemas/requirement.schema';
import { AvailableVehicle, AvailableVehicleDocument } from '../../database/schemas/available-vehicle.schema';
import { Payment, PaymentDocument } from '../../database/schemas/payment.schema';
import { WalletTransaction, WalletTransactionDocument } from '../../database/schemas/wallet-transaction.schema';
import { WithdrawalRequest, WithdrawalRequestDocument } from '../../database/schemas/withdrawal-request.schema';
import { Rating, RatingDocument } from '../../database/schemas/rating.schema';
import { Subscription, SubscriptionDocument, SubscriptionPlan, SubscriptionPlanDocument, SubscriptionStatus } from '../../database/schemas/subscription.schema';
import { Report, ReportDocument, ReportStatus } from '../../database/schemas/report.schema';
import { Banner, BannerDocument } from '../../database/schemas/banner.schema';
import { City, CityDocument } from '../../database/schemas/city.schema';
import { AuditLog, AuditLogDocument } from '../../database/schemas/audit-log.schema';
import {
  AccountDeletionRequest,
  AccountDeletionRequestDocument,
} from '../../database/schemas/account-deletion-request.schema';
import { NotificationsService } from '../notifications/notifications.service';
import { RequirementsService } from '../requirements/requirements.service';
import { AvailableVehiclesService } from '../available-vehicles/available-vehicles.service';
import { MembershipType, UserRole, VerificationStatus } from '../../common/enums/user-role.enum';
import { BookingStatus } from '../../common/enums/vehicle-type.enum';
import { getPaginationParams, buildPaginatedResult, dateRangeFilter } from '../../common/utils/pagination.util';

@Injectable()
export class AdminService {
  constructor(
    @InjectModel(User.name) private userModel: Model<UserDocument>,
    @InjectModel(Requirement.name) private requirementModel: Model<RequirementDocument>,
    @InjectModel(AvailableVehicle.name) private vehicleModel: Model<AvailableVehicleDocument>,
    @InjectModel(Payment.name) private paymentModel: Model<PaymentDocument>,
    @InjectModel(WalletTransaction.name) private walletTxModel: Model<WalletTransactionDocument>,
    @InjectModel(WithdrawalRequest.name) private withdrawalModel: Model<WithdrawalRequestDocument>,
    @InjectModel(Rating.name) private ratingModel: Model<RatingDocument>,
    @InjectModel(Subscription.name) private subscriptionModel: Model<SubscriptionDocument>,
    @InjectModel(SubscriptionPlan.name) private planModel: Model<SubscriptionPlanDocument>,
    @InjectModel(Report.name) private reportModel: Model<ReportDocument>,
    @InjectModel(Banner.name) private bannerModel: Model<BannerDocument>,
    @InjectModel(City.name) private cityModel: Model<CityDocument>,
    @InjectModel(AuditLog.name) private auditLogModel: Model<AuditLogDocument>,
    @InjectModel(AccountDeletionRequest.name)
    private deletionRequestModel: Model<AccountDeletionRequestDocument>,
    private notificationsService: NotificationsService,
    private requirementsService: RequirementsService,
    private availableVehiclesService: AvailableVehiclesService,
  ) {}

  // ── Account deletion requests ───────────────────────────────────────────────

  async getDeletionRequests(query: any) {
    const { page, limit, skip } = getPaginationParams(query);
    const filter: any = { ...dateRangeFilter(query) };
    if (query.status) filter.status = query.status;
    if (query.search) {
      const rx = new RegExp(String(query.search).replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'i');
      filter.$or = [{ fullName: rx }, { mobile: rx }, { email: rx }, { reason: rx }];
    }

    const [requests, total] = await Promise.all([
      this.deletionRequestModel
        .find(filter)
        .populate('userId', 'fullName mobile email membershipType profileImage')
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(limit)
        .lean(),
      this.deletionRequestModel.countDocuments(filter),
    ]);

    return { message: 'Deletion requests retrieved', data: buildPaginatedResult(requests, total, page, limit) };
  }

  /** Approving permanently removes the user and hides everything they posted. */
  async approveDeletionRequest(id: string, adminId: string) {
    const request = await this.deletionRequestModel.findById(id);
    if (!request) throw new NotFoundException('Deletion request not found');
    if (request.status !== 'pending') {
      throw new BadRequestException(`This request is already ${request.status}.`);
    }

    const userId = request.userId;
    // Hide their content first, then remove the account itself.
    await Promise.all([
      this.requirementModel.updateMany({ postedBy: userId }, { isDeleted: true, deletedAt: new Date() }),
      this.vehicleModel.updateMany({ postedBy: userId }, { isDeleted: true, deletedAt: new Date() }),
      this.ratingModel.deleteMany({ $or: [{ rater: userId }, { ratedUser: userId }] }),
    ]);
    await this.userModel.findByIdAndDelete(userId);

    request.status = 'approved';
    request.processedBy = new Types.ObjectId(adminId);
    request.processedAt = new Date();
    await request.save();

    await this.auditLogModel.create({
      userId: new Types.ObjectId(adminId),
      action: 'DELETE_ACCOUNT_APPROVED',
      resource: 'user',
      resourceId: userId.toString(),
    });
    return { message: 'Account deleted', data: request };
  }

  async rejectDeletionRequest(id: string, adminId: string, reason?: string) {
    const request = await this.deletionRequestModel.findById(id);
    if (!request) throw new NotFoundException('Deletion request not found');
    if (request.status !== 'pending') {
      throw new BadRequestException(`This request is already ${request.status}.`);
    }

    request.status = 'rejected';
    request.rejectionReason = reason?.trim();
    request.processedBy = new Types.ObjectId(adminId);
    request.processedAt = new Date();
    await request.save();

    await this.auditLogModel.create({
      userId: new Types.ObjectId(adminId),
      action: 'DELETE_ACCOUNT_REJECTED',
      resource: 'user',
      resourceId: request.userId.toString(),
    });
    return { message: 'Deletion request rejected', data: request };
  }

  async getDashboardStats() {
    const now = new Date();
    const todayStart = new Date(now.setHours(0, 0, 0, 0));
    const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);

    const [
      totalUsers, activeUsers, verifiedUsers, premiumUsers, goldenUsers,
      totalRequirements, activeRequirements,
      totalVehicles, activeVehicles,
      totalRevenue, monthlyRevenue,
      pendingReports, totalNotifications,
      todayRegistrations, todayRequirements,
      pendingVerifications,
    ] = await Promise.all([
      this.userModel.countDocuments({ isActive: true }),
      this.userModel.countDocuments({ isActive: true, isBlocked: false, lastActive: { $gte: new Date(Date.now() - 7 * 24 * 60 * 60 * 1000) } }),
      this.userModel.countDocuments({ isVerified: true }),
      this.userModel.countDocuments({ membershipType: MembershipType.PREMIUM }),
      this.userModel.countDocuments({ membershipType: MembershipType.GOLDEN }),
      this.requirementModel.countDocuments({ isDeleted: false }),
      this.requirementModel.countDocuments({ status: BookingStatus.ACTIVE, isDeleted: false }),
      this.vehicleModel.countDocuments({ isDeleted: false }),
      this.vehicleModel.countDocuments({ status: 'available', isDeleted: false }),
      this.razorpayRevenue(),
      this.razorpayRevenue(monthStart),
      this.reportModel.countDocuments({ status: ReportStatus.PENDING }),
      this.notificationsService ? 0 : 0,
      this.userModel.countDocuments({ createdAt: { $gte: todayStart } }),
      this.requirementModel.countDocuments({ createdAt: { $gte: todayStart } }),
      // Matches the default filter on the Verification Requests page.
      this.userModel.countDocuments({ verificationStatus: VerificationStatus.PENDING }),
    ]);

    return {
      message: 'Dashboard stats',
      data: {
        users: { total: totalUsers, active: activeUsers, verified: verifiedUsers, premium: premiumUsers, golden: goldenUsers },
        requirements: { total: totalRequirements, active: activeRequirements, today: todayRequirements },
        vehicles: { total: totalVehicles, active: activeVehicles },
        revenue: {
          total: totalRevenue,
          monthly: monthlyRevenue,
        },
        reports: { pending: pendingReports },
        verifications: { pending: pendingVerifications },
        today: { registrations: todayRegistrations, requirements: todayRequirements },
      },
    };
  }

  async getUsers(query: any) {
    const { page, limit, skip, sort } = getPaginationParams(query);
    const filter: any = {};

    if (query.search) {
      filter.$or = [
        { fullName: new RegExp(query.search, 'i') },
        { email: new RegExp(query.search, 'i') },
        { mobile: new RegExp(query.search, 'i') },
        { agencyName: new RegExp(query.search, 'i') },
      ];
    }

    if (query.role) filter.role = query.role;
    if (query.membershipType) filter.membershipType = query.membershipType;
    if (query.isVerified !== undefined) filter.isVerified = query.isVerified === 'true';
    if (query.isBlocked !== undefined) filter.isBlocked = query.isBlocked === 'true';
    // Account status (what the Status column shows) — distinct from `active` below,
    // which means "seen in the last 7 days".
    if (query.isActive !== undefined) filter.isActive = query.isActive === 'true';
    if (query.city) filter.city = new RegExp(query.city, 'i');
    // "Active" = same definition as the dashboard card: not blocked and seen in the last 7 days.
    if (query.active === 'true') {
      filter.isActive = true;
      filter.isBlocked = false;
      filter.lastActive = { $gte: new Date(Date.now() - 7 * 24 * 60 * 60 * 1000) };
    }

    const [users, total] = await Promise.all([
      this.userModel.find(filter).select('-password -refreshToken -fcmTokens').sort(sort).skip(skip).limit(limit).lean(),
      this.userModel.countDocuments(filter),
    ]);

    return { message: 'Users retrieved', data: buildPaginatedResult(users, total, page, limit) };
  }

  // Single user detail for the admin user page.
  async getUser(id: string) {
    if (!Types.ObjectId.isValid(id)) throw new NotFoundException('User not found');
    const user = await this.userModel
      .findById(id)
      .select('-password -refreshToken -fcmTokens')
      .lean();
    if (!user) throw new NotFoundException('User not found');
    return { message: 'User retrieved', data: user };
  }

  // Invitation leaderboard — all users ranked by how many they referred.
  /**
   * `period`: 'all' (default) | 'YYYY-MM' (a month) | 'YYYY' (a year).
   *
   * For a period we can't use the stored `referralCount` — it's a lifetime total
   * with no time dimension. Instead we count the referred users who SIGNED UP in
   * that window, which is what "invites in June 2026" actually means.
   */
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

  async getReferralLeaderboard(query: any) {
    const filter: any = { role: { $nin: [UserRole.ADMIN, UserRole.SUPER_ADMIN] } };
    const search = (query.search || '').trim();
    if (search) {
      const rx = new RegExp(search.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'i');
      filter.$or = [{ fullName: rx }, { mobile: rx }, { agencyName: rx }, { referralCode: rx }];
    }

    const range = this.periodRange(query.period);
    const select = 'fullName agencyName mobile city profileImage referralCode referralCount';

    // ── All time: the stored lifetime counter (also carries admin +/- tweaks) ──
    if (!range) {
      Object.assign(filter, dateRangeFilter(query));
      const users = await this.userModel
        .find(filter)
        .select(select)
        .sort({ referralCount: -1, createdAt: 1 })
        .limit(200)
        .lean();

      return {
        message: 'Referral leaderboard retrieved',
        data: users.map((u, i) => ({
          rank: i + 1,
          _id: u._id,
          name: u.fullName || u.agencyName || 'User',
          mobile: u.mobile ?? '',
          city: u.city ?? '',
          profileImage: u.profileImage ?? '',
          referralCode: u.referralCode ?? '',
          count: u.referralCount ?? 0,
        })),
      };
    }

    // ── A month or a year: count invitees by their signup date ────────────────
    const grouped = await this.userModel.aggregate([
      { $match: { referredBy: { $ne: null, $exists: true }, createdAt: { $gte: range.start, $lt: range.end } } },
      { $group: { _id: '$referredBy', count: { $sum: 1 } } },
      { $sort: { count: -1 } },
      { $limit: 200 },
    ]);

    if (grouped.length === 0) return { message: 'Referral leaderboard retrieved', data: [] };

    const counts = new Map<string, number>(grouped.map((g: any) => [String(g._id), g.count]));
    const referrers = await this.userModel
      .find({ ...filter, _id: { $in: grouped.map((g: any) => g._id) } })
      .select(select)
      .lean();

    const data = referrers
      .map((u: any) => ({
        _id: u._id,
        name: u.fullName || u.agencyName || 'User',
        mobile: u.mobile ?? '',
        city: u.city ?? '',
        profileImage: u.profileImage ?? '',
        referralCode: u.referralCode ?? '',
        count: counts.get(String(u._id)) ?? 0,
      }))
      .sort((a, b) => b.count - a.count)
      .map((u, i) => ({ rank: i + 1, ...u }));

    return { message: 'Referral leaderboard retrieved', data };
  }

  async updateUser(id: string, data: Partial<any>) {
    const user = await this.userModel.findByIdAndUpdate(id, data, { new: true }).select('-password -refreshToken');
    if (!user) throw new NotFoundException('User not found');
    return { message: 'User updated', data: user };
  }

  async verifyUser(id: string) {
    const user = await this.userModel.findByIdAndUpdate(id, { isVerified: true, isAdminApproved: true }, { new: true });
    if (!user) throw new NotFoundException('User not found');
    return { message: 'User verified', data: user };
  }

  async blockUser(id: string, reason?: string) {
    const user = await this.userModel.findByIdAndUpdate(id, { isBlocked: true }, { new: true });
    if (!user) throw new NotFoundException('User not found');
    return { message: 'User blocked' };
  }

  async unblockUser(id: string) {
    const user = await this.userModel.findByIdAndUpdate(id, { isBlocked: false }, { new: true });
    if (!user) throw new NotFoundException('User not found');
    return { message: 'User unblocked' };
  }

  // ─── Verification Requests ─────────────────────────────────────────────────
  async getVerificationRequests(query: any) {
    const { page, limit, skip, sort } = getPaginationParams(query);
    const filter: any = {};

    // Default to pending requests; allow ?status=all or a specific status.
    filter.verificationStatus = query.status && query.status !== 'all'
      ? query.status
      : (query.status === 'all' ? { $ne: VerificationStatus.NONE } : VerificationStatus.PENDING);

    if (query.search) {
      filter.$or = [
        { fullName: new RegExp(query.search, 'i') },
        { email: new RegExp(query.search, 'i') },
        { mobile: new RegExp(query.search, 'i') },
        { agencyName: new RegExp(query.search, 'i') },
      ];
    }
    if (query.role) filter.role = query.role;
    Object.assign(filter, dateRangeFilter(query, 'verificationSubmittedAt'));

    const [users, total] = await Promise.all([
      this.userModel
        .find(filter)
        .select('fullName email mobile agencyName role profileImage membershipType isVerified verificationStatus verificationSubmittedAt verificationRejectionReason documents city state createdAt')
        .sort({ verificationSubmittedAt: -1, ...sort })
        .skip(skip)
        .limit(limit)
        .lean(),
      this.userModel.countDocuments(filter),
    ]);

    return { message: 'Verification requests retrieved', data: buildPaginatedResult(users, total, page, limit) };
  }

  async getVerificationRequest(id: string) {
    const user = await this.userModel
      .findById(id)
      .select('fullName email mobile agencyName role profileImage membershipType isVerified isAdminApproved verificationStatus verificationSubmittedAt verificationRejectionReason documents city state createdAt')
      .lean();
    if (!user) throw new NotFoundException('User not found');
    return { message: 'Verification request retrieved', data: user };
  }

  async approveVerification(id: string) {
    const user = await this.userModel.findByIdAndUpdate(
      id,
      {
        isVerified: true,
        isAdminApproved: true,
        verificationStatus: VerificationStatus.VERIFIED,
        verificationRejectionReason: null,
      },
      { new: true },
    ).select('-password -refreshToken -fcmTokens');
    if (!user) throw new NotFoundException('User not found');
    return { message: 'Verification approved', data: user };
  }

  async rejectVerification(id: string, reason?: string) {
    const user = await this.userModel.findByIdAndUpdate(
      id,
      {
        isVerified: false,
        isAdminApproved: false,
        verificationStatus: VerificationStatus.REJECTED,
        verificationRejectionReason: reason || 'Documents could not be verified',
      },
      { new: true },
    ).select('-password -refreshToken -fcmTokens');
    if (!user) throw new NotFoundException('User not found');
    return { message: 'Verification rejected', data: user };
  }

  private readonly TIER_RANK: Record<string, number> = {
    new: 0, active: 1, verified: 2, premium: 3, golden: 4,
  };

  async upgradeMembership(
    id: string,
    membershipType: MembershipType,
    daysToAdd?: number,
    planId?: string,
  ) {
    const plan = planId
      ? await this.planModel.findById(planId).lean()
      : await this.planModel.findOne({ membershipType, isActive: true }).sort({ price: 1 }).lean();

    const currentUser = await this.userModel.findById(id).select('membershipType membershipExpiresAt').lean();
    if (!currentUser) throw new NotFoundException('User not found');

    const currentSub = await this.subscriptionModel
      .findOne({ userId: new Types.ObjectId(id), status: SubscriptionStatus.ACTIVE })
      .sort({ endDate: -1 })
      .lean();

    const currentTier = this.TIER_RANK[currentUser.membershipType ?? 'new'] ?? 0;
    const newTier = this.TIER_RANK[membershipType] ?? 0;
    const days = daysToAdd ?? plan?.durationDays ?? 30;
    const now = new Date();

    let startDate: Date;
    let expiresAt: Date;

    if (currentSub && currentSub.endDate > now) {
      if (newTier === currentTier) {
        // Same tier — extend from current end date
        startDate = new Date(currentSub.endDate);
        expiresAt = new Date(currentSub.endDate);
        expiresAt.setDate(expiresAt.getDate() + days);
      } else if (newTier > currentTier) {
        // Higher tier — carry remaining days into new plan
        const remainingDays = Math.ceil((currentSub.endDate.getTime() - now.getTime()) / (1000 * 60 * 60 * 24));
        startDate = now;
        expiresAt = new Date(now);
        expiresAt.setDate(expiresAt.getDate() + days + remainingDays);
      } else {
        // Lower tier — replace
        startDate = now;
        expiresAt = new Date(now);
        expiresAt.setDate(expiresAt.getDate() + days);
      }
      await this.subscriptionModel.findByIdAndUpdate(currentSub._id, { status: SubscriptionStatus.EXPIRED });
    } else {
      startDate = now;
      expiresAt = new Date(now);
      expiresAt.setDate(expiresAt.getDate() + days);
    }

    const user = await this.userModel.findByIdAndUpdate(id, {
      membershipType,
      isPremium: [MembershipType.PREMIUM, MembershipType.GOLDEN].includes(membershipType),
      isGolden: membershipType === MembershipType.GOLDEN,
      membershipExpiresAt: expiresAt,
    }, { new: true });

    if (!user) throw new NotFoundException('User not found');

    if (plan) {
      await this.subscriptionModel.create({
        userId: new Types.ObjectId(id),
        planId: plan._id,
        status: SubscriptionStatus.ACTIVE,
        startDate,
        endDate: expiresAt,
        amount: plan.discountedPrice > 0 && plan.discountedPrice < plan.price ? plan.discountedPrice : plan.price,
        membershipType: plan.membershipType,
      });
    }

    return { message: `Membership upgraded to ${membershipType}`, data: user };
  }

  // ─── Subscription Plan management ────────────────────────────────────────────
  async getPlans() {
    const plans = await this.planModel.find().sort({ sortOrder: 1, price: 1 }).lean();
    return { message: 'Plans retrieved', data: plans };
  }

  async createPlan(data: any) {
    const plan = await this.planModel.create({
      name: data.name,
      description: data.description ?? '',
      membershipType: data.membershipType,
      duration: data.duration,
      price: Math.round(Number(data.price) || 0),
      discountedPrice: Math.round(Number(data.discountedPrice) || 0),
      durationDays: Math.round(Number(data.durationDays) || 30),
      features: Array.isArray(data.features) ? data.features : [],
      isActive: data.isActive ?? true,
      isPopular: data.isPopular ?? false,
      sortOrder: Math.round(Number(data.sortOrder) || 0),
    });
    return { message: 'Plan created', data: plan };
  }

  async updatePlan(id: string, data: any) {
    const update: any = {};
    for (const k of ['name', 'description', 'membershipType', 'duration', 'features', 'isActive', 'isPopular']) {
      if (data[k] !== undefined) update[k] = data[k];
    }
    for (const k of ['price', 'discountedPrice', 'durationDays', 'sortOrder']) {
      if (data[k] !== undefined) update[k] = Math.round(Number(data[k]) || 0);
    }
    const plan = await this.planModel.findByIdAndUpdate(id, update, { new: true });
    if (!plan) throw new NotFoundException('Plan not found');
    return { message: 'Plan updated', data: plan };
  }

  async deletePlan(id: string) {
    const plan = await this.planModel.findByIdAndDelete(id);
    if (!plan) throw new NotFoundException('Plan not found');
    return { message: 'Plan deleted' };
  }

  async getRequirements(query: any) {
    const { page, limit, skip, sort } = getPaginationParams(query);
    const filter: any = { isDeleted: false };

    if (query.search) {
      const rx = new RegExp(query.search, 'i');
      filter.$or = [{ bookingId: rx }, { pickupCity: rx }, { dropCity: rx }, { pickupCityName: rx }, { dropCityName: rx }];
    }
    if (query.pickupCity) filter.pickupCity = new RegExp(query.pickupCity, 'i');
    if (query.status) filter.status = query.status;
    Object.assign(filter, dateRangeFilter(query));

    const [requirements, total] = await Promise.all([
      this.requirementModel
        .find(filter)
        .populate('postedBy', 'fullName agencyName mobile membershipType')
        .sort(sort).skip(skip).limit(limit).lean(),
      this.requirementModel.countDocuments(filter),
    ]);

    return { message: 'Requirements retrieved', data: buildPaginatedResult(requirements, total, page, limit) };
  }

  async getSubscriptions(query: any) {
    const { page, limit, skip, sort } = getPaginationParams(query);
    const filter: any = {};
    if (query.status) filter.status = query.status;
    Object.assign(filter, dateRangeFilter(query));

    // Search by the subscriber's name / mobile (resolve matching users first).
    if (query.search) {
      const rx = new RegExp(query.search, 'i');
      const matchedUsers = await this.userModel
        .find({ $or: [{ fullName: rx }, { mobile: rx }, { agencyName: rx }] })
        .select('_id')
        .lean();
      filter.userId = { $in: matchedUsers.map((u) => u._id) };
    }

    const [subscriptions, total] = await Promise.all([
      this.subscriptionModel
        .find(filter)
        .populate('userId', 'fullName mobile')
        .populate('planId', 'name membershipType')
        .sort(sort).skip(skip).limit(limit).lean(),
      this.subscriptionModel.countDocuments(filter),
    ]);

    return { message: 'Subscriptions retrieved', data: buildPaginatedResult(subscriptions, total, page, limit) };
  }

  async getVehicles(query: any) {
    const { page, limit, skip, sort } = getPaginationParams(query);
    const filter: any = { isDeleted: false };

    if (query.search) {
      filter.$or = [
        { listingId: new RegExp(query.search, 'i') },
        { currentCity: new RegExp(query.search, 'i') },
        { destinationCity: new RegExp(query.search, 'i') },
        { vehicleNumber: new RegExp(query.search, 'i') },
        { driverName: new RegExp(query.search, 'i') },
      ];
    }
    if (query.status) filter.status = query.status;
    Object.assign(filter, dateRangeFilter(query));

    const [vehicles, total] = await Promise.all([
      this.vehicleModel
        .find(filter)
        .populate('postedBy', 'fullName agencyName mobile membershipType')
        .sort(sort).skip(skip).limit(limit).lean(),
      this.vehicleModel.countDocuments(filter),
    ]);

    return { message: 'Vehicles retrieved', data: buildPaginatedResult(vehicles, total, page, limit) };
  }

  // ─── Admin edit/delete for requirements & vehicles (bypass ownership) ──────
  /**
   * Post a requirement on behalf of a user. Delegates to the app's own create so
   * the booking id, expiry and "new requirement" alerts all behave identically —
   * the only difference is who clicked the button.
   */
  async createRequirementFor(userId: string, dto: any) {
    const user = await this.userModel.findById(userId).select('_id');
    if (!user) throw new NotFoundException('User not found');
    return this.requirementsService.create(userId, dto);
  }

  /** Same, for an available-cab listing. */
  async createVehicleFor(userId: string, dto: any) {
    const user = await this.userModel.findById(userId).select('_id');
    if (!user) throw new NotFoundException('User not found');
    return this.availableVehiclesService.create(userId, dto);
  }

  async updateRequirement(id: string, data: Partial<any>) {
    const req = await this.requirementModel
      .findByIdAndUpdate(id, data, { new: true })
      .populate('postedBy', 'fullName agencyName mobile membershipType');
    if (!req) throw new NotFoundException('Requirement not found');
    return { message: 'Requirement updated', data: req };
  }

  async deleteRequirement(id: string) {
    const req = await this.requirementModel.findByIdAndUpdate(id, { isDeleted: true }, { new: true });
    if (!req) throw new NotFoundException('Requirement not found');
    await this.userModel.findByIdAndUpdate(req.postedBy, {
      $inc: { requirementsPosted: -1 },
    });
    return { message: 'Requirement deleted' };
  }

  async updateVehicle(id: string, data: Partial<any>) {
    const vehicle = await this.vehicleModel
      .findByIdAndUpdate(id, data, { new: true })
      .populate('postedBy', 'fullName agencyName mobile membershipType');
    if (!vehicle) throw new NotFoundException('Vehicle not found');
    return { message: 'Vehicle updated', data: vehicle };
  }

  async deleteVehicle(id: string) {
    const vehicle = await this.vehicleModel.findByIdAndUpdate(id, { isDeleted: true }, { new: true });
    if (!vehicle) throw new NotFoundException('Vehicle not found');
    await this.userModel.findByIdAndUpdate(vehicle.postedBy, {
      $inc: { vehiclesPosted: -1 },
    });
    return { message: 'Vehicle deleted' };
  }

  // Cities CRUD
  async createCity(data: Partial<any>) {
    const slug = data.name.toLowerCase().replace(/\s+/g, '-');
    const city = await this.cityModel.create({ ...data, slug });
    return { message: 'City created', data: city };
  }

  async getCities(query: any) {
    const { page, limit, skip } = getPaginationParams(query);
    const filter: any = {};
    if (query.search) filter.name = new RegExp(query.search, 'i');
    if (query.isActive !== undefined) filter.isActive = query.isActive === 'true';

    const [cities, total] = await Promise.all([
      this.cityModel.find(filter).sort({ sortOrder: 1, name: 1 }).skip(skip).limit(limit).lean(),
      this.cityModel.countDocuments(filter),
    ]);

    return { message: 'Cities retrieved', data: buildPaginatedResult(cities, total, page, limit) };
  }

  async updateCity(id: string, data: Partial<any>) {
    const city = await this.cityModel.findByIdAndUpdate(id, data, { new: true });
    if (!city) throw new NotFoundException('City not found');
    return { message: 'City updated', data: city };
  }

  /**
   * City-wise activity across the platform — where the demand (requirements),
   * supply (available cabs) and members (agencies/drivers) actually are. Built
   * live from the requirement / vehicle / user collections (not the manually
   * managed cities list), grouped by a normalized city key so "Rajkot" and
   * "rajkot " collapse together, then ranked by total activity.
   */
  async getCityInsights() {
    // Group requirements by their clean pickup city (fallback to the raw city).
    const cityKey = { $toLower: { $trim: { input: { $ifNull: ['$pickupCityName', '$pickupCity'] } } } };

    const [reqAgg, vehAgg, userAgg] = await Promise.all([
      this.requirementModel.aggregate([
        { $match: { isDeleted: { $ne: true } } },
        { $group: {
          _id: cityKey,
          city: { $first: { $ifNull: ['$pickupCityName', '$pickupCity'] } },
          state: { $first: '$pickupState' },
          count: { $sum: 1 },
        } },
      ]),
      this.vehicleModel.aggregate([
        { $match: { isDeleted: { $ne: true } } },
        { $group: {
          _id: { $toLower: { $trim: { input: '$currentCity' } } },
          city: { $first: '$currentCity' },
          state: { $first: '$currentState' },
          count: { $sum: 1 },
        } },
      ]),
      this.userModel.aggregate([
        { $match: { role: { $nin: ['admin', 'super_admin'] }, city: { $nin: [null, ''] } } },
        { $group: {
          _id: { $toLower: { $trim: { input: '$city' } } },
          city: { $first: '$city' },
          state: { $first: '$state' },
          count: { $sum: 1 },
        } },
      ]),
    ]);

    const map = new Map<string, { key: string; city: string; state: string; requirements: number; vehicles: number; users: number }>();
    const upsert = (k: string, city: string, state: string) => {
      if (!k) return null;
      if (!map.has(k)) map.set(k, { key: k, city: city || k, state: state || '', requirements: 0, vehicles: 0, users: 0 });
      const e = map.get(k)!;
      if (state && !e.state) e.state = state;
      if (city && (!e.city || e.city === k)) e.city = city;
      return e;
    };

    for (const r of reqAgg as any[]) { const e = upsert(r._id, r.city, r.state); if (e) e.requirements = r.count; }
    for (const v of vehAgg as any[]) { const e = upsert(v._id, v.city, v.state); if (e) e.vehicles = v.count; }
    for (const u of userAgg as any[]) { const e = upsert(u._id, u.city, u.state); if (e) e.users = u.count; }

    const rows = [...map.values()]
      .map((e) => ({ ...e, total: e.requirements + e.vehicles + e.users }))
      .filter((e) => e.total > 0)
      .sort((a, b) => b.total - a.total);

    const totals = rows.reduce(
      (acc, r) => ({
        cities: acc.cities + 1,
        requirements: acc.requirements + r.requirements,
        vehicles: acc.vehicles + r.vehicles,
        users: acc.users + r.users,
      }),
      { cities: 0, requirements: 0, vehicles: 0, users: 0 },
    );

    return { message: 'City insights retrieved', data: { rows, totals } };
  }

  async deleteCity(id: string) {
    await this.cityModel.findByIdAndDelete(id);
    return { message: 'City deleted' };
  }

  // Banners CRUD
  async createBanner(data: Partial<any>) {
    const banner = await this.bannerModel.create(data);
    return { message: 'Banner created', data: banner };
  }

  async getBanners(isActive?: boolean) {
    const filter: any = {};
    if (isActive !== undefined) filter.isActive = isActive;
    const banners = await this.bannerModel.find(filter).sort({ sortOrder: 1 }).lean();
    return { message: 'Banners retrieved', data: banners };
  }

  async updateBanner(id: string, data: Partial<any>) {
    const banner = await this.bannerModel.findByIdAndUpdate(id, data, { new: true });
    if (!banner) throw new NotFoundException('Banner not found');
    return { message: 'Banner updated', data: banner };
  }

  async deleteBanner(id: string) {
    await this.bannerModel.findByIdAndDelete(id);
    return { message: 'Banner deleted' };
  }

  // Reports
  async getReports(query: any) {
    const { page, limit, skip } = getPaginationParams(query);
    const filter: any = {};
    if (query.status) filter.status = query.status;
    if (query.search) {
      const rx = new RegExp(query.search, 'i');
      filter.$or = [{ reason: rx }, { description: rx }, { targetType: rx }];
    }
    Object.assign(filter, dateRangeFilter(query));

    const [reports, total] = await Promise.all([
      this.reportModel
        .find(filter)
        .populate('reportedBy', 'fullName email mobile agencyName city state membershipType profileImage')
        .sort({ createdAt: -1 }).skip(skip).limit(limit).lean(),
      this.reportModel.countDocuments(filter),
    ]);

    // Attach the reported user's details (targetId is polymorphic, so resolve manually).
    const userTargetIds = reports
      .filter((r: any) => r.targetType === 'user' && r.targetId)
      .map((r: any) => r.targetId);
    if (userTargetIds.length) {
      const targets = await this.userModel
        .find({ _id: { $in: userTargetIds } })
        .select('fullName email mobile agencyName city state membershipType profileImage')
        .lean();
      const map = Object.fromEntries(targets.map((t: any) => [t._id.toString(), t]));
      for (const r of reports as any[]) {
        if (r.targetType === 'user') r.target = map[r.targetId?.toString()] ?? null;
      }
    }

    return { message: 'Reports retrieved', data: buildPaginatedResult(reports, total, page, limit) };
  }

  async resolveReport(id: string, adminId: string, action: string, notes?: string) {
    const report = await this.reportModel.findByIdAndUpdate(id, {
      status: ReportStatus.RESOLVED,
      reviewedBy: new Types.ObjectId(adminId),
      reviewedAt: new Date(),
      actionTaken: action,
      adminNotes: notes,
    }, { new: true });

    if (!report) throw new NotFoundException('Report not found');
    return { message: 'Report resolved', data: report };
  }

  async sendAdminNotification(data: {
    title: string;
    body: string;
    imageUrl?: string;
    actionUrl?: string;
    type?: string;
    targetRoles?: string[];
    targetCities?: string[];
    targetMemberships?: string[];
  }) {
    return this.notificationsService.sendAdminNotification(data);
  }

  async getSentNotifications(page = 1, limit = 20) {
    return this.notificationsService.getSentNotifications(page, limit);
  }

  /**
   * Admin activity feed (the header bell): plan purchases, wallet top-ups and
   * withdrawal requests, newest first.
   *
   * Derived from the existing collections rather than stored as its own
   * notification records — the events already exist, so a separate table would
   * only be a second copy that can drift out of sync.
   */
  async getAdminActivity(limit = 20) {
    const perSource = Math.max(1, +limit);
    const name = (u: any) => u?.agencyName || u?.fullName || 'A user';

    const [plans, topUps, withdrawals] = await Promise.all([
      // Plan purchases — a Payment carrying a planId that actually went through.
      this.paymentModel
        .find({ status: 'success', planId: { $exists: true, $ne: null }, razorpayPaymentId: this._hasRazorpayId })
        .sort({ createdAt: -1 })
        .limit(perSource)
        .populate('userId', 'fullName agencyName mobile')
        .populate('planId', 'name')
        .lean(),
      // Wallet top-ups — amounts here are already in rupees.
      this.walletTxModel
        .find({ type: 'credit', status: 'success', razorpayPaymentId: this._hasRazorpayId })
        .sort({ createdAt: -1 })
        .limit(perSource)
        .populate('userId', 'fullName agencyName mobile')
        .lean(),
      this.withdrawalModel
        .find({})
        .sort({ createdAt: -1 })
        .limit(perSource)
        .populate('userId', 'fullName agencyName mobile')
        .lean(),
    ]);

    const items = [
      ...plans.map((p: any) => ({
        id: `plan_${p._id}`,
        type: 'plan',
        title: 'Plan purchased',
        // Payment amounts are stored in paise.
        message: `${name(p.userId)} bought ${p.planId?.name ?? 'a plan'} for ₹${Math.round((p.amount || 0) / 100).toLocaleString('en-IN')}`,
        amount: Math.round((p.amount || 0) / 100),
        href: '/payments',
        createdAt: p.createdAt,
      })),
      ...topUps.map((t: any) => ({
        id: `topup_${t._id}`,
        type: 'payment',
        title: 'Wallet top-up',
        message: `${name(t.userId)} added ₹${(t.amount || 0).toLocaleString('en-IN')} to their wallet`,
        amount: t.amount || 0,
        href: '/wallet',
        createdAt: t.createdAt,
      })),
      ...withdrawals.map((w: any) => ({
        id: `wd_${w._id}`,
        type: 'withdrawal',
        title: w.status === 'pending' ? 'Withdrawal request' : `Withdrawal ${w.status}`,
        message: `${name(w.userId)} requested ₹${(w.amount || 0).toLocaleString('en-IN')} via ${w.method === 'upi' ? 'UPI' : 'bank transfer'}`,
        amount: w.amount || 0,
        status: w.status,
        href: '/withdrawals',
        createdAt: w.createdAt,
      })),
    ]
      .sort((a: any, b: any) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime())
      .slice(0, perSource);

    // Drives the bell's badge — the work actually waiting on an admin.
    const pendingWithdrawals = await this.withdrawalModel.countDocuments({ status: 'pending' });

    return {
      message: 'Admin activity',
      data: { items, pendingWithdrawals },
    };
  }

  async getAnalytics(period: string) {
    const days = period === 'week' ? 7 : period === 'month' ? 30 : period === 'year' ? 365 : 30;
    const startDate = new Date(Date.now() - days * 24 * 60 * 60 * 1000);

    const [userGrowth, requirementGrowth, revenueData, topCities, membershipBreakdown] = await Promise.all([
      this.userModel.aggregate([
        { $match: { createdAt: { $gte: startDate } } },
        { $group: { _id: { $dateToString: { format: '%Y-%m-%d', date: '$createdAt' } }, count: { $sum: 1 } } },
        { $sort: { _id: 1 } },
      ]),
      this.requirementModel.aggregate([
        { $match: { createdAt: { $gte: startDate }, isDeleted: false } },
        { $group: { _id: { $dateToString: { format: '%Y-%m-%d', date: '$createdAt' } }, count: { $sum: 1 } } },
        { $sort: { _id: 1 } },
      ]),
      this.razorpayDailyRevenue(startDate),
      this.requirementModel.aggregate([
        { $match: { isDeleted: false } },
        { $group: { _id: '$pickupCity', count: { $sum: 1 } } },
        { $sort: { count: -1 } },
        { $limit: 10 },
      ]),
      this.userModel.aggregate([
        { $group: { _id: '$membershipType', count: { $sum: 1 } } },
      ]),
    ]);

    return {
      message: 'Analytics data',
      data: { userGrowth, requirementGrowth, revenueData, topCities, membershipBreakdown },
    };
  }

  // ── Revenue: only real Razorpay money counts ────────────────────────────────
  // A transaction is revenue only when it actually went through Razorpay (it has a
  // razorpayPaymentId): plan purchases + wallet top-ups. Admin wallet adjustments and
  // manual entries have no razorpayPaymentId, so they're excluded. Payment amounts are
  // stored in paise (÷100 → rupees); wallet amounts are already in rupees.
  private readonly _hasRazorpayId = { $exists: true, $nin: [null, ''] };

  private async razorpayRevenue(since?: Date): Promise<number> {
    const pMatch: any = { status: 'success', razorpayPaymentId: this._hasRazorpayId };
    const wMatch: any = { type: 'credit', status: 'success', razorpayPaymentId: this._hasRazorpayId };
    if (since) {
      pMatch.createdAt = { $gte: since };
      wMatch.createdAt = { $gte: since };
    }
    const [p, w] = await Promise.all([
      this.paymentModel.aggregate([{ $match: pMatch }, { $group: { _id: null, total: { $sum: '$amount' } } }]),
      this.walletTxModel.aggregate([{ $match: wMatch }, { $group: { _id: null, total: { $sum: '$amount' } } }]),
    ]);
    const planRupees = (p[0]?.total || 0) / 100; // paise → rupees
    const walletRupees = w[0]?.total || 0; // already rupees
    return Math.round(planRupees + walletRupees);
  }

  private async razorpayDailyRevenue(since: Date) {
    const dateKey = { $dateToString: { format: '%Y-%m-%d', date: '$createdAt' } };
    const [planDaily, walletDaily] = await Promise.all([
      this.paymentModel.aggregate([
        { $match: { status: 'success', razorpayPaymentId: this._hasRazorpayId, createdAt: { $gte: since } } },
        { $group: { _id: dateKey, paise: { $sum: '$amount' }, count: { $sum: 1 } } },
      ]),
      this.walletTxModel.aggregate([
        { $match: { type: 'credit', status: 'success', razorpayPaymentId: this._hasRazorpayId, createdAt: { $gte: since } } },
        { $group: { _id: dateKey, rupees: { $sum: '$amount' }, count: { $sum: 1 } } },
      ]),
    ]);
    const map = new Map<string, { revenue: number; count: number }>();
    for (const d of planDaily as any[]) map.set(d._id, { revenue: (d.paise || 0) / 100, count: d.count || 0 });
    for (const d of walletDaily as any[]) {
      const e = map.get(d._id) || { revenue: 0, count: 0 };
      e.revenue += d.rupees || 0;
      e.count += d.count || 0;
      map.set(d._id, e);
    }
    return [...map.entries()]
      .map(([_id, v]) => ({ _id, revenue: Math.round(v.revenue), count: v.count }))
      .sort((a, b) => a._id.localeCompare(b._id));
  }

  // Combined transaction history: subscription payments + wallet top-ups.
  async getUserRequirements(userId: string) {
    const requirements = await this.requirementModel
      .find({ postedBy: new Types.ObjectId(userId), isDeleted: false })
      .sort({ createdAt: -1 })
      .limit(100)
      .lean();
    return { message: 'User requirements retrieved', data: requirements };
  }

  async getUserVehicles(userId: string) {
    const vehicles = await this.vehicleModel
      .find({ postedBy: new Types.ObjectId(userId), isDeleted: false })
      .sort({ createdAt: -1 })
      .limit(100)
      .lean();
    return { message: 'User vehicles retrieved', data: vehicles };
  }

  async getUserPayments(userId: string) {
    // Subscription/plan payments
    const payments = await this.paymentModel
      .find({ userId: new Types.ObjectId(userId) })
      .populate('planId', 'name membershipType')
      .sort({ createdAt: -1 })
      .limit(100)
      .lean();

    // Wallet top-ups, admin adjustments, and both sides of a transfer — a transfer
    // credit is not a top-up, so it must not be labelled as one.
    const walletTxns = await this.walletTxModel
      .find({
        userId: new Types.ObjectId(userId),
        status: 'success',
        $or: [{ type: 'credit' }, { type: 'debit', source: 'transfer' }],
      })
      .populate('counterpartyId', 'fullName agencyName mobile')
      .sort({ createdAt: -1 })
      .limit(100)
      .lean();

    // Normalize both into the same shape
    const unified = [
      ...payments.map((p: any) => ({
        _id: p._id,
        orderId: p.orderId,
        userId: p.userId,
        planId: p.planId,
        amount: p.amount,
        method: p.method || 'razorpay',
        status: p.status,
        createdAt: p.createdAt,
      })),
      ...walletTxns.map((w: any) => {
        const isTransfer = w.source === 'transfer';
        // Name the other party, so a transfer says who the money went to / came from.
        const other = w.counterpartyId?.mobile ?? '';
        const label = isTransfer
          ? `Transfer ${w.type === 'debit' ? 'to' : 'from'}: ${other || 'user'}`
          : w.source === 'admin'
            ? 'Wallet Adjustment'
            : 'Wallet Top-up';

        return {
          _id: w._id,
          orderId: w.razorpayOrderId || `WALLET-${w._id.toString().slice(-8).toUpperCase()}`,
          userId: w.userId,
          planId: { name: label, membershipType: 'wallet' },
          amount: (w.amount || 0) * 100,
          method: isTransfer ? 'transfer' : w.source === 'admin' ? 'admin' : 'razorpay',
          status: w.status,
          createdAt: w.createdAt,
        };
      }),
    ];

    // Sort by date descending
    unified.sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());

    return { message: 'User payments retrieved', data: unified };
  }

  async getUserWithdrawals(userId: string) {
    const withdrawals = await this.withdrawalModel
      .find({ userId: new Types.ObjectId(userId) })
      .sort({ createdAt: -1 })
      .limit(100)
      .lean();
    return { message: 'User withdrawals retrieved', data: withdrawals };
  }

  async getUserReviews(userId: string) {
    // Match by string form so it works whether ratedUser was stored as an ObjectId
    // or a plain string (legacy/seeded data).
    const reviews = await this.ratingModel
      .find({ $expr: { $eq: [{ $toString: '$ratedUser' }, userId] } })
      .populate('rater', 'fullName profileImage')
      .sort({ createdAt: -1 })
      .limit(100)
      .lean();
    return { message: 'User reviews retrieved', data: reviews };
  }

  async updateReview(id: string, data: { stars?: number; review?: string }) {
    const rating = await this.ratingModel.findByIdAndUpdate(id, data, { new: true }).populate('rater', 'fullName profileImage');
    if (!rating) throw new NotFoundException('Review not found');
    // Recompute rated user's average
    const agg = await this.ratingModel.aggregate([
      { $match: { ratedUser: rating.ratedUser } },
      { $group: { _id: null, avg: { $avg: '$stars' }, count: { $sum: 1 } } },
    ]);
    if (agg[0]) {
      await this.userModel.findByIdAndUpdate(rating.ratedUser, {
        rating: Math.round(agg[0].avg * 10) / 10,
        totalRatings: agg[0].count,
      });
    }
    return { message: 'Review updated', data: rating };
  }

  async deleteReview(id: string) {
    const rating = await this.ratingModel.findByIdAndDelete(id);
    if (!rating) throw new NotFoundException('Review not found');
    // Recompute rated user's average
    const agg = await this.ratingModel.aggregate([
      { $match: { ratedUser: rating.ratedUser } },
      { $group: { _id: null, avg: { $avg: '$stars' }, count: { $sum: 1 } } },
    ]);
    await this.userModel.findByIdAndUpdate(rating.ratedUser, {
      rating: agg[0] ? Math.round(agg[0].avg * 10) / 10 : 0,
      totalRatings: agg[0]?.count ?? 0,
    });
    return { message: 'Review deleted' };
  }

  async getUserSubscriptions(userId: string) {
    const subscriptions = await this.subscriptionModel
      .find({ userId: new Types.ObjectId(userId) })
      .populate('planId', 'name membershipType duration durationDays')
      .sort({ createdAt: -1 })
      .limit(50)
      .lean();
    return { message: 'User subscriptions retrieved', data: subscriptions };
  }

  async cancelSubscription(subscriptionId: string) {
    const sub = await this.subscriptionModel.findByIdAndUpdate(
      subscriptionId,
      { status: SubscriptionStatus.CANCELLED },
      { new: true },
    );
    if (!sub) throw new NotFoundException('Subscription not found');
    // If this was the active subscription, downgrade user to basic 'active' membership
    const hasActive = await this.subscriptionModel.exists({
      userId: sub.userId,
      status: SubscriptionStatus.ACTIVE,
    });
    if (!hasActive) {
      await this.userModel.findByIdAndUpdate(sub.userId, {
        membershipType: MembershipType.ACTIVE,
        isPremium: false,
        isGolden: false,
        membershipExpiresAt: null,
      });
    }
    return { message: 'Subscription cancelled', data: sub };
  }

  async updateSubscriptionEndDate(subscriptionId: string, endDate: string) {
    const sub = await this.subscriptionModel.findByIdAndUpdate(
      subscriptionId,
      { endDate: new Date(endDate) },
      { new: true },
    );
    if (!sub) throw new NotFoundException('Subscription not found');
    // Sync membershipExpiresAt on user if this is the active subscription
    if (sub.status === SubscriptionStatus.ACTIVE) {
      await this.userModel.findByIdAndUpdate(sub.userId, { membershipExpiresAt: new Date(endDate) });
    }
    return { message: 'Subscription end date updated', data: sub };
  }

  async updateUserReferralCount(userId: string, delta: number) {
    if (!Types.ObjectId.isValid(userId)) throw new NotFoundException('User not found');
    const user = await this.userModel.findByIdAndUpdate(
      userId,
      { $inc: { referralCount: delta } },
      { new: true },
    ).select('fullName referralCount');
    if (!user) throw new NotFoundException('User not found');
    return { message: `Referral count updated by ${delta}`, data: user };
  }

  async getPayments(query: any) {
    const { page, limit } = getPaginationParams(query);
    const search = (query.search || '').trim();
    const rx = search ? new RegExp(search.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'i') : null;

    const dateFilter = dateRangeFilter(query);
    const paymentFilter: any = { ...dateFilter };
    if (query.status) paymentFilter.status = query.status;
    if (rx) paymentFilter.$or = [{ orderId: rx }, { razorpayPaymentId: rx }];

    // Subscription/plan payments.
    const payments = await this.paymentModel
      .find(paymentFilter)
      .populate('userId', 'fullName email mobile')
      .populate('planId', 'name membershipType')
      .sort({ createdAt: -1 })
      .lean();

    // Wallet money: top-ups, admin adjustments, and BOTH sides of a transfer (the
    // sender's debit and the recipient's credit) so a transfer is never mistaken
    // for a top-up. Only included when the status filter allows a wallet credit.
    const includeWallet = !query.status || ['success', 'paid'].includes(query.status);
    const walletFilter: any = {
      status: 'success',
      $or: [{ type: 'credit' }, { type: 'debit', source: 'transfer' }],
      ...dateFilter,
    };
    if (rx) walletFilter.razorpayOrderId = rx;
    const walletTxns = includeWallet
      ? await this.walletTxModel
          .find(walletFilter)
          .populate('userId', 'fullName email mobile')
          .populate('counterpartyId', 'fullName agencyName mobile')
          .sort({ createdAt: -1 })
          .lean()
      : [];

    // Normalize both into the payments-table shape. Wallet amounts are in rupees,
    // Payment amounts are in paise (the UI divides by 100), so scale wallet ×100.
    const unified = [
      ...payments.map((p: any) => ({
        _id: p._id,
        orderId: p.orderId,
        userId: p.userId,
        planId: p.planId,
        amount: p.amount,
        method: p.method || 'razorpay',
        status: p.status,
        createdAt: p.createdAt,
      })),
      ...walletTxns.map((w: any) => {
        const isTransfer = w.source === 'transfer';
        // Name the other party, so a transfer says who the money went to / came from.
        const other = w.counterpartyId?.mobile ?? '';
        const label = isTransfer
          ? `Transfer ${w.type === 'debit' ? 'to' : 'from'}: ${other || 'user'}`
          : w.source === 'admin'
            ? 'Wallet Adjustment'
            : 'Wallet Top-up';

        return {
          _id: w._id,
          orderId: w.razorpayOrderId || `WALLET-${w._id.toString().slice(-8).toUpperCase()}`,
          userId: w.userId,
          planId: { name: label, membershipType: 'wallet' },
          amount: (w.amount || 0) * 100,
          method: isTransfer ? 'transfer' : w.source === 'admin' ? 'admin' : 'razorpay',
          status: w.status,
          createdAt: w.createdAt,
        };
      }),
    ].sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());

    const total = unified.length;
    const start = (page - 1) * limit;
    const paged = unified.slice(start, start + limit);

    return { message: 'Payments retrieved', data: buildPaginatedResult(paged, total, page, limit) };
  }
}
