import { ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { GarageVehicle, GarageVehicleDocument } from '../../database/schemas/garage-vehicle.schema';
import { CreateGarageVehicleDto, UpdateGarageVehicleDto } from './dto/garage-vehicle.dto';

@Injectable()
export class GarageService {
  constructor(
    @InjectModel(GarageVehicle.name) private garageModel: Model<GarageVehicleDocument>,
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
}
