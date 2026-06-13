import { Controller, Get, Post, Param, Query } from '@nestjs/common';
import { ApiTags, ApiOperation } from '@nestjs/swagger';
import { BannersService } from './banners.service';
import { Public } from '../../common/decorators/roles.decorator';

@ApiTags('Banners')
@Controller('banners')
export class BannersController {
  constructor(private readonly bannersService: BannersService) {}

  @Get()
  @Public()
  @ApiOperation({ summary: 'Get active banners' })
  getBanners(@Query('membershipType') membershipType?: string) {
    return this.bannersService.getActiveBanners(membershipType);
  }

  @Post(':id/click')
  @Public()
  @ApiOperation({ summary: 'Track banner click' })
  trackClick(@Param('id') id: string) {
    return this.bannersService.trackClick(id);
  }
}
