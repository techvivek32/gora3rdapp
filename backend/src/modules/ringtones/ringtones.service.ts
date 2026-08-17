import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { Ringtone, RingtoneDocument } from '../../database/schemas/ringtone.schema';
import { StorageService } from '../storage/storage.service';

@Injectable()
export class RingtonesService {
  constructor(
    @InjectModel(Ringtone.name) private ringtoneModel: Model<RingtoneDocument>,
    private readonly storageService: StorageService,
  ) {}

  async create(data: { title?: string; audioUrl?: string; sortOrder?: number }) {
    const title = (data.title || '').trim();
    const audioUrl = (data.audioUrl || '').trim();
    if (!title) throw new BadRequestException('Title is required');
    if (!audioUrl) throw new BadRequestException('Upload an audio file first');

    // First ringtone added becomes active automatically.
    const count = await this.ringtoneModel.countDocuments();
    const ringtone = await this.ringtoneModel.create({
      title,
      audioUrl,
      sortOrder: data.sortOrder ?? 0,
      isActive: count === 0,
    });
    return { message: 'Ringtone added', data: ringtone };
  }

  async findAll() {
    const data = await this.ringtoneModel.find().sort({ sortOrder: 1, createdAt: -1 }).lean();
    return { message: 'Ringtones', data };
  }

  async update(id: string, data: { title?: string; sortOrder?: number; isActive?: boolean }) {
    const update: any = {};
    if (data.title !== undefined) update.title = (data.title || '').trim();
    if (data.sortOrder !== undefined) update.sortOrder = data.sortOrder;

    // Only one ringtone may be active — turning one on turns the rest off.
    if (data.isActive === true) {
      await this.ringtoneModel.updateMany({ _id: { $ne: id } }, { $set: { isActive: false } });
      update.isActive = true;
    } else if (data.isActive === false) {
      update.isActive = false;
    }

    const ringtone = await this.ringtoneModel.findByIdAndUpdate(id, { $set: update }, { new: true });
    if (!ringtone) throw new NotFoundException('Ringtone not found');
    return { message: 'Ringtone updated', data: ringtone };
  }

  async remove(id: string) {
    const ringtone = await this.ringtoneModel.findByIdAndDelete(id);
    if (!ringtone) throw new NotFoundException('Ringtone not found');
    // Best-effort file cleanup — never fail the delete if storage removal errors.
    this.storageService.deleteFile(ringtone.audioUrl).catch(() => {});
    return { message: 'Ringtone deleted', data: { _id: id } };
  }
}
