/**
 * Server-side data for the pages search engines land on.
 *
 * These run on the server only — at build time for `generateStaticParams`, and
 * again when a page revalidates. They deliberately do NOT use the axios client
 * in `api.ts`: that one is built for the browser, and Next's caching lives on
 * the `fetch` it provides, which is what stops ninety route pages making ninety
 * live calls every time someone crawls the site.
 *
 * Every function here degrades instead of throwing. A landing page with no
 * distance is still a useful page; a build that dies because the API blinked is
 * not. So each returns an empty value on failure and the page decides what to
 * render without it.
 */
import { API_BASE } from './api';
import { slugify } from './seo';
import { INDIA_CITIES } from './india-cities';

/** A day. City lists and per-km rates change rarely, and never urgently. */
const DAY = 60 * 60 * 24;

export interface SeoCity {
  name: string;
  state: string;
  slug: string;
  /** True when the operator has switched this city on in the admin panel. */
  served?: boolean;
  /** True for the cities a national cab search is dominated by. */
  major?: boolean;
}

export interface SeoCab {
  name: string;
  vehicleClass: string;
  pricePerKm: number;
  seats: number;
}

export interface RouteFacts {
  distanceKm: number;
  durationSeconds: number;
  tollInr: number;
}

/** GET a backend path, returning null rather than throwing. */
async function get<T>(path: string, revalidate: number): Promise<T | null> {
  try {
    const res = await fetch(`${API_BASE}${path}`, {
      next: { revalidate },
      headers: { Accept: 'application/json' },
    });
    if (!res.ok) return null;
    const body = (await res.json()) as { data?: T } | T;
    return (body && typeof body === 'object' && 'data' in (body as object)
      ? (body as { data?: T }).data
      : (body as T)) ?? null;
  } catch {
    return null;
  }
}

/**
 * Every city the operator has switched on, as the pages address them.
 *
 * The slug is taken from the API when it has one so the URL matches whatever
 * the admin panel shows, and is derived from the name when it does not — a
 * city added without one still gets a page rather than a `/taxi/undefined`.
 */
export async function getCities(): Promise<SeoCity[]> {
  const rows = await get<Array<Record<string, unknown>>>('/cities', DAY);
  const seen = new Set<string>();
  const out: SeoCity[] = [];

  // The operator's own cities go in first and win every collision: their
  // spelling and their slug are the ones the admin panel and the booking form
  // already use, so a page must not address the same place differently.
  for (const r of Array.isArray(rows) ? rows : []) {
    if (r?.isActive === false) continue;
    const name = String(r?.name ?? '').trim();
    if (!name) continue;
    const slug = slugify(String(r?.slug ?? '') || name);
    if (!slug || seen.has(slug)) continue;
    seen.add(slug);
    out.push({ name, state: normaliseState(String(r?.state ?? '').trim()), slug, served: true });
  }

  // Then the rest of the country. Someone searching "rajkot to goa cab" is
  // looking for a trip, not for a list of cities an operator has switched on —
  // and a cab company that would happily drive that route has nothing to gain
  // from having no page for it. These are publishable but not marked `served`,
  // and the pages say which is which rather than implying a local fleet in
  // every town.
  for (const c of INDIA_CITIES) {
    const slug = slugify(c.name);
    if (!slug || seen.has(slug)) continue;
    seen.add(slug);
    out.push({ name: c.name, state: normaliseState(c.state), slug, major: c.major });
  }

  // A served city is also a major one for linking purposes — it is where the
  // company actually operates, so it belongs in every shortlist.
  for (const c of out) if (c.served) c.major = true;

  return out.sort((a, b) => a.name.localeCompare(b.name));
}

/**
 * Repairs state names that were saved short.
 *
 * One live row has its state as "Raj", which would otherwise mint a second
 * state page at /cab-service/raj competing with the real Rajasthan one — two
 * thin pages for one place is exactly what a search engine demotes. Fixing the
 * data in the admin panel is the real repair; this keeps the site correct in
 * the meantime and costs nothing once the data is clean.
 */
