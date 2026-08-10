import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { WhatsappController } from './whatsapp.controller';
import { WhatsappService } from './whatsapp.service';
import { WhatsappAiService } from './whatsapp-ai.service';
import { User, UserSchema } from '../../database/schemas/user.schema';
import { RequirementsModule } from '../requirements/requirements.module';
import { PlacesModule } from '../places/places.module';
import { SettingsModule } from '../settings/settings.module';

@Module({
  imports: [
    MongooseModule.forFeature([{ name: User.name, schema: UserSchema }]),
    // Reuse the app's own booking creation (booking id, expiry, new-requirement
    // notifications) so a WhatsApp booking behaves exactly like an in-app one.
    RequirementsModule,
    // Distance (Google Directions) + platform rates, to fill in the same
    // app-suggested fare / commission / total an in-app booking would have.
    PlacesModule,
    SettingsModule,
  ],
  controllers: [WhatsappController],
  providers: [WhatsappService, WhatsappAiService],
})
export class WhatsappModule {}
