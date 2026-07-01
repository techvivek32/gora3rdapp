import { Injectable, NotFoundException, ForbiddenException, BadRequestException } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { AvailableVehicle, AvailableVehicleDocument } from '../../database/schemas/available-vehicle.schema';
import { User, UserDocument } from '../../database/schemas/user.schema';
import { CreateAvailableVehicleDto } from './dto/create-available-vehicle.dto';
import { AvailabilityStatus } from '../../common/enums/vehicle-type.enum';
import { MembershipType } from '../../common/enums/user-role.enum';
import { generateVehicleListingId } from '../../common/utils/booking-id.util';
import { getPaginationParams, buildPaginatedResult } from '../../common/utils/pagination.util';
import { NotificationsService } from '../notifications/notifications.service';
import { MIN_WALLET_BALANCE } from '../../common/constants/wallet.constant';

@Injectable()
export class AvailableVehiclesService {
  constructor(
    @InjectModel(AvailableVehicle.name) private vehicleModel: Model<AvailableVehicleDocument>,
    @InjectModel(User.name) private userModel: Model<UserDocument>,
    private notificationsService: NotificationsService,
  ) {}

  async create(userId: string, dto: CreateAvailableVehicleDto) {
    const user = await this.userModel.findById(userId).select('walletBalance');
    if (!user || (user.walletBalance ?? 0) < MIN_WALLET_BALANCE) {
      throw new BadRequestException(
        `You need a minimum wallet balance of ₹${MIN_WALLET_BALANCE} to post a vehicle listing. Please add money to your wallet.`,
      );
    }

    const listing = await this.vehicleModel.create({
      ...dto,
      listingId: generateVehicleListingId(),
      postedBy: new Types.ObjectId(userId),
      status: AvailabilityStatus.AVAILABLE,
    });

    await this.userModel.findByIdAndUpdate(userId, { $inc: { vehiclesPosted: 1 } });

    // Notify the poster (self-confirmation)
    this.notificationsService.notifyVehiclePosted(listing).catch(() => {});

    return { message: 'Vehicle listing posted successfully', data: listing };
  }

  async findAll(userId: string, query: any) {
    const { page, limit, skip, sort } = getPaginationParams(query);
    const user = await this.userModel.findById(userId);

    const filter: any = {
      isDeleted: false,
      status: { $in: [AvailabilityStatus.AVAILABLE, AvailabilityStatus.ON_HOLD, AvailabilityStatus.BOOKED] },
    };

    if (user?.businessCities?.length > 0 && !query.currentCity) {
      filter.currentCity = { $in: user.businessCities };
    }

    if (query.currentCity) filter.currentCity = new RegExp(query.currentCity, 'i');
    if (query.vehicleType) filter.vehicleType = query.vehicleType;
    if (query.dateFrom) filter.availableDate = { $gte: new Date(query.dateFrom) };

    const [vehicles, total] = await Promise.all([
      this.vehicleModel
        .find(filter)
        .populate('postedBy', 'fullName agencyName profileImage membershipType isVerified rating lastActive mobile')
        .sort(sort)
        .skip(skip)
        .limit(limit)
        .lean(),
      this.vehicleModel.countDocuments(filter),
    ]);

    const isPremium = user?.membershipType === MembershipType.PREMIUM ||
      user?.membershipType === MembershipType.GOLDEN ||
      user?.membershipType === MembershipType.ACTIVE ||
      user?.membershipType === MembershipType.VERIFIED ||
      user?.isPremium;

    const processed = vehicles.map((v) => {
      if (!isPremium) {
        const postedBy = v.postedBy as any;
        if (postedBy) postedBy.mobile = undefined;
        (v as any).driverMobile = undefined;
      }
      return v;
    });

    return buildPaginatedResult(processed, total, page, limit);
  }

  async findOne(id: string, userId: string) {
    const vehicle = await this.vehicleModel
      .findById(id)
      .populate('postedBy', 'fullName agencyName profileImage membershipType isVerified rating lastActive mobile email city state')
      .populate('acceptedBy', 'fullName agencyName profileImage membershipType mobile email city state')
      .lean();

    if (!vehicle || vehicle.isDeleted) throw new NotFoundException('Vehicle listing not found');

    await this.vehicleModel.findByIdAndUpdate(id, { $inc: { viewCount: 1 } });

    const user = await this.userModel.findById(userId).select('membershipType isPremium isGolden');
    const isPremium = user?.membershipType === MembershipType.PREMIUM ||
      user?.membershipType === MembershipType.GOLDEN ||
      user?.membershipType === MembershipType.ACTIVE ||
      user?.membershipType === MembershipType.VERIFIED ||
      user?.isPremium;

    if (!isPremium) {
      (vehicle as any).driverMobile = undefined;
      const postedBy = vehicle.postedBy as any;
      if (postedBy) postedBy.mobile = undefined;
    } else {
      await this.vehicleModel.findByIdAndUpdate(id, { $inc: { contactViewCount: 1 } });
    }

    return { message: 'Vehicle listing found', data: vehicle };
  }

