import { Injectable, Logger, NotFoundException, BadRequestException } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { Ringtone, RingtoneDocument } from '../../database/schemas/ringtone.schema';
import { StorageService } from '../storage/storage.service';

@Injectable()
export class RingtonesService {
  private readonly logger = new Logger(RingtonesService.name);

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

  /**
   * Make one ringtone the default for an alert kind (or clear it).
   *
   * Exclusive per kind: setting a new default clears it from every other tone
   * first, so there is never more than one default for a kind — the app picks
   * the first match and two defaults would make the winner arbitrary.
   */
  async setDefault(id: string, kind: 'popup' | 'notification', value: boolean) {
    const field = kind === 'notification' ? 'isDefaultNotification' : 'isDefaultPopup';
    const exists = await this.ringtoneModel.exists({ _id: id });
    if (!exists) throw new NotFoundException('Ringtone not found');

    if (value) {
      await this.ringtoneModel.updateMany({ _id: { $ne: id } }, { $set: { [field]: false } });
    }
    const ringtone = await this.ringtoneModel.findByIdAndUpdate(id, { $set: { [field]: value } }, { new: true });
    return {
      message: value ? `Set as the default ${kind} tone` : `Removed as the default ${kind} tone`,
      data: ringtone,
    };
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
    // If this was a default, the app would keep asking for a file that no longer
    // exists. It falls back to the bundled tone on its own, but say so clearly.
    if (ringtone.isDefaultPopup || ringtone.isDefaultNotification) {
      this.logger.warn(`Deleted ringtone "${ringtone.title}" was a default — new users fall back to the bundled tone until another is set.`);
    }
    // Best-effort file cleanup — never fail the delete if storage removal errors.
    this.storageService.deleteFile(ringtone.audioUrl).catch(() => {});
    return { message: 'Ringtone deleted', data: { _id: id } };
  }
}
