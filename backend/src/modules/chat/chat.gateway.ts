import {
  WebSocketGateway,
  WebSocketServer,
  SubscribeMessage,
  MessageBody,
  ConnectedSocket,
  OnGatewayInit,
  OnGatewayConnection,
  OnGatewayDisconnect,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { Logger, UseGuards } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { ChatService } from './chat.service';
import { User, UserDocument } from '../../database/schemas/user.schema';

@WebSocketGateway({
  cors: { origin: '*', credentials: true },
  namespace: '/chat',
  transports: ['websocket', 'polling'],
})
export class ChatGateway implements OnGatewayInit, OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer() server: Server;
  private readonly logger = new Logger(ChatGateway.name);
  private connectedUsers = new Map<string, string>(); // userId -> socketId

  constructor(
    private readonly chatService: ChatService,
    private readonly jwtService: JwtService,
    @InjectModel(User.name) private userModel: Model<UserDocument>,
  ) {}

  afterInit(server: Server) {
    this.logger.log('Chat WebSocket Gateway initialized');
  }

  async handleConnection(client: Socket) {
    try {
      const token = client.handshake.auth?.token || client.handshake.headers?.authorization?.split(' ')[1];
      if (!token) { client.disconnect(); return; }

      const payload = this.jwtService.verify(token);
      client.data.userId = payload.sub;
      this.connectedUsers.set(payload.sub, client.id);

      // Join user's personal room
      client.join(`user:${payload.sub}`);

      // Update last active
      await this.userModel.findByIdAndUpdate(payload.sub, { lastActive: new Date() });

      // Notify user is online
      this.server.emit('user:online', { userId: payload.sub });
      this.logger.log(`Client connected: ${client.id} (user: ${payload.sub})`);
    } catch (error) {
      this.logger.error('Connection auth failed:', error.message);
      client.disconnect();
    }
  }

  async handleDisconnect(client: Socket) {
    const userId = client.data.userId;
    if (userId) {
      this.connectedUsers.delete(userId);
      await this.userModel.findByIdAndUpdate(userId, { lastActive: new Date() });
      this.server.emit('user:offline', { userId });
    }
    this.logger.log(`Client disconnected: ${client.id}`);
  }

  @SubscribeMessage('chat:join')
  async handleJoinChat(@MessageBody() data: { chatId: string }, @ConnectedSocket() client: Socket) {
    client.join(`chat:${data.chatId}`);
    return { event: 'chat:joined', data: { chatId: data.chatId } };
  }

  @SubscribeMessage('chat:send-message')
  async handleSendMessage(
    @MessageBody() data: { chatId: string; content: string; type?: string },
    @ConnectedSocket() client: Socket,
  ) {
    const userId = client.data.userId;
    if (!userId) return;

    const message = await this.chatService.sendMessage(userId, data.chatId, {
      content: data.content,
      type: data.type as any || 'text',
    });

    // Broadcast to chat room
    this.server.to(`chat:${data.chatId}`).emit('chat:new-message', message);

    // Send push notification to offline users
    await this.chatService.notifyOfflineUsers(data.chatId, userId, message);

    return { event: 'chat:message-sent', data: message };
  }

  @SubscribeMessage('chat:typing')
  handleTyping(
    @MessageBody() data: { chatId: string; isTyping: boolean },
    @ConnectedSocket() client: Socket,
  ) {
    const userId = client.data.userId;
    client.to(`chat:${data.chatId}`).emit('chat:typing', { userId, isTyping: data.isTyping });
  }

  @SubscribeMessage('chat:mark-read')
  async handleMarkRead(
    @MessageBody() data: { chatId: string },
    @ConnectedSocket() client: Socket,
  ) {
    const userId = client.data.userId;
    await this.chatService.markMessagesRead(data.chatId, userId);
    this.server.to(`chat:${data.chatId}`).emit('chat:messages-read', { chatId: data.chatId, userId });
  }

  isUserOnline(userId: string): boolean {
    return this.connectedUsers.has(userId);
  }

  emitToUser(userId: string, event: string, data: any) {
    this.server.to(`user:${userId}`).emit(event, data);
  }
}
