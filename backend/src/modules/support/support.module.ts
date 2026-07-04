import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { SupportController, SupportAdminController } from './support.controller';
import { SupportService } from './support.service';
import { SupportMessage, SupportMessageSchema } from '../../database/schemas/support-message.schema';
import { User, UserSchema } from '../../database/schemas/user.schema';

@Module({
  imports: [
    MongooseModule.forFeature([
      { name: SupportMessage.name, schema: SupportMessageSchema },
      { name: User.name, schema: UserSchema },
    ]),
  ],
  controllers: [SupportController, SupportAdminController],
  providers: [SupportService],
})
export class SupportModule {}
