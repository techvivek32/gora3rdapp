import { Controller, Get, UseGuards } from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation } from '@nestjs/swagger';
import { PopupAdsService } from './popup-ads.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';

// App-facing: any logged-in user fetches the active ad to show on app open.
@ApiTags('Popup Ads')
@ApiBearerAuth('access-token')
@UseGuards(JwtAuthGuard)
@Controller('popup-ads')
export class PopupAdsUserController {
  constructor(private readonly service: PopupAdsService) {}

  @Get('active')
  @ApiOperation({ summary: 'The active popup ad for this side of the app (or null)' })
  getActive(@CurrentUser('role') role: string) {
    // Same binary serves both sides, so the account's current role decides
    // which campaign it sees — the app can't pick for itself.
    return this.service.getActive(role === 'customer' ? 'customer' : 'driver');
  }
}
