import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { RingtonesController } from './ringtones.controller';
import { RingtonesUserController } from './ringtones-user.controller';
import { RingtonesService } from './ringtones.service';
import { Ringtone, RingtoneSchema } from '../../database/schemas/ringtone.schema';

// StorageService is @Global(), so it needs no import here.
@Module({
  imports: [MongooseModule.forFeature([{ name: Ringtone.name, schema: RingtoneSchema }])],
  controllers: [RingtonesController, RingtonesUserController],
  providers: [RingtonesService],
})
export class RingtonesModule {}
