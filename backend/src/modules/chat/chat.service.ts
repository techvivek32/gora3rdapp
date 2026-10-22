import { Injectable, NotFoundException, ForbiddenException } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { Chat, ChatDocument, Message, MessageDocument, MessageType } from '../../database/schemas/chat.schema';
import { User, UserDocument } from '../../database/schemas/user.schema';
import { Requirement, RequirementDocument } from '../../database/schemas/requirement.schema';
import { FirebaseService } from '../firebase/firebase.service';
import { getPaginationParams } from '../../common/utils/pagination.util';

@Injectable()
export class ChatService {
  constructor(
    @InjectModel(Chat.name) private chatModel: Model<ChatDocument>,
    @InjectModel(Message.name) private messageModel: Model<MessageDocument>,
    @InjectModel(User.name) private userModel: Model<UserDocument>,
    @InjectModel(Requirement.name) private requirementModel: Model<RequirementDocument>,
    private firebaseService: FirebaseService,
  ) {}

  /**
   * True when the user currently has a paid membership. Mirrors
   * RequirementsService.isPaidMember and the app's `canContactPosters`, expiry
   * included: a lapsed plan is the free tier even before the downgrade sweep.
   */
  private isPaidMember(user: any): boolean {
    if (!user) return false;
    if (user.membershipExpiresAt && new Date(user.membershipExpiresAt) < new Date()) {
      return false;
    }
    return ['active', 'verified', 'premium', 'golden'].includes(user.membershipType) || user.isPremium === true;
  }

  /**
   * @param requirePaidToStart gate for user-initiated chats: reaching out to a
   *   poster is a paid feature, like Call and WhatsApp. Only STARTING a new
   *   thread is gated — an existing one still opens, so a driver whose chat the
   *   owner opened (see postDriverDetails) is never locked out of it, and
   *   neither is anyone who chatted while their plan was live. Internal callers
   *   leave this off.
   */
  async getOrCreateChat(
    userId1: string,
    userId2: string,
    requirementId?: string,
    requirePaidToStart = false,
  ) {
    const reqId = requirementId && Types.ObjectId.isValid(requirementId) ? new Types.ObjectId(requirementId) : undefined;

    // The booking is part of the key. Looking up by participants alone meant a
    // second booking with the same driver landed in the first booking's thread,
    // mixing the two conversations together.
    const existingChat = await this.chatModel.findOne({
      participants: { $all: [new Types.ObjectId(userId1), new Types.ObjectId(userId2)] },
      ...(reqId
        ? { relatedRequirement: reqId }
        : { relatedRequirement: { $in: [null, undefined] } }),
    });

    if (existingChat) return existingChat;

    if (requirePaidToStart) {
      const starter = await this.userModel
        .findById(userId1)
        .select('membershipType membershipExpiresAt isPremium')
        .lean();
      if (!this.isPaidMember(starter)) {
        throw new ForbiddenException('Buy a membership plan to chat with posters.');
      }
    }

    const chat = await this.chatModel.create({
      participants: [new Types.ObjectId(userId1), new Types.ObjectId(userId2)],
      unreadCount: { [userId1]: 0, [userId2]: 0 },
      ...(reqId ? { relatedRequirement: reqId } : {}),
    });

    // Opening a chat about a booking shares who you are up front: the person
    // starting it posts their driver + vehicle details as the first message, so
    // the other side never has to ask. Best effort — a chat is still created if
    // we can't build the card.
    if (reqId) {
      try {
        const card = await this.driverDetailsCard(userId1, reqId.toString());
        if (card) await this.postDetailsMessage(chat, userId1, card);
      } catch {
        /* never block chat creation on the intro message */
      }
    }

    return chat;
  }

  /** Write a DRIVER_DETAILS message into `chat` and bump the other side's unread. */
  private async postDetailsMessage(chat: any, senderId: string, content: string) {
    const message = await this.messageModel.create({
      chatId: chat._id,
      senderId: new Types.ObjectId(senderId),
      content,
      type: MessageType.DRIVER_DETAILS,
    });
    const unreadUpdate: any = {};
    (chat.participants as any[]).forEach((pid) => {
      if (pid.toString() !== senderId) {
        unreadUpdate[`unreadCount.${pid}`] = (chat.unreadCount?.[pid.toString()] || 0) + 1;
      }
    });
    await this.chatModel.findByIdAndUpdate(chat._id, {
      lastMessage: message._id,
      lastMessageText: 'Driver & vehicle details',
      lastMessageAt: new Date(),
      ...unreadUpdate,
    });
    return message;
  }

