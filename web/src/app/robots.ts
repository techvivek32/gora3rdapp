import type { MetadataRoute } from 'next';
import { SITE_URL, abs } from '@/lib/seo';

/**
 * What a crawler may read, and where the map is.
 *
 * Everything is allowed on purpose. The booking funnel — `/confirm`,
 * `/booked`, `/book/...` — should not appear in search results, but blocking
 * it here is the wrong tool and a common mistake: a disallowed URL is never
 * fetched, so Google never sees the `noindex` on it, and it can still list the
 * bare address off an inbound link. Letting the crawler read the page and find
 * `noindex` is what actually keeps it out of the index, so those pages carry
 * the tag in their own layouts instead.
 */
export default function robots(): MetadataRoute.Robots {
  return {
    rules: [{ userAgent: '*', allow: '/' }],
    sitemap: abs('/sitemap.xml'),
    host: SITE_URL,
  };
}
