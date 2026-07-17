import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { GarageController } from './garage.controller';
import { GarageService } from './garage.service';
import { GarageVehicle, GarageVehicleSchema } from '../../database/schemas/garage-vehicle.schema';

@Module({
  imports: [
    MongooseModule.forFeature([
      { name: GarageVehicle.name, schema: GarageVehicleSchema },
    ]),
  ],
  controllers: [GarageController],
  providers: [GarageService],
})
export class GarageModule {}
