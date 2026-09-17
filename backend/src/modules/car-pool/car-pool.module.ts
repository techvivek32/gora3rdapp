import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { PoolRide, PoolRideSchema } from '../../database/schemas/pool-ride.schema';
import { User, UserSchema } from '../../database/schemas/user.schema';
import { NotificationsModule } from '../notifications/notifications.module';
import { CarPoolController } from './car-pool.controller';
import { CarPoolService } from './car-pool.service';

@Module({
  imports: [
    MongooseModule.forFeature([
      { name: PoolRide.name, schema: PoolRideSchema },
      { name: User.name, schema: UserSchema },
    ]),
    NotificationsModule,
  ],
  controllers: [CarPoolController],
  providers: [CarPoolService],
})
export class CarPoolModule {}
