import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { Payment, PaymentSchema } from '../../database/schemas/payment.schema';
import { PaymentsController } from './payments.controller';
import { SubscriptionsModule } from '../subscriptions/subscriptions.module';
import { SettingsModule } from '../settings/settings.module';
import { WalletModule } from '../wallet/wallet.module';
import { CustomerBookingsModule } from '../customer-bookings/customer-bookings.module';

@Module({
  imports: [
    MongooseModule.forFeature([{ name: Payment.name, schema: PaymentSchema }]),
    SubscriptionsModule,
    SettingsModule,
    // A captured payment can be a wallet top-up or a booking advance, not only
    // a subscription — the webhook settles all three.
    WalletModule,
    CustomerBookingsModule,
  ],
  controllers: [PaymentsController],
})
export class PaymentsModule {}
