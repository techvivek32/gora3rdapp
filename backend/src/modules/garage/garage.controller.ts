import { Body, Controller, Delete, Get, Param, Post, Put, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { GarageService } from './garage.service';
import { CreateGarageVehicleDto, UpdateGarageVehicleDto } from './dto/garage-vehicle.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';

@ApiTags('My Vehicles')
@ApiBearerAuth('access-token')
@UseGuards(JwtAuthGuard)
@Controller('garage')
export class GarageController {
  constructor(private readonly service: GarageService) {}

  @Get()
  @ApiOperation({ summary: "List the user's saved vehicles" })
  list(@CurrentUser('sub') userId: string) {
    return this.service.list(userId);
  }

  @Post()
  @ApiOperation({ summary: 'Add a vehicle to the garage' })
  create(@CurrentUser('sub') userId: string, @Body() dto: CreateGarageVehicleDto) {
    return this.service.create(userId, dto);
  }

  @Put(':id')
  @ApiOperation({ summary: 'Edit a saved vehicle' })
  update(@CurrentUser('sub') userId: string, @Param('id') id: string, @Body() dto: UpdateGarageVehicleDto) {
    return this.service.update(userId, id, dto);
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Remove a saved vehicle' })
  remove(@CurrentUser('sub') userId: string, @Param('id') id: string) {
    return this.service.remove(userId, id);
  }
}
