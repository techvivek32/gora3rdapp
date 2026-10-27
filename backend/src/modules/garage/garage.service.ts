import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { GarageVehicle, GarageVehicleDocument } from '../../database/schemas/garage-vehicle.schema';
import { GarageDriver, GarageDriverDocument } from '../../database/schemas/garage-driver.schema';
import { User, UserDocument } from '../../database/schemas/user.schema';
import { CreateGarageVehicleDto, UpdateGarageVehicleDto } from './dto/garage-vehicle.dto';
import { CreateGarageDriverDto, UpdateGarageDriverDto } from './dto/garage-driver.dto';
import { VerificationService } from '../verification/verification.service';
import { SettingsService } from '../settings/settings.service';

// A saved driver's number must belong to a real driver/vendor account in the app.

@Injectable()
export class GarageService {
  constructor(
    @InjectModel(GarageVehicle.name) private garageModel: Model<GarageVehicleDocument>,
    @InjectModel(GarageDriver.name) private driverModel: Model<GarageDriverDocument>,
    @InjectModel(User.name) private userModel: Model<UserDocument>,
    private readonly verification: VerificationService,
    private readonly settings: SettingsService,
  ) {}

  /**
   * A saved driver's number just needs to be a valid 10-digit mobile — it does
   * NOT have to be a registered account. The driver can be assigned by number and
   * will see the booking in their own "My Bookings" as soon as they install the
   * app and sign in with that number (matched by phone on the booking).
   */
  private assertValidPhone(phone?: string): void {
    const last10 = (phone || '').replace(/\D/g, '').slice(-10);
    if (last10.length !== 10) {
      throw new BadRequestException('Enter a valid 10-digit mobile number.');
    }
  }

  /**
   * You can't add your OWN number as a driver — it's the same account whether
   * you're in customer or driver mode, and you can't assign a trip to yourself.
   */
  private async assertNotOwnNumber(userId: string, phone?: string): Promise<void> {
    const last10 = (phone || '').replace(/\D/g, '').slice(-10);
    if (last10.length !== 10) return;
    const me: any = await this.userModel.findById(userId).select('mobile').lean();
    const myLast10 = (me?.mobile || '').replace(/\D/g, '').slice(-10);
    if (myLast10 && myLast10 === last10) {
      throw new BadRequestException("You can't add your own number as a driver.");
    }
  }

  /**
   * Prevent the same phone number being saved twice in one account's driver list.
   * Compares on the last 10 digits; `exceptId` skips the driver being edited.
   */
  /**
   * A driver's number may sit in ONE garage across the whole platform.
   *
   * This used to scope the check to `userId`, so the same driver could be added
   * by several vendors at once and each would offer them for the same slot. The
   * message distinguishes the two cases: your own garage is something you can
   * fix yourself, another account is not.
   *
   * A REJECTED row is ignored so an admin turning someone down cannot leave the
   * number locked away from whoever legitimately employs that driver.
   */
  private async assertPhoneNotDuplicate(userId: string, phone?: string, exceptId?: string): Promise<void> {
    const last10 = (phone || '').replace(/\D/g, '').slice(-10);
    if (last10.length !== 10) return; // format already validated elsewhere
    const query: any = { phone: last10, approvalStatus: { $ne: 'rejected' } };
    if (exceptId) query._id = { $ne: new Types.ObjectId(exceptId) };
    const existing: any = await this.driverModel.findOne(query).select('userId').lean();
    if (!existing) return;
    const mine = existing.userId?.toString() === userId;
    throw new BadRequestException(
      mine
        ? 'You have already added a driver with this number.'
        : 'This driver is already registered in another account. Contact support if they work for you.',
    );
  }

  /**
   * A driver's Aadhaar and licence numbers identify one PERSON, so each may
   * appear in one garage only — across the whole platform, not just this
   * account. Same rule the registration number already has for vehicles.
   *
   * Without it the same driver could be saved by several vendors at once and
   * each would offer them for the same slot, which is exactly what the
   * registration-number check exists to stop. Phone was already unique, but a
   * phone is easy to change — a document number is not.
   *
   * Digits only for Aadhaar and uppercase-no-space for a licence, so
   * "9413 4584 9688" and "941345849688", or "mh09 20070270222" and
   * "MH0920070270222", collide the way a person would expect.
   *
   * A REJECTED row is ignored, for the same reason as the other guards: an
   * admin turning someone down must not leave the number locked away from
   * whoever legitimately employs that driver.
   */
  private async assertDocNumberNotDuplicate(
    userId: string,
    field: 'aadharNumber' | 'dlNumber',
    value?: string,
    exceptId?: string,
  ): Promise<void> {
    const isAadhar = field === 'aadharNumber';
    const bareJs = (value || '').replace(/[\s-]/g, '');
    const norm = isAadhar ? bareJs : bareJs.toUpperCase();
    // Too short to identify anyone — the DTO validates the real format.
    if (isAadhar ? norm.length !== 12 : norm.length < 6) return;

    // Mongo has no regex-replace, so strip the two separators people actually
    // type ("9413 4584 9688", "9413-4584-9688"). This has to match what the JS
    // side above does, or a stored row would never collide with a new one.
    const stripped = (input: any, ch: string) => ({ $replaceAll: { input, find: ch, replacement: '' } });
    const bare = stripped(stripped({ $ifNull: [`$${field}`, ''] }, ' '), '-');
    const normExpr = isAadhar ? bare : { $toUpper: bare };

    const query: any = {
      $expr: { $eq: [normExpr, norm] },
      approvalStatus: { $ne: 'rejected' },
    };
    if (exceptId) query._id = { $ne: new Types.ObjectId(exceptId) };

    const existing: any = await this.driverModel.findOne(query).select('userId').lean();
    if (!existing) return;

    const label = isAadhar ? 'Aadhaar number' : 'licence number';
    const mine = existing.userId?.toString() === userId;
    throw new BadRequestException(
      mine
        ? `You have already added a driver with this ${label}.`
        : `A driver with this ${label} is already registered in another account. Contact support if they work for you.`,
    );
  }

