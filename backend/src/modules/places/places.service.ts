import { Injectable, BadRequestException, Logger } from '@nestjs/common';

/**
 * Proxies Google Places (Autocomplete + Details) so the API key stays server-side
 * and the mobile/web clients avoid CORS issues calling Google directly.
 */
@Injectable()
export class PlacesService {
  private readonly logger = new Logger(PlacesService.name);

  private get key(): string {
    const k = process.env.GOOGLE_MAPS_API_KEY;
    if (!k || k === 'your-google-maps-api-key') {
      throw new BadRequestException('Places search is not configured on the server.');
    }
    return k;
  }

  async autocomplete(input: string, types?: string) {
    const q = (input || '').trim();
    if (q.length < 1) return { message: 'ok', data: { predictions: [] } };

    const url = new URL('https://maps.googleapis.com/maps/api/place/autocomplete/json');
    url.searchParams.set('input', q);
    url.searchParams.set('key', this.key);
    url.searchParams.set('components', 'country:in');
    url.searchParams.set('language', 'en');
    // Optional Google "types" filter, e.g. "(cities)" to restrict to city-level results.
    if (types && types.trim()) url.searchParams.set('types', types.trim());

    try {
      const res = await fetch(url.toString());
      const body: any = await res.json();
      if (body.status !== 'OK' && body.status !== 'ZERO_RESULTS') {
        this.logger.error(`Places autocomplete ${body.status}: ${body.error_message ?? ''}`);
        throw new BadRequestException(body.error_message || `Places error: ${body.status}`);
      }
      const predictions = (body.predictions || []).map((p: any) => ({
        placeId: p.place_id,
        description: p.description,
        main: p.structured_formatting?.main_text ?? p.description,
        secondary: p.structured_formatting?.secondary_text ?? '',
      }));
      return { message: 'ok', data: { predictions } };
    } catch (e: any) {
      if (e instanceof BadRequestException) throw e;
      this.logger.error(`Places autocomplete failed: ${e?.message ?? e}`);
      throw new BadRequestException('Could not fetch places.');
    }
  }

  /**
   * Google Directions driving distance through ordered points, so the app shows
   * the same road distance Google Maps does (OSRM routes a few % shorter, e.g.
   * 214 vs 222 km). `pointsRaw` is "lat,lng;lat,lng;..." in visit order
   * (pickup -> stops -> drop). Returns total metres/km/seconds across all legs.
   */
  async route(pointsRaw: string) {
    const parts = (pointsRaw || '')
      .split(';')
      .map((s) => s.trim())
      .filter(Boolean);
    if (parts.length < 2) {
      throw new BadRequestException('At least 2 points (origin;destination) are required');
    }
    const coords = parts.map((p) => {
      const [lat, lng] = p.split(',').map((x) => Number(x.trim()));
      if (!isFinite(lat) || !isFinite(lng)) {
        throw new BadRequestException(`Invalid point: ${p}`);
      }
      return { lat, lng };
    });

    const origin = coords[0];
    const destination = coords[coords.length - 1];
    const waypoints = coords.slice(1, -1);

    const url = new URL('https://maps.googleapis.com/maps/api/directions/json');
    url.searchParams.set('origin', `${origin.lat},${origin.lng}`);
    url.searchParams.set('destination', `${destination.lat},${destination.lng}`);
    if (waypoints.length) {
      url.searchParams.set('waypoints', waypoints.map((w) => `${w.lat},${w.lng}`).join('|'));
    }
    url.searchParams.set('mode', 'driving');
    url.searchParams.set('region', 'in');
    url.searchParams.set('key', this.key);

    try {
      const res = await fetch(url.toString());
      const body: any = await res.json();
      if (body.status !== 'OK') {
        this.logger.error(`Directions ${body.status}: ${body.error_message ?? ''}`);
        throw new BadRequestException(body.error_message || `Directions error: ${body.status}`);
      }
      const legs: any[] = body.routes?.[0]?.legs ?? [];
      const meters = legs.reduce((sum, l) => sum + (l.distance?.value ?? 0), 0);
      const seconds = legs.reduce((sum, l) => sum + (l.duration?.value ?? 0), 0);
      return {
        message: 'ok',
        data: {
          distanceMeters: meters,
          distanceKm: Math.round((meters / 1000) * 10) / 10,
          durationSeconds: seconds,
        },
      };
    } catch (e: any) {
      if (e instanceof BadRequestException) throw e;
      this.logger.error(`Directions failed: ${e?.message ?? e}`);
      throw new BadRequestException('Could not compute route.');
    }
  }

  async details(placeId: string) {
    const id = (placeId || '').trim();
    if (!id) throw new BadRequestException('placeId is required');

    const url = new URL('https://maps.googleapis.com/maps/api/place/details/json');
    url.searchParams.set('place_id', id);
    url.searchParams.set('key', this.key);
    url.searchParams.set('language', 'en');
    url.searchParams.set('fields', 'geometry,formatted_address,address_components,name');

    try {
      const res = await fetch(url.toString());
      const body: any = await res.json();
      if (body.status !== 'OK') {
        this.logger.error(`Places details ${body.status}: ${body.error_message ?? ''}`);
        throw new BadRequestException(body.error_message || `Places error: ${body.status}`);
      }
      const r = body.result || {};
      const loc = r.geometry?.location ?? {};
      const comps: any[] = r.address_components || [];
      const cityComp = comps.find((c) =>
        c.types?.some((t: string) =>
          ['locality', 'administrative_area_level_3', 'administrative_area_level_2'].includes(t),
        ),
      );
      const stateComp = comps.find((c) =>
        c.types?.some((t: string) => t === 'administrative_area_level_1'),
      );
      return {
        message: 'ok',
        data: {
          address: r.formatted_address ?? r.name ?? '',
          lat: loc.lat ?? 0,
          lng: loc.lng ?? 0,
          city: cityComp?.long_name ?? '',
          state: stateComp?.long_name ?? '',
        },
      };
    } catch (e: any) {
      if (e instanceof BadRequestException) throw e;
      this.logger.error(`Places details failed: ${e?.message ?? e}`);
      throw new BadRequestException('Could not fetch place details.');
    }
  }
}
