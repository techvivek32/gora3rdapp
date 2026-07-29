import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { PlacesService } from './places.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';

@ApiTags('Places')
@Controller('places')
export class PlacesController {
  constructor(private readonly placesService: PlacesService) {}

  @Get('autocomplete')
  @ApiOperation({ summary: 'Google Places autocomplete predictions for an address query' })
  autocomplete(@Query('input') input: string, @Query('types') types?: string) {
    return this.placesService.autocomplete(input, types);
  }

  @Get('cities')
  @ApiOperation({ summary: 'Autocomplete Indian cities (city-level predictions only)' })
  cities(@Query('input') input: string) {
    return this.placesService.autocomplete(input, '(cities)');
  }

  @Get('route')
  @ApiOperation({ summary: 'Google Directions driving distance through ordered points "lat,lng;lat,lng;..."' })
  route(@Query('points') points: string) {
    return this.placesService.route(points);
  }

  @ApiBearerAuth('access-token')
  @UseGuards(JwtAuthGuard)
  @Get('details')
  @ApiOperation({ summary: 'Resolve a place_id to address + coordinates + city' })
  details(@Query('placeId') placeId: string) {
    return this.placesService.details(placeId);
  }
}
