import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { VerificationService } from './verification.service';
import { VerificationController } from './verification.controller';
import { SettingsModule } from '../settings/settings.module';
import { User, UserSchema } from '../../database/schemas/user.schema';

@Module({
  imports: [SettingsModule, MongooseModule.forFeature([{ name: User.name, schema: UserSchema }])],
  controllers: [VerificationController],
  providers: [VerificationService],
  exports: [VerificationService],
})
export class VerificationModule {}
