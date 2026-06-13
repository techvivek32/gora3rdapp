import { Injectable, NotFoundException, ForbiddenException } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { AvailableVehicle, AvailableVehicleDocument } from '../../database/schemas/available-vehicle.schema';
import { User, UserDocument } from '../../database/schemas/user.schema';
import { CreateAvailableVehicleDto } from './dto/create-available-vehicle.dto';
import { AvailabilityStatus } from '../../common/enums/vehicle-type.enum';
import { MembershipType } from '../../common/enums/user-role.enum';
import { generateVehicleListingId } from '../../common/utils/booking-id.util';
import { getPaginationParams, buildPaginatedResult } from '../../common/utils/pagination.util';

@Injectable()
export class AvailableVehiclesService {
  constructor(
    @InjectModel(AvailableVehicle.name) private vehicleModel: Model<AvailableVehicleDocument>,
    @InjectModel(User.name) private userModel: Model<UserDocument>,
  ) {}

  async create(userId: string, dto: CreateAvailableVehicleDto) {
    const listing = await this.vehicleModel.create({
      ...dto,
      listingId: generateVehicleListingId(),
      postedBy: new Types.ObjectId(userId),
      status: AvailabilityStatus.AVAILABLE,
    });

    await this.userModel.findByIdAndUpdate(userId, { $inc: { vehiclesPosted: 1 } });

    return { message: 'Vehicle listing posted successfully', data: listing };
  }

  async findAll(userId: string, query: any) {
    const { page, limit, skip, sort } = getPaginationParams(query);
    const user = await this.userModel.findById(userId);

    const filter: any = {
      isDeleted: false,
      status: AvailabilityStatus.AVAILABLE,
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
        .populate('postedBy', 'fullName agencyName profileImage membershipType isVerified rating lastActive')
        .sort(sort)
        .skip(skip)
        .limit(limit)
        .lean(),
      this.vehicleModel.countDocuments(filter),
    ]);

    const isPremium = ['premium', 'golden'].includes(user?.membershipType);

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
      .populate('postedBy', 'fullName agencyName profileImage membershipType isVerified rating lastActive mobile')
      .lean();

    if (!vehicle || vehicle.isDeleted) throw new NotFoundException('Vehicle listing not found');

    await this.vehicleModel.findByIdAndUpdate(id, { $inc: { viewCount: 1 } });

    const user = await this.userModel.findById(userId).select('membershipType isPremium isGolden');
    const isPremium = user?.isPremium || user?.isGolden || ['premium', 'golden'].includes(user?.membershipType);

    if (!isPremium) {
      (vehicle as any).driverMobile = undefined;
      const postedBy = vehicle.postedBy as any;
      if (postedBy) postedBy.mobile = undefined;
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
}
