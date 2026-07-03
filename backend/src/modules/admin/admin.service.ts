import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { User, UserDocument } from '../../database/schemas/user.schema';
import { Requirement, RequirementDocument } from '../../database/schemas/requirement.schema';
import { AvailableVehicle, AvailableVehicleDocument } from '../../database/schemas/available-vehicle.schema';
import { Payment, PaymentDocument } from '../../database/schemas/payment.schema';
import { WalletTransaction, WalletTransactionDocument } from '../../database/schemas/wallet-transaction.schema';
import { Subscription, SubscriptionDocument, SubscriptionPlan, SubscriptionPlanDocument, SubscriptionStatus } from '../../database/schemas/subscription.schema';
import { Report, ReportDocument, ReportStatus } from '../../database/schemas/report.schema';
import { Banner, BannerDocument } from '../../database/schemas/banner.schema';
import { City, CityDocument } from '../../database/schemas/city.schema';
import { AuditLog, AuditLogDocument } from '../../database/schemas/audit-log.schema';
import { NotificationsService } from '../notifications/notifications.service';
import { MembershipType, UserRole, VerificationStatus } from '../../common/enums/user-role.enum';
import { BookingStatus } from '../../common/enums/vehicle-type.enum';
import { getPaginationParams, buildPaginatedResult } from '../../common/utils/pagination.util';

