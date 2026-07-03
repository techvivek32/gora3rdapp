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
import { Report, ReportSchema } from '../../database/schemas/report.schema';
import { Banner, BannerSchema } from '../../database/schemas/banner.schema';
import { City, CitySchema } from '../../database/schemas/city.schema';
import { SubscriptionPlan, SubscriptionPlanSchema } from '../../database/schemas/subscription.schema';
import { AuditLog, AuditLogSchema } from '../../database/schemas/audit-log.schema';
import { Notification, NotificationSchema } from '../../database/schemas/notification.schema';
import { NotificationsModule } from '../notifications/notifications.module';

@Module({
  imports: [
    MongooseModule.forFeature([
      { name: User.name, schema: UserSchema },
      { name: Requirement.name, schema: RequirementSchema },
      { name: AvailableVehicle.name, schema: AvailableVehicleSchema },
      { name: Payment.name, schema: PaymentSchema },
      { name: Subscription.name, schema: SubscriptionSchema },
      { name: WalletTransaction.name, schema: WalletTransactionSchema },
      { name: SubscriptionPlan.name, schema: SubscriptionPlanSchema },
      { name: Report.name, schema: ReportSchema },
      { name: Banner.name, schema: BannerSchema },
      { name: City.name, schema: CitySchema },
      { name: AuditLog.name, schema: AuditLogSchema },
      { name: Notification.name, schema: NotificationSchema },
    ]),
    NotificationsModule,
  ],
  controllers: [AdminController],
  providers: [AdminService],
  exports: [AdminService],
})
export class AdminModule {}
