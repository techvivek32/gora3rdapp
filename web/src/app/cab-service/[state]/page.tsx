import type { Metadata } from 'next';
import Link from 'next/link';
import { notFound } from 'next/navigation';
import { JsonLd } from '@/components/JsonLd';
import { COMPANY } from '@/lib/company';
import { abs, cityPath, clampDescription, inr, routePath, statePath } from '@/lib/seo';
import { getCabs, getCities, statesOf } from '@/lib/seo-data';

/**
 * One page per state — the page that answers "rajasthan cab service".
 *
 * The broadest of the three landing-page kinds, and the one that needs the
 * most care not to be empty: a state page that only repeats the city list adds
 * nothing. So it names every city served, every route inside the state, and
 * the per-kilometre rates, and sends the visitor down to the page that prices
 * the trip they actually want.
 */
export const revalidate = 86400;
export const dynamicParams = true;

type Params = { state: string };

export async function generateStaticParams(): Promise<Params[]> {
  const states = statesOf(await getCities());
  return states.map((s) => ({ state: s.slug }));
}

export async function generateMetadata({ params }: { params: Promise<Params> }): Promise<Metadata> {
  const { state: slug } = await params;
  const state = statesOf(await getCities()).find((s) => s.slug === slug);
  if (!state) return { title: 'State not found', robots: { index: false, follow: false } };

  const title = `${state.name} Cab Service — Outstation & Local Taxi Booking`;
  const description = clampDescription(
    `Book a cab anywhere in ${state.name} at a fixed per-kilometre fare. Outstation drops, round trips and hourly rentals across ${state.cities.map((c) => c.name).join(', ')}.`,
  );
  const url = abs(statePath(state.slug));

  return {
    title,
    description,
    alternates: { canonical: url },
    openGraph: { type: 'website', url, title, description, siteName: COMPANY.brand, locale: 'en_IN' },
    twitter: { card: 'summary_large_image', title, description },
  };
}

