import { Controller, Get, Post, Put, Delete, Body, Param, Query, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { AvailableVehiclesService } from './available-vehicles.service';
import { CreateAvailableVehicleDto } from './dto/create-available-vehicle.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';

@ApiTags('Available Vehicles')
@ApiBearerAuth('access-token')
@UseGuards(JwtAuthGuard)
@Controller('available-vehicles')
export class AvailableVehiclesController {
  constructor(private readonly service: AvailableVehiclesService) {}

  @Post()
  @ApiOperation({ summary: 'Post available vehicle' })
  create(@CurrentUser('sub') userId: string, @Body() dto: CreateAvailableVehicleDto) {
    return this.service.create(userId, dto);
  }

  @Get()
  @ApiOperation({ summary: 'Get available vehicles feed' })
  findAll(@CurrentUser('sub') userId: string, @Query() query: any) {
    return this.service.findAll(userId, query);
  }

  @Get('my')
  @ApiOperation({ summary: 'Get my vehicle listings' })
  getMyVehicles(@CurrentUser('sub') userId: string) {
    return this.service.getMyVehicles(userId);
  }

  @Get('accepted-by-me')
  @ApiOperation({ summary: 'Get vehicle listings I have accepted' })
  getAcceptedByMe(@CurrentUser('sub') userId: string) {
    return this.service.getAcceptedByMe(userId);
  }

  @Post(':id/accept')
  @ApiOperation({ summary: 'Accept a vehicle listing' })
  acceptVehicle(@Param('id') id: string, @CurrentUser('sub') userId: string) {
    return this.service.acceptVehicle(id, userId);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get vehicle listing details' })
  findOne(@Param('id') id: string, @CurrentUser('sub') userId: string) {
    return this.service.findOne(id, userId);
  }

  @Put(':id')
  @ApiOperation({ summary: 'Update vehicle listing' })
  update(@Param('id') id: string, @CurrentUser('sub') userId: string, @Body() dto: Partial<CreateAvailableVehicleDto>) {
    return this.service.update(id, userId, dto);
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Delete vehicle listing' })
  remove(@Param('id') id: string, @CurrentUser('sub') userId: string) {
    return this.service.remove(id, userId);
  }
}
