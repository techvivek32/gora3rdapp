import { Injectable, NotFoundException, ForbiddenException } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { Requirement, RequirementDocument } from '../../database/schemas/requirement.schema';
import { User, UserDocument } from '../../database/schemas/user.schema';
import { NotificationsService } from '../notifications/notifications.service';
import { CreateRequirementDto } from './dto/create-requirement.dto';
import { UpdateRequirementDto } from './dto/update-requirement.dto';
import { FilterRequirementsDto } from './dto/filter-requirements.dto';
import { BookingStatus } from '../../common/enums/vehicle-type.enum';
import { MembershipType } from '../../common/enums/user-role.enum';
import {
  generateBookingId,
  generateRequirementId,
} from '../../common/utils/booking-id.util';
import {
  getPaginationParams,
  buildPaginatedResult,
} from '../../common/utils/pagination.util';

@Injectable()
export class RequirementsService {
  constructor(
    @InjectModel(Requirement.name) private requirementModel: Model<RequirementDocument>,
    @InjectModel(User.name) private userModel: Model<UserDocument>,
    private notificationsService: NotificationsService,
  ) {}

  async create(userId: string, dto: CreateRequirementDto) {
    const bookingId = generateBookingId();
    const requirementId = generateRequirementId();

    const expiresAt = new Date(dto.travelDate);
    expiresAt.setDate(expiresAt.getDate() + 1);

    const requirement = await this.requirementModel.create({
      ...dto,
      bookingId,
      requirementId,
      postedBy: new Types.ObjectId(userId),
      status: BookingStatus.ACTIVE,
      expiresAt,
    });

    await this.userModel.findByIdAndUpdate(userId, { $inc: { requirementsPosted: 1 } });

    // Send push notifications to matching city users
    await this.notificationsService.notifyNewRequirement(requirement);

    return {
      message: 'Requirement posted successfully',
      data: requirement,
    };
  }

  async findAll(userId: string, query: FilterRequirementsDto) {
    const { page, limit, skip, sort } = getPaginationParams(query);

    const user = await this.userModel.findById(userId);
    const filter: any = {
      isDeleted: false,
      status: { $in: [BookingStatus.ACTIVE, BookingStatus.ACCEPTED] },
    };

    // Filter by user's business cities if they have set them
    if (user?.businessCities?.length > 0 && !query.pickupCity) {
      filter.$or = [
        { pickupCity: { $in: user.businessCities } },
        { dropCity: { $in: user.businessCities } },
      ];
    }

    if (query.pickupCity) filter.pickupCity = new RegExp(query.pickupCity, 'i');
    if (query.dropCity) filter.dropCity = new RegExp(query.dropCity, 'i');
    if (query.vehicleType) filter.vehicleType = query.vehicleType;
    if (query.tripType) filter.tripType = query.tripType;
    if (query.bookingId) filter.bookingId = query.bookingId;

    if (query.dateFrom || query.dateTo) {
      filter.travelDate = {};
      if (query.dateFrom) filter.travelDate.$gte = new Date(query.dateFrom);
      if (query.dateTo) filter.travelDate.$lte = new Date(query.dateTo);
    }

    const [requirements, total] = await Promise.all([
      this.requirementModel
        .find(filter)
        .populate('postedBy', 'fullName agencyName profileImage membershipType isVerified rating lastActive')
        .sort(sort)
        .skip(skip)
        .limit(limit)
        .lean(),
      this.requirementModel.countDocuments(filter),
    ]);

    // Apply contact lock based on membership
    const isPremium = user?.membershipType === MembershipType.PREMIUM ||
      user?.membershipType === MembershipType.GOLDEN ||
      user?.isPremium;

    const processedRequirements = requirements.map((req) => {
      if (!isPremium) {
        const postedBy = req.postedBy as any;
        if (postedBy) {
          postedBy.mobile = undefined;
          postedBy.agencyName = undefined;
          postedBy.profileImage = undefined;
        }
      }
      return req;
    });

    return buildPaginatedResult(processedRequirements, total, page, limit);
  }

