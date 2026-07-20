import { Body, Controller, Delete, Get, Param, Post, Put, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { FranchiseService } from './franchise.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { UserRole } from '../../common/enums/user-role.enum';

@ApiTags('Franchises (admin)')
@ApiBearerAuth('access-token')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.ADMIN, UserRole.SUPER_ADMIN)
@Controller('admin/franchises')
export class FranchiseController {
  constructor(private readonly service: FranchiseService) {}

  @Get()
  @ApiOperation({ summary: 'List franchises' })
  list(@Query() query: any) {
    return this.service.list(query);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get one franchise' })
  getOne(@Param('id') id: string) {
    return this.service.getOne(id);
  }

  @Post()
  @ApiOperation({ summary: 'Create a franchise' })
  create(@Body() data: any) {
    return this.service.create(data);
  }

  @Put(':id')
  @ApiOperation({ summary: 'Edit a franchise' })
  update(@Param('id') id: string, @Body() data: any) {
    return this.service.update(id, data);
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Delete a franchise' })
  remove(@Param('id') id: string) {
    return this.service.remove(id);
  }
}
