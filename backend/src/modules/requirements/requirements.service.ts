import { Injectable, NotFoundException, ForbiddenException, BadRequestException } from '@nestjs/common';
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

    // Notify the poster (self-confirmation)
    this.notificationsService.notifyRequirementPosted(requirement).catch(() => {});
    // Notify matching city users
    this.notificationsService.notifyNewRequirement(requirement).catch(() => {});

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
      status: { $in: [BookingStatus.ACTIVE, BookingStatus.ON_HOLD, BookingStatus.ACCEPTED, BookingStatus.CANCELLED] },
    };

    // Filter by user's business cities if they have set them. Match leniently:
    // a requirement counts if any business city appears in its clean city name or
    // its detailed pickup/drop address (case-insensitive).
    if (user?.businessCities?.length > 0 && !query.pickupCity) {
      const escape = (s: string) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
      const cityRegexes = user.businessCities
        .filter((c) => c && c.trim())
        .map((c) => new RegExp(escape(c.trim()), 'i'));
      filter.$or = cityRegexes.flatMap((rx) => [
        { pickupCityName: rx },
        { dropCityName: rx },
        { pickupCity: rx },
        { dropCity: rx },
      ]);
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
        .populate('postedBy', 'fullName agencyName profileImage membershipType isVerified rating lastActive mobile')
        .sort(sort)
        .skip(skip)
        .limit(limit)
        .lean(),
      this.requirementModel.countDocuments(filter),
    ]);

    // Apply contact lock based on membership. Keep this in sync with findOne()
    // and the app card's `canContact` so the Phone/WhatsApp buttons always work
    // when they are shown.
    const isPremium = user?.membershipType === MembershipType.PREMIUM ||
      user?.membershipType === MembershipType.GOLDEN ||
      user?.membershipType === MembershipType.ACTIVE ||
      user?.membershipType === MembershipType.VERIFIED ||
      user?.isPremium;

    const processedRequirements = requirements.map((req) => {
      const postedBy = req.postedBy as any;
      // The owner can always see their own number; premium tiers see everyone's.
      const isOwner = postedBy && postedBy._id?.toString() === userId;
      if (!isPremium && !isOwner) {
        if (postedBy) {
          // Only the phone number is gated for non-premium users; the profile
          // picture and agency name are public display info shown on the card.
          postedBy.mobile = undefined;
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

    // Manually populate acceptedBy to avoid Mongoose lean() populate inconsistencies
    const acceptedByIds = (requirement as any).acceptedBy as Types.ObjectId[];
    if (acceptedByIds && acceptedByIds.length > 0) {
      const acceptors = await this.userModel
        .find({ _id: { $in: acceptedByIds } })
        .select('fullName agencyName profileImage membershipType mobile email city state')
        .lean();
      (requirement as any).acceptedBy = acceptors;
    } else {
      (requirement as any).acceptedBy = [];
    }

    return { message: 'Requirement found', data: requirement };
  }

  /**
   * Look up a requirement by its display code (requirementId or bookingId),
   * e.g. "ID-REQ95642459" or "REQ95642459". Used by the home-page ID search.
   */
  async lookupByCode(code: string, userId: string) {
    const raw = (code || '').trim().replace(/^ID-/i, '').trim();
    if (!raw) throw new NotFoundException('No booking found with this ID');
    const escaped = raw.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const rx = new RegExp(`^${escaped}$`, 'i');
    const doc = await this.requirementModel
      .findOne({ isDeleted: { $ne: true }, $or: [{ requirementId: rx }, { bookingId: rx }] })
      .select('_id')
      .lean();
    if (!doc) throw new NotFoundException('No booking found with this ID');
    return this.findOne(String(doc._id), userId);
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

  // Owner-only status change (used for hold/unhold/mark-booked from My Requirements).
  async setStatus(id: string, userId: string, status: string) {
    const allowed = [BookingStatus.ACTIVE, BookingStatus.ON_HOLD, BookingStatus.ACCEPTED];
    if (!allowed.includes(status as BookingStatus)) {
      throw new ForbiddenException('Invalid status');
    }
    const requirement = await this.requirementModel.findById(id);
    if (!requirement) throw new NotFoundException('Requirement not found');
    if (requirement.postedBy.toString() !== userId) {
      throw new ForbiddenException('Not authorized to update this requirement');
    }

    const updated = await this.requirementModel
      .findByIdAndUpdate(id, { status }, { new: true })
      .populate('postedBy', 'fullName agencyName profileImage membershipType isVerified rating lastActive mobile')
      .lean();
    return { message: 'Status updated', data: updated };
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

  /** Fields exposed for an assigned driver / poster on a requirement card. */
  private static readonly PARTY_SELECT =
    'fullName agencyName mobile membershipType profileImage isVerified rating city state';

  /**
   * Hand this booking to a driver. Owner-only. Marks the requirement booked
   * (accepted) in the same step — assigning a driver *is* the booking.
   */
  async assignDriver(id: string, ownerId: string, driverId: string) {
    if (!Types.ObjectId.isValid(driverId)) throw new BadRequestException('Invalid driver');

    const requirement = await this.requirementModel.findById(id);
    if (!requirement) throw new NotFoundException('Requirement not found');
    if (requirement.postedBy.toString() !== ownerId) {
      throw new ForbiddenException('Not authorized to update this requirement');
    }
    if (requirement.status === BookingStatus.CANCELLED) {
      throw new BadRequestException('This requirement is cancelled');
    }
    if (driverId === ownerId) {
      throw new BadRequestException('You cannot assign a requirement to yourself');
    }

    const driver = await this.userModel
      .findOne({ _id: new Types.ObjectId(driverId), isActive: true, isBlocked: { $ne: true } })
      .select('_id fcmTokens')
      .lean();
    if (!driver) throw new NotFoundException('Driver not found');

    const updated = await this.requirementModel
      .findByIdAndUpdate(
        id,
        {
          assignedDriver: driver._id,
          assignedAt: new Date(),
          status: BookingStatus.ACCEPTED, // assigning a driver books the requirement
        },
        { new: true },
      )
      .populate('postedBy', RequirementsService.PARTY_SELECT)
      .populate('assignedDriver', RequirementsService.PARTY_SELECT)
      .lean();

    this.notificationsService.notifyRequirementAssigned(updated).catch(() => {});

    return { message: 'Driver assigned', data: updated };
  }

  /** Remove the assigned driver and put the requirement back in Running. */
  async unassignDriver(id: string, ownerId: string) {
    const requirement = await this.requirementModel.findById(id);
    if (!requirement) throw new NotFoundException('Requirement not found');
    if (requirement.postedBy.toString() !== ownerId) {
      throw new ForbiddenException('Not authorized to update this requirement');
    }

    const updated = await this.requirementModel
      .findByIdAndUpdate(
        id,
        { $unset: { assignedDriver: '', assignedAt: '' }, $set: { status: BookingStatus.ACTIVE } },
        { new: true },
      )
      .populate('postedBy', RequirementsService.PARTY_SELECT)
      .lean();

    return { message: 'Driver unassigned', data: updated };
  }

  // ── Trip start / end, gated by an OTP the owner reads out to the driver ──────

  private static readonly OTP_TTL_MS = 15 * 60 * 1000; // 15 minutes

  /**
   * Driver asks to start (or end) the trip. We mint an OTP and deliver it to the
   * OWNER — the driver never sees it. The owner reads it out, the driver enters
   * it below. That handshake is what proves the two are actually together.
   */
  async requestTripOtp(id: string, driverId: string, action: 'start' | 'end') {
    if (action !== 'start' && action !== 'end') {
      throw new BadRequestException('Invalid action');
    }

    const requirement = await this.requirementModel.findById(id);
    if (!requirement) throw new NotFoundException('Requirement not found');
    if (requirement.assignedDriver?.toString() !== driverId) {
      throw new ForbiddenException('This booking is not assigned to you');
    }

    if (action === 'start' && requirement.tripStatus !== 'pending') {
      throw new BadRequestException(
        requirement.tripStatus === 'started' ? 'Trip already started' : 'Trip already completed',
      );
    }
    if (action === 'end' && requirement.tripStatus !== 'started') {
      throw new BadRequestException('Start the trip first');
    }

    const otp = `${Math.floor(100000 + Math.random() * 900000)}`; // 6 digits
    await this.requirementModel.findByIdAndUpdate(id, {
      tripOtp: otp,
      tripOtpAction: action,
      tripOtpExpiresAt: new Date(Date.now() + RequirementsService.OTP_TTL_MS),
    });

    const driver = await this.userModel.findById(driverId).select('fullName agencyName mobile').lean();
    this.notificationsService
      .notifyTripOtp(requirement, driver, otp, action)
      .catch(() => {});

    return { message: `OTP sent to the requirement owner`, data: { action } };
  }

  /** Driver enters the OTP the owner gave them. */
  async verifyTripOtp(id: string, driverId: string, action: 'start' | 'end', otp: string) {
    // tripOtp* are select:false on the schema — opt in for the comparison.
    const requirement = await this.requirementModel
      .findById(id)
      .select('+tripOtp +tripOtpAction +tripOtpExpiresAt');
    if (!requirement) throw new NotFoundException('Requirement not found');
    if (requirement.assignedDriver?.toString() !== driverId) {
      throw new ForbiddenException('This booking is not assigned to you');
    }

    if (!requirement.tripOtp || requirement.tripOtpAction !== action) {
      throw new BadRequestException('No OTP requested. Tap Start again.');
    }
    if (!requirement.tripOtpExpiresAt || requirement.tripOtpExpiresAt.getTime() < Date.now()) {
      throw new BadRequestException('OTP expired. Request a new one.');
    }
    if (requirement.tripOtp !== `${otp}`.trim()) {
      throw new BadRequestException('Incorrect OTP');
    }

    const update: any = {
      $unset: { tripOtp: '', tripOtpAction: '', tripOtpExpiresAt: '' },
      $set:
        action === 'start'
          ? { tripStatus: 'started', tripStartedAt: new Date() }
          : {
              tripStatus: 'completed',
              tripCompletedAt: new Date(),
              status: BookingStatus.COMPLETED,
            },
    };

    const updated = await this.requirementModel
      .findByIdAndUpdate(id, update, { new: true })
      .populate('postedBy', RequirementsService.PARTY_SELECT)
      .populate('assignedDriver', RequirementsService.PARTY_SELECT)
      .lean();

    this.notificationsService.notifyTripStatus(updated, action).catch(() => {});

    return { message: action === 'start' ? 'Trip started' : 'Trip completed', data: updated };
  }

  /** Requirements other users have assigned to me. */
  async getAssignedToMe(userId: string) {
    const requirements = await this.requirementModel
      .find({ assignedDriver: new Types.ObjectId(userId), isDeleted: false })
      .sort({ assignedAt: -1 })
      .populate('postedBy', RequirementsService.PARTY_SELECT)
      .populate('assignedDriver', RequirementsService.PARTY_SELECT)
      .lean();

    return { message: 'Assigned requirements', data: requirements };
  }

  async getMyRequirements(userId: string, status?: BookingStatus) {
    const filter: any = { postedBy: new Types.ObjectId(userId), isDeleted: false };
    if (status) filter.status = status;

    const requirements = await this.requirementModel
      .find(filter)
      .sort({ createdAt: -1 })
      .populate('postedBy', 'fullName agencyName profileImage membershipType mobile email city state')
      .populate('assignedDriver', RequirementsService.PARTY_SELECT)
      .lean();

    // Manually populate acceptedBy for each requirement
    const allAcceptorIds = [...new Set(
      requirements.flatMap((r: any) => (r.acceptedBy as Types.ObjectId[]) || []).map(String)
    )];
    let acceptorMap: Record<string, any> = {};
    if (allAcceptorIds.length > 0) {
      const acceptors = await this.userModel
        .find({ _id: { $in: allAcceptorIds } })
        .select('fullName agencyName mobile membershipType profileImage')
        .lean();
      acceptorMap = Object.fromEntries(acceptors.map((a: any) => [a._id.toString(), a]));
    }
    for (const req of requirements as any[]) {
      req.acceptedBy = ((req.acceptedBy as Types.ObjectId[]) || [])
        .map((aid: any) => acceptorMap[aid.toString()])
        .filter(Boolean);
    }

    return { message: 'My requirements', data: requirements };
  }
}
