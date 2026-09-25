import { Controller, Get, Post, Put, Body, Param, Query, UseGuards, HttpCode, HttpStatus, Res } from '@nestjs/common';
import { Response } from 'express';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { CustomerBookingsService } from './customer-bookings.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { UserRole } from '../../common/enums/user-role.enum';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import {
  CreateCustomerBookingDto,
  UpdateCustomerBookingDto,
  ApplyBookingDto,
  SelectOfferDto,
  CancelBookingDto,
  RateBookingDto,
} from './dto/customer-booking.dto';

@ApiTags('Customer Bookings')
@ApiBearerAuth('access-token')
@UseGuards(JwtAuthGuard)
@Controller('customer-bookings')
export class CustomerBookingsController {
  constructor(private readonly service: CustomerBookingsService) {}

  // ── Literal routes first (so they don't collide with :id) ──

  @Get('my')
  @ApiOperation({ summary: "Customer: my bookings (optional ?status=)" })
  getMyBookings(@CurrentUser('sub') userId: string, @Query('status') status?: string) {
    return this.service.getMyBookings(userId, status);
  }

  @Get('available')
  @ApiOperation({ summary: 'Driver/Vendor: open bookings I can apply to' })
  listAvailable(@CurrentUser('sub') userId: string, @Query('serviceType') serviceType?: string) {
    return this.service.listAvailable(userId, serviceType);
  }

  @Get('my-applications')
  @ApiOperation({ summary: 'Driver/Vendor: bookings I applied to' })
  getMyApplications(@CurrentUser('sub') userId: string) {
    return this.service.getMyApplications(userId);
  }

  @Get('admin/all')
  @UseGuards(RolesGuard)
  @Roles(UserRole.ADMIN, UserRole.SUPER_ADMIN)
  @ApiOperation({ summary: 'Admin: list all customer bookings (read-only)' })
  adminListAll(@Query('status') status?: string, @Query('serviceType') serviceType?: string) {
    return this.service.listAllForAdmin({ status, serviceType });
  }

  // ── Customer actions ──

  @Post()
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Customer: create a booking request' })
  create(@CurrentUser('sub') userId: string, @Body() dto: CreateCustomerBookingDto) {
    return this.service.create(userId, dto);
  }

  @Get(':id/invoice')
  @ApiOperation({ summary: 'Download the PDF invoice for a completed booking (customer, selected driver, or admin)' })
  async invoice(
    @CurrentUser('sub') userId: string,
    @CurrentUser('role') role: string,
    @Param('id') id: string,
    @Res() res: Response,
  ) {
    const { buffer, filename } = await this.service.getInvoice(userId, [role], id);
    res.set({
      'Content-Type': 'application/pdf',
      'Content-Disposition': `attachment; filename="${filename}"`,
      'Content-Length': String(buffer.length),
      'Cache-Control': 'private, no-store',
    });
    res.end(buffer);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Customer: booking detail with offers' })
  getOne(@CurrentUser('sub') userId: string, @Param('id') id: string) {
    return this.service.getBookingForCustomer(userId, id);
  }

  @Post(':id/select')
  @ApiOperation({ summary: 'Customer: select a driver/vendor offer' })
  select(@CurrentUser('sub') userId: string, @Param('id') id: string, @Body() dto: SelectOfferDto) {
    return this.service.selectDriver(userId, id, dto.offerId);
  }

  @Put(':id')
  @ApiOperation({ summary: 'Customer: edit an OPEN booking (releases stale offers)' })
  update(@CurrentUser('sub') userId: string, @Param('id') id: string, @Body() dto: UpdateCustomerBookingDto) {
    return this.service.updateByCustomer(userId, id, dto);
  }

  @Post(':id/cancel')
  @ApiOperation({ summary: 'Customer: cancel booking (releases held offers)' })
  cancel(@CurrentUser('sub') userId: string, @Param('id') id: string, @Body() dto: CancelBookingDto) {
    return this.service.cancelByCustomer(userId, id, dto.reason);
  }

  @Post(':id/rate')
  @ApiOperation({ summary: 'Customer: rate the driver after completion' })
  rate(@CurrentUser('sub') userId: string, @Param('id') id: string, @Body() dto: RateBookingDto) {
    return this.service.rate(userId, id, dto);
  }

  // ── Driver/Vendor actions ──

  @Post(':id/apply')
  @ApiOperation({ summary: 'Driver/Vendor: apply/quote (holds wallet commitment)' })
  apply(@CurrentUser('sub') userId: string, @Param('id') id: string, @Body() dto: ApplyBookingDto) {
    return this.service.apply(userId, id, dto);
  }

  @Post(':id/accept')
  @ApiOperation({ summary: 'Golden Driver/Vendor: directly accept a booking (instant assign)' })
  accept(@CurrentUser('sub') userId: string, @Param('id') id: string) {
    return this.service.acceptDirect(userId, id);
  }

  @Post(':id/arrived')
  @ApiOperation({ summary: 'Driver: mark arriving at pickup (notifies customer)' })
  arrived(@CurrentUser('sub') userId: string, @Param('id') id: string) {
    return this.service.driverArrived(userId, id);
  }

  @Post(':id/trip/request-otp')
  @ApiOperation({ summary: 'Driver: request the start/end OTP (shown to the customer)' })
  requestTripOtp(@CurrentUser('sub') userId: string, @Param('id') id: string, @Body('action') action: 'start' | 'end') {
    return this.service.requestTripOtp(userId, id, action);
  }

  @Post(':id/trip/verify-otp')
  @ApiOperation({ summary: 'Driver: verify the OTP the customer read out to start/end the trip' })
  verifyTripOtp(
    @CurrentUser('sub') userId: string,
    @Param('id') id: string,
    @Body('action') action: 'start' | 'end',
    @Body('otp') otp: string,
  ) {
    return this.service.verifyTripOtp(userId, id, action, otp);
  }

  @Post(':id/driver-cancel')
  @ApiOperation({ summary: 'Driver: cancel after being selected' })
  driverCancel(@CurrentUser('sub') userId: string, @Param('id') id: string, @Body() dto: CancelBookingDto) {
    return this.service.cancelByDriver(userId, id, dto.reason);
  }
}
