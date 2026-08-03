import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { WhatsappController } from './whatsapp.controller';
import { WhatsappService } from './whatsapp.service';
import { User, UserSchema } from '../../database/schemas/user.schema';
import { RequirementsModule } from '../requirements/requirements.module';

@Module({
  imports: [
    MongooseModule.forFeature([{ name: User.name, schema: UserSchema }]),
    // Reuse the app's own booking creation (booking id, expiry, new-requirement
    // notifications) so a WhatsApp booking behaves exactly like an in-app one.
    RequirementsModule,
  ],
  controllers: [WhatsappController],
  providers: [WhatsappService],
})
export class WhatsappModule {}