  /**
   * "Driver Name / Contact / Vehicle Registration / Vehicle Type" for a user.
   * Returns '' when we know nothing useful, so the caller can skip posting.
   */
  private async driverDetailsCard(userId: string, requirementId?: string): Promise<string> {
    const u: any = await this.userModel
      .findById(userId)
      .select('fullName agencyName mobile documents')
      .lean();
    if (!u) return '';
    const name = (u.agencyName || u.fullName || '').trim();
    const phone = (u.mobile || '').trim();
    const rc: any = u.documents?.vehicleRc || {};
    const reg = (rc.number || rc.documentNumber || '').trim();

    let vehicleType = '';
    if (requirementId && Types.ObjectId.isValid(requirementId)) {
      const r: any = await this.requirementModel
        .findById(requirementId)
        .select('vehicleType')
        .lean();
      vehicleType = (r?.vehicleType || '').trim();
    }

    if (!name && !phone && !reg && !vehicleType) return '';
    return [
      `Driver Name: ${name || '-'}`,
      `Contact Number: ${phone || '-'}`,
      `Vehicle Registration: ${reg || '-'}`,
      `Vehicle Type: ${vehicleType || '-'}`,
    ].join('\n');
  }

  /** Id (string) of the other participant in a chat. */
  private otherParticipantId(participants: any[], userId: string): string | undefined {
    return participants
      .map((p) => (p?._id?.toString?.() ?? p?.toString?.()))
      .find((id) => id && id !== userId);
  }

  /** Fetch the given users keyed by id (manual populate — reliable across modules). */
  private async usersById(ids: string[]): Promise<Map<string, any>> {
    const uniq = [...new Set(ids.filter(Boolean))];
    if (!uniq.length) return new Map();
    const users = await this.userModel
      .find({ _id: { $in: uniq.map((id) => new Types.ObjectId(id)) } })
      .select('fullName agencyName profileImage lastActive membershipType isVerified')
      .lean();
    return new Map(users.map((u: any) => [u._id.toString(), u]));
  }

  async getUserChats(userId: string): Promise<any> {
    const chats = await this.chatModel
      .find({
        participants: new Types.ObjectId(userId),
        isActive: true,
      })
      .populate('lastMessage')
      .populate('relatedRequirement', 'bookingId pickupCity dropCity pickup drop travelDate travelTime tripType vehicleType')
      .sort({ lastMessageAt: -1 })
      .lean();

    // Manually attach the OTHER participant's profile (populate('participants') is
    // unreliable here, so fetch them directly with the injected User model).
    const otherIds = chats.map((c) => this.otherParticipantId(c.participants as any[], userId));
    const userMap = await this.usersById(otherIds.filter(Boolean) as string[]);

    return {
      message: 'Chats retrieved',
      data: chats.map((chat) => {
        const otherId = this.otherParticipantId(chat.participants as any[], userId);
        return {
          ...chat,
          otherUser: otherId ? userMap.get(otherId) ?? null : null,
          unreadCount: chat.unreadCount?.[userId] || 0,
        };
      }),
    };
  }

  /**
   * The same chats as `getUserChats`, but grouped by the booking they belong to.
   *
   * A posted booking can attract several drivers, each opening their own 1:1
   * thread. A flat list makes that look like unrelated conversations, so the app
   * shows one row per BOOKING with the number of drivers who messaged, and the
   * threads nested underneath.
   *
   * Chats with no booking attached (plain profile-to-profile messages) are
   * returned in a single trailing group with `booking: null`.
   */
  async getUserChatsGrouped(userId: string): Promise<any> {
    const { data: chats } = await this.getUserChats(userId);

    const groups = new Map<string, any>();
    for (const chat of chats as any[]) {
      const booking = chat.relatedRequirement || null;
      const key = booking?._id ? booking._id.toString() : '__direct__';
      if (!groups.has(key)) {
        groups.set(key, {
          key,
          booking,
          chats: [],
          driverCount: 0,
          unreadCount: 0,
          lastMessageAt: null as Date | null,
        });
      }
      const g = groups.get(key);
      // The nested thread only needs enough to render a row and open the room.
      g.chats.push({
        _id: chat._id,
        otherUser: chat.otherUser,
        lastMessageText: chat.lastMessageText,
        lastMessageAt: chat.lastMessageAt,
        unreadCount: chat.unreadCount,
      });
      g.driverCount += 1;
      g.unreadCount += chat.unreadCount || 0;
      if (!g.lastMessageAt || (chat.lastMessageAt && chat.lastMessageAt > g.lastMessageAt)) {
        g.lastMessageAt = chat.lastMessageAt;
      }
    }

    // Most recently active booking first; the no-booking group always last.
    const data = [...groups.values()].sort((a, b) => {
      if (!a.booking) return 1;
      if (!b.booking) return -1;
      return new Date(b.lastMessageAt || 0).getTime() - new Date(a.lastMessageAt || 0).getTime();
    });

    return { message: 'Chats grouped by booking', data };
  }

  /** Single chat with the other participant + linked booking, for the room header. */
  async getChatDetail(chatId: string, userId: string) {
    if (!Types.ObjectId.isValid(chatId)) throw new NotFoundException('Chat not found');
    const chat: any = await this.chatModel
      .findById(chatId)
      .populate('relatedRequirement', 'bookingId pickupCity dropCity pickup drop travelDate travelTime tripType vehicleType fare commission status postedBy assignedDriver secureBooking')
      .lean();
    if (!chat) throw new NotFoundException('Chat not found');
    const isParticipant = (chat.participants as any[]).some((p) => (p?._id?.toString?.() ?? p?.toString?.()) === userId);
    if (!isParticipant) throw new ForbiddenException('Not a participant in this chat');
    const otherId = this.otherParticipantId(chat.participants as any[], userId);
    const other = otherId ? (await this.usersById([otherId])).get(otherId) : null;
    return { message: 'Chat', data: { ...chat, otherUser: other ?? null } };
  }

