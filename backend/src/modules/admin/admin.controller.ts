import {
  Controller, Get, Post, Put, Delete, Body, Param, Query, UseGuards,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { AdminService } from './admin.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { UserRole } from '../../common/enums/user-role.enum';
import { MembershipType } from '../../common/enums/user-role.enum';

@ApiTags('Admin')
@ApiBearerAuth('access-token')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.ADMIN, UserRole.SUPER_ADMIN)
@Controller('admin')
export class AdminController {
  constructor(private readonly adminService: AdminService) {}

  // ─── Dashboard ─────────────────────────────────────────────────────────────
  @Get('dashboard')
  @ApiOperation({ summary: 'Get dashboard statistics' })
  getDashboard() {
    return this.adminService.getDashboardStats();
  }

  @Get('analytics')
  @ApiOperation({ summary: 'Get analytics data' })
  getAnalytics(@Query('period') period: string) {
    return this.adminService.getAnalytics(period || 'month');
  }

  // ─── Users ─────────────────────────────────────────────────────────────────
  @Get('users')
  @ApiOperation({ summary: 'Get all users' })
  getUsers(@Query() query: any) {
    return this.adminService.getUsers(query);
  }

  @Get('referral-leaderboard')
  @ApiOperation({ summary: 'Invitation leaderboard (users ranked by referrals)' })
  getReferralLeaderboard(@Query() query: any) {
    return this.adminService.getReferralLeaderboard(query);
  }

  @Get('users/:id')
  @ApiOperation({ summary: 'Get a single user' })
  getUser(@Param('id') id: string) {
    return this.adminService.getUser(id);
  }

  @Put('users/:id')
  @ApiOperation({ summary: 'Update user' })
  updateUser(@Param('id') id: string, @Body() data: any) {
    return this.adminService.updateUser(id, data);
  }

  @Post('users/:id/verify')
  @ApiOperation({ summary: 'Verify user account' })
  verifyUser(@Param('id') id: string) {
    return this.adminService.verifyUser(id);
  }

  @Post('users/:id/block')
  @ApiOperation({ summary: 'Block user' })
  blockUser(@Param('id') id: string, @Body('reason') reason: string) {
    return this.adminService.blockUser(id, reason);
  }

  @Post('users/:id/unblock')
  @ApiOperation({ summary: 'Unblock user' })
  unblockUser(@Param('id') id: string) {
    return this.adminService.unblockUser(id);
  }

  @Post('users/:id/upgrade-membership')
  @ApiOperation({ summary: 'Upgrade user membership' })
  upgradeMembership(
    @Param('id') id: string,
    @Body('membershipType') membershipType: MembershipType,
    @Body('daysToAdd') daysToAdd: number,
  ) {
    return this.adminService.upgradeMembership(id, membershipType, daysToAdd);
  }

  @Get('users/:id/requirements')
  @ApiOperation({ summary: 'Get requirements posted by a user' })
  getUserRequirements(@Param('id') id: string) {
    return this.adminService.getUserRequirements(id);
  }

  @Get('users/:id/vehicles')
  @ApiOperation({ summary: 'Get vehicles posted by a user' })
  getUserVehicles(@Param('id') id: string) {
    return this.adminService.getUserVehicles(id);
  }

  @Get('users/:id/payments')
  @ApiOperation({ summary: 'Get payments made by a user' })
  getUserPayments(@Param('id') id: string) {
    return this.adminService.getUserPayments(id);
  }

  @Get('users/:id/withdrawals')
  @ApiOperation({ summary: 'Get withdrawal requests by a user' })
  getUserWithdrawals(@Param('id') id: string) {
    return this.adminService.getUserWithdrawals(id);
  }

  @Get('users/:id/reviews')
  @ApiOperation({ summary: 'Get reviews received by a user' })
  getUserReviews(@Param('id') id: string) {
    return this.adminService.getUserReviews(id);
  }

  @Put('reviews/:id')
  @ApiOperation({ summary: 'Edit a review' })
  updateReview(@Param('id') id: string, @Body() data: { stars?: number; review?: string }) {
    return this.adminService.updateReview(id, data);
  }

  @Delete('reviews/:id')
  @ApiOperation({ summary: 'Delete a review' })
  deleteReview(@Param('id') id: string) {
    return this.adminService.deleteReview(id);
  }

