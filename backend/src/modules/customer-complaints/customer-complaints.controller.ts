import { Body, Controller, Get, Param, Post, Put, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { UserRole } from '../../common/enums/user-role.enum';
import { CustomerComplaintsService } from './customer-complaints.service';
import { CreateComplaintDto, UpdateComplaintDto } from './dto/customer-complaint.dto';

@ApiTags('Customer Complaints')
@ApiBearerAuth('access-token')
@UseGuards(JwtAuthGuard)
@Controller('customer-complaints')
export class CustomerComplaintsController {
  constructor(private readonly service: CustomerComplaintsService) {}

  // ── Customer ──
  @Post()
  @ApiOperation({ summary: 'Customer files a complaint' })
  create(@CurrentUser('sub') userId: string, @Body() dto: CreateComplaintDto) {
    return this.service.create(userId, dto);
  }

  @Get('my')
  @ApiOperation({ summary: "Customer's own complaints" })
  mine(@CurrentUser('sub') userId: string) {
    return this.service.myComplaints(userId);
  }

  // ── Admin ──
  @Get()
  @UseGuards(RolesGuard)
  @Roles(UserRole.ADMIN, UserRole.SUPER_ADMIN)
  @ApiOperation({ summary: 'Admin: list all complaints' })
  listAll(@Query('status') status?: string) {
    return this.service.listAll(status);
  }

  @Put(':id')
  @UseGuards(RolesGuard)
  @Roles(UserRole.ADMIN, UserRole.SUPER_ADMIN)
  @ApiOperation({ summary: 'Admin: update complaint status / note' })
  update(@Param('id') id: string, @Body() dto: UpdateComplaintDto) {
    return this.service.update(id, dto);
  }
}
