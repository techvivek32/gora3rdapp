import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { TrainingController } from './training.controller';
import { TrainingService } from './training.service';
import { TrainingVideo, TrainingVideoSchema } from '../../database/schemas/training-video.schema';

@Module({
  imports: [
    MongooseModule.forFeature([
      { name: TrainingVideo.name, schema: TrainingVideoSchema },
    ]),
  ],
  controllers: [TrainingController],
  providers: [TrainingService],
})
export class TrainingModule {}