  @Get('users/:id/subscriptions')
  @ApiOperation({ summary: 'Get subscriptions of a user' })
  getUserSubscriptions(@Param('id') id: string) {
    return this.adminService.getUserSubscriptions(id);
  }

  // ─── Verification Requests ─────────────────────────────────────────────────
  @Get('verification-requests')
  @ApiOperation({ summary: 'List KYC verification requests' })
  getVerificationRequests(@Query() query: any) {
    return this.adminService.getVerificationRequests(query);
  }

  @Get('verification-requests/:id')
  @ApiOperation({ summary: 'Get a single verification request with documents' })
  getVerificationRequest(@Param('id') id: string) {
    return this.adminService.getVerificationRequest(id);
  }

  @Post('verification-requests/:id/approve')
  @ApiOperation({ summary: 'Approve a verification request' })
  approveVerification(@Param('id') id: string) {
    return this.adminService.approveVerification(id);
  }

  @Post('verification-requests/:id/reject')
  @ApiOperation({ summary: 'Reject a verification request' })
  rejectVerification(@Param('id') id: string, @Body('reason') reason: string) {
    return this.adminService.rejectVerification(id, reason);
  }

  // ─── Requirements ──────────────────────────────────────────────────────────
  @Get('requirements')
  @ApiOperation({ summary: 'Get all requirements' })
  getRequirements(@Query() query: any) {
    return this.adminService.getRequirements(query);
  }

  @Put('requirements/:id')
  @ApiOperation({ summary: 'Edit a requirement' })
  updateRequirement(@Param('id') id: string, @Body() data: any) {
    return this.adminService.updateRequirement(id, data);
  }

  @Delete('requirements/:id')
  @ApiOperation({ summary: 'Delete a requirement' })
  deleteRequirement(@Param('id') id: string) {
    return this.adminService.deleteRequirement(id);
  }

  // ─── Subscriptions ─────────────────────────────────────────────────────────
  @Get('subscriptions')
  @ApiOperation({ summary: 'Get all subscriptions' })
  getSubscriptions(@Query() query: any) {
    return this.adminService.getSubscriptions(query);
  }

  // ─── Subscription Plans (admin editable) ─────────────────────────────────────
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
  @ApiOperation({ summary: 'Get all available vehicles' })
  getVehicles(@Query() query: any) {
    return this.adminService.getVehicles(query);
  }

  @Put('vehicles/:id')
  @ApiOperation({ summary: 'Edit an available vehicle' })
  updateVehicle(@Param('id') id: string, @Body() data: any) {
    return this.adminService.updateVehicle(id, data);
  }

  @Delete('vehicles/:id')
  @ApiOperation({ summary: 'Delete an available vehicle' })
  deleteVehicle(@Param('id') id: string) {
    return this.adminService.deleteVehicle(id);
  }

  // ─── Cities ────────────────────────────────────────────────────────────────
  @Post('cities')
  @ApiOperation({ summary: 'Create city' })
  createCity(@Body() data: any) {
    return this.adminService.createCity(data);
  }

  @Get('cities')
  @ApiOperation({ summary: 'Get all cities' })
  getCities(@Query() query: any) {
    return this.adminService.getCities(query);
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

  // ─── Banners ───────────────────────────────────────────────────────────────
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
  @ApiOperation({ summary: 'Get all reports' })
  getReports(@Query() query: any) {
    return this.adminService.getReports(query);
  }

  @Post('reports/:id/resolve')
  @ApiOperation({ summary: 'Resolve a report' })
  resolveReport(
    @Param('id') id: string,
    @CurrentUser('sub') adminId: string,
    @Body('action') action: string,
    @Body('notes') notes: string,
  ) {
    return this.adminService.resolveReport(id, adminId, action, notes);
  }

  // ─── Notifications ─────────────────────────────────────────────────────────
  @Post('notifications/send')
  @ApiOperation({ summary: 'Send admin notification' })
  sendNotification(@Body() data: any) {
    return this.adminService.sendAdminNotification(data);
  }

  // ─── Payments ──────────────────────────────────────────────────────────────
  @Get('payments')
  @ApiOperation({ summary: 'Get all payments' })
  getPayments(@Query() query: any) {
    return this.adminService.getPayments(query);
  }
}
