import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { GarageController } from './garage.controller';
import { GarageService } from './garage.service';
import { GarageVehicle, GarageVehicleSchema } from '../../database/schemas/garage-vehicle.schema';
import { GarageDriver, GarageDriverSchema } from '../../database/schemas/garage-driver.schema';
import { User, UserSchema } from '../../database/schemas/user.schema';

@Module({
  imports: [
    MongooseModule.forFeature([
      { name: GarageVehicle.name, schema: GarageVehicleSchema },
      { name: GarageDriver.name, schema: GarageDriverSchema },
      { name: User.name, schema: UserSchema },
    ]),
  ],
  controllers: [GarageController],
  providers: [GarageService],
})
export class GarageModule {}