  async list(userId: string, approvedOnly = false) {
    const filter: any = { userId: new Types.ObjectId(userId) };
    if (approvedOnly) filter.approvalStatus = 'approved';
    const vehicles = await this.garageModel
      .find(filter)
      .sort({ createdAt: -1 })
      .lean();
    return { message: 'My vehicles', data: vehicles };
  }

  /**
   * When the admin has turned enforcement on, a vehicle may only be added by the
   * person it is registered to. Checked here and not just in the app, because the
   * app is the one part of this an attacker controls.
   *
   * A lookup that cannot run (no vendor keys, vendor down, no record) is NOT
   * treated as a mismatch - that would lock every user out of their own garage
   * the moment the vendor has a bad day.
   */
  /**
   * A registration number identifies one physical car, so it may exist in one
   * garage only — across the WHOLE platform, not just this account.
   *
   * Without this the same car could be added by several vendors and each would
   * offer it for the same slot. There was no duplicate check at all before:
   * not cross-account, not even within an account.
   *
   * A REJECTED row is ignored: an admin turning someone down must not leave the
   * number locked so the rightful owner can never add it. `exceptId` lets an
   * edit keep its own number.
   */
  private async assertRcNotInAnotherGarage(
    userId: string,
    registrationNumber?: string,
    exceptId?: string,
  ): Promise<void> {
    const rc = (registrationNumber || '').replace(/\s+/g, '').toUpperCase();
    if (!rc) return;

    const query: any = {
      // Stored uppercase by the schema, but old rows and spacing vary — match
      // on the normalised form so "RJ 19 AB 1234" and "RJ19AB1234" collide.
      $expr: {
        $eq: [{ $toUpper: { $replaceAll: { input: '$registrationNumber', find: ' ', replacement: '' } } }, rc],
      },
      approvalStatus: { $ne: 'rejected' },
    };
    if (exceptId) query._id = { $ne: new Types.ObjectId(exceptId) };

    const existing: any = await this.garageModel.findOne(query).select('userId').lean();
    if (!existing) return;

    const mine = existing.userId?.toString() === userId;
    throw new BadRequestException(
      mine
        ? 'This vehicle is already in your garage.'
        : 'This vehicle is already registered in another account. Contact support if it belongs to you.',
    );
  }

  private async assertRcOwnedByUser(userId: string, registrationNumber?: string): Promise<void> {
    const s: any = await this.settings.getSettings().catch(() => null);
    if (s?.verifyEnforceNameMatch !== true) return;
    if (!registrationNumber) return;

    const me: any = await this.userModel.findById(userId).select('fullName agencyName').lean();
    const claimed = (me?.fullName || me?.agencyName || '').trim();
    if (!claimed) return;

    const rc = await this.verification.lookupRc(registrationNumber, claimed).catch(() => null);
    if (!rc?.configured || !rc.found || !rc.nameMatch) return;
    if (!rc.nameMatch.matched) {
      throw new BadRequestException(
        'This vehicle is registered to a different name. You can only add a vehicle registered in your own name.',
      );
    }
  }

  async create(userId: string, dto: CreateGarageVehicleDto) {
    await this.assertRcNotInAnotherGarage(userId, dto.registrationNumber);
    await this.assertRcOwnedByUser(userId, dto.registrationNumber);
    const vehicle = await this.garageModel.create({
      ...dto,
      userId: new Types.ObjectId(userId),
    });
    return { message: 'Vehicle added', data: vehicle };
  }

