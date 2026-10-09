import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { GarageVehicle, GarageVehicleDocument } from '../../database/schemas/garage-vehicle.schema';
import { GarageDriver, GarageDriverDocument } from '../../database/schemas/garage-driver.schema';
import { User, UserDocument } from '../../database/schemas/user.schema';
import { CreateGarageVehicleDto, UpdateGarageVehicleDto } from './dto/garage-vehicle.dto';
import { CreateGarageDriverDto, UpdateGarageDriverDto } from './dto/garage-driver.dto';

// A saved driver's number must belong to a real driver/vendor account in the app.

@Injectable()
export class GarageService {
  constructor(
    @InjectModel(GarageVehicle.name) private garageModel: Model<GarageVehicleDocument>,
    @InjectModel(GarageDriver.name) private driverModel: Model<GarageDriverDocument>,
    @InjectModel(User.name) private userModel: Model<UserDocument>,
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
   * Prevent the same phone number being saved twice in one account's driver list.
   * Compares on the last 10 digits; `exceptId` skips the driver being edited.
   */
  private async assertPhoneNotDuplicate(userId: string, phone?: string, exceptId?: string): Promise<void> {
    const last10 = (phone || '').replace(/\D/g, '').slice(-10);
    if (last10.length !== 10) return; // format already validated elsewhere
    const query: any = { userId: new Types.ObjectId(userId), phone: last10 };
    if (exceptId) query._id = { $ne: new Types.ObjectId(exceptId) };
    const existing = await this.driverModel.findOne(query).select('_id').lean();
    if (existing) {
      throw new BadRequestException('You have already added a driver with this number.');
    }
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

  async create(userId: string, dto: CreateGarageVehicleDto) {
    const vehicle = await this.garageModel.create({
      ...dto,
      userId: new Types.ObjectId(userId),
    });
    return { message: 'Vehicle added', data: vehicle };
  }

  async update(userId: string, id: string, dto: UpdateGarageVehicleDto) {
    const vehicle = await this.owned(userId, id);
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
    // Only allow saving a driver whose number is a registered driver/vendor.
    this.assertValidPhone(dto.phone);
    // ...and not one this account already saved.
    await this.assertPhoneNotDuplicate(userId, dto.phone);
    const driver = await this.driverModel.create({
      ...dto,
      userId: new Types.ObjectId(userId),
    });
    return { message: 'Driver added', data: driver };
  }

  async updateDriver(userId: string, id: string, dto: UpdateGarageDriverDto) {
    const driver = await this.ownedDriver(userId, id);
    // Re-validate whenever the phone is being set/changed.
    if (dto.phone !== undefined && dto.phone !== driver.phone) {
      this.assertValidPhone(dto.phone);
      await this.assertPhoneNotDuplicate(userId, dto.phone, id);
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
