import { Controller, Get, UseGuards } from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation } from '@nestjs/swagger';
import { PopupAdsService } from './popup-ads.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';

// App-facing: any logged-in user fetches the active ad to show on app open.
@ApiTags('Popup Ads')
@ApiBearerAuth('access-token')
@UseGuards(JwtAuthGuard)
@Controller('popup-ads')
export class PopupAdsUserController {
  constructor(private readonly service: PopupAdsService) {}

  @Get('active')
  @ApiOperation({ summary: 'The active popup ad to show on app open (or null)' })
  getActive() {
    return this.service.getActive();
  }
}