const STATE_FIXES: Record<string, string> = {
  raj: 'Rajasthan',
  mh: 'Maharashtra',
  guj: 'Gujarat',
  gj: 'Gujarat',
  up: 'Uttar Pradesh',
  mp: 'Madhya Pradesh',
  hr: 'Haryana',
  pb: 'Punjab',
  ka: 'Karnataka',
  tn: 'Tamil Nadu',
};

export function normaliseState(state: string): string {
  const key = state.toLowerCase().trim();
  return STATE_FIXES[key] ?? state;
}

/** The cab classes on offer, cheapest per km first. */
export async function getCabs(): Promise<SeoCab[]> {
  const rows = await get<Array<Record<string, unknown>>>('/home-content/cab-categories', DAY);
  if (!Array.isArray(rows)) return [];
  return rows
    .filter((r) => r?.isActive !== false && Number(r?.pricePerKm) > 0)
    .map((r) => ({
      name: String(r?.name ?? '').trim(),
      vehicleClass: String(r?.vehicleClass ?? '').trim(),
      pricePerKm: Number(r?.pricePerKm) || 0,
      seats: Number(r?.seats) || 4,
    }))
    .filter((c) => c.name)
    .sort((a, b) => a.pricePerKm - b.pricePerKm);
}

/**
 * Where a city is, resolved through the same Places proxy the booking form
 * uses, so a city added in the admin panel needs no code change here.
 *
 * Cached for a week: a city does not move, and the only reason to look again is
 * a spelling correction in the admin panel.
 */
const WEEK = DAY * 7;

export async function geocodeCity(city: SeoCity): Promise<{ lat: number; lng: number } | null> {
  const query = [city.name, city.state, 'India'].filter(Boolean).join(', ');
  const preds = await get<{ predictions?: Array<{ placeId?: string; description?: string }> }>(
    `/places/autocomplete?input=${encodeURIComponent(query)}`,
    WEEK,
  );
  const placeId = preds?.predictions?.[0]?.placeId;
  if (!placeId) return null;
  const details = await get<{ lat?: number; lng?: number }>(
    `/places/details?placeId=${encodeURIComponent(placeId)}`,
    WEEK,
  );
  const lat = Number(details?.lat);
  const lng = Number(details?.lng);
  if (!lat || !lng) return null;
  return { lat, lng };
}

/**
 * Real driving distance, time and toll between two cities.
 *
 * Driving distance, not a straight line: the fare is charged on the road, and a
 * page that advertises 290 km for a 334 km trip is quoting a fare the customer
 * will not be charged. Null when it cannot be resolved, and the page then omits
 * the figure rather than inventing one.
 */
export async function getRouteFacts(from: SeoCity, to: SeoCity): Promise<RouteFacts | null> {
  const [a, b] = await Promise.all([geocodeCity(from), geocodeCity(to)]);
  if (!a || !b) return null;
  const points = `${a.lat},${a.lng};${b.lat},${b.lng}`;
  const data = await get<{ distanceKm?: number; durationSeconds?: number; tollInr?: number }>(
    `/places/route?points=${encodeURIComponent(points)}`,
    WEEK,
  );
  const distanceKm = Number(data?.distanceKm);
  if (!distanceKm) return null;
  return {
    distanceKm,
    durationSeconds: Number(data?.durationSeconds) || 0,
    tollInr: Number(data?.tollInr) || 0,
  };
}

/** "5h 45m" from seconds, or '' when the time is unknown. */
export function humanDuration(seconds: number): string {
  if (!seconds || seconds < 60) return '';
  const h = Math.floor(seconds / 3600);
  const m = Math.round((seconds % 3600) / 60);
  if (!h) return `${m}m`;
  return m ? `${h}h ${m}m` : `${h}h`;
}

