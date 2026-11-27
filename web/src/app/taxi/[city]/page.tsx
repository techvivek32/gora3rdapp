import type { Metadata } from 'next';
import Link from 'next/link';
import { notFound } from 'next/navigation';
import { JsonLd } from '@/components/JsonLd';
import { COMPANY } from '@/lib/company';
import { abs, cityPath, clampDescription, inr, routePath, statePath } from '@/lib/seo';
import { getCabs, getCities, linkedDestinations } from '@/lib/seo-data';
import { slugify } from '@/lib/seo';

/**
 * One page per city — the page that answers "cab service in jodhpur" and
 * "taxi jodhpur".
 *
 * A city search and a route search want different things. Someone typing a
 * route already knows where they are going and wants a price; someone typing a
 * city is still choosing, so this page's job is to show what runs from here —
 * every route out of the city, the cars, and what local hire costs — and hand
 * them on to the page that prices their trip.
 */
export const revalidate = 86400;
export const dynamicParams = true;

type Params = { city: string };

export async function generateStaticParams(): Promise<Params[]> {
  const cities = await getCities();
  return cities.map((c) => ({ city: c.slug }));
}

export async function generateMetadata({ params }: { params: Promise<Params> }): Promise<Metadata> {
  const { city: slug } = await params;
  const city = (await getCities()).find((c) => c.slug === slug);
  if (!city) return { title: 'City not found', robots: { index: false, follow: false } };

  const where = city.state ? `${city.name}, ${city.state}` : city.name;
  // Hourly local hire is only claimed where the operator actually runs. For
  // every other city the honest offer is the intercity trip, and the page says
  // that instead of implying a local fleet in a town it has never worked in.
  const title = city.served
    ? `Cab Service in ${city.name} — Outstation & Local Taxi Booking`
    : `${city.name} Cab Booking — Outstation Taxi & One Way Drop`;
  const description = clampDescription(
    city.served
      ? `Book an outstation or local cab in ${where} at a fixed per-kilometre fare. One way, round trip and hourly rentals with verified drivers and no hidden charges.`
      : `Book an outstation cab to or from ${where} at a fixed per-kilometre fare. One way drops and round trips with verified drivers and no hidden charges.`,
  );
  const url = abs(cityPath(city.slug));

  return {
    title,
    description,
    alternates: { canonical: url },
    openGraph: { type: 'website', url, title, description, siteName: COMPANY.brand, locale: 'en_IN' },
    twitter: { card: 'summary_large_image', title, description },
  };
}

