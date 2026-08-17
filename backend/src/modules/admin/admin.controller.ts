import {
  Controller, Get, Post, Put, Delete, Body, Param, Query, UseGuards,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { AdminService } from './admin.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { BlockImpersonationGuard } from '../../common/guards/block-impersonation.guard';
import { UserRole } from '../../common/enums/user-role.enum';
import { MembershipType } from '../../common/enums/user-role.enum';

// Class default: admin-only. Endpoints a franchise may use are individually marked
// with @Roles(...FRANCHISE_ROLES) — method-level @Roles fully overrides the class
// one (RolesGuard uses getAllAndOverride). Each such endpoint receives the caller's
// `franchiseCity` from the JWT (undefined for admins → no scoping) and passes it to
// the service, which restricts every query to that city.
const FRANCHISE_ROLES = [UserRole.ADMIN, UserRole.SUPER_ADMIN, UserRole.FRANCHISE];

@ApiTags('Admin')
@ApiBearerAuth('access-token')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.ADMIN, UserRole.SUPER_ADMIN)
@Controller('admin')
export class AdminController {
  constructor(private readonly adminService: AdminService) {}

  // ─── Dashboard ─────────────────────────────────────────────────────────────
  @Get('dashboard')
  @Roles(...FRANCHISE_ROLES)
  @ApiOperation({ summary: 'Get dashboard statistics' })
  getDashboard(@Query() query: any, @CurrentUser('franchiseCity') city?: string) {
    return this.adminService.getDashboardStats(query, city);
  }

  @Get('analytics')
  @Roles(...FRANCHISE_ROLES)
  @ApiOperation({ summary: 'Get analytics data' })
  getAnalytics(@Query() query: any, @CurrentUser('franchiseCity') city?: string) {
    return this.adminService.getAnalytics(query, city);
  }

  // ─── Users ─────────────────────────────────────────────────────────────────
  @Get('users')
  @Roles(...FRANCHISE_ROLES)
  @ApiOperation({ summary: 'Get all users' })
  getUsers(@Query() query: any, @CurrentUser('franchiseCity') city?: string) {
    return this.adminService.getUsers(query, city);
  }

  @Get('referral-leaderboard')
  @Roles(...FRANCHISE_ROLES)
  @ApiOperation({ summary: 'Invitation leaderboard (users ranked by referrals)' })
  getReferralLeaderboard(@Query() query: any, @CurrentUser('franchiseCity') city?: string) {
    return this.adminService.getReferralLeaderboard(query, city);
  }

  @Get('users/:id')
  @Roles(...FRANCHISE_ROLES)
  @ApiOperation({ summary: 'Get a single user' })
  getUser(@Param('id') id: string, @CurrentUser('franchiseCity') city?: string) {
    return this.adminService.getUser(id, city);
  }

  @Put('users/:id')
  @Roles(...FRANCHISE_ROLES)
  @ApiOperation({ summary: 'Update user' })
  updateUser(@Param('id') id: string, @Body() data: any, @CurrentUser('franchiseCity') city?: string) {
    return this.adminService.updateUser(id, data, city);
  }

  @Post('users/:id/verify')
  @Roles(...FRANCHISE_ROLES)
  @ApiOperation({ summary: 'Verify user account' })
  verifyUser(@Param('id') id: string, @CurrentUser('franchiseCity') city?: string) {
    return this.adminService.verifyUser(id, city);
  }

  @Post('users/:id/block')
  @Roles(...FRANCHISE_ROLES)
  @ApiOperation({ summary: 'Block user' })
  blockUser(@Param('id') id: string, @Body('reason') reason: string, @CurrentUser('franchiseCity') city?: string) {
    return this.adminService.blockUser(id, reason, city);
  }

  @Post('users/:id/unblock')
  @Roles(...FRANCHISE_ROLES)
  @ApiOperation({ summary: 'Unblock user' })
  unblockUser(@Param('id') id: string, @CurrentUser('franchiseCity') city?: string) {
    return this.adminService.unblockUser(id, city);
  }

  @Post('users/:id/upgrade-membership')
  // Admin only — a franchise can view subscriptions but not change membership.
  @ApiOperation({ summary: 'Upgrade user membership' })
  upgradeMembership(
    @Param('id') id: string,
    @Body('membershipType') membershipType: MembershipType,
    @Body('daysToAdd') daysToAdd: number,
    @Body('planId') planId: string,
    @CurrentUser('franchiseCity') city?: string,
  ) {
    return this.adminService.upgradeMembership(id, membershipType, daysToAdd, planId, city);
  }

