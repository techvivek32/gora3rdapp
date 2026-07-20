import { Injectable, BadRequestException } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { SupportMessage, SupportMessageDocument } from '../../database/schemas/support-message.schema';
import { User, UserDocument } from '../../database/schemas/user.schema';
import { FirebaseService } from '../firebase/firebase.service';

@Injectable()
export class SupportService {
  constructor(
    @InjectModel(SupportMessage.name) private msgModel: Model<SupportMessageDocument>,
    @InjectModel(User.name) private userModel: Model<UserDocument>,
    private firebaseService: FirebaseService,
  ) {}

  // ─── User side ─────────────────────────────────────────────────────────────
  async getMyMessages(userId: string) {
    const uid = new Types.ObjectId(userId);
    // Mark admin messages as read now that the user is viewing the chat.
    await this.msgModel.updateMany({ userId: uid, sender: 'admin', read: false }, { read: true });
    const messages = await this.msgModel.find({ userId: uid }).sort({ createdAt: 1 }).lean();
    return { message: 'Messages retrieved', data: messages };
  }

  async sendUserMessage(userId: string, text: string) {
    const clean = (text || '').trim();
    if (!clean) throw new BadRequestException('Message cannot be empty');
    const msg = await this.msgModel.create({
      userId: new Types.ObjectId(userId),
      sender: 'user',
      text: clean.slice(0, 2000),
      read: false,
    });
    return { message: 'Sent', data: msg };
  }

  // ─── Franchise city-scoping helpers (see AdminService for the rationale) ──────
  private cityRx(city: string) {
    return new RegExp(`^${city.trim().replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}$`, 'i');
  }
  private cityMatches(a?: string | null, b?: string | null) {
    return (a || '').trim().toLowerCase() === (b || '').trim().toLowerCase();
  }
  private async assertUserInCity(userId: string, franchiseCity?: string | null) {
    if (!franchiseCity) return;
    if (!Types.ObjectId.isValid(userId)) throw new BadRequestException('Not found');
    const u = await this.userModel.findById(userId).select('city').lean();
    if (!u || !this.cityMatches((u as any).city, franchiseCity)) {
      throw new BadRequestException('Not found');
    }
  }

  // ─── Admin side ────────────────────────────────────────────────────────────
  async getConversations(franchiseCity?: string | null) {
    const rows = await this.msgModel.aggregate([
      { $sort: { createdAt: -1 } },
      {
        $group: {
          _id: '$userId',
          lastMessage: { $first: '$text' },
          lastMessageAt: { $first: '$createdAt' },
          lastSender: { $first: '$sender' },
          unread: {
            $sum: { $cond: [{ $and: [{ $eq: ['$sender', 'user'] }, { $eq: ['$read', false] }] }, 1, 0] },
          },
        },
      },
      { $sort: { lastMessageAt: -1 } },
      { $lookup: { from: 'users', localField: '_id', foreignField: '_id', as: 'user' } },
      { $unwind: { path: '$user', preserveNullAndEmptyArrays: true } },
      // Franchise: keep only conversations with users in their city.
      ...(franchiseCity ? [{ $match: { 'user.city': this.cityRx(franchiseCity) } }] : []),
      {
        $project: {
          _id: 0,
          userId: '$_id',
          name: { $ifNull: ['$user.fullName', 'User'] },
          mobile: { $ifNull: ['$user.mobile', ''] },
          profileImage: '$user.profileImage',
          lastMessage: 1,
          lastMessageAt: 1,
          lastSender: 1,
          unread: 1,
        },
      },
    ]);
    return { message: 'Conversations retrieved', data: rows };
  }

  async getConversation(userId: string, franchiseCity?: string | null) {
    await this.assertUserInCity(userId, franchiseCity);
    const uid = new Types.ObjectId(userId);
    // Admin is viewing → mark the user's messages as read.
    await this.msgModel.updateMany({ userId: uid, sender: 'user', read: false }, { read: true });
    const [user, messages] = await Promise.all([
      this.userModel.findById(userId).select('fullName mobile profileImage').lean(),
      this.msgModel.find({ userId: uid }).sort({ createdAt: 1 }).lean(),
    ]);
    return { message: 'Conversation retrieved', data: { user, messages } };
  }

  async adminReply(userId: string, text: string, franchiseCity?: string | null) {
    await this.assertUserInCity(userId, franchiseCity);
    const clean = (text || '').trim();
    if (!clean) throw new BadRequestException('Reply cannot be empty');

    const msg = await this.msgModel.create({
      userId: new Types.ObjectId(userId),
      sender: 'admin',
      text: clean.slice(0, 2000),
      read: false,
    });

    // Best-effort push notification to the user.
    try {
      const user = await this.userModel.findById(userId).select('fcmTokens').lean();
      const tokens = (user?.fcmTokens ?? []).filter(Boolean);
      if (tokens.length) {
        await this.firebaseService.sendPushNotification(tokens, {
          title: 'Gora Cabs Support',
          body: clean.length > 120 ? `${clean.slice(0, 120)}…` : clean,
          data: { type: 'support_chat' },
        });
      }
    } catch {
      /* ignore push failures */
    }

    return { message: 'Reply sent', data: msg };
  }
}
