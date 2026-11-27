import type { MetadataRoute } from 'next';
import { abs, cityPath, routePath, statePath } from '@/lib/seo';
import { getCities, priorityPairs, statesOf } from '@/lib/seo-data';

/**
 * The list a search engine reads to find every page worth reading.
 *
 * It is generated from the live city list rather than written by hand, which
 * is the whole point: the operator adds a city in the admin panel and its
 * pages — the city page, its state page, and a route page to and from every
 * other city — appear in the sitemap on the next revalidation, with nobody
 * editing this file.
 *
 * `priority` is a hint and a weak one, so it is used only to say what this site
 * is actually about: the home page first, then the routes people search for by
 * name, then cities and states.
 */
export const revalidate = 86400;

export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  const now = new Date();
  const cities = await getCities();

  const staticPages: MetadataRoute.Sitemap = [
    { url: abs('/'), lastModified: now, changeFrequency: 'daily', priority: 1 },
    { url: abs('/cabs'), lastModified: now, changeFrequency: 'weekly', priority: 0.7 },
    { url: abs('/pool'), lastModified: now, changeFrequency: 'daily', priority: 0.6 },
    { url: abs('/support'), lastModified: now, changeFrequency: 'monthly', priority: 0.3 },
  ];

  // The priority set only, not all 77,006 pairs. Every pair still has a
  // working page — see `priorityPairs` for why they are not all listed here.
  // A sitemap is a recommendation, and recommending seventy-seven thousand
  // near-identical pages from a site with no ranking history is the fastest
  // way to have all of them ignored.
  const routes: MetadataRoute.Sitemap = priorityPairs(cities).map(({ from, to }) => ({
    url: abs(routePath(from.slug, to.slug)),
    lastModified: now,
    changeFrequency: 'weekly',
    priority: 0.8,
  }));

  const cityPages: MetadataRoute.Sitemap = cities.map((c) => ({
    url: abs(cityPath(c.slug)),
    lastModified: now,
    changeFrequency: 'weekly',
    priority: 0.7,
  }));

  const statePages: MetadataRoute.Sitemap = statesOf(cities).map((s) => ({
    url: abs(statePath(s.slug)),
    lastModified: now,
    changeFrequency: 'weekly',
    priority: 0.6,
  }));

  return [...staticPages, ...routes, ...cityPages, ...statePages];
}
