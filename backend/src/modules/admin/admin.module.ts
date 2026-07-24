import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { AdminController } from './admin.controller';
import { AdminService } from './admin.service';
import { User, UserSchema } from '../../database/schemas/user.schema';
import { Requirement, RequirementSchema } from '../../database/schemas/requirement.schema';
import { AvailableVehicle, AvailableVehicleSchema } from '../../database/schemas/available-vehicle.schema';
import { Payment, PaymentSchema } from '../../database/schemas/payment.schema';
import { Subscription, SubscriptionSchema } from '../../database/schemas/subscription.schema';
import { WalletTransaction, WalletTransactionSchema } from '../../database/schemas/wallet-transaction.schema';
import { WithdrawalRequest, WithdrawalRequestSchema } from '../../database/schemas/withdrawal-request.schema';
import { Rating, RatingSchema } from '../../database/schemas/rating.schema';
import { Report, ReportSchema } from '../../database/schemas/report.schema';
import { Banner, BannerSchema } from '../../database/schemas/banner.schema';
import { City, CitySchema } from '../../database/schemas/city.schema';
import { SubscriptionPlan, SubscriptionPlanSchema } from '../../database/schemas/subscription.schema';
import { AuditLog, AuditLogSchema } from '../../database/schemas/audit-log.schema';
import { Notification, NotificationSchema } from '../../database/schemas/notification.schema';
import { AccountDeletionRequest, AccountDeletionRequestSchema } from '../../database/schemas/account-deletion-request.schema';
import { Franchise, FranchiseSchema } from '../../database/schemas/franchise.schema';
import { FranchiseSettlement, FranchiseSettlementSchema } from '../../database/schemas/franchise-settlement.schema';
import { NotificationsModule } from '../notifications/notifications.module';
import { RequirementsModule } from '../requirements/requirements.module';
import { AvailableVehiclesModule } from '../available-vehicles/available-vehicles.module';

@Module({
  imports: [
    MongooseModule.forFeature([
      { name: User.name, schema: UserSchema },
      { name: Requirement.name, schema: RequirementSchema },
      { name: AvailableVehicle.name, schema: AvailableVehicleSchema },
      { name: Payment.name, schema: PaymentSchema },
      { name: Subscription.name, schema: SubscriptionSchema },
      { name: WalletTransaction.name, schema: WalletTransactionSchema },
      { name: WithdrawalRequest.name, schema: WithdrawalRequestSchema },
      { name: Rating.name, schema: RatingSchema },
      { name: SubscriptionPlan.name, schema: SubscriptionPlanSchema },
      { name: Report.name, schema: ReportSchema },
      { name: Banner.name, schema: BannerSchema },
      { name: City.name, schema: CitySchema },
      { name: AuditLog.name, schema: AuditLogSchema },
      { name: Notification.name, schema: NotificationSchema },
      { name: AccountDeletionRequest.name, schema: AccountDeletionRequestSchema },
      { name: Franchise.name, schema: FranchiseSchema },
      { name: FranchiseSettlement.name, schema: FranchiseSettlementSchema },
    ]),
    NotificationsModule,
    // Admin "post on behalf of a user" reuses these services, so booking ids,
    // expiry and the new-requirement notifications behave exactly as they do in
    // the app rather than being reimplemented here.
    RequirementsModule,
    AvailableVehiclesModule,
  ],
  controllers: [AdminController],
  providers: [AdminService],
  exports: [AdminService],
})
export class AdminModule {}
