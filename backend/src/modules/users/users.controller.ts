import {
  Controller, Get, Put, Post, Delete, Body, Param, Query, UseGuards, UseInterceptors,
  UploadedFile, ParseFilePipe, MaxFileSizeValidator, FileTypeValidator,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ApiTags, ApiOperation, ApiBearerAuth, ApiConsumes } from '@nestjs/swagger';
import { UsersService } from './users.service';
import { UpdateProfileDto } from './dto/update-profile.dto';
import { SubmitVerificationDto } from './dto/submit-verification.dto';
import { RateUserDto } from './dto/rate-user.dto';
import { RequestAccountDeletionDto } from './dto/request-account-deletion.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';

@ApiTags('Users')
@ApiBearerAuth('access-token')
@UseGuards(JwtAuthGuard)
@Controller('users')
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Get('profile')
  @ApiOperation({ summary: 'Get current user profile' })
  getProfile(@CurrentUser('sub') userId: string) {
    return this.usersService.getProfile(userId);
  }

  @Put('profile')
  @ApiOperation({ summary: 'Update user profile' })
  updateProfile(@CurrentUser('sub') userId: string, @Body() dto: UpdateProfileDto) {
    return this.usersService.updateProfile(userId, dto);
  }

  @Post('account/delete-request')
  @ApiOperation({ summary: 'Request account deletion (reviewed by an admin)' })
  requestAccountDeletion(
    @CurrentUser('sub') userId: string,
    @Body() dto: RequestAccountDeletionDto,
  ) {
    return this.usersService.requestAccountDeletion(userId, dto.reason);
  }

  @Get('account/delete-request')
  @ApiOperation({ summary: 'Status of the current user’s deletion request' })
  getDeletionRequestStatus(@CurrentUser('sub') userId: string) {
    return this.usersService.getDeletionRequestStatus(userId);
  }

  @Post('verification')
  @ApiOperation({ summary: 'Submit KYC documents for verification' })
  submitVerification(
    @CurrentUser('sub') userId: string,
    @Body() dto: SubmitVerificationDto,
  ) {
    return this.usersService.submitVerification(userId, dto);
  }

  @Put('business-cities')
  @ApiOperation({ summary: 'Update business cities' })
  updateBusinessCities(
    @CurrentUser('sub') userId: string,
    @Body('cities') cities: string[],
  ) {
    return this.usersService.updateBusinessCities(userId, cities);
  }

  @Get('referral-info')
  @ApiOperation({ summary: 'Get my referral code and how many users I invited' })
  getReferralInfo(@CurrentUser('sub') userId: string) {
    return this.usersService.getReferralInfo(userId);
  }

  @Get('referral-leaderboard')
  @ApiOperation({ summary: 'Top inviters ranked by referral count' })
  getReferralLeaderboard(@CurrentUser('sub') userId: string) {
    return this.usersService.getReferralLeaderboard(userId);
  }

  @Get('lookup')
  @ApiOperation({ summary: 'Find a user by mobile number' })
  lookupByMobile(@Query('mobile') mobile: string) {
    return this.usersService.lookupByMobile(mobile);
  }

  @Get('card/:userId')
  @ApiOperation({ summary: 'Get user public profile card' })
  getUserCard(@Param('userId') userId: string) {
    return this.usersService.getUserCard(userId);
  }

  @Post(':userId/rate')
  @ApiOperation({ summary: 'Rate a user (one time only)' })
  rateUser(
    @Param('userId') userId: string,
    @CurrentUser('sub') raterId: string,
    @Body() dto: RateUserDto,
  ) {
    return this.usersService.rateUser(raterId, userId, dto);
  }

  @Get(':userId/rating-status')
  @ApiOperation({ summary: 'Whether the current user has already rated this user' })
  getRatingStatus(@Param('userId') userId: string, @CurrentUser('sub') raterId: string) {
    return this.usersService.getRatingStatus(raterId, userId);
  }

  @Get(':userId/reviews')
  @ApiOperation({ summary: 'Get all reviews for a user' })
  getReviews(@Param('userId') userId: string) {
    return this.usersService.getReviews(userId);
  }

  @Put('notifications')
  @ApiOperation({ summary: 'Toggle notifications and set alert filters' })
  toggleNotifications(
    @CurrentUser('sub') userId: string,
    @Body('enabled') enabled: boolean,
    @Body('vehicleTypes') vehicleTypes?: string[],
    @Body('tripTypes') tripTypes?: string[],
  ) {
    return this.usersService.toggleNotifications(userId, enabled, vehicleTypes, tripTypes);
  }

  @Post('fcm-token')
  @ApiOperation({ summary: 'Add FCM device token' })
  addFcmToken(@CurrentUser('sub') userId: string, @Body('token') token: string) {
    return this.usersService.updateFcmToken(userId, token, 'add');
  }

  @Get('search')
  @ApiOperation({ summary: 'Search users' })
  searchUsers(
    @Query('q') query: string,
    @Query('page') page?: number,
    @Query('limit') limit?: number,
  ) {
    return this.usersService.searchUsers(query, page, limit);
  }
}
