import {
  Controller, Get, Put, Post, Body, Param, Query, UseGuards, UseInterceptors,
  UploadedFile, ParseFilePipe, MaxFileSizeValidator, FileTypeValidator,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ApiTags, ApiOperation, ApiBearerAuth, ApiConsumes } from '@nestjs/swagger';
import { UsersService } from './users.service';
import { UpdateProfileDto } from './dto/update-profile.dto';
import { SubmitVerificationDto } from './dto/submit-verification.dto';
import { RateUserDto } from './dto/rate-user.dto';
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

  @Put('notifications')
  @ApiOperation({ summary: 'Toggle notifications' })
  toggleNotifications(
    @CurrentUser('sub') userId: string,
    @Body('enabled') enabled: boolean,
  ) {
    return this.usersService.toggleNotifications(userId, enabled);
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
