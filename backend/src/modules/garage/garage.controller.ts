import { Body, Controller, Delete, Get, Param, Post, Put, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { GarageService } from './garage.service';
import { CreateGarageVehicleDto, UpdateGarageVehicleDto } from './dto/garage-vehicle.dto';
import { CreateGarageDriverDto, UpdateGarageDriverDto } from './dto/garage-driver.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';

@ApiTags('My Vehicles')
@ApiBearerAuth('access-token')
@UseGuards(JwtAuthGuard)
@Controller('garage')
export class GarageController {
  constructor(private readonly service: GarageService) {}

  // ── Drivers (literal routes declared before ':id' to avoid collision) ──

  @Get('drivers')
  @ApiOperation({ summary: "List the user's saved drivers" })
  listDrivers(@CurrentUser('sub') userId: string) {
    return this.service.listDrivers(userId);
  }

  @Post('drivers')
  @ApiOperation({ summary: 'Add a driver to My Drivers' })
  createDriver(@CurrentUser('sub') userId: string, @Body() dto: CreateGarageDriverDto) {
    return this.service.createDriver(userId, dto);
  }

  @Put('drivers/:id')
  @ApiOperation({ summary: 'Edit a saved driver' })
  updateDriver(@CurrentUser('sub') userId: string, @Param('id') id: string, @Body() dto: UpdateGarageDriverDto) {
    return this.service.updateDriver(userId, id, dto);
  }

  @Delete('drivers/:id')
  @ApiOperation({ summary: 'Remove a saved driver' })
  removeDriver(@CurrentUser('sub') userId: string, @Param('id') id: string) {
    return this.service.removeDriver(userId, id);
  }

  // ── Vehicles ──

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