/**
 * Which route pages are built ahead of time — and why it is not all of them.
 *
 * 278 cities make 77,006 ordered pairs. Every one of them has a working page:
 * the route segment sets `dynamicParams`, so a pair nobody has asked for yet is
 * rendered on the first request — by a visitor or by a crawler — with its real
 * distance fetched then and cached afterwards. Nothing is missing.
 *
 * What is NOT done is building all 77,006 at once, for two separate reasons,
 * and the second matters more than the first:
 *
 *  1. Cost and time. Each page needs a live routing call for its real
 *     distance. Seventy-seven thousand of those on every deploy is a bill and
 *     an hours-long build for pages most of which nobody will ever open.
 *
 *  2. **It would be read as a doorway.** Publishing tens of thousands of
 *     near-identical pages in one go, from a site with no ranking history, is
 *     the exact pattern search engines demote — and the penalty lands on the
 *     whole domain, including the pages that were good. Sites that do carry
 *     route pages at that scale earned the authority first and grew into it.
 *
 * So the set below is the one worth putting in front of a crawler on day one:
 * routes touching a city the operator actually serves, and routes between the
 * country's biggest cities. The rest stay reachable, linked from their city
 * pages, and get indexed as they earn it.
 */
export const PRERENDER_ROUTE_LIMIT = 400;

/** Ranks a pair so the most searched-for routes survive the cap. */
function pairScore(from: SeoCity, to: SeoCity): number {
  let score = 0;
  if (from.served) score += 4;
  if (to.served) score += 4;
  if (from.major) score += 1;
  if (to.major) score += 1;
  return score;
}

/**
 * The route pages built at deploy time and listed in the sitemap.
 *
 * Both directions are kept: "jodhpur to jaipur cab" and "jaipur to jodhpur cab"
 * are two different searches by two different people, and each deserves the
 * page that answers it.
 */
export function priorityPairs(cities: SeoCity[]): Array<{ from: SeoCity; to: SeoCity }> {
  const served = cities.filter((c) => c.served);
  const major = cities.filter((c) => c.major);
  const pairs = new Map<string, { from: SeoCity; to: SeoCity; score: number }>();

  const add = (from: SeoCity, to: SeoCity) => {
    if (from.slug === to.slug) return;
    const key = `${from.slug}>${to.slug}`;
    if (pairs.has(key)) return;
    pairs.set(key, { from, to, score: pairScore(from, to) });
  };

  // Every route into and out of a city the operator serves, to anywhere major.
  for (const s of served) for (const m of major) { add(s, m); add(m, s); }
  // And the big-city routes, which is what most national searching is.
  for (const a of major) for (const b of major) add(a, b);

  return [...pairs.values()]
    .sort((x, y) => y.score - x.score || x.from.name.localeCompare(y.from.name))
    .slice(0, PRERENDER_ROUTE_LIMIT)
    .map(({ from, to }) => ({ from, to }));
}

/**
 * The destinations a city page links out to.
 *
 * This is how the long tail is discovered: a crawler that reaches
 * `/taxi/rajkot` finds real links to Rajkot→Mumbai, Rajkot→Delhi and the rest,
 * follows them, and indexes the ones that earn it. Links, not a sitemap dump.
 */
export function linkedDestinations(cities: SeoCity[], from: SeoCity, limit = 24): SeoCity[] {
  const rest = cities.filter((c) => c.slug !== from.slug);
  const sameState = rest.filter((c) => c.state && c.state === from.state);
  const servedCities = rest.filter((c) => c.served && !sameState.includes(c));
  const majors = rest.filter((c) => c.major && !c.served && !sameState.includes(c));

  const out: SeoCity[] = [];
  const seen = new Set<string>();
  for (const group of [sameState, servedCities, majors, rest]) {
    for (const c of group) {
      if (seen.has(c.slug)) continue;
      seen.add(c.slug);
      out.push(c);
      if (out.length >= limit) return out;
    }
  }
  return out;
}

/** The states that have at least one live city, for the state landing pages. */
export function statesOf(cities: SeoCity[]): Array<{ name: string; slug: string; cities: SeoCity[] }> {
  const map = new Map<string, { name: string; slug: string; cities: SeoCity[] }>();
  for (const c of cities) {
    if (!c.state) continue;
    const slug = slugify(c.state);
    if (!slug) continue;
    const entry = map.get(slug) ?? { name: c.state, slug, cities: [] };
    entry.cities.push(c);
    map.set(slug, entry);
  }
  return [...map.values()].sort((a, b) => a.name.localeCompare(b.name));
}
