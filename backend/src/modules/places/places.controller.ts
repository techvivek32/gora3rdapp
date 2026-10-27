import { Controller, Get, Query } from '@nestjs/common';
import { ApiTags, ApiOperation } from '@nestjs/swagger';
import { PlacesService } from './places.service';

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

  // Public since the website prices a trip BEFORE the visitor identifies
  // themselves (guest booking) — a guard here would break the fare page for
  // every signed-out customer.
  //
  // Directions is the expensive Google call, so the global per-IP throttler is
  // now the only thing limiting spend on it. Keep that throttler enabled, and
  // watch the Google billing dashboard after this ships.
  @Get('route')
  @ApiOperation({ summary: 'Google Directions driving distance through ordered points "lat,lng;lat,lng;..."' })
  route(@Query('points') points: string) {
    return this.placesService.route(points);
  }

  // Public for the same reason as `route` above: a guest has to be able to turn
  // the place they picked into coordinates before the fare can be worked out.
  @Get('details')
  @ApiOperation({ summary: 'Resolve a place_id to address + coordinates + city' })
  details(@Query('placeId') placeId: string) {
    return this.placesService.details(placeId);
  }
}
