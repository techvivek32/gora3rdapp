import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { Payment, PaymentSchema } from '../../database/schemas/payment.schema';
import { PaymentsController } from './payments.controller';
import { SubscriptionsModule } from '../subscriptions/subscriptions.module';
import { SettingsModule } from '../settings/settings.module';

@Module({
  imports: [
    MongooseModule.forFeature([{ name: Payment.name, schema: PaymentSchema }]),
    SubscriptionsModule,
    SettingsModule,
  ],
  controllers: [PaymentsController],
})
export class PaymentsModule {}
