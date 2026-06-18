import { Controller, Get, Post, Body, Param, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { SubscriptionsService } from './subscriptions.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { Public } from '../../common/decorators/roles.decorator';

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

  @Post('test-activate/:planId')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth('access-token')
  @ApiOperation({ summary: 'TEST: Activate subscription without payment' })
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
