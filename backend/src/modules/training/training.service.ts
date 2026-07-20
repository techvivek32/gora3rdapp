import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { TrainingVideo, TrainingVideoDocument } from '../../database/schemas/training-video.schema';

@Injectable()
export class TrainingService {
  constructor(
    @InjectModel(TrainingVideo.name) private videoModel: Model<TrainingVideoDocument>,
  ) {}

  /** Active videos for the app, in display order. */
  async listActive() {
    const videos = await this.videoModel
      .find({ isActive: true })
      .sort({ sortOrder: 1, createdAt: -1 })
      .lean();
    return { message: 'Training videos', data: videos };
  }

  /** Every video (incl. inactive) — admin. */
  async listAll() {
    const videos = await this.videoModel.find().sort({ sortOrder: 1, createdAt: -1 }).lean();
    return { message: 'Training videos', data: videos };
  }

  async create(data: { title: string; url: string; isActive?: boolean; sortOrder?: number }) {
    const video = await this.videoModel.create({
      title: (data.title || '').trim(),
      url: (data.url || '').trim(),
      isActive: data.isActive ?? true,
      sortOrder: Math.round(Number(data.sortOrder) || 0),
    });
    return { message: 'Training video added', data: video };
  }

  async update(id: string, data: Partial<{ title: string; url: string; isActive: boolean; sortOrder: number }>) {
    const update: any = {};
    if (data.title !== undefined) update.title = `${data.title}`.trim();
    if (data.url !== undefined) update.url = `${data.url}`.trim();
    if (data.isActive !== undefined) update.isActive = data.isActive;
    if (data.sortOrder !== undefined) update.sortOrder = Math.round(Number(data.sortOrder) || 0);

    const video = await this.videoModel.findByIdAndUpdate(id, update, { new: true });
    if (!video) throw new NotFoundException('Training video not found');
    return { message: 'Training video updated', data: video };
  }

  async remove(id: string) {
    const video = await this.videoModel.findByIdAndDelete(id);
    if (!video) throw new NotFoundException('Training video not found');
    return { message: 'Training video removed' };
  }
}
