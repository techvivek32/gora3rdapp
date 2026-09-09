import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { CustomerBookingsController } from './customer-bookings.controller';
import { CustomerBookingsService } from './customer-bookings.service';
import { CustomerBooking, CustomerBookingSchema } from '../../database/schemas/customer-booking.schema';
import { User, UserSchema } from '../../database/schemas/user.schema';
import { WalletTransaction, WalletTransactionSchema } from '../../database/schemas/wallet-transaction.schema';
import { NotificationsModule } from '../notifications/notifications.module';
import { SettingsModule } from '../settings/settings.module';

@Module({
  imports: [
    MongooseModule.forFeature([
      { name: CustomerBooking.name, schema: CustomerBookingSchema },
      { name: User.name, schema: UserSchema },
      { name: WalletTransaction.name, schema: WalletTransactionSchema },
    ]),
    NotificationsModule,
    SettingsModule,
  ],
  controllers: [CustomerBookingsController],
  providers: [CustomerBookingsService],
})
export class CustomerBookingsModule {}
