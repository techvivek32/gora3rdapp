import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { UsersController } from './users.controller';
import { UsersService } from './users.service';
import { User, UserSchema } from '../../database/schemas/user.schema';
import { AvailableVehicle, AvailableVehicleSchema } from '../../database/schemas/available-vehicle.schema';
import { Rating, RatingSchema } from '../../database/schemas/rating.schema';
import { StorageModule } from '../storage/storage.module';

@Module({
  imports: [
    MongooseModule.forFeature([
      { name: User.name, schema: UserSchema },
      { name: AvailableVehicle.name, schema: AvailableVehicleSchema },
      { name: Rating.name, schema: RatingSchema },
    ]),
    StorageModule,
  ],
  controllers: [UsersController],
  providers: [UsersService],
  exports: [UsersService],
})
export class UsersModule {}
