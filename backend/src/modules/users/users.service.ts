import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { User, UserDocument } from '../../database/schemas/user.schema';
import { UpdateProfileDto } from './dto/update-profile.dto';
import { getPaginationParams, buildPaginatedResult } from '../../common/utils/pagination.util';

@Injectable()
export class UsersService {
  constructor(@InjectModel(User.name) private userModel: Model<UserDocument>) {}

  async getProfile(userId: string) {
    const user = await this.userModel
      .findById(userId)
      .select('-password -refreshToken -fcmTokens -loginAttempts -lockUntil')
      .lean();

    if (!user) throw new NotFoundException('User not found');
    return { message: 'Profile retrieved', data: user };
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

  async getUserCard(userId: string, requestingUserId: string) {
    const [targetUser, requestingUser] = await Promise.all([
      this.userModel.findById(userId).select(
        'fullName agencyName profileImage membershipType isVerified rating totalRatings lastActive city state mobile',
      ).lean(),
      this.userModel.findById(requestingUserId).select('membershipType isPremium isGolden'),
    ]);

    if (!targetUser) throw new NotFoundException('User not found');

    const isPremium = requestingUser?.isPremium || requestingUser?.isGolden ||
      ['premium', 'golden'].includes(requestingUser?.membershipType);

    if (!isPremium) {
      (targetUser as any).mobile = undefined;
    }

    return { message: 'User card retrieved', data: targetUser };
  }

  async toggleNotifications(userId: string, enabled: boolean) {
    await this.userModel.findByIdAndUpdate(userId, { notificationsEnabled: enabled });
    return { message: `Notifications ${enabled ? 'enabled' : 'disabled'}` };
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
