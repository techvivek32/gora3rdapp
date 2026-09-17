import { Body, Controller, Get, Param, Post, Put, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { UserRole } from '../../common/enums/user-role.enum';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { CarPoolService } from './car-pool.service';
import {
  BookSeatsDto,
  CancelDto,
  CompleteRideDto,
  CreatePoolRideDto,
  PickupDto,
  RatePoolRideDto,
  UpdatePoolRideDto,
} from './dto/car-pool.dto';

@ApiTags('Car Pool')
@ApiBearerAuth('access-token')
@UseGuards(JwtAuthGuard)
@Controller('car-pool')
export class CarPoolController {
  constructor(private readonly service: CarPoolService) {}

  // ── Driver ────────────────────────────────────────────────────────────────
  @Post()
  @ApiOperation({ summary: 'Driver: post a pool ride' })
  create(@CurrentUser('sub') userId: string, @Body() dto: CreatePoolRideDto) {
    return this.service.createRide(userId, dto);
  }

  @Get('my-rides')
  @ApiOperation({ summary: 'Driver: my posted rides (status=active|past)' })
  myRides(@CurrentUser('sub') userId: string, @Query('status') status?: string) {
    return this.service.listMyRides(userId, status);
  }

  @Get('earnings')
  @ApiOperation({ summary: 'Driver: pool earnings summary' })
  earnings(@CurrentUser('sub') userId: string) {
    return this.service.earnings(userId);
  }

  // ── Passenger ───────────────────────────────────────────────────────────────
  @Get('available')
  @ApiOperation({ summary: 'Passenger: search available pool rides' })
  available(@CurrentUser('sub') userId: string, @Query('from') from?: string, @Query('to') to?: string, @Query('date') date?: string) {
    return this.service.searchAvailable(userId, { from, to, date });
  }

  @Get('my-bookings')
  @ApiOperation({ summary: 'Passenger: my seat bookings' })
  myBookings(@CurrentUser('sub') userId: string) {
    return this.service.myBookings(userId);
  }

  // ── Admin ─────────────────────────────────────────────────────────────────
  @Get('admin/all')
  @UseGuards(RolesGuard)
  @Roles(UserRole.ADMIN, UserRole.SUPER_ADMIN)
  @ApiOperation({ summary: 'Admin: list all pool rides' })
  adminAll(@Query('status') status?: string) {
    return this.service.listAllForAdmin({ status });
  }

  // ── By id (keep AFTER literal routes) ───────────────────────────────────────
  @Get(':id')
  @ApiOperation({ summary: 'Ride details (owner sees passengers; others see own booking)' })
  getRide(@CurrentUser('sub') userId: string, @Param('id') id: string) {
    return this.service.getRide(userId, id);
  }

  @Put(':id')
  @ApiOperation({ summary: 'Driver: edit an active ride' })
  update(@CurrentUser('sub') userId: string, @Param('id') id: string, @Body() dto: UpdatePoolRideDto) {
    return this.service.updateRide(userId, id, dto);
  }

  @Post(':id/stop')
  @ApiOperation({ summary: 'Driver: stop/cancel a ride' })
  stop(@CurrentUser('sub') userId: string, @Param('id') id: string, @Body() dto: CancelDto) {
    return this.service.stopRide(userId, id, dto);
  }

  @Post(':id/start')
  @ApiOperation({ summary: 'Driver: start the ride' })
  start(@CurrentUser('sub') userId: string, @Param('id') id: string) {
    return this.service.startRide(userId, id);
  }

  @Post(':id/pickup')
  @ApiOperation({ summary: 'Driver: mark passengers picked up' })
  pickup(@CurrentUser('sub') userId: string, @Param('id') id: string, @Body() dto: PickupDto) {
    return this.service.markPickup(userId, id, dto);
  }

  @Post(':id/complete')
  @ApiOperation({ summary: 'Driver: complete the ride' })
  complete(@CurrentUser('sub') userId: string, @Param('id') id: string, @Body() dto: CompleteRideDto) {
    return this.service.completeRide(userId, id, dto);
  }

  @Post(':id/book')
  @ApiOperation({ summary: 'Passenger: book seats' })
  book(@CurrentUser('sub') userId: string, @Param('id') id: string, @Body() dto: BookSeatsDto) {
    return this.service.bookSeats(userId, id, dto);
  }

  @Post(':id/cancel-booking')
  @ApiOperation({ summary: 'Passenger: cancel my booking' })
  cancelBooking(@CurrentUser('sub') userId: string, @Param('id') id: string) {
    return this.service.cancelBooking(userId, id);
  }

  @Post(':id/rate')
  @ApiOperation({ summary: 'Passenger: rate a completed ride' })
  rate(@CurrentUser('sub') userId: string, @Param('id') id: string, @Body() dto: RatePoolRideDto) {
    return this.service.rateRide(userId, id, dto);
  }
}
