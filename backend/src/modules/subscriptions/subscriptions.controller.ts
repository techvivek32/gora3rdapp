import { Controller, Get, Post, Body, Param, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { SubscriptionsService } from './subscriptions.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { Public, Roles } from '../../common/decorators/roles.decorator';
import { UserRole } from '../../common/enums/user-role.enum';

@ApiTags('Subscriptions')
@Controller('subscriptions')
export class SubscriptionsController {
  constructor(private readonly subscriptionsService: SubscriptionsService) {}

  @Get('plans')
  @Public()
  @ApiOperation({ summary: 'Get all active membership plans' })
  getPlans() {
    return this.subscriptionsService.getActivePlans();
  }

  @Post('create-order/:planId')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth('access-token')
  @ApiOperation({ summary: 'Create Razorpay payment order for a plan' })
  createOrder(@CurrentUser('sub') userId: string, @Param('planId') planId: string) {
    return this.subscriptionsService.createPaymentOrder(userId, planId);
  }

  @Post('create-qr-order/:planId')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth('access-token')
  @ApiOperation({ summary: 'Create a Razorpay UPI QR for a plan (Pay by QR)' })
  createQrOrder(@CurrentUser('sub') userId: string, @Param('planId') planId: string) {
    return this.subscriptionsService.createQrOrder(userId, planId);
  }

  @Get('payment-status/:paymentId')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth('access-token')
  @ApiOperation({ summary: 'Poll a payment status (used by the QR flow)' })
  paymentStatus(@CurrentUser('sub') userId: string, @Param('paymentId') paymentId: string) {
    return this.subscriptionsService.getPaymentStatus(paymentId, userId);
  }

  @Post('verify-payment')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth('access-token')
  @ApiOperation({ summary: 'Verify Razorpay payment and activate subscription' })
  verifyPayment(@CurrentUser('sub') userId: string, @Body() data: {
    razorpayOrderId: string;
    razorpayPaymentId: string;
    razorpaySignature: string;
  }) {
    return this.subscriptionsService.verifyPayment(userId, data);
  }

  // ADMIN-ONLY: activates a plan without payment. Must never be open to normal
  // users (that would be free premium for everyone).
  @Post('test-activate/:planId')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.ADMIN, UserRole.SUPER_ADMIN)
  @ApiBearerAuth('access-token')
  @ApiOperation({ summary: 'ADMIN: Activate subscription without payment (testing)' })
  testActivateSubscription(@CurrentUser('sub') userId: string, @Param('planId') planId: string) {
    return this.subscriptionsService.testActivateSubscription(userId, planId);
  }

  @Get('my-subscription')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth('access-token')
  @ApiOperation({ summary: 'Get current user subscription' })
  getMySubscription(@CurrentUser('sub') userId: string) {
    return this.subscriptionsService.getUserSubscription(userId);
  }
}