  @Get('users/:id/requirements')
  @Roles(...FRANCHISE_ROLES)
  @ApiOperation({ summary: 'Get requirements posted by a user' })
  getUserRequirements(@Param('id') id: string, @CurrentUser('franchiseCity') city?: string) {
    return this.adminService.getUserRequirements(id, city);
  }

  @Get('users/:id/vehicles')
  @Roles(...FRANCHISE_ROLES)
  @ApiOperation({ summary: 'Get vehicles posted by a user' })
  getUserVehicles(@Param('id') id: string, @CurrentUser('franchiseCity') city?: string) {
    return this.adminService.getUserVehicles(id, city);
  }

  @Get('users/:id/payments')
  @Roles(...FRANCHISE_ROLES)
  @ApiOperation({ summary: 'Get payments made by a user' })
  getUserPayments(@Param('id') id: string, @CurrentUser('franchiseCity') city?: string) {
    return this.adminService.getUserPayments(id, city);
  }

  @Get('users/:id/withdrawals')
  @Roles(...FRANCHISE_ROLES)
  @ApiOperation({ summary: 'Get withdrawal requests by a user' })
  getUserWithdrawals(@Param('id') id: string, @CurrentUser('franchiseCity') city?: string) {
    return this.adminService.getUserWithdrawals(id, city);
  }

  @Get('users/:id/reviews')
  @Roles(...FRANCHISE_ROLES)
  @ApiOperation({ summary: 'Get reviews received by a user' })
  getUserReviews(@Param('id') id: string, @CurrentUser('franchiseCity') city?: string) {
    return this.adminService.getUserReviews(id, city);
  }

  @Put('reviews/:id')
  @Roles(...FRANCHISE_ROLES)
  @ApiOperation({ summary: 'Edit a review' })
  updateReview(@Param('id') id: string, @Body() data: { stars?: number; review?: string }, @CurrentUser('franchiseCity') city?: string) {
    return this.adminService.updateReview(id, data, city);
  }

  @Delete('reviews/:id')
  @Roles(...FRANCHISE_ROLES)
  @ApiOperation({ summary: 'Delete a review' })
  deleteReview(@Param('id') id: string, @CurrentUser('franchiseCity') city?: string) {
    return this.adminService.deleteReview(id, city);
  }

  @Get('users/:id/subscriptions')
  @Roles(...FRANCHISE_ROLES)
  @ApiOperation({ summary: 'Get subscriptions of a user' })
  getUserSubscriptions(@Param('id') id: string, @CurrentUser('franchiseCity') city?: string) {
    return this.adminService.getUserSubscriptions(id, city);
  }

  @Post('subscriptions/:id/cancel')
  // Admin only — franchises view subscriptions but cannot cancel them.
  @ApiOperation({ summary: 'Cancel a subscription' })
  cancelSubscription(@Param('id') id: string, @CurrentUser('franchiseCity') city?: string) {
    return this.adminService.cancelSubscription(id, city);
  }

  @Put('subscriptions/:id/end-date')
  // Admin only — franchises view subscriptions but cannot change the end date.
  @ApiOperation({ summary: 'Update subscription end date' })
  updateSubscriptionEndDate(@Param('id') id: string, @Body('endDate') endDate: string, @CurrentUser('franchiseCity') city?: string) {
    return this.adminService.updateSubscriptionEndDate(id, endDate, city);
  }

  // ─── Verification Requests ─────────────────────────────────────────────────
  @Get('verification-requests')
  @Roles(...FRANCHISE_ROLES)
  @ApiOperation({ summary: 'List KYC verification requests' })
  getVerificationRequests(@Query() query: any, @CurrentUser('franchiseCity') city?: string) {
    return this.adminService.getVerificationRequests(query, city);
  }

  @Get('verification-requests/:id')
  @Roles(...FRANCHISE_ROLES)
  @ApiOperation({ summary: 'Get a single verification request with documents' })
  getVerificationRequest(@Param('id') id: string, @CurrentUser('franchiseCity') city?: string) {
    return this.adminService.getVerificationRequest(id, city);
  }

  @Post('verification-requests/:id/approve')
  @Roles(...FRANCHISE_ROLES)
  @ApiOperation({ summary: 'Approve a verification request' })
  approveVerification(@Param('id') id: string, @CurrentUser('franchiseCity') city?: string) {
    return this.adminService.approveVerification(id, city);
  }

