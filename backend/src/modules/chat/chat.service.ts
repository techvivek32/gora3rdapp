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

  async getOrCreateChat(userId1: string, userId2: string) {
    const existingChat = await this.chatModel.findOne({
      participants: { $all: [new Types.ObjectId(userId1), new Types.ObjectId(userId2)] },
    });

    if (existingChat) return existingChat;

    return this.chatModel.create({
      participants: [new Types.ObjectId(userId1), new Types.ObjectId(userId2)],
      unreadCount: { [userId1]: 0, [userId2]: 0 },
    });
  }

  async getUserChats(userId: string): Promise<any> {
    const chats = await this.chatModel
      .find({
        participants: new Types.ObjectId(userId),
        isActive: true,
      })
      .populate('participants', 'fullName agencyName profileImage lastActive membershipType isVerified')
      .populate('lastMessage')
      .sort({ lastMessageAt: -1 })
      .lean();

    return {
      message: 'Chats retrieved',
      data: chats.map((chat) => ({
        ...chat,
        unreadCount: chat.unreadCount?.[userId] || 0,
      })),
    };
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

    return { message: 'Messages retrieved', data: messages.reverse() };
  }

  async sendMessage(userId: string, chatId: string, data: { content: string; type: MessageType }) {
    const chat = await this.chatModel.findById(chatId);
    if (!chat) throw new NotFoundException('Chat not found');

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