  async findOne(id: string, userId: string) {
    const requirement = await this.requirementModel
      .findById(id)
      .populate('postedBy', 'fullName agencyName profileImage membershipType isVerified rating lastActive mobile email city state')
      .populate('acceptedBy', 'fullName agencyName profileImage membershipType mobile email city state')
      .lean();

    if (!requirement || requirement.isDeleted) {
      throw new NotFoundException('Requirement not found');
    }

    // Increment view count
    await this.requirementModel.findByIdAndUpdate(id, { $inc: { viewCount: 1 } });

    const user = await this.userModel.findById(userId);
    const isPremium = user?.membershipType === MembershipType.PREMIUM ||
      user?.membershipType === MembershipType.GOLDEN ||
      user?.membershipType === MembershipType.ACTIVE ||
      user?.membershipType === MembershipType.VERIFIED ||
      user?.isPremium;

    if (!isPremium) {
      const postedBy = requirement.postedBy as any;
      if (postedBy) {
        postedBy.mobile = undefined;
      }
    } else {
      await this.requirementModel.findByIdAndUpdate(id, { $inc: { contactViewCount: 1 } });
    }

    return { message: 'Requirement found', data: requirement };
  }

  async update(id: string, userId: string, dto: UpdateRequirementDto) {
    const requirement = await this.requirementModel.findById(id);
    if (!requirement) throw new NotFoundException('Requirement not found');
    if (requirement.postedBy.toString() !== userId) {
      throw new ForbiddenException('Not authorized to update this requirement');
    }

    const updated = await this.requirementModel
      .findByIdAndUpdate(id, dto, { new: true })
      .populate('postedBy', 'fullName agencyName profileImage membershipType isVerified rating lastActive mobile')
      .lean();
    return { message: 'Requirement updated', data: updated };
  }

  async remove(id: string, userId: string) {
    const requirement = await this.requirementModel.findById(id);
    if (!requirement) throw new NotFoundException('Requirement not found');
    if (requirement.postedBy.toString() !== userId) {
      throw new ForbiddenException('Not authorized to delete this requirement');
    }

    await this.requirementModel.findByIdAndUpdate(id, {
      isDeleted: true,
      deletedAt: new Date(),
      status: BookingStatus.CANCELLED,
    });

    return { message: 'Requirement deleted' };
  }

  async acceptRequirement(id: string, userId: string) {
    const requirement = await this.requirementModel.findById(id);
    if (!requirement) throw new NotFoundException('Requirement not found');

    if (requirement.postedBy.toString() === userId) {
      return { message: 'You cannot accept your own requirement' };
    }

    const isAlreadyAccepted = requirement.acceptedBy.some(
      (uid) => uid.toString() === userId,
    );

    if (isAlreadyAccepted) {
      return { message: 'Already accepted this requirement' };
    }

    await this.requirementModel.findByIdAndUpdate(id, {
      $addToSet: { acceptedBy: new Types.ObjectId(userId) },
      status: BookingStatus.ACCEPTED,
    });

    // Notify the poster
    const user = await this.userModel.findById(userId);
    await this.notificationsService.notifyRequirementAccepted(requirement, user);

    return { message: 'Requirement accepted successfully' };
  }

  async getAcceptedByMe(userId: string) {
    const requirements = await this.requirementModel
      .find({
        acceptedBy: new Types.ObjectId(userId),
        postedBy: { $ne: new Types.ObjectId(userId) },
        isDeleted: false,
      })
      .populate('postedBy', 'fullName agencyName profileImage membershipType')
      .sort({ updatedAt: -1 })
      .lean();
    return { message: 'Accepted requirements', data: requirements };
  }

  async cancelRequirement(id: string, userId: string, reason: string) {
    const requirement = await this.requirementModel.findById(id);
    if (!requirement) throw new NotFoundException('Requirement not found');
    if (requirement.postedBy.toString() !== userId) {
      throw new ForbiddenException('Not authorized to cancel this requirement');
    }

    await this.requirementModel.findByIdAndUpdate(id, {
      status: BookingStatus.CANCELLED,
      cancellationReason: reason,
      cancelledAt: new Date(),
    });

    return { message: 'Requirement cancelled successfully' };
  }

  async getMyRequirements(userId: string, status?: BookingStatus) {
    const filter: any = { postedBy: new Types.ObjectId(userId), isDeleted: false };
    if (status) filter.status = status;

    const requirements = await this.requirementModel
      .find(filter)
      .sort({ createdAt: -1 })
      .populate('postedBy', 'fullName agencyName profileImage membershipType mobile email city state')
      .populate('acceptedBy', 'fullName agencyName mobile membershipType')
      .lean();

    return { message: 'My requirements', data: requirements };
  }
}