  @Post('verification-requests/:id/reject')
  @Roles(...FRANCHISE_ROLES)
  @ApiOperation({ summary: 'Reject a verification request' })
  rejectVerification(@Param('id') id: string, @Body('reason') reason: string, @CurrentUser('franchiseCity') city?: string) {
    return this.adminService.rejectVerification(id, reason, city);
  }

  @Post('users/:id/documents')
  @Roles(...FRANCHISE_ROLES)
  @ApiOperation({ summary: "Upload KYC documents on a user's behalf and send for verification" })
  submitDocumentsFor(@Param('id') id: string, @Body() documents: Record<string, any>, @CurrentUser('franchiseCity') city?: string) {
    return this.adminService.submitDocumentsFor(id, documents, city);
  }

  @Post('verification-requests/:id/documents/:doc')
  @Roles(...FRANCHISE_ROLES)
  @ApiOperation({ summary: 'Approve or reject a single KYC document' })
  reviewDocument(
    @Param('id') id: string,
    @Param('doc') doc: string,
    @Body('status') status: 'approved' | 'rejected',
    @Body('reason') reason?: string,
    @CurrentUser('franchiseCity') city?: string,
  ) {
    return this.adminService.reviewDocument(id, doc, status, reason, city);
  }

  // ─── Requirements ──────────────────────────────────────────────────────────
  @Get('requirements')
  @Roles(...FRANCHISE_ROLES)
  @ApiOperation({ summary: 'Get all requirements' })
  getRequirements(@Query() query: any, @CurrentUser('franchiseCity') city?: string) {
    return this.adminService.getRequirements(query, city);
  }

  @Post('users/:id/requirements')
  @Roles(...FRANCHISE_ROLES)
  @ApiOperation({ summary: 'Post a requirement on behalf of a user' })
  createRequirementFor(@Param('id') userId: string, @Body() data: any, @CurrentUser('franchiseCity') city?: string) {
    return this.adminService.createRequirementFor(userId, data, city);
  }

  @Post('users/:id/vehicles')
  @Roles(...FRANCHISE_ROLES)
  @ApiOperation({ summary: 'Post an available cab on behalf of a user' })
  createVehicleFor(@Param('id') userId: string, @Body() data: any, @CurrentUser('franchiseCity') city?: string) {
    return this.adminService.createVehicleFor(userId, data, city);
  }

  @Put('requirements/:id')
  @Roles(...FRANCHISE_ROLES)
  @ApiOperation({ summary: 'Edit a requirement' })
  updateRequirement(@Param('id') id: string, @Body() data: any, @CurrentUser('franchiseCity') city?: string) {
    return this.adminService.updateRequirement(id, data, city);
  }

  @Delete('requirements/:id')
  @Roles(...FRANCHISE_ROLES)
  @ApiOperation({ summary: 'Delete a requirement' })
  deleteRequirement(@Param('id') id: string, @CurrentUser('franchiseCity') city?: string) {
    return this.adminService.deleteRequirement(id, city);
  }

  // ─── Subscriptions ─────────────────────────────────────────────────────────
  @Get('subscriptions')
  @Roles(...FRANCHISE_ROLES)
  @ApiOperation({ summary: 'Get all subscriptions' })
  getSubscriptions(@Query() query: any, @CurrentUser('franchiseCity') city?: string) {
    return this.adminService.getSubscriptions(query, city);
  }

  // ─── Subscription Plans (admin only — platform config) ───────────────────────
  @Get('subscription-plans')
  @ApiOperation({ summary: 'List all subscription plans (incl. inactive)' })
  getPlans() {
    return this.adminService.getPlans();
  }

  @Post('subscription-plans')
  @ApiOperation({ summary: 'Create a subscription plan' })
  createPlan(@Body() data: any) {
    return this.adminService.createPlan(data);
  }

  @Put('subscription-plans/:id')
  @ApiOperation({ summary: 'Update a subscription plan' })
  updatePlan(@Param('id') id: string, @Body() data: any) {
    return this.adminService.updatePlan(id, data);
  }

  @Delete('subscription-plans/:id')
  @ApiOperation({ summary: 'Delete a subscription plan' })
  deletePlan(@Param('id') id: string) {
    return this.adminService.deletePlan(id);
  }

  // ─── Vehicles ──────────────────────────────────────────────────────────────
  @Get('vehicles')
  @Roles(...FRANCHISE_ROLES)
  @ApiOperation({ summary: 'Get all available vehicles' })
  getVehicles(@Query() query: any, @CurrentUser('franchiseCity') city?: string) {
    return this.adminService.getVehicles(query, city);
  }

