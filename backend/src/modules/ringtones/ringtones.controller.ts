import { Controller, Get, Post, Put, Delete, Body, Param, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { RingtonesService } from './ringtones.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { UserRole } from '../../common/enums/user-role.enum';

// Admin-only (admin + super_admin). No FRANCHISE_ROLES override, so franchises
// are blocked — ringtones are a platform-wide config like banners.
@ApiTags('Ringtones')
@ApiBearerAuth('access-token')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.ADMIN, UserRole.SUPER_ADMIN)
@Controller('admin/ringtones')
export class RingtonesController {
  constructor(private readonly ringtonesService: RingtonesService) {}

  @Post()
  @ApiOperation({ summary: 'Add a ringtone' })
  create(@Body() data: { title?: string; audioUrl?: string; sortOrder?: number }) {
    return this.ringtonesService.create(data);
  }

  @Get()
  @ApiOperation({ summary: 'List all ringtones' })
  findAll() {
    return this.ringtonesService.findAll();
  }

  @Put(':id')
  @ApiOperation({ summary: 'Update / set-active a ringtone' })
  update(@Param('id') id: string, @Body() data: { title?: string; sortOrder?: number; isActive?: boolean }) {
    return this.ringtonesService.update(id, data);
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Delete a ringtone' })
  remove(@Param('id') id: string) {
    return this.ringtonesService.remove(id);
  }
}
