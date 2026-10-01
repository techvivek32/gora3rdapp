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
  /** Strip HTML tags/entities + noisy POI tokens from Google's turn-by-turn
   *  instructions so the app shows a clean line like "Turn left onto Kuvadva Rd". */
  private stripHtml(s: string): string {
    let out = (s || '')
      .replace(/<[^>]*>/g, ' ')
      .replace(/&nbsp;/g, ' ')
      .replace(/&amp;/g, '&')
      .replace(/&#39;/g, "'")
      .replace(/&quot;/g, '"')
      // Google embeds emoji/pictographs + variation selectors from local POI names.
      .replace(/[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{2B00}-\u{2BFF}\u{1F1E6}-\u{1F1FF}\u{2190}-\u{21FF}\u{FE00}-\u{FE0F}\u{200D}]/gu, '');
    // Drop a noisy landmark clause that starts with a house/POI number, e.g.
    // "Turn left at 1099 … onto Kuvadva Rd" -> "Turn left onto Kuvadva Rd".
    out = out.replace(/\s+at\s+\d[^]*?\s+onto\s+/gi, ' onto ');
    // Trailing "at 1099 …" with no road -> just drop the number clause.
    out = out.replace(/\s+at\s+\d\S*(\s+\S+){0,3}\s*$/i, '');
    return out
      .replace(/\s*\/\s*/g, ' / ')
      .replace(/\s+([,.])/g, '$1')
      .replace(/\s{2,}/g, ' ')
      .trim();
  }

  /** Decode a Google "encoded polyline" string into [{lat,lng}] points. */
  private decodePolyline(encoded: string): { lat: number; lng: number }[] {
    if (!encoded) return [];
    const points: { lat: number; lng: number }[] = [];
    let index = 0, lat = 0, lng = 0;
    while (index < encoded.length) {
      let b: number, shift = 0, result = 0;
      do { b = encoded.charCodeAt(index++) - 63; result |= (b & 0x1f) << shift; shift += 5; } while (b >= 0x20);
      lat += (result & 1) ? ~(result >> 1) : (result >> 1);
      shift = 0; result = 0;
      do { b = encoded.charCodeAt(index++) - 63; result |= (b & 0x1f) << shift; shift += 5; } while (b >= 0x20);
      lng += (result & 1) ? ~(result >> 1) : (result >> 1);
      points.push({ lat: lat / 1e5, lng: lng / 1e5 });
    }
    return points;
  }

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
      const tollInr = await this.fetchToll(origin, destination, waypoints);
      // Decoded route geometry so the app can draw the polyline on a map.
      const encoded = body.routes?.[0]?.overview_polyline?.points ?? '';
      const points = this.decodePolyline(encoded);
      // Turn-by-turn steps (across all legs) for in-app navigation guidance.
      const steps = legs
        .flatMap((l: any) => l.steps ?? [])
        .map((s: any) => ({
          instruction: this.stripHtml(s.html_instructions || ''),
          maneuver: s.maneuver || '',
          distanceM: s.distance?.value ?? 0,
          durationS: s.duration?.value ?? 0,
          startLat: s.start_location?.lat ?? 0,
          startLng: s.start_location?.lng ?? 0,
          endLat: s.end_location?.lat ?? 0,
          endLng: s.end_location?.lng ?? 0,
        }));
      return {
        message: 'ok',
        data: {
          distanceMeters: meters,
          distanceKm: Math.round((meters / 1000) * 10) / 10,
          durationSeconds: seconds,
          tollInr, // estimated toll (₹) from Google Routes API; 0 if unavailable
          points, // [{lat,lng}] route geometry for drawing the map polyline
          steps, // turn-by-turn guidance for in-app navigation
        },
      };
    } catch (e: any) {
      if (e instanceof BadRequestException) throw e;
      this.logger.error(`Directions failed: ${e?.message ?? e}`);
      throw new BadRequestException('Could not compute route.');
    }
  }

  /**
   * Estimated toll (INR) for a driving route via the Google Routes API
   * (extraComputations: TOLLS). Returns 0 when Google has no toll data for the
   * route or on any error, so the caller can degrade gracefully.
   */
  private async fetchToll(
    origin: { lat: number; lng: number },
    destination: { lat: number; lng: number },
    waypoints: { lat: number; lng: number }[],
  ): Promise<number> {
    try {
      const loc = (p: { lat: number; lng: number }) => ({ location: { latLng: { latitude: p.lat, longitude: p.lng } } });
      const bodyReq = {
        origin: loc(origin),
        destination: loc(destination),
        intermediates: waypoints.map(loc),
        travelMode: 'DRIVE',
        routingPreference: 'TRAFFIC_UNAWARE',
        extraComputations: ['TOLLS'],
      };
      const res = await fetch('https://routes.googleapis.com/directions/v2:computeRoutes', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': this.key,
          'X-Goog-FieldMask': 'routes.travelAdvisory.tollInfo,routes.distanceMeters',
        },
        body: JSON.stringify(bodyReq),
      });
      const body: any = await res.json();
      // Surface Routes API problems (e.g. API not enabled) instead of silently 0.
      if (body?.error) {
        this.logger.error(`Routes API error ${body.error.status ?? body.error.code}: ${body.error.message ?? ''}`);
        return 0;
      }
      const prices: any[] = body?.routes?.[0]?.travelAdvisory?.tollInfo?.estimatedPrice ?? [];
      // Sum the INR component (units + nanos). Ignore other currencies.
      let inr = 0;
      for (const p of prices) {
        if ((p?.currencyCode ?? 'INR') === 'INR') {
          inr += Number(p.units ?? 0) + Number(p.nanos ?? 0) / 1e9;
        }
      }
      return Math.round(inr);
    } catch (e: any) {
      this.logger.warn(`Routes toll fetch failed: ${e?.message ?? e}`);
      return 0;
    }
  }

  /**
   * Driving distance between two place *names* (e.g. "Jaipur" -> "Udaipur").
   * Google Directions accepts text addresses directly and returns the resolved
   * endpoint coordinates in the legs, so one call gives us both the road distance
   * and the pickup/drop lat-lng. Used by the WhatsApp booking flow where only city
   * names are known. Returns null on any failure (unknown city, key missing, etc.)
   * so callers can degrade gracefully instead of failing the whole booking.
   */
  async routeByAddress(
    origin: string,
    destination: string,
  ): Promise<{ distanceKm: number; pickup: { lat: number; lng: number }; drop: { lat: number; lng: number } } | null> {
    const o = (origin || '').trim();
    const d = (destination || '').trim();
    if (!o || !d) return null;
    let key: string;
    try {
      key = this.key;
    } catch {
      return null; // Google not configured — skip pricing, still create the booking.
    }

    const url = new URL('https://maps.googleapis.com/maps/api/directions/json');
    url.searchParams.set('origin', `${o}, India`);
    url.searchParams.set('destination', `${d}, India`);
    url.searchParams.set('mode', 'driving');
    url.searchParams.set('region', 'in');
    url.searchParams.set('key', key);

    try {
      const res = await fetch(url.toString());
      const body: any = await res.json();
      if (body.status !== 'OK') {
        this.logger.warn(`routeByAddress ${body.status} for "${o}"->"${d}": ${body.error_message ?? ''}`);
        return null;
      }
      const legs: any[] = body.routes?.[0]?.legs ?? [];
      if (!legs.length) return null;
      const meters = legs.reduce((sum, l) => sum + (l.distance?.value ?? 0), 0);
      const start = legs[0].start_location ?? {};
      const end = legs[legs.length - 1].end_location ?? {};
      return {
        distanceKm: Math.round((meters / 1000) * 10) / 10,
        pickup: { lat: start.lat ?? 0, lng: start.lng ?? 0 },
        drop: { lat: end.lat ?? 0, lng: end.lng ?? 0 },
      };
    } catch (e: any) {
      this.logger.warn(`routeByAddress failed for "${o}"->"${d}": ${e?.message ?? e}`);
      return null;
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
