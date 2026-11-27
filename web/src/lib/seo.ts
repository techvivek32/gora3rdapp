/**
 * One place that knows the site's public address and how its URLs are spelled.
 *
 * Every canonical tag, Open Graph URL, sitemap entry and JSON-LD `@id` has to
 * agree on the origin, or Google treats the same page at two addresses as two
 * pages and splits the ranking between them. So nothing below hard-codes a
 * host; they all come through `SITE_URL`.
 *
 * The default is production on purpose, the same reasoning as `API_BASE`: a
 * build with no env still emits correct absolute URLs. Point a local build
 * somewhere else with NEXT_PUBLIC_SITE_URL.
 */
export const SITE_URL = (process.env.NEXT_PUBLIC_SITE_URL || 'https://gorataxi.com').replace(/\/$/, '');

/** Absolute URL for a site-relative path. Canonicals must be absolute. */
export function abs(path = '/'): string {
  return `${SITE_URL}${path.startsWith('/') ? path : `/${path}`}`;
}

/**
 * The URL-safe form of a city or state name.
 *
 * Lower case, spaces to hyphens, accents and punctuation dropped. "Jammu and
 * Kashmir" becomes "jammu-and-kashmir"; the city API's own `slug` is used when
 * it has one, and this is the fallback for states and for cities saved without.
 */
export function slugify(value: string): string {
  return (value || '')
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
}

/** The path for a city-to-city page, e.g. `/cabs/jodhpur-to-jaipur`. */
export function routePath(fromSlug: string, toSlug: string): string {
  return `/cabs/${fromSlug}-to-${toSlug}`;
}

/** The path for a single city, e.g. `/taxi/jodhpur`. */
export function cityPath(slug: string): string {
  return `/taxi/${slug}`;
}

/** The path for a state, e.g. `/cab-service/rajasthan`. */
export function statePath(slug: string): string {
  return `/cab-service/${slug}`;
}

/**
 * Splits `jodhpur-to-jaipur` into its two slugs.
 *
 * Returns null for anything that is not a pair, which is what keeps a stray
 * `/cabs/something` from rendering an empty route page: the page 404s instead.
 * City slugs themselves may contain hyphens ("navi-mumbai"), so the split is on
 * the first `-to-` and the rest is the destination.
 */
export function parseRouteSlug(slug: string): { from: string; to: string } | null {
  const m = /^(.+?)-to-(.+)$/.exec(slug || '');
  if (!m) return null;
  const [, from, to] = m;
  if (!from || !to || from === to) return null;
  return { from, to };
}

/** Title case for display, from a slug: "jodhpur" → "Jodhpur". */
export function titleFromSlug(slug: string): string {
  return (slug || '')
    .split('-')
    .filter(Boolean)
    .map((w) => w.charAt(0).toUpperCase() + w.slice(1))
    .join(' ');
}

/**
 * A description trimmed to what a search result will actually show.
 *
 * Google renders about 155-160 characters; anything past that is cut with an
 * ellipsis mid-sentence, which reads like a mistake. Cut on a word boundary
 * instead.
 */
export function clampDescription(text: string, max = 158): string {
  const s = (text || '').replace(/\s+/g, ' ').trim();
  if (s.length <= max) return s;
  const cut = s.slice(0, max);
  const lastSpace = cut.lastIndexOf(' ');
  return `${(lastSpace > 40 ? cut.slice(0, lastSpace) : cut).replace(/[.,;:\-\s]+$/, '')}…`;
}

/** Indian rupees, no decimals — the form every fare on the site uses. */
export function inr(n: number): string {
  return `₹${Math.round(n).toLocaleString('en-IN')}`;
}
