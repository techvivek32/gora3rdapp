import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { AnalyticsService } from './analytics.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { UserRole } from '../../common/enums/user-role.enum';

@ApiTags('Analytics')
@ApiBearerAuth('access-token')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.ADMIN, UserRole.SUPER_ADMIN)
@Controller('analytics')
export class AnalyticsController {
  constructor(private readonly analyticsService: AnalyticsService) {}

  @Get('top-cities')
  @ApiOperation({ summary: 'Get top cities by requirement count' })
  getTopCities(@Query('limit') limit?: number) {
    return this.analyticsService.getTopCities(limit);
  }

  @Get('membership-conversion')
  @ApiOperation({ summary: 'Get membership conversion analytics' })
  getMembershipConversion() {
    return this.analyticsService.getMembershipConversion();
  }

  @Get('revenue-by-plan')
  @ApiOperation({ summary: 'Get revenue breakdown by plan' })
  getRevenueByPlan() {
    return this.analyticsService.getRevenueByPlan();
  }
}