  async update(id: string, userId: string, dto: Partial<CreateAvailableVehicleDto>) {
    const vehicle = await this.vehicleModel.findById(id);
    if (!vehicle) throw new NotFoundException('Vehicle listing not found');
    if (vehicle.postedBy.toString() !== userId) throw new ForbiddenException('Unauthorized');

    const updated = await this.vehicleModel.findByIdAndUpdate(id, dto, { new: true });
    return { message: 'Vehicle listing updated', data: updated };
  }

  // Owner-only status change (hold/unhold/mark-booked).
  async setStatus(id: string, userId: string, status: string) {
    const allowed = [AvailabilityStatus.AVAILABLE, AvailabilityStatus.ON_HOLD, AvailabilityStatus.BOOKED];
    if (!allowed.includes(status as AvailabilityStatus)) throw new ForbiddenException('Invalid status');
    const vehicle = await this.vehicleModel.findById(id);
    if (!vehicle) throw new NotFoundException('Vehicle listing not found');
    if (vehicle.postedBy.toString() !== userId) throw new ForbiddenException('Unauthorized');

    const updated = await this.vehicleModel.findByIdAndUpdate(id, { status }, { new: true });
    return { message: 'Status updated', data: updated };
  }

  async cancel(id: string, userId: string, reason: string) {
    const vehicle = await this.vehicleModel.findById(id);
    if (!vehicle) throw new NotFoundException('Vehicle listing not found');
    if (vehicle.postedBy.toString() !== userId) throw new ForbiddenException('Unauthorized');

    await this.vehicleModel.findByIdAndUpdate(id, {
      status: AvailabilityStatus.CANCELLED,
      cancellationReason: reason,
      cancelledAt: new Date(),
    });
    return { message: 'Vehicle listing cancelled' };
  }

  async remove(id: string, userId: string) {
    const vehicle = await this.vehicleModel.findById(id);
    if (!vehicle) throw new NotFoundException('Vehicle listing not found');
    if (vehicle.postedBy.toString() !== userId) throw new ForbiddenException('Unauthorized');

    await this.vehicleModel.findByIdAndUpdate(id, {
      isDeleted: true,
      status: AvailabilityStatus.EXPIRED,
    });

    return { message: 'Vehicle listing removed' };
  }

  async getMyVehicles(userId: string) {
    const vehicles = await this.vehicleModel
      .find({ postedBy: new Types.ObjectId(userId), isDeleted: false })
      .sort({ createdAt: -1 })
      .lean();

    return { message: 'My vehicle listings', data: vehicles };
  }

  async acceptVehicle(id: string, userId: string) {
    const vehicle = await this.vehicleModel.findById(id);
    if (!vehicle) throw new NotFoundException('Vehicle listing not found');

    if (vehicle.postedBy.toString() === userId) {
      return { message: 'You cannot accept your own vehicle listing' };
    }

    const isAlreadyAccepted = (vehicle as any).acceptedBy?.some(
      (uid: any) => uid.toString() === userId,
    );

    if (isAlreadyAccepted) {
      return { message: 'Already accepted this vehicle listing' };
    }

    await this.vehicleModel.findByIdAndUpdate(id, {
      $addToSet: { acceptedBy: new Types.ObjectId(userId) },
      status: AvailabilityStatus.BOOKED,
    });

    return { message: 'Vehicle listing accepted successfully' };
  }

  async getAcceptedByMe(userId: string) {
    const vehicles = await this.vehicleModel
      .find({
        acceptedBy: new Types.ObjectId(userId),
        postedBy: { $ne: new Types.ObjectId(userId) },
        isDeleted: false,
      })
      .populate('postedBy', 'fullName agencyName profileImage membershipType')
      .sort({ updatedAt: -1 })
      .lean();
    return { message: 'Accepted vehicle listings', data: vehicles };
  }
}
