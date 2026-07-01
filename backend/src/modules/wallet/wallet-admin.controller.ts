import { Controller, Get, Post, Body, Param, Query, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { WalletService } from './wallet.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { UserRole } from '../../common/enums/user-role.enum';
import { AdjustWalletDto } from './dto/wallet.dto';

@ApiTags('Admin Wallets')
@ApiBearerAuth('access-token')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.ADMIN, UserRole.SUPER_ADMIN)
@Controller('admin/wallets')
export class WalletAdminController {
  constructor(private readonly walletService: WalletService) {}

  @Get()
  @ApiOperation({ summary: 'List all users with their wallet balance' })
  getAll(@Query() query: { page?: number; limit?: number; search?: string }) {
    return this.walletService.getAllWalletsForAdmin(query);
  }

  @Post(':id/adjust')
  @ApiOperation({ summary: "Add or cut a user's wallet balance with a reason" })
  adjust(
    @CurrentUser('sub') adminId: string,
    @Param('id') userId: string,
    @Body() dto: AdjustWalletDto,
  ) {
    return this.walletService.adjustWallet(adminId, userId, dto);
  }
}
