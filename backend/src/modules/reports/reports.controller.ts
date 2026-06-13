import { Controller, Get, Post, Body, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { ReportsService } from './reports.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';

@ApiTags('Reports')
@ApiBearerAuth('access-token')
@UseGuards(JwtAuthGuard)
@Controller('reports')
export class ReportsController {
  constructor(private readonly reportsService: ReportsService) {}

  @Post()
  @ApiOperation({ summary: 'Submit a report' })
  createReport(@CurrentUser('sub') userId: string, @Body() data: any) {
    return this.reportsService.createReport(userId, data);
  }

  @Get('my')
  @ApiOperation({ summary: 'Get my reports' })
  getMyReports(@CurrentUser('sub') userId: string) {
    return this.reportsService.getMyReports(userId);
  }
}
