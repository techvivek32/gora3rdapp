import { Controller, Post, Headers, Body, RawBodyRequest, Req, HttpCode, HttpStatus } from '@nestjs/common';
import { ApiTags, ApiOperation } from '@nestjs/swagger';
import { Request } from 'express';
import { SubscriptionsService } from '../subscriptions/subscriptions.service';
import { Public } from '../../common/decorators/roles.decorator';
import * as crypto from 'crypto';
import { SettingsService } from '../settings/settings.service';

@ApiTags('Payments')
@Controller('payments')
export class PaymentsController {
  constructor(
    private readonly subscriptionsService: SubscriptionsService,
    private readonly settingsService: SettingsService,
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
    const keys = await this.settingsService.getRazorpayKeys();
    const webhookSecret = keys.webhookSecret;
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
      // QR payments arrive as payment.captured too but have no order_id — those are
      // handled by the qr_code.credited branch below, so skip them here.
      if (payment && payment.order_id) {
        try {
          // The webhook body HMAC was already verified above, so this order is
          // authentic — activate directly. (Do NOT call verifyPayment here: it
          // re-checks the CHECKOUT signature HMAC(orderId|paymentId, keySecret),
          // which the webhook signature never matches — that path always failed
          // and even flipped paid orders to FAILED.)
          await this.subscriptionsService.markOrderPaidAndActivate(payment.order_id, payment.id);
        } catch (_) {}
      }
    } else if (event === 'qr_code.credited') {
      // Someone scanned a "Pay by QR" code and paid. Match it back to its pending
      // payment via the QR id and activate the membership.
      const qr = body?.payload?.qr_code?.entity;
      const payment = body?.payload?.payment?.entity;
      if (qr?.id) {
        try {
          await this.subscriptionsService.handleQrCredited(qr.id, payment?.id);
        } catch (_) {}
      }
    }

    return { status: 'ok' };
  }
}
