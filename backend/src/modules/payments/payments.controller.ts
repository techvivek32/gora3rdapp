import { Controller, Post, Headers, Body, RawBodyRequest, Req, HttpCode, HttpStatus } from '@nestjs/common';
import { ApiTags, ApiOperation } from '@nestjs/swagger';
import { Request } from 'express';
import { SubscriptionsService } from '../subscriptions/subscriptions.service';
import { Public } from '../../common/decorators/roles.decorator';
import * as crypto from 'crypto';
import { ConfigService } from '@nestjs/config';

@ApiTags('Payments')
@Controller('payments')
export class PaymentsController {
  constructor(
    private readonly subscriptionsService: SubscriptionsService,
    private readonly configService: ConfigService,
  ) {}

  @Public()
  @Post('webhook/razorpay')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Razorpay webhook handler' })
  async handleRazorpayWebhook(
    @Headers('x-razorpay-signature') signature: string,
    @Body() body: any,
    @Req() req: RawBodyRequest<Request>,
  ) {
    const webhookSecret = this.configService.get<string>('razorpay.webhookSecret');
    const rawBody = req.rawBody?.toString() || JSON.stringify(body);

    const expectedSig = crypto
      .createHmac('sha256', webhookSecret!)
      .update(rawBody)
      .digest('hex');

    if (expectedSig !== signature) {
      return { status: 'invalid_signature' };
    }

    const event = body?.event;
    if (event === 'payment.captured') {
      const payment = body?.payload?.payment?.entity;
      if (payment) {
        try {
          await this.subscriptionsService.verifyPayment(null, {
            razorpayOrderId: payment.order_id,
            razorpayPaymentId: payment.id,
            razorpaySignature: signature,
          });
        } catch (_) {}
      }
    }

    return { status: 'ok' };
  }
}