  @Put('vehicles/:id')
  @Roles(...FRANCHISE_ROLES)
  @ApiOperation({ summary: 'Edit an available vehicle' })
  updateVehicle(@Param('id') id: string, @Body() data: any, @CurrentUser('franchiseCity') city?: string) {
    return this.adminService.updateVehicle(id, data, city);
  }

  @Delete('vehicles/:id')
  @Roles(...FRANCHISE_ROLES)
  @ApiOperation({ summary: 'Delete an available vehicle' })
  deleteVehicle(@Param('id') id: string, @CurrentUser('franchiseCity') city?: string) {
    return this.adminService.deleteVehicle(id, city);
  }

  // ─── Cities ────────────────────────────────────────────────────────────────
  // A franchise can VIEW cities (its own only) and city-insights, but city CRUD is
  // platform config — admin only.
  @Post('cities')
  @ApiOperation({ summary: 'Create city' })
  createCity(@Body() data: any) {
    return this.adminService.createCity(data);
  }

  @Get('cities')
  @Roles(...FRANCHISE_ROLES)
  @ApiOperation({ summary: 'Get all cities' })
  getCities(@Query() query: any, @CurrentUser('franchiseCity') city?: string) {
    return this.adminService.getCities(query, city);
  }

  @Get('city-insights')
  @Roles(...FRANCHISE_ROLES)
  @ApiOperation({ summary: 'City-wise activity (requirements / cabs / users)' })
  getCityInsights(@Query() query: any, @CurrentUser('franchiseCity') city?: string) {
    return this.adminService.getCityInsights(query, city);
  }

  @Put('cities/:id')
  @ApiOperation({ summary: 'Update city' })
  updateCity(@Param('id') id: string, @Body() data: any) {
    return this.adminService.updateCity(id, data);
  }

  @Delete('cities/:id')
  @ApiOperation({ summary: 'Delete city' })
  deleteCity(@Param('id') id: string) {
    return this.adminService.deleteCity(id);
  }

  // ─── Banners (admin only — platform config) ──────────────────────────────────
  @Post('banners')
  @ApiOperation({ summary: 'Create banner' })
  createBanner(@Body() data: any) {
    return this.adminService.createBanner(data);
  }

  @Get('banners')
  @ApiOperation({ summary: 'Get all banners' })
  getBanners(@Query('isActive') isActive?: boolean) {
    return this.adminService.getBanners(isActive);
  }

  @Put('banners/:id')
  @ApiOperation({ summary: 'Update banner' })
  updateBanner(@Param('id') id: string, @Body() data: any) {
    return this.adminService.updateBanner(id, data);
  }

  @Delete('banners/:id')
  @ApiOperation({ summary: 'Delete banner' })
  deleteBanner(@Param('id') id: string) {
    return this.adminService.deleteBanner(id);
  }

  // ─── Reports ───────────────────────────────────────────────────────────────
  @Get('reports')
  @Roles(...FRANCHISE_ROLES)
  @ApiOperation({ summary: 'Get all reports' })
  getReports(@Query() query: any, @CurrentUser('franchiseCity') city?: string) {
    return this.adminService.getReports(query, city);
  }

  @Post('reports/:id/resolve')
  @Roles(...FRANCHISE_ROLES)
  @ApiOperation({ summary: 'Resolve a report' })
  resolveReport(
    @Param('id') id: string,
    @CurrentUser('sub') adminId: string,
    @Body('action') action: string,
    @Body('notes') notes: string,
    @CurrentUser('franchiseCity') city?: string,
  ) {
    return this.adminService.resolveReport(id, adminId, action, notes, city);
  }

  // ─── Account deletion requests ─────────────────────────────────────────────
  @Get('deletion-requests')
  @Roles(...FRANCHISE_ROLES)
  @ApiOperation({ summary: 'List account deletion requests' })
  getDeletionRequests(@Query() query: any, @CurrentUser('franchiseCity') city?: string) {
    return this.adminService.getDeletionRequests(query, city);
  }

  @Post('deletion-requests/:id/approve')
  @Roles(...FRANCHISE_ROLES)
  @ApiOperation({ summary: 'Approve a deletion request (removes the user)' })
  approveDeletionRequest(@Param('id') id: string, @CurrentUser('sub') adminId: string, @CurrentUser('franchiseCity') city?: string) {
    return this.adminService.approveDeletionRequest(id, adminId, city);
  }

  @Post('deletion-requests/:id/reject')
  @Roles(...FRANCHISE_ROLES)
  @ApiOperation({ summary: 'Reject a deletion request' })
  rejectDeletionRequest(
    @Param('id') id: string,
    @CurrentUser('sub') adminId: string,
    @Body('reason') reason?: string,
    @CurrentUser('franchiseCity') city?: string,
  ) {
    return this.adminService.rejectDeletionRequest(id, adminId, reason, city);
  }

