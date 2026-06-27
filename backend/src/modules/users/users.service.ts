import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { User, UserDocument } from '../../database/schemas/user.schema';
import { AvailableVehicle, AvailableVehicleDocument } from '../../database/schemas/available-vehicle.schema';
import { UpdateProfileDto } from './dto/update-profile.dto';
import { SubmitVerificationDto } from './dto/submit-verification.dto';
import { VerificationStatus } from '../../common/enums/user-role.enum';
import { getPaginationParams, buildPaginatedResult } from '../../common/utils/pagination.util';

// Public-facing profile fields (no credentials / private data).
const PUBLIC_PROFILE_SELECT =
  'fullName agencyName profileImage coverImage membershipType isVerified verificationStatus rating totalRatings lastActive city state mobile role businessCities requirementsPosted vehiclesPosted createdAt';

@Injectable()
export class UsersService {
  constructor(
    @InjectModel(User.name) private userModel: Model<UserDocument>,
    @InjectModel(AvailableVehicle.name) private vehicleModel: Model<AvailableVehicleDocument>,
  ) {}

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
    const { agencyName, ...documents } = dto;

    // Keep only the document entries that were actually provided.
    const cleanedDocuments = Object.fromEntries(
      Object.entries(documents).filter(([, value]) => value && (value.number || value.image)),
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
