import { Controller, Get, Post, Body, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { WalletService } from './wallet.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { CreateTopUpDto, VerifyTopUpDto, RequestWithdrawalDto, TransferFundsDto } from './dto/wallet.dto';

@ApiTags('Wallet')
@ApiBearerAuth('access-token')
@UseGuards(JwtAuthGuard)
@Controller('wallet')
export class WalletController {
  constructor(private readonly walletService: WalletService) {}

  @Get()
  @ApiOperation({ summary: 'Get wallet balance and recent transactions' })
  getWallet(@CurrentUser('sub') userId: string) {
    return this.walletService.getWallet(userId);
  }

  @Post('create-order')
  @ApiOperation({ summary: 'Create a Razorpay order to add money to the wallet' })
  createOrder(@CurrentUser('sub') userId: string, @Body() dto: CreateTopUpDto) {
    return this.walletService.createTopUpOrder(userId, dto);
  }

  @Post('verify')
  @ApiOperation({ summary: 'Verify the payment and credit the wallet' })
  verify(@CurrentUser('sub') userId: string, @Body() dto: VerifyTopUpDto) {
    return this.walletService.verifyTopUp(userId, dto);
  }

  @Post('withdraw')
  @ApiOperation({ summary: 'Request a withdrawal (debits the wallet until reviewed)' })
  withdraw(@CurrentUser('sub') userId: string, @Body() dto: RequestWithdrawalDto) {
    return this.walletService.requestWithdrawal(userId, dto);
  }

  @Post('transfer')
  @ApiOperation({ summary: "Transfer money to another user's wallet by mobile number" })
  transfer(@CurrentUser('sub') userId: string, @Body() dto: TransferFundsDto) {
    return this.walletService.transferFunds(userId, dto);
  }
}
