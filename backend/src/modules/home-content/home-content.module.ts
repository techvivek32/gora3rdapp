import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import {
  CabCategory,
  CabCategorySchema,
  CityImage,
  CityImageSchema,
  HomeShowcase,
  HomeShowcaseSchema,
} from '../../database/schemas/home-content.schema';
import { HomeContentController } from './home-content.controller';
import { HomeContentService } from './home-content.service';

@Module({
  imports: [
    MongooseModule.forFeature([
      { name: HomeShowcase.name, schema: HomeShowcaseSchema },
      { name: CityImage.name, schema: CityImageSchema },
      { name: CabCategory.name, schema: CabCategorySchema },
    ]),
  ],
  controllers: [HomeContentController],
  providers: [HomeContentService],
})
export class HomeContentModule {}
