import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { PopupAdsController } from './popup-ads.controller';
import { PopupAdsUserController } from './popup-ads-user.controller';
import { PopupAdsService } from './popup-ads.service';
import { PopupAd, PopupAdSchema } from '../../database/schemas/popup-ad.schema';

// StorageService is @Global(), so it needs no import here.
@Module({
  imports: [MongooseModule.forFeature([{ name: PopupAd.name, schema: PopupAdSchema }])],
  controllers: [PopupAdsController, PopupAdsUserController],
  providers: [PopupAdsService],
})
export class PopupAdsModule {}
