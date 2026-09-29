import { Controller, Get, Post, Param, Body, Query, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { ChatService } from './chat.service';
import { ChatGateway } from './chat.gateway';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';

@ApiTags('Chat')
@ApiBearerAuth('access-token')
@UseGuards(JwtAuthGuard)
@Controller('chats')
export class ChatController {
  constructor(
    private readonly chatService: ChatService,
    private readonly chatGateway: ChatGateway,
  ) {}

  @Get()
  @ApiOperation({ summary: 'Get all user chats' })
  getUserChats(@CurrentUser('sub') userId: string): Promise<any> {
    return this.chatService.getUserChats(userId);
  }

  @Post('with/:userId')
  @ApiOperation({ summary: 'Get or create chat with a user (optionally linked to a booking)' })
  getOrCreateChat(
    @CurrentUser('sub') userId: string,
    @Param('userId') targetUserId: string,
    @Query('requirementId') requirementId?: string,
    @Body() body?: { requirementId?: string },
  ) {
    return this.chatService.getOrCreateChat(userId, targetUserId, requirementId || body?.requirementId);
  }

  @Get(':chatId')
  @ApiOperation({ summary: 'Chat detail (other participant + linked booking) for the header' })
  getChatDetail(@Param('chatId') chatId: string, @CurrentUser('sub') userId: string) {
    return this.chatService.getChatDetail(chatId, userId);
  }

  @Get(':chatId/messages')
  @ApiOperation({ summary: 'Get chat messages' })
  getChatMessages(
    @Param('chatId') chatId: string,
    @CurrentUser('sub') userId: string,
    @Query('page') page?: number,
    @Query('limit') limit?: number,
  ) {
    return this.chatService.getChatMessages(chatId, userId, page, limit);
  }

  @Post(':chatId/messages')
  @ApiOperation({ summary: 'Send a message (HTTP; also broadcast over the socket)' })
  async sendMessage(
    @Param('chatId') chatId: string,
    @CurrentUser('sub') userId: string,
    @Body() body: { content: string; type?: string },
  ) {
    const message: any = await this.chatService.sendMessage(userId, chatId, {
      content: body.content,
      type: (body.type as any) || 'text',
    });
    // Real-time deliver to the room (the other participant) + push to offline.
    this.chatGateway.broadcastNewMessage(chatId, message);
    await this.chatService.notifyOfflineUsers(chatId, userId, message);
    // The caller is the sender → mark their own message so the app right-aligns it.
    return { message: 'Message sent', data: { ...message, isMe: true } };
  }
}
