import { Controller, Get, Post, Param, Body, Query, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { ChatService } from './chat.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';

@ApiTags('Chat')
@ApiBearerAuth('access-token')
@UseGuards(JwtAuthGuard)
@Controller('chats')
export class ChatController {
  constructor(private readonly chatService: ChatService) {}

  @Get()
  @ApiOperation({ summary: 'Get all user chats' })
  getUserChats(@CurrentUser('sub') userId: string): Promise<any> {
    return this.chatService.getUserChats(userId);
  }

  @Post('with/:userId')
  @ApiOperation({ summary: 'Get or create chat with a user' })
  getOrCreateChat(@CurrentUser('sub') userId: string, @Param('userId') targetUserId: string) {
    return this.chatService.getOrCreateChat(userId, targetUserId);
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
}
