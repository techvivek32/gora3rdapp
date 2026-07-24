import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { SettingsController } from './settings.controller';
import { SettingsService } from './settings.service';
import { PlatformSettings, PlatformSettingsSchema } from '../../database/schemas/settings.schema';
import { User, UserSchema } from '../../database/schemas/user.schema';
import { Franchise, FranchiseSchema } from '../../database/schemas/franchise.schema';

@Module({
  imports: [
    MongooseModule.forFeature([
      { name: PlatformSettings.name, schema: PlatformSettingsSchema },
      { name: User.name, schema: UserSchema },
      { name: Franchise.name, schema: FranchiseSchema },
    ]),
  ],
  controllers: [SettingsController],
  providers: [SettingsService],
  exports: [SettingsService],
})
export class SettingsModule {}
