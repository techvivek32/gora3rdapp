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
      return {
        message: 'ok',
        data: {
          address: r.formatted_address ?? r.name ?? '',
          lat: loc.lat ?? 0,
          lng: loc.lng ?? 0,
          city: cityComp?.long_name ?? '',
        },
      };
    } catch (e: any) {
      if (e instanceof BadRequestException) throw e;
      this.logger.error(`Places details failed: ${e?.message ?? e}`);
      throw new BadRequestException('Could not fetch place details.');
    }
  }
}
