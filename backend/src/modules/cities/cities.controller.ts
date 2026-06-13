import { Controller, Get, Query } from '@nestjs/common';
import { ApiTags, ApiOperation } from '@nestjs/swagger';
import { CitiesService } from './cities.service';
import { Public } from '../../common/decorators/roles.decorator';

@ApiTags('Cities')
@Controller('cities')
export class CitiesController {
  constructor(private readonly citiesService: CitiesService) {}

  @Get()
  @Public()
  @ApiOperation({ summary: 'Get all active cities' })
  getAll(@Query('search') search?: string, @Query('state') state?: string) {
    return this.citiesService.getAll(search, state);
  }

  @Get('featured')
  @Public()
  @ApiOperation({ summary: 'Get featured cities' })
  getFeatured() {
    return this.citiesService.getFeatured();
  }

  @Get('by-state')
  @Public()
  @ApiOperation({ summary: 'Get cities grouped by state' })
  getByState() {
    return this.citiesService.getByState();
  }
}
