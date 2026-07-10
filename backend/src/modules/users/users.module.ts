import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { UsersController } from './users.controller';
import { UsersService } from './users.service';
import { User, UserSchema } from '../../database/schemas/user.schema';
import { AvailableVehicle, AvailableVehicleSchema } from '../../database/schemas/available-vehicle.schema';
import { Rating, RatingSchema } from '../../database/schemas/rating.schema';
import { AccountDeletionRequest, AccountDeletionRequestSchema } from '../../database/schemas/account-deletion-request.schema';
import { StorageModule } from '../storage/storage.module';

@Module({
  imports: [
    MongooseModule.forFeature([
      { name: User.name, schema: UserSchema },
      { name: AvailableVehicle.name, schema: AvailableVehicleSchema },
      { name: Rating.name, schema: RatingSchema },
      { name: AccountDeletionRequest.name, schema: AccountDeletionRequestSchema },
    ]),
    StorageModule,
  ],
  controllers: [UsersController],
  providers: [UsersService],
  exports: [UsersService],
})
export class UsersModule {}