export default async function StatePage({ params }: { params: Promise<Params> }) {
  const { state: slug } = await params;
  const cities = await getCities();
  const state = statesOf(cities).find((s) => s.slug === slug);
  if (!state) notFound();

  const cabs = await getCabs();
  const url = abs(statePath(state.slug));
  const cheapest = cabs.length ? cabs[0] : null;

  /**
   * Routes with both ends inside this state — the ones the page is about.
   *
   * Capped, because a state like Uttar Pradesh carries 25 cities and would
   * otherwise print 600 links on one page. A wall of links that long helps
   * nobody: it is unreadable, and it spreads the page's own standing so thinly
   * across its links that none of them gains anything. The biggest cities
   * first, which is where the searching is.
   */
  const ranked = [...state.cities].sort(
    (a, b) => Number(!!b.served) - Number(!!a.served) || Number(!!b.major) - Number(!!a.major) || a.name.localeCompare(b.name),
  );
  const internalRoutes: Array<{ from: (typeof ranked)[number]; to: (typeof ranked)[number] }> = [];
  outer: for (const from of ranked) {
    for (const to of ranked) {
      if (from.slug === to.slug) continue;
      internalRoutes.push({ from, to });
      if (internalRoutes.length >= 36) break outer;
    }
  }

  const faqs = [
    {
      q: `How much does a cab cost in ${state.name}?`,
      a: cheapest
        ? `Outstation trips are charged per kilometre, starting at ${inr(cheapest.pricePerKm)} per km for a ${cheapest.vehicleClass || 'hatchback'}. The exact fare depends on the route and the car, and is shown in full before you confirm.`
        : `Outstation trips are charged per kilometre for the distance actually driven, with the full fare shown before you confirm.`,
    },
    {
      q: `Which cities in ${state.name} do you cover?`,
      a: `${state.cities.map((c) => c.name).join(', ')} — with outstation drops to and from cities in other states as well.`,
    },
    {
      q: 'Can I book a round trip?',
      a: 'Yes. A round trip is priced separately from a one way drop and keeps the same car and driver for the whole trip, including the return.',
    },
  ];

  const jsonLd = [
    {
      '@context': 'https://schema.org',
      '@type': 'BreadcrumbList',
      itemListElement: [
        { '@type': 'ListItem', position: 1, name: 'Home', item: abs('/') },
        { '@type': 'ListItem', position: 2, name: `${state.name} cabs`, item: url },
      ],
    },
    {
      '@context': 'https://schema.org',
      '@type': 'TaxiService',
      '@id': `${url}#service`,
      name: `${state.name} cab service`,
      provider: { '@id': `${abs('/')}#organization` },
      areaServed: { '@type': 'State', name: state.name, containedInPlace: { '@type': 'Country', name: 'India' } },
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

      <section className="mx-auto max-w-5xl px-4 pb-10 pt-12 sm:pt-16">
        <nav aria-label="Breadcrumb" className="mb-4 text-sm text-muted">
          <Link href="/" className="hover:text-ink">Home</Link>
          <span className="px-2">/</span>
          <span className="text-ink">{state.name}</span>
        </nav>

        <h1 className="text-3xl font-bold leading-tight sm:text-4xl">
          {state.name} Cab Service
        </h1>
        <p className="mt-3 max-w-2xl text-muted">
          Outstation drops, round trips and hourly local hire across {state.name}. Fares are
          charged per kilometre for the distance actually driven, with toll, state tax and parking
          stated separately so nothing is hidden.
        </p>

        <div className="mt-7">
          <Link href="/book/cab" className="btn-primary">Check fare &amp; book →</Link>
        </div>
      </section>

      <section className="bg-surface py-12">
        <div className="mx-auto max-w-5xl px-4">
          <h2 className="text-2xl font-bold">Cities we serve in {state.name}</h2>
          <ul className="mt-6 grid gap-2 sm:grid-cols-2 lg:grid-cols-3">
            {state.cities.map((c) => (
              <li key={c.slug}>
                <Link
                  href={cityPath(c.slug)}
                  className="block rounded-card bg-bg px-4 py-3 text-sm font-medium ring-1 ring-hairline/70 transition hover:ring-brand-500"
                >
                  Cab service in {c.name}
                </Link>
              </li>
            ))}
          </ul>
        </div>
      </section>

      {internalRoutes.length > 0 && (
        <section className="py-12">
          <div className="mx-auto max-w-5xl px-4">
            <h2 className="text-2xl font-bold">Cab routes within {state.name}</h2>
            <ul className="mt-6 grid gap-2 sm:grid-cols-2 lg:grid-cols-3">
              {internalRoutes.map(({ from, to }) => (
                <li key={`${from.slug}-${to.slug}`}>
                  <Link
                    href={routePath(from.slug, to.slug)}
                    className="block rounded-card bg-surface px-4 py-3 text-sm font-medium ring-1 ring-hairline/70 transition hover:ring-brand-500"
                  >
                    {from.name} to {to.name} cab
                  </Link>
                </li>
              ))}
            </ul>
          </div>
        </section>
      )}

      {cabs.length > 0 && (
        <section className="bg-surface py-12">
          <div className="mx-auto max-w-5xl px-4">
            <h2 className="text-2xl font-bold">Per-kilometre rates</h2>
            <ul className="mt-6 grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
              {cabs.map((cab) => (
                <li key={cab.name} className="rounded-card bg-bg p-4 ring-1 ring-hairline/70">
                  <p className="font-semibold">{cab.name}</p>
                  <p className="mt-1 text-xs text-muted">{cab.vehicleClass} · {cab.seats} seats</p>
                  <p className="mt-2 text-sm font-semibold text-brand-600">{inr(cab.pricePerKm)}/km</p>
                </li>
              ))}
            </ul>
          </div>
        </section>
      )}

      <section className="py-12">
        <div className="mx-auto max-w-5xl px-4">
          <h2 className="text-2xl font-bold">{state.name} cab booking — common questions</h2>
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
    </>
  );
}
