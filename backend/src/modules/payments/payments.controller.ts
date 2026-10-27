import { Controller, Post, Headers, Body, RawBodyRequest, Req, HttpCode, HttpStatus, Logger } from '@nestjs/common';
import { ApiTags, ApiOperation } from '@nestjs/swagger';
import { Request } from 'express';
import { SubscriptionsService } from '../subscriptions/subscriptions.service';
import { WalletService } from '../wallet/wallet.service';
import { CustomerBookingsService } from '../customer-bookings/customer-bookings.service';
import { Public } from '../../common/decorators/roles.decorator';
import * as crypto from 'crypto';
import { SettingsService } from '../settings/settings.service';

@ApiTags('Payments')
@Controller('payments')
export class PaymentsController {
  private readonly logger = new Logger(PaymentsController.name);

  constructor(
    private readonly subscriptionsService: SubscriptionsService,
    private readonly settingsService: SettingsService,
    // A captured payment may be a wallet top-up or a booking advance, not just
    // a subscription — the webhook has to be able to settle all three.
    private readonly walletService: WalletService,
    private readonly customerBookingsService: CustomerBookingsService,
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
    // Never verify with an empty secret — an empty HMAC key is public, so an
    // attacker could forge a valid signature and activate paid memberships free.
    if (!webhookSecret || !signature) {
      return { status: 'invalid_signature' };
    }
    const rawBody = req.rawBody?.toString() || JSON.stringify(body);

    const expectedSig = crypto
      .createHmac('sha256', webhookSecret)
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
        // An order belongs to exactly one of these three, and each no-ops when
        // the order is not theirs — so try all three rather than guessing.
        //
        // Only subscriptions used to be handled here, which meant a wallet
        // top-up or a booking advance was credited ONLY by the app's own
        // verify call. If that call never landed the customer was charged and
        // nothing ever reconciled it. Each is awaited separately so one
        // failure cannot stop the others.
        //
        // (Do NOT call verifyPayment here: it re-checks the CHECKOUT signature
        // HMAC(orderId|paymentId, keySecret), which a webhook signature never
        // matches — that path always failed and even flipped paid orders to
        // FAILED. The webhook body HMAC above is what authenticates this.)
        try {
          await this.walletService.creditTopUpByOrderId(payment.order_id, payment.id);
        } catch (e: any) {
          this.logger.error(`Webhook wallet credit failed for ${payment.order_id}: ${e?.message ?? e}`);
        }
        try {
          await this.customerBookingsService.applyAdvanceByOrderId(payment.order_id, payment.id);
        } catch (e: any) {
          this.logger.error(`Webhook advance apply failed for ${payment.order_id}: ${e?.message ?? e}`);
        }
        try {
          await this.subscriptionsService.markOrderPaidAndActivate(payment.order_id, payment.id);
        } catch (e: any) {
          this.logger.error(`Webhook subscription activate failed for ${payment.order_id}: ${e?.message ?? e}`);
        }
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
