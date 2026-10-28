import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { GarageController } from './garage.controller';
import { GarageService } from './garage.service';
import { GarageVehicle, GarageVehicleSchema } from '../../database/schemas/garage-vehicle.schema';
import { GarageDriver, GarageDriverSchema } from '../../database/schemas/garage-driver.schema';
import { User, UserSchema } from '../../database/schemas/user.schema';
import { VerificationModule } from '../verification/verification.module';
import { SettingsModule } from '../settings/settings.module';

@Module({
  imports: [
    MongooseModule.forFeature([
      { name: GarageVehicle.name, schema: GarageVehicleSchema },
      { name: GarageDriver.name, schema: GarageDriverSchema },
      { name: User.name, schema: UserSchema },
    ]),
    VerificationModule,
    SettingsModule,
  ],
  controllers: [GarageController],
  providers: [GarageService],
  // The admin panel adds vehicles/drivers on a member's behalf through this
  // same service, so the duplicate and validation rules stay in one place.
  exports: [GarageService],
})
export class GarageModule {}
