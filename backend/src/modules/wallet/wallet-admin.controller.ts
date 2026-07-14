import { Controller, Get, Post, Body, Param, Query, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { WalletService } from './wallet.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { UserRole } from '../../common/enums/user-role.enum';
import { AdjustWalletDto, RejectWithdrawalDto, TransferFundsDto } from './dto/wallet.dto';

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

  @Post(':id/transfer')
  @ApiOperation({ summary: "Transfer from this user's wallet to another user (same as the app's transfer)" })
  transfer(@Param('id') userId: string, @Body() dto: TransferFundsDto) {
    // Reuses the app's transfer: race-safe debit, insufficient-balance guard and
    // the two matching transaction records. :id is the SENDER.
    return this.walletService.transferFunds(userId, dto);
  }

  // ─── Withdrawals ───────────────────────────────────────────────────────────

  @Get('withdrawals')
  @ApiOperation({ summary: 'List withdrawal requests' })
  getWithdrawals(@Query() query: any) {
    return this.walletService.getWithdrawals(query);
  }

  @Post('withdrawals/:id/approve')
  @ApiOperation({ summary: 'Approve a withdrawal request' })
  approveWithdrawal(@CurrentUser('sub') adminId: string, @Param('id') id: string) {
    return this.walletService.approveWithdrawal(adminId, id);
  }

  @Post('withdrawals/:id/reject')
  @ApiOperation({ summary: 'Reject a withdrawal request and refund the amount' })
  rejectWithdrawal(
    @CurrentUser('sub') adminId: string,
    @Param('id') id: string,
    @Body() dto: RejectWithdrawalDto,
  ) {
    return this.walletService.rejectWithdrawal(adminId, id, dto);
  }

  // Declared LAST on purpose: ':id' is a wildcard, so above the withdrawals routes
  // it would swallow GET /admin/wallets/withdrawals as id="withdrawals".
  @Get(':id')
  @ApiOperation({ summary: "One user's wallet balance + transactions" })
  getOne(@Param('id') userId: string) {
    return this.walletService.getWallet(userId);
  }
}
