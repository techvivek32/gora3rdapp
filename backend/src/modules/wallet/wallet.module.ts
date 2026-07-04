import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { WalletController } from './wallet.controller';
import { WalletAdminController } from './wallet-admin.controller';
import { WalletService } from './wallet.service';
import { User, UserSchema } from '../../database/schemas/user.schema';
import { WalletTransaction, WalletTransactionSchema } from '../../database/schemas/wallet-transaction.schema';
import { WithdrawalRequest, WithdrawalRequestSchema } from '../../database/schemas/withdrawal-request.schema';

@Module({
  imports: [
    MongooseModule.forFeature([
      { name: User.name, schema: UserSchema },
      { name: WalletTransaction.name, schema: WalletTransactionSchema },
      { name: WithdrawalRequest.name, schema: WithdrawalRequestSchema },
    ]),
  ],
  controllers: [WalletController, WalletAdminController],
  providers: [WalletService],
})
export class WalletModule {}
