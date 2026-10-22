import { Controller, Get, Post, Body, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { WalletService } from './wallet.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { CreateTopUpDto, VerifyTopUpDto, RequestWithdrawalDto, TransferFundsDto } from './dto/wallet.dto';

/**
 * The customer-mode wallet — the same operations as WalletController, but every
 * one of them is scoped to the user's SEPARATE `customerWalletBalance`. The two
 * wallets live on one account and never mix: topping up here does not raise the
 * driver-side balance and so never satisfies MIN_WALLET_BALANCE, and a transfer
 * from here lands in the recipient's customer wallet.
 *
 * The scope is fixed by the route, never taken from the request body, so a
 * client cannot aim a customer-wallet call at the driver wallet (or vice versa).
 */
@ApiTags('Customer Wallet')
@ApiBearerAuth('access-token')
@UseGuards(JwtAuthGuard)
@Controller('customer-wallet')
export class CustomerWalletController {
  constructor(private readonly walletService: WalletService) {}

  @Get()
  @ApiOperation({ summary: 'Get customer wallet balance and recent transactions' })
  getWallet(@CurrentUser('sub') userId: string) {
    return this.walletService.getWallet(userId, undefined, 'customer');
  }

  @Post('create-order')
  @ApiOperation({ summary: 'Create a Razorpay order to add money to the customer wallet' })
  createOrder(@CurrentUser('sub') userId: string, @Body() dto: CreateTopUpDto) {
    return this.walletService.createTopUpOrder(userId, dto, 'customer');
  }

  @Post('verify')
  @ApiOperation({ summary: 'Verify the payment and credit the customer wallet' })
  verify(@CurrentUser('sub') userId: string, @Body() dto: VerifyTopUpDto) {
    // Which wallet gets credited comes from the pending transaction created by
    // create-order above, so this needs no scope of its own.
    return this.walletService.verifyTopUp(userId, dto);
  }

  @Post('withdraw')
  @ApiOperation({ summary: 'Request a withdrawal from the customer wallet' })
  withdraw(@CurrentUser('sub') userId: string, @Body() dto: RequestWithdrawalDto) {
    return this.walletService.requestWithdrawal(userId, dto, 'customer');
  }

  @Post('transfer')
  @ApiOperation({ summary: "Transfer to another user's CUSTOMER wallet by mobile number" })
  transfer(@CurrentUser('sub') userId: string, @Body() dto: TransferFundsDto) {
    return this.walletService.transferFunds(userId, dto, undefined, 'customer');
  }
}
