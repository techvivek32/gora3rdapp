import { Body, Controller, Delete, Get, Param, Post, Put, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { TrainingService } from './training.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { UserRole } from '../../common/enums/user-role.enum';

@ApiTags('Training Videos')
@ApiBearerAuth('access-token')
@UseGuards(JwtAuthGuard)
@Controller()
export class TrainingController {
  constructor(private readonly service: TrainingService) {}

  // ── App: list active videos ─────────────────────────────────────────────────
  @Get('training-videos')
  @ApiOperation({ summary: 'List active training videos (app)' })
  listActive() {
    return this.service.listActive();
  }

  // ── Admin CRUD ───────────────────────────────────────────────────────────────
  @Get('admin/training-videos')
  @UseGuards(RolesGuard)
  @Roles(UserRole.ADMIN, UserRole.SUPER_ADMIN)
  @ApiOperation({ summary: 'List all training videos (admin)' })
  listAll() {
    return this.service.listAll();
  }

  @Post('admin/training-videos')
  @UseGuards(RolesGuard)
  @Roles(UserRole.ADMIN, UserRole.SUPER_ADMIN)
  @ApiOperation({ summary: 'Add a training video' })
  create(@Body() data: { title: string; url: string; isActive?: boolean; sortOrder?: number }) {
    return this.service.create(data);
  }

  @Put('admin/training-videos/:id')
  @UseGuards(RolesGuard)
  @Roles(UserRole.ADMIN, UserRole.SUPER_ADMIN)
  @ApiOperation({ summary: 'Edit a training video' })
  update(@Param('id') id: string, @Body() data: any) {
    return this.service.update(id, data);
  }

  @Delete('admin/training-videos/:id')
  @UseGuards(RolesGuard)
  @Roles(UserRole.ADMIN, UserRole.SUPER_ADMIN)
  @ApiOperation({ summary: 'Delete a training video' })
  remove(@Param('id') id: string) {
    return this.service.remove(id);
  }
}
