import { ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { GarageVehicle, GarageVehicleDocument } from '../../database/schemas/garage-vehicle.schema';
import { GarageDriver, GarageDriverDocument } from '../../database/schemas/garage-driver.schema';
import { CreateGarageVehicleDto, UpdateGarageVehicleDto } from './dto/garage-vehicle.dto';
import { CreateGarageDriverDto, UpdateGarageDriverDto } from './dto/garage-driver.dto';

@Injectable()
export class GarageService {
  constructor(
    @InjectModel(GarageVehicle.name) private garageModel: Model<GarageVehicleDocument>,
    @InjectModel(GarageDriver.name) private driverModel: Model<GarageDriverDocument>,
  ) {}

  async list(userId: string) {
    const vehicles = await this.garageModel
      .find({ userId: new Types.ObjectId(userId) })
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
    await vehicle.save();
    return { message: 'Vehicle updated', data: vehicle };
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

  async listDrivers(userId: string) {
    const drivers = await this.driverModel
      .find({ userId: new Types.ObjectId(userId) })
      .sort({ createdAt: -1 })
      .lean();
    return { message: 'My drivers', data: drivers };
  }

  async createDriver(userId: string, dto: CreateGarageDriverDto) {
    const driver = await this.driverModel.create({
      ...dto,
      userId: new Types.ObjectId(userId),
    });
    return { message: 'Driver added', data: driver };
  }

  async updateDriver(userId: string, id: string, dto: UpdateGarageDriverDto) {
    const driver = await this.ownedDriver(userId, id);
    Object.assign(driver, dto);
    await driver.save();
    return { message: 'Driver updated', data: driver };
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
