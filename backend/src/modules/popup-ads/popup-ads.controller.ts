import { Controller, Get, Post, Put, Delete, Body, Param, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { PopupAdsService } from './popup-ads.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { UserRole } from '../../common/enums/user-role.enum';

// Admin-only (admin + super_admin), like banners — franchises are blocked.
@ApiTags('Popup Ads')
@ApiBearerAuth('access-token')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.ADMIN, UserRole.SUPER_ADMIN)
@Controller('admin/popup-ads')
export class PopupAdsController {
  constructor(private readonly service: PopupAdsService) {}

  @Post()
  @ApiOperation({ summary: 'Add a popup ad (image + optional link)' })
  create(@Body() data: { imageUrl?: string; linkUrl?: string }) {
    return this.service.create(data);
  }

  @Get()
  @ApiOperation({ summary: 'List all popup ads' })
  findAll() {
    return this.service.findAll();
  }

  @Put(':id')
  @ApiOperation({ summary: 'Update / set-active a popup ad' })
  update(@Param('id') id: string, @Body() data: { linkUrl?: string; isActive?: boolean }) {
    return this.service.update(id, data);
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Delete a popup ad' })
  remove(@Param('id') id: string) {
    return this.service.remove(id);
  }
}
