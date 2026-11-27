import type { Metadata } from 'next';
import Link from 'next/link';
import { notFound } from 'next/navigation';
import { JsonLd } from '@/components/JsonLd';
import { COMPANY } from '@/lib/company';
import { abs, clampDescription, cityPath, inr, parseRouteSlug, routePath } from '@/lib/seo';
import {
  getCabs,
  getCities,
  getRouteFacts,
  humanDuration,
  linkedDestinations,
  priorityPairs,
  type SeoCity,
} from '@/lib/seo-data';

/**
 * One page per city pair — the page that answers "jodhpur to jaipur cab".
 *
 * This is the part of the site a search engine can actually rank for an
 * intercity query. The home page says the company drives people places; this
 * says how far Jodhpur is from Jaipur, how long it takes, what each class of
 * car costs per kilometre and what the fare does and does not include. That is
 * a real answer, which is the only kind worth publishing: a grid of pages that
 * differ only in two swapped city names is a doorway, and gets treated as one.
 *
 * Rendered statically and revalidated daily, so a crawler is served HTML with
 * the numbers already in it rather than an empty shell that fills in after
 * JavaScript runs.
 */
export const revalidate = 86400;

/**
 * The reason every city pair in the country works without all of them being
 * built: a route that was not prerendered is rendered on its first request —
 * crawler or visitor — with its real distance fetched then, and cached from
 * that point on. `generateStaticParams` below picks only the ones worth having
 * ready in advance.
 */
export const dynamicParams = true;

type Params = { route: string };

export async function generateStaticParams(): Promise<Params[]> {
  const cities = await getCities();
  return priorityPairs(cities).map(({ from, to }) => ({ route: `${from.slug}-to-${to.slug}` }));
}

/** Resolves the two cities in the slug, or null when either is not ours. */
async function resolve(routeSlug: string): Promise<{ from: SeoCity; to: SeoCity } | null> {
  const parsed = parseRouteSlug(routeSlug);
  if (!parsed) return null;
  const cities = await getCities();
  const from = cities.find((c) => c.slug === parsed.from);
  const to = cities.find((c) => c.slug === parsed.to);
  if (!from || !to) return null;
  return { from, to };
}

export async function generateMetadata({ params }: { params: Promise<Params> }): Promise<Metadata> {
  const { route } = await params;
  const pair = await resolve(route);
  if (!pair) return { title: 'Cab route not found', robots: { index: false, follow: false } };

  const { from, to } = pair;
  const facts = await getRouteFacts(from, to);
  const km = facts ? `${Math.round(facts.distanceKm)} km` : '';
  const time = facts ? humanDuration(facts.durationSeconds) : '';

  const title = `${from.name} to ${to.name} Cab — One Way & Round Trip Taxi`;
  const description = clampDescription(
    `Book a ${from.name} to ${to.name} cab at a fixed per-kilometre fare.` +
      (km ? ` About ${km}${time ? `, ${time} by road` : ''}.` : '') +
      ' Choose a hatchback, sedan or SUV. Verified drivers, no hidden charges, free cancellation before pickup.',
  );
  const url = abs(routePath(from.slug, to.slug));

  return {
    title,
    description,
    alternates: { canonical: url },
    openGraph: { type: 'website', url, title, description, siteName: COMPANY.brand, locale: 'en_IN' },
    twitter: { card: 'summary_large_image', title, description },
    // Stated outright because this page sits under /cabs, and the layout there
    // marks the fare-results screen `noindex`. Metadata is inherited down the
    // segment, so without this line every route page would quietly inherit it
    // — the whole set of pages this work exists to publish, hidden by one
    // sensible decision about a different page.
    robots: { index: true, follow: true },
  };
}

