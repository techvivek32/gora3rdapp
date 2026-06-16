import {
  Controller, Get, Post, Put, Delete, Body, Param, Query, UseGuards, HttpCode, HttpStatus,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { RequirementsService } from './requirements.service';
import { CreateRequirementDto } from './dto/create-requirement.dto';
import { UpdateRequirementDto } from './dto/update-requirement.dto';
import { FilterRequirementsDto } from './dto/filter-requirements.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { BookingStatus } from '../../common/enums/vehicle-type.enum';

@ApiTags('Requirements')
@ApiBearerAuth('access-token')
@UseGuards(JwtAuthGuard)
@Controller('requirements')
export class RequirementsController {
  constructor(private readonly requirementsService: RequirementsService) {}

  @Post()
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Post a new vehicle requirement' })
  create(@CurrentUser('sub') userId: string, @Body() dto: CreateRequirementDto) {
    return this.requirementsService.create(userId, dto);
  }

  @Get()
  @ApiOperation({ summary: 'Get all requirements feed (with filters)' })
  findAll(@CurrentUser('sub') userId: string, @Query() query: FilterRequirementsDto) {
    return this.requirementsService.findAll(userId, query);
  }

  @Get('my')
  @ApiOperation({ summary: 'Get my posted requirements' })
  getMyRequirements(
    @CurrentUser('sub') userId: string,
    @Query('status') status?: BookingStatus,
  ) {
    return this.requirementsService.getMyRequirements(userId, status);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get requirement details' })
  findOne(@Param('id') id: string, @CurrentUser('sub') userId: string) {
    return this.requirementsService.findOne(id, userId);
  }

  @Put(':id')
  @ApiOperation({ summary: 'Update a requirement' })
  update(
    @Param('id') id: string,
    @CurrentUser('sub') userId: string,
    @Body() dto: UpdateRequirementDto,
  ) {
    return this.requirementsService.update(id, userId, dto);
  }

  @Post(':id/accept')
  @ApiOperation({ summary: 'Accept/respond to a requirement' })
  accept(@Param('id') id: string, @CurrentUser('sub') userId: string) {
    return this.requirementsService.acceptRequirement(id, userId);
  }

  @Post(':id/cancel')
  @ApiOperation({ summary: 'Cancel a requirement' })
  cancel(
    @Param('id') id: string,
    @CurrentUser('sub') userId: string,
    @Body('reason') reason: string,
  ) {
    return this.requirementsService.cancelRequirement(id, userId, reason);
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Delete a requirement' })
  remove(@Param('id') id: string, @CurrentUser('sub') userId: string) {
    return this.requirementsService.remove(id, userId);
  }
}