export default async function CityPage({ params }: { params: Promise<Params> }) {
  const { city: slug } = await params;
  const cities = await getCities();
  const city = cities.find((c) => c.slug === slug);
  if (!city) notFound();

  const cabs = await getCabs();
  // Not all 277 others — the ones a person leaving this city is most likely to
  // be going to, which is also the set worth spending link equity on.
  const destinations = linkedDestinations(cities, city, 24);
  const stateSlug = city.state ? slugify(city.state) : '';
  const inState = cities.filter((c) => c.slug !== city.slug && c.state === city.state).slice(0, 20);
  const url = abs(cityPath(city.slug));
  const cheapest = cabs.length ? cabs[0] : null;

  const faqs = [
    {
      q: `How do I book a cab in ${city.name}?`,
      a: `Enter your pickup and drop point, pick a date and choose a car. The fare is shown before you confirm, and you can pay the driver directly at the end of the trip.`,
    },
    {
      q: `What does a taxi in ${city.name} cost?`,
      a: cheapest
        ? `Outstation trips are charged per kilometre, starting at ${inr(cheapest.pricePerKm)} per km for a ${cheapest.vehicleClass || 'hatchback'}. Local hire is sold as an hourly package with a set number of kilometres included.`
        : `Outstation trips are charged per kilometre for the distance driven. Local hire is sold as an hourly package with a set number of kilometres included.`,
    },
    {
      q: `Is a one way drop available from ${city.name}?`,
      a: `Yes. A one way booking is charged only for the distance you travel, with no return fare added.`,
    },
    {
      q: 'Are the drivers verified?',
      a: 'Yes. Licence and vehicle papers are checked before a driver can take a booking, and the driver\'s name and car number are shared with you before pickup.',
    },
  ];

  const jsonLd = [
    {
      '@context': 'https://schema.org',
      '@type': 'BreadcrumbList',
      itemListElement: [
        { '@type': 'ListItem', position: 1, name: 'Home', item: abs('/') },
        ...(city.state
          ? [{ '@type': 'ListItem', position: 2, name: `${city.state} cabs`, item: abs(statePath(stateSlug)) }]
          : []),
        { '@type': 'ListItem', position: city.state ? 3 : 2, name: `Cabs in ${city.name}`, item: url },
      ],
    },
    {
      '@context': 'https://schema.org',
      '@type': 'TaxiService',
      '@id': `${url}#service`,
      name: `Cab service in ${city.name}`,
      provider: { '@id': `${abs('/')}#organization` },
      areaServed: { '@type': 'City', name: city.name, containedInPlace: city.state || undefined },
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
          {city.state && (
            <>
              <span className="px-2">/</span>
              <Link href={statePath(stateSlug)} className="hover:text-ink">{city.state}</Link>
            </>
          )}
          <span className="px-2">/</span>
          <span className="text-ink">{city.name}</span>
        </nav>

        <h1 className="text-3xl font-bold leading-tight sm:text-4xl">
          {city.served ? `Cab Service in ${city.name}` : `${city.name} Cab Booking`}
        </h1>
        <p className="mt-3 max-w-2xl text-muted">
          {city.served
            ? `Outstation drops, round trips and hourly local hire from ${city.name}${city.state ? `, ${city.state}` : ''}.`
            : `Outstation drops and round trips to and from ${city.name}${city.state ? `, ${city.state}` : ''}, arranged on request.`}{' '}
          Fares are charged per kilometre for the distance actually driven, and the full amount is
          shown before you confirm.
        </p>

        <div className="mt-7 flex flex-wrap gap-3">
          <Link href="/book/cab" className="btn-primary">Check fare &amp; book →</Link>
          {city.state && (
            <Link href={statePath(stateSlug)} className="btn-ghost">
              All {city.state} cabs →
            </Link>
          )}
        </div>
      </section>

      {destinations.length > 0 && (
        <section className="bg-surface py-12">
          <div className="mx-auto max-w-5xl px-4">
            <h2 className="text-2xl font-bold">Popular cab routes from {city.name}</h2>
            <p className="mt-2 text-sm text-muted">
              Each route has its own fare, distance and drive time.
            </p>
            <ul className="mt-6 grid gap-2 sm:grid-cols-2 lg:grid-cols-3">
              {destinations.map((d) => (
                <li key={d.slug}>
                  <Link
                    href={routePath(city.slug, d.slug)}
                    className="block rounded-card bg-bg px-4 py-3 text-sm font-medium ring-1 ring-hairline/70 transition hover:ring-brand-500"
                  >
                    {city.name} to {d.name} cab
                  </Link>
                </li>
              ))}
            </ul>
          </div>
        </section>
      )}

      {cabs.length > 0 && (
        <section className="py-12">
          <div className="mx-auto max-w-5xl px-4">
            <h2 className="text-2xl font-bold">Cars available in {city.name}</h2>
            <ul className="mt-6 grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
              {cabs.map((cab) => (
                <li key={cab.name} className="rounded-card bg-surface p-4 ring-1 ring-hairline/70">
                  <p className="font-semibold">{cab.name}</p>
                  <p className="mt-1 text-xs text-muted">
                    {cab.vehicleClass} · {cab.seats} seats
                  </p>
                  <p className="mt-2 text-sm font-semibold text-brand-600">
                    {inr(cab.pricePerKm)}/km
                  </p>
                </li>
              ))}
            </ul>
          </div>
        </section>
      )}

      {inState.length > 0 && (
        <section className="bg-surface py-12">
          <div className="mx-auto max-w-5xl px-4">
            <h2 className="text-2xl font-bold">Other cities we serve in {city.state}</h2>
            <ul className="mt-5 flex flex-wrap gap-2">
              {inState.map((c) => (
                <li key={c.slug}>
                  <Link
                    href={cityPath(c.slug)}
                    className="inline-block rounded-full bg-bg px-4 py-2 text-sm font-medium ring-1 ring-hairline/70 transition hover:ring-brand-500"
                  >
                    {c.name}
                  </Link>
                </li>
              ))}
            </ul>
          </div>
        </section>
      )}

      <section className="py-12">
        <div className="mx-auto max-w-5xl px-4">
          <h2 className="text-2xl font-bold">Booking a cab in {city.name} — common questions</h2>
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
