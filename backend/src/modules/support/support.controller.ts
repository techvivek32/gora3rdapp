import { Controller, Get, Post, Body, Param, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { SupportService } from './support.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { UserRole } from '../../common/enums/user-role.enum';

// ─── User-facing support chat ─────────────────────────────────────────────────
@ApiTags('Support')
@ApiBearerAuth('access-token')
@UseGuards(JwtAuthGuard)
@Controller('support')
export class SupportController {
  constructor(private readonly supportService: SupportService) {}

  @Get('messages')
  @ApiOperation({ summary: 'Get my support chat messages' })
  getMyMessages(@CurrentUser('sub') userId: string) {
    return this.supportService.getMyMessages(userId);
  }

  @Post('messages')
  @ApiOperation({ summary: 'Send a message to support' })
  sendMessage(@CurrentUser('sub') userId: string, @Body('text') text: string) {
    return this.supportService.sendUserMessage(userId, text);
  }
}

// ─── Admin-facing support chats ──────────────────────────────────────────────
@ApiTags('Admin Support')
@ApiBearerAuth('access-token')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.ADMIN, UserRole.SUPER_ADMIN)
@Controller('admin/support')
export class SupportAdminController {
  constructor(private readonly supportService: SupportService) {}

  @Get('conversations')
  @ApiOperation({ summary: 'List all support conversations' })
  getConversations() {
    return this.supportService.getConversations();
  }

  @Get('conversations/:userId')
  @ApiOperation({ summary: "Get a user's support conversation" })
  getConversation(@Param('userId') userId: string) {
    return this.supportService.getConversation(userId);
  }

  @Post('conversations/:userId/reply')
  @ApiOperation({ summary: 'Reply to a user in support chat' })
  reply(@Param('userId') userId: string, @Body('text') text: string) {
    return this.supportService.adminReply(userId, text);
  }
}