export default async function RoutePage({ params }: { params: Promise<Params> }) {
  const { route } = await params;
  const pair = await resolve(route);
  if (!pair) notFound();

  const { from, to } = pair;
  const [facts, cabs, cities] = await Promise.all([getRouteFacts(from, to), getCabs(), getCities()]);

  const km = facts ? Math.round(facts.distanceKm) : 0;
  const time = facts ? humanDuration(facts.durationSeconds) : '';
  const url = abs(routePath(from.slug, to.slug));

  /** Base fare only, and labelled as such everywhere it appears. */
  const quote = (perKm: number) => (km ? Math.round(km * perKm) : 0);
  const cheapest = cabs.length ? cabs[0] : null;

  /**
   * Other routes from the same origin, so the set links to itself.
   *
   * With 278 cities this is also how a crawler finds the pages that were never
   * prerendered — it follows these links rather than being handed a sitemap of
   * seventy-seven thousand URLs.
   */
  const siblings = linkedDestinations(cities, from, 12).filter((c) => c.slug !== to.slug);

  const faqs = [
    {
      q: `What is the ${from.name} to ${to.name} cab fare?`,
      a:
        cheapest && km
          ? `The base fare starts at about ${inr(quote(cheapest.pricePerKm))} for a ${cheapest.vehicleClass || 'hatchback'} ` +
            `over roughly ${km} km, charged at ${inr(cheapest.pricePerKm)} per kilometre. Toll, state tax, parking, driver allowance and GST are additional. ` +
            `Larger cars cost more per kilometre; the exact fare for your date is shown before you confirm.`
          : `The fare is charged per kilometre for the distance actually driven, with the exact amount shown before you confirm the booking.`,
    },
    {
      q: `How far is ${to.name} from ${from.name}?`,
      a: km
        ? `About ${km} km by road${time ? `, which usually takes around ${time} in a car` : ''}.`
        : `The road distance is measured for your exact pickup and drop points when you request a fare.`,
    },
    {
      q: `Is a one way ${from.name} to ${to.name} taxi available?`,
      a: `Yes. A one way booking is charged for the distance you travel only — there is no return fare added. A round trip is priced separately and can be booked for the same route.`,
    },
    {
      q: 'What is included in the fare?',
      a: 'The quoted fare covers the distance driven at the per-kilometre rate for the car you choose. Toll, state tax and parking are paid to the driver during the trip on the Best Price option, or included upfront on the All Inclusive option.',
    },
    {
      q: 'Do I need to pay in advance?',
      a: 'No. You can pay the driver directly at the end of the trip, or pay part of the fare online when booking if you prefer.',
    },
  ];

  const jsonLd = [
    {
      '@context': 'https://schema.org',
      '@type': 'BreadcrumbList',
      itemListElement: [
        { '@type': 'ListItem', position: 1, name: 'Home', item: abs('/') },
        { '@type': 'ListItem', position: 2, name: `Cabs in ${from.name}`, item: abs(cityPath(from.slug)) },
        { '@type': 'ListItem', position: 3, name: `${from.name} to ${to.name}`, item: url },
      ],
    },
    {
      '@context': 'https://schema.org',
      '@type': 'Service',
      '@id': `${url}#service`,
      serviceType: 'Intercity cab booking',
      name: `${from.name} to ${to.name} cab`,
      provider: { '@id': `${abs('/')}#organization` },
      areaServed: [
        { '@type': 'City', name: from.name },
        { '@type': 'City', name: to.name },
      ],
      ...(cheapest && km
        ? {
            offers: {
              '@type': 'Offer',
              priceCurrency: 'INR',
              price: String(quote(cheapest.pricePerKm)),
              description: `Base fare from ${from.name} to ${to.name} for a ${cheapest.vehicleClass || 'hatchback'}, before toll, state tax, parking and GST.`,
              availability: 'https://schema.org/InStock',
              url,
            },
          }
        : {}),
    },
    {
      '@context': 'https://schema.org',
      '@type': 'FAQPage',
      mainEntity: faqs.map((f) => ({
        '@type': 'Question',
        name: f.q,
        acceptedAnswer: { '@type': 'Answer', text: f.a },
      })),
    },
  ];

  return (
    <>
      <JsonLd data={jsonLd} />

      <section className="relative mx-auto max-w-5xl px-4 pb-10 pt-12 sm:pt-16">
        <nav aria-label="Breadcrumb" className="mb-4 text-sm text-muted">
          <Link href="/" className="hover:text-ink">Home</Link>
          <span className="px-2">/</span>
          <Link href={cityPath(from.slug)} className="hover:text-ink">{from.name}</Link>
          <span className="px-2">/</span>
          <span className="text-ink">{to.name}</span>
        </nav>

        <h1 className="text-3xl font-bold leading-tight sm:text-4xl">
          {from.name} to {to.name} Cab
        </h1>
        <p className="mt-3 max-w-2xl text-muted">
          Book a one way or round trip taxi from {from.name} to {to.name} at a fixed per-kilometre
          fare. You pay for the distance you travel — there is no return charge on a one way trip.
        </p>

        {(km > 0 || time) && (
          <dl className="mt-6 grid gap-3 sm:grid-cols-3">
            {km > 0 && (
              <div className="rounded-card bg-surface p-4 ring-1 ring-hairline/70">
                <dt className="text-xs uppercase tracking-wide text-muted">Road distance</dt>
                <dd className="mt-1 text-2xl font-bold">{km} km</dd>
              </div>
            )}
            {time && (
              <div className="rounded-card bg-surface p-4 ring-1 ring-hairline/70">
                <dt className="text-xs uppercase tracking-wide text-muted">Typical drive time</dt>
                <dd className="mt-1 text-2xl font-bold">{time}</dd>
              </div>
            )}
            {cheapest && km > 0 && (
              <div className="rounded-card bg-surface p-4 ring-1 ring-hairline/70">
                <dt className="text-xs uppercase tracking-wide text-muted">Base fare from</dt>
                <dd className="mt-1 text-2xl font-bold">{inr(quote(cheapest.pricePerKm))}</dd>
              </div>
            )}
          </dl>
        )}

        <div className="mt-7 flex flex-wrap gap-3">
          <Link href="/book/cab" className="btn-primary">
            Check fare &amp; book →
          </Link>
          <Link href={routePath(to.slug, from.slug)} className="btn-ghost">
            {to.name} to {from.name} →
          </Link>
        </div>
      </section>

      {cabs.length > 0 && (
        <section className="bg-surface py-12">
          <div className="mx-auto max-w-5xl px-4">
            <h2 className="text-2xl font-bold">
              {from.name} to {to.name} taxi fare by car type
            </h2>
            <p className="mt-2 text-sm text-muted">
              Rates are per kilometre for the distance driven.
              {km > 0 ? ` The amounts below are for roughly ${km} km.` : ''} Toll, state tax,
              parking, driver allowance and GST are additional and shown before you confirm.
            </p>

            <div className="mt-6 overflow-x-auto">
              <table className="w-full min-w-[34rem] border-collapse text-left text-sm">
                <thead>
                  <tr className="border-b border-hairline text-xs uppercase tracking-wide text-muted">
                    <th scope="col" className="py-3 pr-4 font-semibold">Car</th>
                    <th scope="col" className="py-3 pr-4 font-semibold">Seats</th>
                    <th scope="col" className="py-3 pr-4 font-semibold">Per km</th>
                    {km > 0 && <th scope="col" className="py-3 font-semibold">Base fare</th>}
                  </tr>
                </thead>
                <tbody>
                  {cabs.map((cab) => (
                    <tr key={cab.name} className="border-b border-hairline/60">
                      <td className="py-3 pr-4">
                        <span className="font-semibold">{cab.name}</span>
                        {cab.vehicleClass && (
                          <span className="block text-xs text-muted">{cab.vehicleClass}</span>
                        )}
                      </td>
                      <td className="py-3 pr-4">{cab.seats}</td>
                      <td className="py-3 pr-4">{inr(cab.pricePerKm)}/km</td>
                      {km > 0 && <td className="py-3 font-semibold">{inr(quote(cab.pricePerKm))}</td>}
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>

            {facts && facts.tollInr > 0 && (
              <p className="mt-4 text-xs text-muted">
                Toll on this route is roughly {inr(facts.tollInr)} each way and is paid during the
                trip unless you choose the All Inclusive fare.
              </p>
            )}
          </div>
        </section>
      )}

      <section className="py-12">
        <div className="mx-auto max-w-5xl px-4">
          <h2 className="text-2xl font-bold">
            {from.name} to {to.name} cab — common questions
          </h2>
          <div className="mt-6 divide-y divide-hairline">
            {faqs.map((f) => (
              <details key={f.q} className="group py-4">
                <summary className="cursor-pointer list-none font-semibold">
                  {f.q}
                  <span className="float-right text-muted transition group-open:rotate-45">+</span>
                </summary>
                <p className="mt-2 text-sm text-muted">{f.a}</p>
              </details>
            ))}
          </div>
        </div>
      </section>

      {siblings.length > 0 && (
        <section className="bg-surface py-12">
          <div className="mx-auto max-w-5xl px-4">
            <h2 className="text-2xl font-bold">Other cabs from {from.name}</h2>
            <ul className="mt-5 flex flex-wrap gap-2">
              {siblings.map((c) => (
                <li key={c.slug}>
                  <Link
                    href={routePath(from.slug, c.slug)}
                    className="inline-block rounded-full bg-sunken px-4 py-2 text-sm font-medium transition hover:bg-hairline"
                  >
                    {from.name} to {c.name}
                  </Link>
                </li>
              ))}
            </ul>
          </div>
        </section>
      )}
    </>
  );
}
