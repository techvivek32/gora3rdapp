import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { AvailableVehiclesController } from './available-vehicles.controller';
import { AvailableVehiclesService } from './available-vehicles.service';
import { AvailableVehicle, AvailableVehicleSchema } from '../../database/schemas/available-vehicle.schema';
import { User, UserSchema } from '../../database/schemas/user.schema';
import { NotificationsModule } from '../notifications/notifications.module';

@Module({
  imports: [
    MongooseModule.forFeature([
      { name: AvailableVehicle.name, schema: AvailableVehicleSchema },
      { name: User.name, schema: UserSchema },
    ]),
    NotificationsModule,
  ],
  controllers: [AvailableVehiclesController],
  providers: [AvailableVehiclesService],
  exports: [AvailableVehiclesService],
})
export class AvailableVehiclesModule {}