  // ─── Notifications (admin only) ──────────────────────────────────────────────
  @Post('notifications/send')
  @ApiOperation({ summary: 'Send admin notification' })
  sendNotification(@Body() data: any) {
    return this.adminService.sendAdminNotification(data);
  }

  @Get('notifications')
  @ApiOperation({ summary: 'Sent notification history with read/click stats' })
  getSentNotifications(@Query() query: any) {
    return this.adminService.getSentNotifications(query.page, query.limit);
  }

  @Get('activity')
  @ApiOperation({ summary: 'Admin activity feed: plan buys, top-ups, withdrawals' })
  getAdminActivity(@Query('limit') limit?: number) {
    return this.adminService.getAdminActivity(limit);
  }

  @Post('users/:id/referral-count')
  // Admin only — franchises view the invite leaderboard but cannot add/deduct invites.
  @ApiOperation({ summary: 'Update user referral count (add/deduct)' })
  updateUserReferralCount(@Param('id') id: string, @Body('delta') delta: number, @CurrentUser('franchiseCity') city?: string) {
    return this.adminService.updateUserReferralCount(id, delta, city);
  }

  // ─── Payments ──────────────────────────────────────────────────────────────
  @Get('payments')
  @Roles(...FRANCHISE_ROLES)
  @ApiOperation({ summary: 'Get all payments' })
  getPayments(@Query() query: any, @CurrentUser('franchiseCity') city?: string) {
    return this.adminService.getPayments(query, city);
  }

  // ─── Admin profile ───────────────────────────────────────────────────────────
  @Get('profile')
  @ApiOperation({ summary: "The logged-in admin's own profile" })
  getMyProfile(@CurrentUser('sub') userId: string) {
    return this.adminService.getMyProfile(userId);
  }

  @Put('profile')
  @UseGuards(BlockImpersonationGuard)
  @ApiOperation({ summary: "Update the logged-in admin's own name / email / mobile" })
  updateMyProfile(
    @CurrentUser('sub') userId: string,
    @Body() dto: { fullName?: string; email?: string; mobile?: string },
  ) {
    return this.adminService.updateMyProfile(userId, dto);
  }

  @Post('profile/activate-golden')
  @UseGuards(BlockImpersonationGuard)
  @ApiOperation({ summary: 'Give the logged-in admin a free lifetime Golden membership' })
  activateGolden(@CurrentUser('sub') userId: string) {
    return this.adminService.activateGoldenForSelf(userId);
  }

  @Post('profile/change-password')
  @UseGuards(BlockImpersonationGuard)
  @ApiOperation({ summary: "Change the logged-in admin's password (verifies the current one)" })
  changePassword(
    @CurrentUser('sub') userId: string,
    @Body('oldPassword') oldPassword: string,
    @Body('newPassword') newPassword: string,
  ) {
    return this.adminService.changePassword(userId, oldPassword, newPassword);
  }

  // ─── Franchise leaderboard (admin only) ──────────────────────────────────────
  @Get('franchise-leaderboard')
  @ApiOperation({ summary: 'All franchises ranked by their city activity/revenue' })
  getFranchiseLeaderboard(@Query() query: any) {
    return this.adminService.getFranchiseLeaderboard(query);
  }

  // ─── Franchise earnings & settlements ────────────────────────────────────────
  @Get('franchise-earnings/:id')
  @ApiOperation({ summary: "A franchise's commission earnings + settlements (admin)" })
  getFranchiseEarnings(@Param('id') id: string) {
    return this.adminService.getFranchiseEarnings(id);
  }

  @Post('franchise-earnings/:id/settle')
  @ApiOperation({ summary: 'Record a payout to a franchise (admin settles commission)' })
  settleFranchise(
    @Param('id') id: string,
    @CurrentUser('sub') adminId: string,
    @Body('amount') amount: number,
    @Body('note') note?: string,
  ) {
    return this.adminService.settleFranchise(id, adminId, amount, note);
  }

  // A logged-in franchise's own earnings (for the franchise panel Profile page).
  @Get('my-earnings')
  @Roles(...FRANCHISE_ROLES)
  @ApiOperation({ summary: "The logged-in franchise's own commission earnings" })
  getMyFranchiseEarnings(@CurrentUser('sub') franchiseId: string) {
    return this.adminService.getFranchiseEarnings(franchiseId);
  }
}