  async update(userId: string, id: string, dto: UpdateGarageVehicleDto) {
    const vehicle = await this.owned(userId, id);
    // Any edit drops the row back to `pending` (below), which would hand a
    // blacklisted owner a one-tap way out of the ban. Refuse instead.
    if (vehicle.approvalStatus === 'blacklisted') {
      throw new BadRequestException(
        'This vehicle has been blocked by our team and cannot be edited. Please contact support.',
      );
    }
    // Changing the plate must clear the same bar as adding one, or the check
    // on create is trivially sidestepped by adding then editing.
    if (dto.registrationNumber !== undefined && dto.registrationNumber !== vehicle.registrationNumber) {
      await this.assertRcNotInAnotherGarage(userId, dto.registrationNumber, id);
      await this.assertRcOwnedByUser(userId, dto.registrationNumber);
    }
    Object.assign(vehicle, dto);
    // Any edit sends the vehicle back for admin review — details changed, so the
    // previous approval no longer applies.
    vehicle.approvalStatus = 'pending';
    vehicle.rejectionReason = '';
    vehicle.reviewedAt = undefined;
    vehicle.reviewedBy = undefined;
    await vehicle.save();
    return { message: 'Vehicle updated — sent for admin approval', data: vehicle };
  }

  async remove(userId: string, id: string) {
    await this.owned(userId, id);
    await this.garageModel.findByIdAndDelete(id);
    return { message: 'Vehicle removed' };
  }

  /** Fetch the vehicle and confirm it belongs to this user. */
  private async owned(userId: string, id: string): Promise<GarageVehicleDocument> {
    if (!Types.ObjectId.isValid(id)) throw new NotFoundException('Vehicle not found');
    const vehicle = await this.garageModel.findById(id);
    if (!vehicle) throw new NotFoundException('Vehicle not found');
    if (vehicle.userId.toString() !== userId) {
      throw new ForbiddenException('This vehicle is not yours');
    }
    return vehicle;
  }

  // ─── Drivers (My Drivers) ──────────────────────────────────────────────────

  async listDrivers(userId: string, approvedOnly = false) {
    const filter: any = { userId: new Types.ObjectId(userId) };
    if (approvedOnly) filter.approvalStatus = 'approved';
    const drivers = await this.driverModel
      .find(filter)
      .sort({ createdAt: -1 })
      .lean();
    return { message: 'My drivers', data: drivers };
  }

  async createDriver(userId: string, dto: CreateGarageDriverDto) {
    this.assertValidPhone(dto.phone);
    // ...not your own number, and not one this account already saved.
    await this.assertNotOwnNumber(userId, dto.phone);
    await this.assertPhoneNotDuplicate(userId, dto.phone);
    // One Aadhaar / one licence = one driver, platform-wide.
    await this.assertDocNumberNotDuplicate(userId, 'aadharNumber', dto.aadharNumber);
    await this.assertDocNumberNotDuplicate(userId, 'dlNumber', dto.dlNumber);
    const driver = await this.driverModel.create({
      ...dto,
      userId: new Types.ObjectId(userId),
    });
    return { message: 'Driver added', data: driver };
  }

  async updateDriver(userId: string, id: string, dto: UpdateGarageDriverDto) {
    const driver = await this.ownedDriver(userId, id);
    // Same escape hatch as vehicles — see update().
    if (driver.approvalStatus === 'blacklisted') {
      throw new BadRequestException(
        'This driver has been blocked by our team and cannot be edited. Please contact support.',
      );
    }
    // Re-validate whenever the phone is being set/changed.
    if (dto.phone !== undefined && dto.phone !== driver.phone) {
      this.assertValidPhone(dto.phone);
      await this.assertNotOwnNumber(userId, dto.phone);
      await this.assertPhoneNotDuplicate(userId, dto.phone, id);
    }
    if (dto.aadharNumber !== undefined && dto.aadharNumber !== driver.aadharNumber) {
      await this.assertDocNumberNotDuplicate(userId, 'aadharNumber', dto.aadharNumber, id);
    }
    if (dto.dlNumber !== undefined && dto.dlNumber !== driver.dlNumber) {
      await this.assertDocNumberNotDuplicate(userId, 'dlNumber', dto.dlNumber, id);
    }
    Object.assign(driver, dto);
    // Any edit sends the driver back for admin review.
    driver.approvalStatus = 'pending';
    driver.rejectionReason = '';
    driver.reviewedAt = undefined;
    driver.reviewedBy = undefined;
    await driver.save();
    return { message: 'Driver updated — sent for admin approval', data: driver };
  }

  async removeDriver(userId: string, id: string) {
    await this.ownedDriver(userId, id);
    await this.driverModel.findByIdAndDelete(id);
    return { message: 'Driver removed' };
  }

  /** Fetch the driver and confirm it belongs to this user. */
  private async ownedDriver(userId: string, id: string): Promise<GarageDriverDocument> {
    if (!Types.ObjectId.isValid(id)) throw new NotFoundException('Driver not found');
    const driver = await this.driverModel.findById(id);
    if (!driver) throw new NotFoundException('Driver not found');
    if (driver.userId.toString() !== userId) {
      throw new ForbiddenException('This driver is not yours');
    }
    return driver;
  }
}
