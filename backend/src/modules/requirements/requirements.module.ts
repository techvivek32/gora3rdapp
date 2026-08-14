import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { RequirementsController } from './requirements.controller';
import { RequirementsService } from './requirements.service';
import { Requirement, RequirementSchema } from '../../database/schemas/requirement.schema';
import { User, UserSchema } from '../../database/schemas/user.schema';
import { Notification, NotificationSchema } from '../../database/schemas/notification.schema';
import { NotificationsModule } from '../notifications/notifications.module';
import { SettingsModule } from '../settings/settings.module';

@Module({
  imports: [
    MongooseModule.forFeature([
      { name: Requirement.name, schema: RequirementSchema },
      { name: User.name, schema: UserSchema },
      { name: Notification.name, schema: NotificationSchema },
    ]),
    NotificationsModule,
    SettingsModule,
  ],
  controllers: [RequirementsController],
  providers: [RequirementsService],
  exports: [RequirementsService],
})
export class RequirementsModule {}
