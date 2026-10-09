import { Injectable, NotFoundException, ForbiddenException } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { Chat, ChatDocument, Message, MessageDocument, MessageType } from '../../database/schemas/chat.schema';
import { User, UserDocument } from '../../database/schemas/user.schema';
import { FirebaseService } from '../firebase/firebase.service';
import { getPaginationParams } from '../../common/utils/pagination.util';

@Injectable()
export class ChatService {
  constructor(
    @InjectModel(Chat.name) private chatModel: Model<ChatDocument>,
    @InjectModel(Message.name) private messageModel: Model<MessageDocument>,
    @InjectModel(User.name) private userModel: Model<UserDocument>,
    private firebaseService: FirebaseService,
  ) {}

  async getOrCreateChat(userId1: string, userId2: string, requirementId?: string) {
    const reqId = requirementId && Types.ObjectId.isValid(requirementId) ? new Types.ObjectId(requirementId) : undefined;
    const existingChat = await this.chatModel.findOne({
      participants: { $all: [new Types.ObjectId(userId1), new Types.ObjectId(userId2)] },
    });

    if (existingChat) {
      // Link (or re-link) to the booking this chat was opened from so the list
      // + header can show the booking id / route / date.
      if (reqId && existingChat.relatedRequirement?.toString() !== reqId.toString()) {
        existingChat.relatedRequirement = reqId;
        await existingChat.save();
      }
      return existingChat;
    }

    return this.chatModel.create({
      participants: [new Types.ObjectId(userId1), new Types.ObjectId(userId2)],
      unreadCount: { [userId1]: 0, [userId2]: 0 },
      ...(reqId ? { relatedRequirement: reqId } : {}),
    });
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