@Injectable()
export class AdminService {
  constructor(
    @InjectModel(User.name) private userModel: Model<UserDocument>,
    @InjectModel(Requirement.name) private requirementModel: Model<RequirementDocument>,
    @InjectModel(AvailableVehicle.name) private vehicleModel: Model<AvailableVehicleDocument>,
    @InjectModel(Payment.name) private paymentModel: Model<PaymentDocument>,
    @InjectModel(WalletTransaction.name) private walletTxModel: Model<WalletTransactionDocument>,
    @InjectModel(Subscription.name) private subscriptionModel: Model<SubscriptionDocument>,
    @InjectModel(SubscriptionPlan.name) private planModel: Model<SubscriptionPlanDocument>,
    @InjectModel(Report.name) private reportModel: Model<ReportDocument>,
    @InjectModel(Banner.name) private bannerModel: Model<BannerDocument>,
    @InjectModel(City.name) private cityModel: Model<CityDocument>,
    @InjectModel(AuditLog.name) private auditLogModel: Model<AuditLogDocument>,
    private notificationsService: NotificationsService,
  ) {}

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
      this.paymentModel.aggregate([{ $match: { status: 'success' } }, { $group: { _id: null, total: { $sum: '$amount' } } }]),
      this.paymentModel.aggregate([
        { $match: { status: 'success', createdAt: { $gte: monthStart } } },
        { $group: { _id: null, total: { $sum: '$amount' } } },
      ]),
      this.reportModel.countDocuments({ status: ReportStatus.PENDING }),
      this.notificationsService ? 0 : 0,
      this.userModel.countDocuments({ createdAt: { $gte: todayStart } }),
      this.requirementModel.countDocuments({ createdAt: { $gte: todayStart } }),
    ]);

    return {
      message: 'Dashboard stats',
      data: {
        users: { total: totalUsers, active: activeUsers, verified: verifiedUsers, premium: premiumUsers, golden: goldenUsers },
        requirements: { total: totalRequirements, active: activeRequirements, today: todayRequirements },
        vehicles: { total: totalVehicles, active: activeVehicles },
        revenue: {
          total: totalRevenue[0]?.total || 0,
          monthly: monthlyRevenue[0]?.total || 0,
        },
        reports: { pending: pendingReports },
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
    if (query.city) filter.city = new RegExp(query.city, 'i');

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
  async getReferralLeaderboard(query: any) {
    const filter: any = { role: { $nin: [UserRole.ADMIN, UserRole.SUPER_ADMIN] } };
    const search = (query.search || '').trim();
    if (search) {
      const rx = new RegExp(search.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'i');
      filter.$or = [{ fullName: rx }, { mobile: rx }, { agencyName: rx }, { referralCode: rx }];
    }

    const users = await this.userModel
      .find(filter)
      .select('fullName agencyName mobile city profileImage referralCode referralCount')
      .sort({ referralCount: -1, createdAt: 1 })
      .limit(200)
      .lean();

    const data = users.map((u, i) => ({
      rank: i + 1,
      _id: u._id,
      name: u.fullName || u.agencyName || 'User',
      mobile: u.mobile ?? '',
      city: u.city ?? '',
      profileImage: u.profileImage ?? '',
      referralCode: u.referralCode ?? '',
      count: u.referralCount ?? 0,
    }));

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

  async upgradeMembership(id: string, membershipType: MembershipType, daysToAdd?: number) {
    // Prefer the plan's own duration; fall back to the passed value or 30 days.
    const plan = await this.planModel
      .findOne({ membershipType, isActive: true })
      .sort({ price: 1 })
      .lean();

    const days = daysToAdd ?? plan?.durationDays ?? 30;
    const startDate = new Date();
    const expiresAt = new Date(startDate);
    expiresAt.setDate(expiresAt.getDate() + days);

    const user = await this.userModel.findByIdAndUpdate(id, {
      membershipType,
      isPremium: [MembershipType.PREMIUM, MembershipType.GOLDEN].includes(membershipType),
      isGolden: membershipType === MembershipType.GOLDEN,
      membershipExpiresAt: expiresAt,
    }, { new: true });

    if (!user) throw new NotFoundException('User not found');

    // Mark previous active subscriptions as expired, then record this admin-granted
    // membership as an active subscription so it shows in the Memberships list.
    await this.subscriptionModel.updateMany(
      { userId: new Types.ObjectId(id), status: SubscriptionStatus.ACTIVE },
      { status: SubscriptionStatus.EXPIRED },
    );

    if (plan) {
      await this.subscriptionModel.create({
        userId: new Types.ObjectId(id),
        planId: plan._id,
        status: SubscriptionStatus.ACTIVE,
        startDate,
        endDate: expiresAt,
        amount: plan.discountedPrice > 0 && plan.discountedPrice < plan.price ? plan.discountedPrice : plan.price,
        membershipType,
      });
    }

    return { message: `Membership upgraded to ${membershipType}`, data: user };
  }

  async getRequirements(query: any) {
    const { page, limit, skip, sort } = getPaginationParams(query);
    const filter: any = { isDeleted: false };

    if (query.search) filter.bookingId = new RegExp(query.search, 'i');
    if (query.pickupCity) filter.pickupCity = new RegExp(query.pickupCity, 'i');
    if (query.status) filter.status = query.status;

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

  async sendAdminNotification(data: { title: string; body: string; targetType: string; targetCities?: string[]; targetMemberships?: string[] }) {
    return this.notificationsService.sendGlobalNotification(data.title, data.body);
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
      this.paymentModel.aggregate([
        { $match: { status: 'success', createdAt: { $gte: startDate } } },
        { $group: { _id: { $dateToString: { format: '%Y-%m-%d', date: '$createdAt' } }, revenue: { $sum: '$amount' }, count: { $sum: 1 } } },
        { $sort: { _id: 1 } },
      ]),
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

  // Combined transaction history: subscription payments + wallet top-ups.
  async getPayments(query: any) {
    const { page, limit } = getPaginationParams(query);
    const search = (query.search || '').trim();
    const rx = search ? new RegExp(search.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'i') : null;

    const paymentFilter: any = {};
    if (query.status) paymentFilter.status = query.status;
    if (rx) paymentFilter.$or = [{ orderId: rx }, { razorpayPaymentId: rx }];

    // Subscription/plan payments.
    const payments = await this.paymentModel
      .find(paymentFilter)
      .populate('userId', 'fullName email mobile')
      .populate('planId', 'name membershipType')
      .sort({ createdAt: -1 })
      .lean();

    // Wallet top-ups (money the user added). Only include when the status filter
    // isn't set to something a wallet credit can't be.
    const includeWallet = !query.status || ['success', 'paid'].includes(query.status);
    const walletFilter: any = { type: 'credit', status: 'success' };
    if (rx) walletFilter.razorpayOrderId = rx;
    const walletTxns = includeWallet
      ? await this.walletTxModel
          .find(walletFilter)
          .populate('userId', 'fullName email mobile')
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
      ...walletTxns.map((w: any) => ({
        _id: w._id,
        orderId: w.razorpayOrderId || `WALLET-${w._id.toString().slice(-8).toUpperCase()}`,
        userId: w.userId,
        planId: { name: w.source === 'admin' ? 'Wallet Adjustment' : 'Wallet Top-up', membershipType: 'wallet' },
        amount: (w.amount || 0) * 100,
        method: w.source === 'admin' ? 'admin' : 'razorpay',
        status: w.status,
        createdAt: w.createdAt,
      })),
    ].sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());

    const total = unified.length;
    const start = (page - 1) * limit;
    const paged = unified.slice(start, start + limit);

    return { message: 'Payments retrieved', data: buildPaginatedResult(paged, total, page, limit) };
  }
}
