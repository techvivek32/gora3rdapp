import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { WalletController } from './wallet.controller';
import { CustomerWalletController } from './customer-wallet.controller';
import { WalletAdminController } from './wallet-admin.controller';
import { WalletService } from './wallet.service';
import { User, UserSchema } from '../../database/schemas/user.schema';
import { WalletTransaction, WalletTransactionSchema } from '../../database/schemas/wallet-transaction.schema';
import { WithdrawalRequest, WithdrawalRequestSchema } from '../../database/schemas/withdrawal-request.schema';
import { SettingsModule } from '../settings/settings.module';
import { Requirement, RequirementSchema } from '../../database/schemas/requirement.schema';
import { CustomerBooking, CustomerBookingSchema } from '../../database/schemas/customer-booking.schema';

@Module({
  imports: [
    MongooseModule.forFeature([
      { name: User.name, schema: UserSchema },
      { name: WalletTransaction.name, schema: WalletTransactionSchema },
      { name: WithdrawalRequest.name, schema: WithdrawalRequestSchema },
      // Read-only, so the wallet can show a transaction's route instead of a
      // bare booking id — see WalletService.attachRoutes.
      { name: Requirement.name, schema: RequirementSchema },
      { name: CustomerBooking.name, schema: CustomerBookingSchema },
    ]),
    SettingsModule,
  ],
  controllers: [WalletController, CustomerWalletController, WalletAdminController],
  providers: [WalletService],
  // The Razorpay webhook settles wallet top-ups too, so PaymentsModule needs this.
  exports: [WalletService],
})
export class WalletModule {}