  async getChatMessages(chatId: string, userId: string, page = 1, limit = 50) {
    const chat = await this.chatModel.findById(chatId);
    if (!chat) throw new NotFoundException('Chat not found');

    const isParticipant = chat.participants.some((p) => p.toString() === userId);
    if (!isParticipant) throw new ForbiddenException('Not a participant in this chat');

    const { skip } = getPaginationParams({ page, limit });

    const messages = await this.messageModel
      .find({ chatId: new Types.ObjectId(chatId), isDeleted: false })
      .populate('senderId', 'fullName profileImage')
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit)
      .lean();

    // Flag the caller's own messages so the app can right-align them.
    const withMine = messages.reverse().map((m: any) => ({
      ...m,
      isMe: (m.senderId?._id?.toString?.() ?? m.senderId?.toString?.()) === userId,
    }));
    return { message: 'Messages retrieved', data: withMine };
  }

  /** True only if the user is a participant of the chat (used to gate socket joins). */
  async isParticipant(userId: string, chatId: string): Promise<boolean> {
    if (!Types.ObjectId.isValid(chatId)) return false;
    const chat = await this.chatModel.findById(chatId).select('participants').lean();
    return !!chat && (chat.participants as any[]).some((p) => p.toString() === userId);
  }

  async sendMessage(userId: string, chatId: string, data: { content: string; type: MessageType }) {
    const chat = await this.chatModel.findById(chatId);
    if (!chat) throw new NotFoundException('Chat not found');
    // Only a participant may post — stops injecting messages into other people's chats.
    if (!chat.participants.some((p) => p.toString() === userId)) {
      throw new ForbiddenException('Not a participant in this chat');
    }

    const message = await this.messageModel.create({
      chatId: new Types.ObjectId(chatId),
      senderId: new Types.ObjectId(userId),
      content: data.content,
      type: data.type || MessageType.TEXT,
    });

    // Update chat's last message
    const unreadUpdate: any = {};
    chat.participants.forEach((participantId) => {
      if (participantId.toString() !== userId) {
        unreadUpdate[`unreadCount.${participantId}`] = (chat.unreadCount?.[participantId.toString()] || 0) + 1;
      }
    });

    await this.chatModel.findByIdAndUpdate(chatId, {
      lastMessage: message._id,
      lastMessageText: data.content.substring(0, 100),
      lastMessageAt: new Date(),
      ...unreadUpdate,
    });

    return await this.messageModel.findById(message._id).populate('senderId', 'fullName profileImage').lean();
  }

  /**
   * Auto-post the assigned driver's details into the owner↔driver chat (creating
   * the chat if needed). Sent as the driver so it reads as "the driver's details"
   * to the owner. Used by the requirements module when a driver is assigned.
   */
  async postDriverDetails(ownerId: string, driverId: string, requirementId: string, content: string) {
    const chat = await this.getOrCreateChat(ownerId, driverId, requirementId);
    const message = await this.messageModel.create({
      chatId: chat._id,
      senderId: new Types.ObjectId(driverId),
      content,
      type: MessageType.DRIVER_DETAILS,
    });
    const unreadUpdate: any = {};
    (chat.participants as any[]).forEach((pid) => {
      if (pid.toString() !== driverId) {
        unreadUpdate[`unreadCount.${pid}`] = (chat.unreadCount?.[pid.toString()] || 0) + 1;
      }
    });
    await this.chatModel.findByIdAndUpdate(chat._id, {
      lastMessage: message._id,
      lastMessageText: 'Driver & vehicle details',
      lastMessageAt: new Date(),
      ...unreadUpdate,
    });
    return message;
  }

  async markMessagesRead(chatId: string, userId: string) {
    await this.messageModel.updateMany(
      { chatId: new Types.ObjectId(chatId), senderId: { $ne: new Types.ObjectId(userId) } },
      { $addToSet: { readBy: new Types.ObjectId(userId) } },
    );

    await this.chatModel.findByIdAndUpdate(chatId, {
      [`unreadCount.${userId}`]: 0,
    });
  }

  async notifyOfflineUsers(chatId: string, senderId: string, message: any) {
    const chat = await this.chatModel.findById(chatId).populate('participants', 'fcmTokens fullName');
    if (!chat) return;

    const sender = await this.userModel.findById(senderId).select('fullName');

    for (const participant of chat.participants as any[]) {
      if (participant._id.toString() !== senderId && participant.fcmTokens?.length) {
        await this.firebaseService.sendPushNotification(participant.fcmTokens, {
          title: `💬 ${sender?.fullName || 'New Message'}`,
          body: message.content,
          data: { chatId, type: 'new_message' },
        }).catch(() => {});
      }
    }
  }
}
