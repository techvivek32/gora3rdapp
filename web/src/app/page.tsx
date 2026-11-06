'use client';

import { Fragment, useState } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useQuery } from '@tanstack/react-query';
import {
  Armchair, ArrowRight, Building2, Car, CarTaxiFront, CheckCircle2, Clock,
  Headphones, Luggage, Mail, MapPin, MessageCircle, Phone, Route, ShieldCheck,
  Smartphone, Snowflake, Tag, Users, Wallet,
} from 'lucide-react';
import { apiGet } from '@/lib/api';
import { PlaceInput } from '@/components/PlaceInput';
import { AppMock } from '@/components/AppMock';
import { CarSide } from '@/components/CarSide';
import { TaxiHero } from '@/components/TaxiHero';
import { Poster } from '@/components/Poster';
import { tripDraft } from '@/lib/trip-draft';
import { rupees, toDateInput } from '@/lib/format';
import { useSiteText } from '@/lib/site-text';
import { cityChip } from '@/lib/city-colour';
import type { CabCategory, City, Geo, PlatformSettings, SupportContact } from '@/lib/types';

interface Showcase {
  _id?: string;
  title?: string;
  subtitle?: string;
  imageUrl?: string;
  actionUrl?: string;
}
interface HomeContent {
  heroImage?: string;
  travel?: Showcase[];
  offers?: Showcase[];
  explore?: Showcase[];
}

const SERVICES = [
  {
    href: '/book/cab',
    icon: CarTaxiFront,
    title: 'Cab Booking',
    blurb: 'One Way · Round Trip · Local',
    desc: 'Outstation and in-city cabs. The full fare, broken down, before you confirm.',
    tone: 'text-cabsolid',
  },
  {
    href: '/book/hire_driver',
    icon: Car,
    title: 'Hire a Driver',
    blurb: 'Hourly · Full day',
    desc: 'You have the car, we send a verified driver. Priced by the day, not the kilometre.',
    tone: 'text-drivesolid',
  },
  {
    href: '/pool',
    icon: Users,
    title: 'Car Pool',
    blurb: 'Share & save',
    desc: 'Book a seat on a trip someone is already making. Cheaper, and one less car out.',
    tone: 'text-poolsolid',
  },
];

/** Answered from how the product actually works — nothing aspirational. */
const FAQ = [
  ['Do I need an account to book?',
   'No. Give a name and a mobile number at the point of booking and that is it. Signing in only adds your history and the option to pay online.'],
  ['When do I pay?',
   'You can book with ₹0 advance and pay the driver directly, or pay 10% or 100% online to lock the trip in. Whatever is left is settled with the driver.'],
  ['Is the fare I see the fare I pay?',
   'On All Inclusive, yes — toll, state tax, driver allowance and GST are already in the number. Best Price shows a lower fare because toll, state tax and parking are paid to the driver during the trip instead.'],
  ['Who is driving?',
   'Our team assigns a verified driver and shares their name, vehicle and number with you before the trip. On a car pool you can see who is offering the ride before you book a seat.'],
  ['Can I cancel?', 'Yes, free of charge any time before pickup.'],
  ['I booked on the website — is it in the app too?',
   'Yes. Open the Gora Taxi app with the same mobile number and the trip is already there.'],
];

export default function HomePage() {
  const { data } = useQuery({
    queryKey: ['home-content'],
    queryFn: () => apiGet<HomeContent>('/home-content'),
    retry: 0,
  });

  // Real cab classes, with the admin's own photographs and per-km rates. The
  // fleet strip shows the cars we actually run, not stock imagery of cars we
  // do not.
  const { data: cats } = useQuery({
    queryKey: ['cab-categories'],
    queryFn: () => apiGet<CabCategory[]>('/home-content/cab-categories'),
    retry: 0,
  });

  // Where the network is set up. Real rows from the admin panel, so the
  // coverage strip says what is actually true today rather than a number
  // someone typed into a design.
  const { data: cityRows } = useQuery({
    queryKey: ['cities'],
    queryFn: () => apiGet<City[]>('/cities'),
    staleTime: 5 * 60 * 1000,
    retry: 0,
  });

  // Company details and the wording around them are the operator's, set in
  // the admin panel. The defaults ship with the site so nothing is blank on
  // the first paint.
  const t = useSiteText();

  // Contact Us, live from the operator's settings. Nothing about how to reach
  // Gora is written into this page: change it in the admin panel and it
  // changes here.
  const { data: contact } = useQuery({
    queryKey: ['support-contact'],
    queryFn: () => apiGet<SupportContact>('/settings/support-contact'),
    retry: 0,
  });
  const { data: settings } = useQuery({
    queryKey: ['public-settings'],
    queryFn: () => apiGet<PlatformSettings>('/settings'),
    staleTime: 5 * 60 * 1000,
    retry: 0,
  });

  // Everything below the hero is decoration fed by the admin panel, so a
  // response in an unexpected shape must cost that strip and nothing else.
  // Without the guard a non-array answer threw inside render and took the
  // whole home page down — a white screen because a showcase query hiccuped.
  const list = <T,>(v: unknown, n: number): T[] => (Array.isArray(v) ? (v as T[]).slice(0, n) : []);

  // `travel` is the row of categories the operator keeps in the admin panel
  // — Airport, Hotel, Temple — each with a photograph. The app has always
  // shown it; the website was dropping it on the floor.
  const travel = list<Showcase>(data?.travel, 4);
  const explore = list<Showcase>(data?.explore, 6);
  const offers = list<Showcase>(data?.offers, 6);
  const fleet = list<CabCategory>(cats, 4);
  const cities = list<City>(cityRows, 60).filter((c) => c.name);
  // A picture first, then the operator's own featured flag — and never more
  // than six, because a poster grid is a selection, not a list. The list is
  // the chip row underneath it.
  const featured = [...cities]
    .sort((a, b) => Number(!!b.imageUrl) - Number(!!a.imageUrl)
      || Number(!!b.isFeatured) - Number(!!a.isFeatured))
    .filter((c) => c.imageUrl || c.isFeatured)
    .slice(0, 6);
  const states = new Set(cities.map((c) => c.state).filter(Boolean)).size;

  /**
   * The next chapter number.
   *
   * Half these sections only exist when the operator has filled them in, so
   * a hand-written "06" on Explore becomes a lie the moment someone clears
   * their city list. JSX children evaluate in source order and `&&`
   * short-circuits before the element is built, so a section that does not
   * render never takes a number.
   */
  let chapter = 0;
  const step = () => String(++chapter).padStart(2, '0');

  const phone = (contact?.phone || settings?.supportPhone || '').trim();
  const phone2 = (settings?.supportPhone2 || '').trim();
  const email = (settings?.supportEmail || '').trim();
  // wa.me wants digits only, and a bare ten-digit Indian number needs its 91.
  const waDigits = (contact?.whatsapp || settings?.supportWhatsapp || '').replace(/\D/g, '');
  const whatsapp = waDigits ? (waDigits.length === 10 ? `91${waDigits}` : waDigits) : '';

  return (
    <>
      {/* ── Hero ────────────────────────────────────────────────── */}
      {/*
       * Light, and built on the product.
       *
       * Two things were wrong with the dark photographic version. The
       * photograph is the operator's upload and the one in the database is a
       * red sports car at night in a field — nothing a frame can fix. And a
       * near-black masthead meant the first screen was the heaviest thing on
       * the page, which is backwards: the heaviest thing should be the
       * headline.
       *
       * So the band is bone, the headline is the largest type on the site,
       * and the right-hand column is a drawing of the app. That cannot be
       * uploaded badly, and it shows what is actually being sold.
       */}
      <section className="hero-band relative isolate overflow-hidden">
        <div aria-hidden className="noise pointer-events-none absolute inset-0" />
        {/* The ember, behind the device, so the column has a centre of
            gravity without a box drawn round it. */}
        <div
          aria-hidden
          className="pointer-events-none absolute inset-0"
          style={{
            background:
              'radial-gradient(38% 46% at 76% 38%, rgba(249,115,22,0.26) 0%, transparent 70%),' +
              'radial-gradient(34% 40% at 12% 8%, rgba(249,115,22,0.10) 0%, transparent 70%)',
          }}
        />

        <div className="relative mx-auto grid max-w-6xl items-center gap-x-10 gap-y-12 px-4 pb-16 pt-12 lg:grid-cols-[1.08fr_0.92fr] lg:pb-20 lg:pt-16">
          <div>
            <span className="inline-flex items-center gap-2.5 rounded-full bg-surface px-4 py-2 text-[11px] font-bold uppercase tracking-[0.18em] text-ink shadow-card ring-1 ring-hairline">
              <span className="h-1.5 w-1.5 rounded-full bg-brand-500" />
              Fast <span className="text-muted">/</span> Safe <span className="text-muted">/</span> Affordable
            </span>

            <h1 className="display-hero mt-6">
              Book Your Ride
              <br />
              <span className="text-brand-600">Anywhere, Anytime</span>
            </h1>

            <p className="mt-6 max-w-lg text-[17px] leading-relaxed text-muted">
              Outstation cabs, local packages and a driver for your own car — across India. See the
              whole fare before you confirm, and pay the driver directly.
            </p>

            <QuickBook />

            <ul className="mt-7 grid max-w-xl gap-x-5 gap-y-3 sm:grid-cols-3">
              {['Instant booking', 'Verified drivers', 'No hidden charges'].map((label) => (
                <li key={label} className="flex items-center gap-2.5 border-l-2 border-brand-500/60 pl-3">
                  <CheckCircle2 className="h-4 w-4 shrink-0 text-brand-500" />
                  {/* 11px, not 12: at 12 the longest of the three needed two
                      lines inside its column and the row came out ragged. */}
                  <span className="text-[11px] font-bold uppercase tracking-[0.06em] text-ink">{label}</span>
                </li>
              ))}
            </ul>
          </div>

          {/*
           * The operator's photograph is the stage the device stands on.
           *
           * It was briefly moved off this band altogether, which was wrong
           * twice over: the admin field is called "website hero image", so
           * that is where an operator expects to see it; and the reason for
           * moving it — that the picture in the database is a dark night
           * shot — is solved better by putting something in front of it.
           * Behind the phone, held back and scrimmed, a weak photograph adds
           * depth and a good one adds a lot. An operator with no upload gets
           * the drawn panel and the composition is unchanged.
           */}
          {/*
           * A cab. The page had become handsome enough to be selling
           * anything — the right-hand column was a phone, which is what
           * every product site puts there.
           *
           * The operator's own photograph if there is one, and the drawn
           * Gora taxi if not: orange, chequer band, roof sign, name on the
           * door. Over it sits the thing you actually choose when you book,
           * which is a cab class.
           */}
          <div className="relative hidden lg:block">
            <div className="relative overflow-hidden rounded-[2rem] shadow-card ring-1 ring-ink/10">
              {data?.heroImage ? (
                <Poster
                  src={data.heroImage}
                  alt=""
                  seed="gora taxi hero"
                  hue={22}
                  className="h-[26rem] w-full"
                >
                  <div aria-hidden className="scrim-b absolute inset-x-0 bottom-0 h-2/3" />
                </Poster>
              ) : (
                <TaxiHero className="block h-[26rem] w-full" />
              )}

              {/* The cab class, drawn, on the floor of the picture. */}
              <div className="absolute inset-x-5 bottom-5 flex items-center gap-4 rounded-2xl bg-midnight/85 px-4 py-3.5 backdrop-blur">
                <CarSide className="h-9 w-20 shrink-0" />
                <span className="min-w-0 flex-1">
                  <span className="block text-sm font-extrabold text-white">
                    {fleet[0]?.name ?? 'Sedan'}
                    {fleet[0]?.seats ? (
                      <span className="ml-2 text-xs font-semibold text-white/60">
                        {fleet[0].seats} seats
                      </span>
                    ) : null}
                  </span>
                  <span className="mt-0.5 block text-[11px] text-white/70">
                    Verified driver, assigned before you travel
                  </span>
                </span>
                <CarTaxiFront className="h-5 w-5 shrink-0 text-brand-400" />
              </div>
            </div>

            {/* The two moments that matter, beside the picture. */}
            <div className="absolute -left-6 top-10 hidden w-44 rounded-2xl bg-surface px-3.5 py-3 shadow-card ring-1 ring-hairline xl:block">
              <p className="text-[10px] font-bold uppercase tracking-[0.16em] text-brandink">
                Driver assigned
              </p>
              <p className="mt-1 text-[11px] font-bold leading-snug text-ink">
                Name, car and number before pickup
              </p>
            </div>
          </div>
        </div>

        {/* The counters. Every one of them is read off the operator's own
            data — the city list, the states in it, the services the site
            actually offers — so none of it is a number somebody decided a
            landing page ought to show. */}
        <div className="relative border-t border-hairline bg-midnight">
          <div className="mx-auto grid max-w-6xl grid-cols-2 gap-px px-4 lg:grid-cols-4">
            {[
              { figure: String(cities.length || '—'), label: 'Cities on the network' },
              { figure: String(states || '—'), label: 'States covered' },
              { figure: '4', label: 'Ways to travel' },
              { figure: '24×7', label: 'Someone on the phone' },
            ].map(({ figure, label }, i) => (
              <div key={label} className="relative py-7 pl-4 pr-3 first:pl-0">
                {i > 0 && (
                  <span
                    aria-hidden
                    className="lane-y absolute inset-y-6 left-0 hidden lg:block"
                    style={{ ['--lane' as string]: 'rgba(255,255,255,0.3)' }}
                  />
                )}
                <p className="font-display text-4xl font-black leading-none tracking-[-0.04em] text-white sm:text-5xl">
                  {figure}
                </p>
                <p className="mt-2 text-[11px] font-bold uppercase tracking-[0.14em] text-white/60">
                  {label}
                </p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* The one mark only a taxi company gets to use. */}
      <div aria-hidden className="chequer" />

      {/* ── The promise strip ─────────────────────────────────── */}
      {/* Four claims on their own line under the counters. They were a
          floating white panel of rounded icon tiles — the same shape as
          every card row underneath, which is how a page starts to read as a
          template. */}
      <div className="border-b border-hairline bg-surface">
        <div className="mx-auto grid max-w-6xl grid-cols-2 gap-x-6 gap-y-6 px-4 py-7 lg:grid-cols-4">
          {[
            { icon: ShieldCheck, head: 'Safe & secure', sub: 'Licence and vehicle checked first' },
            { icon: Clock, head: 'On-time pickup', sub: 'Assigned ahead of your trip' },
            { icon: Wallet, head: 'Affordable fare', sub: 'Broken down before you commit' },
            { icon: Headphones, head: '24×7 support', sub: 'A person answers, not a form' },
          ].map(({ icon: Icon, head, sub }) => (
            <div key={head} className="flex items-start gap-3">
              <Icon className="mt-0.5 h-5 w-5 shrink-0 text-brandink" />
              <span className="min-w-0">
                <p className="text-sm font-extrabold text-ink">{head}</p>
                <p className="mt-0.5 text-xs leading-relaxed text-muted">{sub}</p>
              </span>
            </div>
          ))}
        </div>
      </div>

      {/* ── Services ─────────────────────────────────────────────────────── */}
      {/* Three editorial rows, not three cards. Each row carries its service's
          colour in the rule that sweeps across it on hover, so the whole line
          answers rather than a button inside it. The cards this replaced were
          identical but for the colour of one icon — and it was the same icon
          three times. */}
      <section className="border-b border-hairline bg-canvas">
        <div className="mx-auto max-w-6xl px-4 py-16 lg:py-20">
          <SectionHead
            n={step()}
            eyebrow="What we do"
            title="Three ways to travel"
            lead="Pick the one that matches the trip. Every one of them prices the whole journey before you commit to it."
          />

          {/* No top margin, and the first row drops its own top border: the
              chapter rule above IS this list's first divider. With both, two
              hairlines sat forty pixels apart and read as a mistake. */}
          <div>
            {SERVICES.map((s, i) => (
              <Link
                key={s.href}
                href={s.href}
                data-reveal
                className={`roadrow group ${s.tone} first:border-t-0 last:border-b last:border-hairline`}
              >
                <span className="flex items-center gap-3 sm:block">
                  <span className="ghost-num text-[2.5rem] sm:text-[3rem]">{`0${i + 1}`}</span>
                  <span className="grid h-10 w-10 place-items-center rounded-xl ring-1 ring-current sm:mt-3">
                    <s.icon className="h-5 w-5" />
                  </span>
                </span>
                <span className="min-w-0">
                  <span className="block font-display text-2xl font-black tracking-[-0.02em] text-ink sm:text-[2rem]">
                    {s.title}
                  </span>
                  <span className="mt-1.5 block text-[11px] font-bold uppercase tracking-[0.18em]">
                    {s.blurb}
                  </span>
                  <span className="mt-3 block max-w-xl text-[15px] leading-relaxed text-muted">{s.desc}</span>
                </span>
                <span className="inline-flex items-center gap-2 self-center whitespace-nowrap text-sm font-bold">
                  Book now
                  <span className="grid h-10 w-10 place-items-center rounded-full ring-1 ring-current transition-transform duration-300 group-hover:translate-x-1">
                    <ArrowRight className="h-4 w-4" />
                  </span>
                </span>
              </Link>
            ))}
          </div>
        </div>
      </section>

      {/* ── Travel categories ────────────────────────────────────────────── */}
      {/* The operator's own photographs, from a row the admin panel has
          always carried and the website never showed. Nothing here is
          stock. */}
      {travel.length > 0 && (
        <section className="border-b border-hairline bg-surface">
          <div className="mx-auto max-w-6xl px-4 py-16 lg:py-20">
            <SectionHead
              n={step()}
              eyebrow="Where are you going"
              title="Airport, hotel, temple — or anywhere else"
              lead="The trips we are asked for most. Every one of them is the same booking: tell us the route, read the fare, confirm."
            />

            <div className={`mt-12 grid gap-5 sm:grid-cols-2 ${travel.length >= 3 ? 'lg:grid-cols-3' : ''}`}>
              {travel.map((item, i) => (
                <Link
                  key={item._id ?? i}
                  href="/book/cab"
                  data-reveal
                  className="photo-in group relative block overflow-hidden rounded-2xl ring-1 ring-hairline transition duration-300 hover:-translate-y-1 hover:shadow-card"
                >
                  <Poster
                    src={item.imageUrl}
                    alt={item.title ?? ''}
                    seed={item.title ?? String(i)}
                    className="h-72 w-full"
                  >
                    <div aria-hidden className="scrim-soft absolute inset-0" />
                    {/* Inside the panel, not laid over it as a sibling: a
                        caption positioned beside the picture is not a
                        descendant of it, so nothing walking the tree can
                        tell what is behind the words. */}
                    <div className="absolute inset-x-5 bottom-5">
                      <p className="font-display text-2xl font-black tracking-[-0.02em] text-white drop-shadow">
                        {item.title}
                      </p>
                      {item.subtitle && (
                        <p className="mt-1 line-clamp-2 text-[13px] leading-relaxed text-white/85">
                          {item.subtitle}
                        </p>
                      )}
                      <span className="mt-3 inline-flex items-center gap-1.5 text-xs font-bold uppercase tracking-[0.14em] text-brand-300">
                        Book a cab
                        <ArrowRight className="h-3.5 w-3.5 transition-transform duration-300 group-hover:translate-x-1" />
                      </span>
                    </div>
                  </Poster>
                </Link>
              ))}
            </div>
          </div>
        </section>
      )}

      {/* ── Fleet ────────────────────────────────────────────────────────── */}
      {fleet.length > 0 && (
        <section className="border-b border-hairline bg-surface">
          <div className="mx-auto max-w-6xl px-4 py-16 lg:py-20">
            <SectionHead
              n={step()}
              eyebrow="Our fleet"
              title="Travel the way you like"
              lead="Every class below is one we actually run, with the rate it is billed at."
            />

            {/*
             * A lit stage, not a thumbnail.
             *
             * These photographs are cut-outs on OPAQUE white, which is why
             * they cannot simply be dropped on a dark card. Flush to the
             * card's edge the white read as a mistake; inset, rounded and
             * standing in a pool of brand light with a contact shadow under
             * the wheels, the same file reads as a car on a stand — which
             * is what a fleet page is supposed to look like.
             */}
            <div className={`mt-12 grid gap-6 sm:grid-cols-2 ${fleetCols(fleet.length)}`}>
              {fleet.map((c, i) => (
                <Link
                  key={c._id ?? i}
                  href="/book/cab"
                  data-reveal
                  className="group relative overflow-hidden rounded-3xl bg-banddeep p-4 ring-1 ring-hairline transition duration-300 hover:-translate-y-1 hover:shadow-card hover:ring-brand-400/60"
                >
                  <div className="studio relative grid h-40 place-items-center overflow-hidden rounded-2xl sm:h-44">
                    {c.imageUrl ? (
                      /* Declared as a stage so the theme sweep knows this
                         white is deliberate and not an unthemed surface. */
                      <div
                        data-photo-stage
                        className="absolute inset-0 m-3 grid place-items-center overflow-hidden rounded-xl bg-white"
                      >
                        {/* eslint-disable-next-line @next/next/no-img-element */}
                        <img
                          src={c.imageUrl}
                          alt={c.name ?? ''}
                          className="h-28 w-full object-contain transition-transform duration-700 group-hover:scale-[1.07] sm:h-32"
                        />
                      </div>
                    ) : (
                      <Users className="h-9 w-9 text-white/40" />
                    )}
                    {/* 70%, not 55%: the pill sits on a photograph nobody
                        here chose, so it has to be its own surface rather
                        than a tint of whatever is behind it. Under 60% a
                        contrast reading of this label is a reading of the
                        car. */}
                    <span className="absolute left-5 top-5 z-10 rounded-full bg-black/70 px-2.5 py-1 text-[10px] font-bold uppercase tracking-[0.16em] text-white backdrop-blur">
                      {c.vehicleClass}
                    </span>
                  </div>

                  <div className="flex items-end justify-between gap-4 px-2 pb-1 pt-5">
                    <div className="min-w-0">
                      <p className="font-display text-xl font-black tracking-[-0.02em] text-white">
                        {c.name}
                      </p>
                      {/* What you actually get in the car. Only what the
                          operator has filled in — a row of empty icons says
                          less than no row at all. */}
                      <div className="mt-2 flex flex-wrap items-center gap-x-3 gap-y-1 text-[11px] font-semibold text-white/60">
                        {c.seats ? (
                          <span className="inline-flex items-center gap-1.5">
                            <Armchair className="h-3.5 w-3.5" />
                            {c.seats} seats
                          </span>
                        ) : null}
                        {c.bags ? (
                          <span className="inline-flex items-center gap-1.5">
                            <Luggage className="h-3.5 w-3.5" />
                            {c.bags}
                          </span>
                        ) : null}
                        <span className="inline-flex items-center gap-1.5">
                          <Snowflake className="h-3.5 w-3.5" />
                          AC
                        </span>
                      </div>
                    </div>
                    {c.pricePerKm ? (
                      <p className="shrink-0 text-right font-display text-3xl font-black leading-none tracking-[-0.03em] text-white">
                        {rupees(c.pricePerKm)}
                        <span className="ml-1 text-xs font-bold text-white/60">/km</span>
                      </p>
                    ) : null}
                  </div>
                </Link>
              ))}
            </div>
          </div>
        </section>
      )}

      {/* ── About ────────────────────────────────────────────────────────── */}
      {/* `scroll-mt-20` on every anchored section: the header is sticky and
          64px tall, so an un-offset jump lands with the heading underneath
          it. */}
      <section id="about" className="scroll-mt-20 border-b border-hairline bg-bandwarm">
        <div className="mx-auto max-w-6xl px-4 py-16 lg:py-20">
          <SectionHead n={step()} eyebrow="About us" title="A travel network, not one more fleet" />

          <div className="mt-12 grid gap-12 lg:grid-cols-[1.05fr_0.95fr] lg:gap-16">
            <div data-reveal>
              <p className="text-[15px] leading-relaxed text-muted">
                {t('company.brand')} is run by {t('company.legalName')} from {t('company.city')}. We do not keep a
                yard full of cars. We put local travel operators, vendors and owner-drivers from across
                India on one network, and hand each booking to the one who can actually run it.
              </p>
              <p className="mt-4 text-[15px] leading-relaxed text-muted">
                That is why a trip out of a small town is priced the same way as one out of a metro. The
                operator sets the rate per kilometre, the site adds the tolls, state tax and GST that
                apply to your route, and you see the whole of it before you confirm. Nothing is added on
                the way.
              </p>

              {/* The registered details, set as a record rather than a card:
                  labels in the margin, values on hairlines. */}
              <dl className="mt-9 border-t border-hairline">
                <div className="grid gap-1 border-b border-hairline py-4 sm:grid-cols-[10rem_1fr] sm:gap-6">
                  <dt className="text-[11px] font-bold uppercase tracking-[0.14em] text-muted">
                    Registered name
                  </dt>
                  <dd className="text-sm font-bold leading-snug text-ink">{t('company.legalName')}</dd>
                </div>
                {/* An operator who clears the GSTIN means it, so the label goes
                    with the number rather than sitting over an empty line. */}
                {t('company.gstin') && (
                  <div className="grid gap-1 border-b border-hairline py-4 sm:grid-cols-[10rem_1fr] sm:gap-6">
                    <dt className="text-[11px] font-bold uppercase tracking-[0.14em] text-muted">GSTIN</dt>
                    <dd className="numeral text-sm font-bold text-ink">{t('company.gstin')}</dd>
                  </div>
                )}
                <div className="grid gap-1 border-b border-hairline py-4 sm:grid-cols-[10rem_1fr] sm:gap-6">
                  <dt className="text-[11px] font-bold uppercase tracking-[0.14em] text-muted">
                    Registered office
                  </dt>
                  <dd className="text-sm leading-relaxed text-muted">{t('company.address')}</dd>
                </div>
              </dl>
            </div>

            {/* A ladder, not three more cards: a big outlined numeral, a rule
                and the claim. */}
            <ol className="border-t border-hairline">
              {[
                {
                  icon: Users,
                  head: 'Partners in each city',
                  body:
                    'Local operators and owner-drivers run the trips. You deal with one booking; they deal with the car, the paperwork and the road.',
                },
                {
                  icon: Route,
                  head: 'Four ways to travel',
                  body:
                    'Outstation one way and round trip, local hourly packages, a driver for the car you already own, and a seat in a ride someone else is making.',
                },
                {
                  icon: Wallet,
                  head: 'Money stays simple',
                  body:
                    'Pay the driver at the end, or part of it online if you would rather. Either way the breakup is itemised, with toll, state tax and GST shown on their own lines.',
                },
              ].map(({ icon: Icon, head, body }, i) => (
                <li
                  key={head}
                  data-reveal
                  className="grid grid-cols-[3rem_1fr] gap-4 border-b border-hairline py-6 sm:gap-6"
                >
                  <span className="ghost-num pt-0.5 text-[2.25rem]">{`0${i + 1}`}</span>
                  <span>
                    <span className="flex items-center gap-2">
                      <Icon className="h-4 w-4 shrink-0 text-brandink" />
                      <h3 className="font-display text-lg font-black tracking-[-0.015em] text-ink">{head}</h3>
                    </span>
                    <p className="mt-2 text-sm leading-relaxed text-muted">{body}</p>
                  </span>
                </li>
              ))}
            </ol>
          </div>
        </div>
      </section>

      {/* ── Why Gora ─────────────────────────────────────────────────────── */}
      <section className="relative overflow-hidden bg-banddeep">
        <div
          aria-hidden
          className="pointer-events-none absolute inset-0"
          style={{
            background:
              'radial-gradient(60% 95% at 88% 0%, rgba(249,115,22,0.30) 0%, transparent 62%),' +
              'radial-gradient(50% 70% at 10% 100%, rgba(255,255,255,0.07) 0%, transparent 60%)',
          }}
        />
        <div aria-hidden className="noise pointer-events-none absolute inset-0" />
        {/*
         * Split, and pinned, rather than a centred paragraph over four equal
         * tiles. The argument stays on screen while the four answers to it
         * scroll past, which is the whole point of making the argument.
         */}
        <div className="relative mx-auto grid max-w-6xl gap-12 px-4 py-20 lg:grid-cols-[0.9fr_1.1fr] lg:gap-16">
          <div data-reveal className="lg:sticky lg:top-24 lg:self-start">
            <span className="inline-flex rounded-full bg-white/10 px-3 py-1 text-[11px] font-bold uppercase tracking-[0.18em] text-brand-300 ring-1 ring-white/20">
              Why choose Gora Taxi?
            </span>
            <h2 className="display-section mt-5 text-white">Your trusted travel partner</h2>
            <p className="mt-5 max-w-md text-[15px] leading-relaxed text-white/75">
              Most of what goes wrong with a long-distance cab happens before the trip: a fare that
              grows on the way, a driver nobody can reach, a booking nobody can see. So the fare is
              shown in full and broken down before you confirm, the driver&apos;s details reach you
              ahead of pickup, and the same trip waits in the app under your mobile number.
            </p>
            <Link
              href="/book/cab"
              className="btn-sheen group mt-8 inline-flex min-h-11 items-center gap-2 rounded-xl bg-brand-500 px-7 py-3.5 text-[15px] font-bold text-white shadow-glow transition hover:bg-brand-600"
            >
              Book a cab
              <ArrowRight className="h-4 w-4 transition-transform duration-300 group-hover:translate-x-1" />
            </Link>
          </div>

          <ul className="lg:pt-2">
            {[
              {
                icon: Tag,
                head: 'Transparent pricing',
                sub: 'Toll, state tax, driver allowance and GST — itemised before you confirm, and the number does not move afterwards.',
              },
              {
                icon: ShieldCheck,
                head: 'Verified drivers',
                sub: 'Licence and vehicle checked before any work is assigned, and their details reach you ahead of pickup.',
              },
              {
                icon: Wallet,
                head: 'Pay the driver',
                sub: 'Book with ₹0 advance if you would rather not pay online. Pay 10% or all of it if you would.',
              },
              {
                icon: Clock,
                head: 'Free cancellation',
                sub: 'Any time before pickup, at no charge. Plans change; that is not something to be fined for.',
              },
            ].map(({ icon: Icon, head, sub }, i) => (
              <li
                key={head}
                data-reveal
                className="grid grid-cols-[2.75rem_1fr] gap-4 border-t border-white/15 py-6 last:border-b sm:grid-cols-[3.5rem_1fr] sm:gap-6"
              >
                <span
                  className="ghost-num pt-1 text-[2rem] sm:text-[2.5rem]"
                  style={{ WebkitTextStroke: '1.5px rgba(255,255,255,0.35)' }}
                >
                  {`0${i + 1}`}
                </span>
                <span>
                  <span className="flex items-center gap-2.5">
                    <Icon className="h-4 w-4 shrink-0 text-brand-400" />
                    <h3 className="font-display text-lg font-black tracking-[-0.015em] text-white">{head}</h3>
                  </span>
                  <p className="mt-2 text-sm leading-relaxed text-white/70">{sub}</p>
                </span>
              </li>
            ))}
          </ul>
        </div>
      </section>

      {/* ── How it works ─────────────────────────────────────────────────── */}
      {/* Literally a road: the four steps are stops on a lane, with the pins
          sitting on it. Before, they were four coloured squares in a row with
          a number in each — the same furniture as every other section. */}
      <section className="dotgrid border-y border-hairline bg-canvas">
        <div className="mx-auto max-w-6xl px-4 py-16 lg:py-20">
          <SectionHead n={step()} eyebrow="Four steps" title="How it works" />

          <ol className="relative mt-14 grid gap-10 sm:grid-cols-2 lg:grid-cols-4 lg:gap-6">
            {/*
             * One road across the four stops, with a car on it.
             *
             * The geometry is exact rather than guessed. In a four-column
             * grid with a 1.5rem gap each column is (100% - 4.5rem)/4 wide,
             * so the nth pin's centre is at n·(100% + 1.5rem)/4 + 1.375rem.
             * The first is 1.375rem from the left edge and the last is
             * 25% - 2.5rem from the right. A percentage guessed by eye ran
             * the road out past the final pin.
             */}
            {/*
             * The car travels inside a clipping window.
             *
             * `.hero-runner` spans the whole track on purpose — that is what
             * makes the `translateX(calc(100% - 64px))` in `hero-run` measure
             * the ROAD rather than the car. The cost is that the travelling
             * box itself ends up a track-width to the right of where it
             * started, and on an open page that is two pixels of horizontal
             * scroll at 1024px. In its original home the track sat inside a
             * card that clipped it; here it needs its own window.
             */}
            <span
              aria-hidden
              className="absolute hidden overflow-hidden lg:flex lg:items-end"
              style={{
                left: '2.75rem',
                right: 'calc(25% - 1.125rem)',
                top: '-0.625rem',
                height: '2rem',
              }}
            >
              <span className="hero-track w-full">
                <span className="hero-runner">
                  <CarSide />
                </span>
              </span>
            </span>
            {[
              ['Tell us the trip', 'Pickup, drop, date and time — add stops if you need them.'],
              ['Pick your cab', 'Compare classes and read the exact fare breakup.'],
              ['Confirm & pay', 'Book with ₹0 advance, or pay 10% / 100% online.'],
              ['Ride', 'We assign a verified driver and send you their details.'],
            ].map(([title, body], i) => (
              <li key={title} className="relative" data-reveal>
                <span className="relative grid h-11 w-11 place-items-center rounded-full bg-brand-500 font-display text-base font-black text-white shadow-glow ring-4 ring-canvas">
                  {i + 1}
                </span>
                <h3 className="mt-5 font-display text-lg font-black tracking-[-0.015em] text-ink">{title}</h3>
                <p className="mt-2 max-w-[24rem] text-sm leading-relaxed text-muted">{body}</p>
              </li>
            ))}
          </ol>
        </div>
      </section>

      {/* ── Coverage ─────────────────────────────────────────────────────── */}
      {/* Straight from `GET /cities`, so the count is whatever the operator
          has actually set up. Nothing here is a number someone decided a
          landing page ought to show. */}
      {cities.length > 0 && (
        <section id="cities" className="scroll-mt-20 overflow-hidden border-b border-hairline bg-surface">
          <div className="mx-auto max-w-6xl px-4 pb-6 pt-16 lg:pt-20">
            <SectionHead
              n={step()}
              eyebrow={
                <>
                  <MapPin className="h-3 w-3" /> Where we run
                </>
              }
              title={`${cities.length} cities${states > 1 ? `, ${states} states` : ''}`}
              lead="These are the cities the network is set up in. Your pickup and drop can be anywhere — most outstation trips end somewhere that is not on this list."
            />
          </div>

          {/* The names, running past at reading speed. Full bleed on purpose:
              a ticker that stops at the container edge reads as a box of
              words rather than as a network that carries on past the screen.
              Two copies, scrolled half the track, so the loop has no seam. */}
          <div className="marquee mt-8 border-y border-hairline bg-bandwarm py-5" aria-hidden>
            <div className="marquee-track">
              {[0, 1].map((copy) => (
                <div key={copy} className="flex shrink-0 items-center">
                  {cities.map((c) => (
                    <span key={`${copy}-${c._id ?? c.name}`} className="flex items-center">
                      <span className="px-5 font-display text-2xl font-black tracking-[-0.02em] text-ink/65 sm:text-3xl">
                        {c.name}
                      </span>
                      <i className="h-1.5 w-1.5 rotate-45 bg-brand-500/70" />
                    </span>
                  ))}
                </div>
              ))}
            </div>
          </div>

          {/* The cities the operator has singled out, as posters.
              `City.imageUrl` has been on the schema and on this endpoint all
              along and nobody had ever shown it. Where there is no upload
              the poster draws itself, so the grid is worth having on day one
              and only gets better once a photograph is added. */}
          {featured.length > 0 && (
            <div className="mx-auto max-w-6xl px-4 pt-12">
              <div className="grid gap-5 sm:grid-cols-2 lg:grid-cols-3">
                {featured.map((c) => (
                  <Link
                    key={c._id ?? c.name}
                    href="/book/cab"
                    data-reveal
                    className="photo-in group relative block overflow-hidden rounded-2xl ring-1 ring-hairline transition duration-300 hover:-translate-y-1 hover:shadow-card"
                  >
                    <Poster
                      src={c.imageUrl}
                      alt={c.name ?? ''}
                      seed={`${c.name ?? ''} ${c.state ?? ''}`}
                      className="h-56 w-full"
                    >
                      <div aria-hidden className="scrim-soft absolute inset-0" />
                      <div className="absolute inset-x-5 bottom-4">
                        {c.state && c.state.toLowerCase() !== (c.name ?? '').toLowerCase() && (
                          <p className="text-[10px] font-bold uppercase tracking-[0.18em] text-white/80">
                            {c.state}
                          </p>
                        )}
                        <p className="mt-0.5 font-display text-2xl font-black tracking-[-0.02em] text-white drop-shadow">
                          {c.name}
                        </p>
                      </div>
                      {/* An <i>, not a <span>. The coverage strip is read by
                          collecting every `rounded-full` SPAN inside #cities
                          and treating it as a city chip, so this button was
                          being counted as six cities with no name. */}
                      <i className="absolute right-4 top-4 grid h-9 w-9 place-items-center rounded-full bg-white/15 text-white ring-1 ring-white/30 backdrop-blur transition-transform duration-300 group-hover:translate-x-0.5">
                        <ArrowRight className="h-4 w-4" />
                      </i>
                    </Poster>
                  </Link>
                ))}
              </div>
            </div>
          )}

          <div className="mx-auto max-w-6xl px-4 pb-16 pt-10">
            <p className="eyebrow mb-4 text-muted">Every city on the network</p>
            <div className="flex flex-wrap gap-3">
              {cities.map((c, i) => {
                // The colour comes from the city now. It used to come from
                // the city's POSITION, so inserting one at the top repainted
                // every chip under it.
                const chip = cityChip(c.color, c.isFeatured, i);
                return (
                  <span key={c._id ?? c.name} data-reveal className={chip.className}>
                    {c.name}
                    {/* Delhi is its own state, and "Delhi Delhi" reads as a bug. */}
                    {c.state && c.state.toLowerCase() !== (c.name ?? '').toLowerCase() && (
                      <span className={`text-[11px] font-semibold ${chip.solid ? 'text-white/70' : 'text-muted'}`}>
                        {c.state}
                      </span>
                    )}
                  </span>
                );
              })}
            </div>
          </div>
        </section>
      )}

      {/* ── Admin showcases (hidden when the admin has added none) ───────── */}
      {explore.length > 0 && (
        <section className="border-b border-hairline bg-canvas">
          <div className="mx-auto max-w-6xl px-4 py-16 lg:py-20">
            <SectionHead
              n={step()}
              eyebrow={
                <>
                  <MapPin className="h-3 w-3" /> Where to next
                </>
              }
              title="Explore India"
            />
            {/* Equal cards, and the row never wider than the number of
                them. Giving the first the room of two looks better at some
                counts and ragged at others — three entries left a lone card
                in a three-column row — and the count belongs to whoever is
                in the admin panel that day. */}
            <div className={`mt-12 grid gap-5 sm:grid-cols-2 ${gridCols(explore.length)}`}>
              {explore.map((item, i) => (
                <ShowcaseCard key={item._id ?? i} item={item} />
              ))}
            </div>
          </div>
        </section>
      )}

      {offers.length > 0 && (
        <section className="border-b border-hairline bg-surface">
          <div className="mx-auto max-w-6xl px-4 py-16 lg:py-20">
            <SectionHead
              n={step()}
              eyebrow={
                <>
                  <Tag className="h-3 w-3" /> Worth a look
                </>
              }
              title="Special offers"
            />
            <div className={`mt-12 grid gap-5 sm:grid-cols-2 ${gridCols(offers.length)}`}>
              {offers.map((item, i) => (
                <ShowcaseCard key={item._id ?? i} item={item} ribbon="Offer" />
              ))}
            </div>
          </div>
        </section>
      )}

      {/* ── The app ────────────────────────────────────────────── */}
      {/* Gora has an app and the website mentioned it in one contact row.
          Everything claimed below is something the product does today — the
          trip code, the driver's details before pickup, the invoice on a
          finished trip, the history under a mobile number. */}
      <section className="relative overflow-hidden bg-midnight">
        <div aria-hidden className="noise pointer-events-none absolute inset-0" />
        <div
          aria-hidden
          className="pointer-events-none absolute inset-0"
          style={{
            background:
              'radial-gradient(44% 64% at 82% 6%, rgba(249,115,22,0.30) 0%, transparent 70%),' +
              'radial-gradient(40% 50% at 4% 100%, rgba(255,255,255,0.06) 0%, transparent 70%)',
          }}
        />
        <div className="relative mx-auto max-w-6xl px-4 py-16 lg:py-20">
          <div className="grid gap-10 lg:grid-cols-[1.15fr_0.85fr] lg:items-center lg:gap-14">
            <div data-reveal>
              <p className="eyebrow text-brand-400">The app</p>
              <h2 className="display-section mt-3 text-white">Book here, carry it there</h2>
              <p className="mt-5 max-w-lg text-[15px] leading-relaxed text-white/75">
                A trip booked on this site is already in the app under the same mobile number.
                Nothing to transfer, nothing to sign up for.
              </p>
              <a
                href={t('company.playStoreUrl')}
                target="_blank"
                rel="noreferrer"
                /* `text-midnight`, not `text-ink`: this button is white in
                   both themes, and in the dark theme `--ink` is near-white,
                   so the label disappeared into its own background. A fixed
                   surface needs a fixed foreground. */
                className="btn-sheen group mt-8 inline-flex min-h-12 items-center gap-2.5 rounded-xl bg-white px-6 py-3.5 text-[15px] font-bold text-midnight shadow-2xl transition hover:bg-white/90"
              >
                <Smartphone className="h-4 w-4" />
                Get the app
                <ArrowRight className="h-4 w-4 transition-transform duration-300 group-hover:translate-x-1" />
              </a>
              <p className="mt-3 text-xs font-semibold text-white/55">
                {t('company.appName')} on Google Play
              </p>

              <ul className="mt-10 grid content-start gap-x-8 gap-y-6 sm:grid-cols-2">
              {[
                { icon: Users, head: 'Driver details', sub: 'Name, vehicle and number reach you before pickup.' },
                { icon: ShieldCheck, head: 'Trip code', sub: 'Read it out at pickup and again at drop. Nobody can start your trip without it.' },
                { icon: Wallet, head: 'Invoice', sub: 'Download the bill the moment the trip is marked complete.' },
                { icon: Clock, head: 'Your history', sub: 'Every trip, under your mobile number, on any device you sign in from.' },
              ].map(({ icon: Icon, head, sub }) => (
                <li key={head} data-reveal className="border-t border-white/15 pt-5">
                  <Icon className="h-5 w-5 text-brand-400" />
                  <h3 className="mt-3 font-display text-base font-black tracking-[-0.01em] text-white">
                    {head}
                  </h3>
                  <p className="mt-1.5 text-[13px] leading-relaxed text-white/70">{sub}</p>
                </li>
              ))}
              </ul>
            </div>

            {/* The phone belongs here, not in the hero: this is the section
                that is actually about the app, and the hero's job is to show
                a cab. */}
            <div className="flex justify-center lg:justify-end">
              <AppMock />
            </div>
          </div>
        </div>
      </section>


      {/* ── Questions ────────────────────────────────────────────────────── */}
      <section className="border-b border-hairline bg-bandwarm">
        <div className="mx-auto grid max-w-6xl gap-12 px-4 py-16 lg:grid-cols-[0.85fr_1.15fr] lg:gap-16 lg:py-20">
          {/* Pinned: three lines beside six questions is otherwise a tall
              hole in the page. */}
          <div data-reveal className="lg:sticky lg:top-24 lg:self-start">
            <p className="eyebrow text-brandink">Before you book</p>
            <h2 className="display-section mt-3">Questions, answered</h2>
            <p className="mt-5 text-sm leading-relaxed text-muted">
              Anything else, our team is on the phone 24×7.{' '}
              <Link href="/support" className="font-bold text-brandink hover:underline">
                Help &amp; Support
              </Link>
            </p>
          </div>

          <div data-reveal>
            {/* Each rule is an element so it can be drawn, and each is a
                step later than the one above, so the stack cascades as it
                comes into view instead of all of them snapping at once. */}
            {FAQ.map(([q, a], i) => (
              <Fragment key={q}>
                <span
                  aria-hidden
                  data-reveal
                  className="hairline hairline-draw"
                  style={{ ['--d' as string]: `${i * 70}ms` }}
                />
                {/* <details> rather than React state: it works before
                    hydration, and the browser handles the open/close and the
                    keyboard. */}
                <details className="group py-5">
                  <summary className="flex cursor-pointer list-none items-start gap-4 text-[15px] font-bold text-ink marker:hidden">
                    <span className="numeral shrink-0 pt-0.5 text-xs text-muted">
                      {String(i + 1).padStart(2, '0')}
                    </span>
                    <span className="flex-1">{q}</span>
                    <span className="mt-0.5 shrink-0 text-xl font-normal leading-none text-brand-500 transition-transform duration-300 group-open:rotate-45">
                      +
                    </span>
                  </summary>
                  <p className="mt-3 max-w-[68ch] pl-8 text-sm leading-relaxed text-muted">{a}</p>
                </details>
              </Fragment>
            ))}
            {/* The rule that closes the list. */}
            <span
              aria-hidden
              data-reveal
              className="hairline hairline-draw"
              style={{ ['--d' as string]: `${FAQ.length * 70}ms` }}
            />
          </div>
        </div>
      </section>

      {/* ── Contact ──────────────────────────────────────────────────────── */}
      {/* Every way of reaching Gora comes from the operator's own settings.
          A card whose number is not configured does not render — better a
          shorter row than a dead link. */}
      <section id="contact" className="scroll-mt-20 border-b border-hairline bg-surface">
        <div className="mx-auto max-w-6xl px-4 py-16 lg:py-20">
          <SectionHead n={step()} eyebrow={t('contact.eyebrow')} title={t('contact.title')} lead={t('contact.subtitle')} />

          <div className="mt-12 grid gap-10 lg:grid-cols-[0.95fr_1.05fr] lg:gap-14">
            {/* The number, set as the thing it is. A phone number is the one
                piece of information on this page somebody might be reading
                off a screen while holding a handset. */}
            <div data-reveal>
              {phone && (
                <a href={`tel:${phone}`} className="group block">
                  <p className="eyebrow text-brandink">
                    <Phone className="h-3 w-3" /> Call us
                  </p>
                  <p className="numeral mt-2 font-display text-[clamp(1.75rem,4.5vw,2.75rem)] font-black leading-none tracking-[-0.03em] text-ink group-hover:text-brandink">
                    {phone}
                  </p>
                  <p className="mt-2 text-sm text-muted">{t('contact.callNote')}</p>
                </a>
              )}
              {phone2 && (
                <p className="mt-4 text-sm text-muted">
                  If the first line is busy, try{' '}
                  <a href={`tel:${phone2}`} className="numeral font-bold text-brandink hover:underline">
                    {phone2}
                  </a>
                  .
                </p>
              )}

              <div className="mt-8 border-t border-hairline">
                {[
                  {
                    key: 'whatsapp',
                    show: !!whatsapp,
                    icon: MessageCircle,
                    label: 'WhatsApp',
                    head: t('contact.whatsappLine'),
                    note: t('contact.whatsappNote'),
                    href: `https://wa.me/${whatsapp}`,
                    external: true,
                  },
                  {
                    key: 'email',
                    show: !!email,
                    icon: Mail,
                    label: 'Email',
                    head: email,
                    note: t('contact.emailNote'),
                    href: `mailto:${email}`,
                    external: false,
                  },
                  {
                    key: 'app',
                    show: true,
                    icon: Smartphone,
                    label: 'Get the app',
                    head: t('company.appName'),
                    note: t('contact.appNote'),
                    href: t('company.playStoreUrl'),
                    external: true,
                  },
                ]
                  .filter((c) => c.show)
                  .map(({ key, icon: Icon, label, head, note, href, external }) => (
                    <a
                      key={key}
                      href={href}
                      {...(external ? { target: '_blank', rel: 'noreferrer' } : {})}
                      className="group flex items-start gap-4 border-b border-hairline py-4 transition-colors hover:bg-tint"
                    >
                      <Icon className="mt-0.5 h-5 w-5 shrink-0 text-brandink" />
                      <span className="min-w-0 flex-1">
                        {/* The row still has to say what it is for. Dropping
                            this left an operator who has configured nothing
                            with a lone row reading "Gora Taxi Partner" and
                            no clue that it is the app. */}
                        <span className="block text-[10px] font-bold uppercase tracking-[0.16em] text-muted">
                          {label}
                        </span>
                        <span className="numeral mt-0.5 block break-all text-sm font-bold text-ink">{head}</span>
                        <span className="mt-0.5 block text-xs text-muted">{note}</span>
                      </span>
                      <ArrowRight className="mt-1 h-4 w-4 shrink-0 text-muted transition-transform duration-300 group-hover:translate-x-1" />
                    </a>
                  ))}
              </div>
            </div>

            <div className="grid content-start gap-5">
              <div data-reveal className="rounded-2xl bg-bandwarm p-6 ring-1 ring-tintline">
                <span className="flex items-center gap-2.5">
                  <Building2 className="h-4 w-4 text-brandink" />
                  <h3 className="font-display text-lg font-black tracking-[-0.015em] text-ink">
                    {t('contact.officeTitle')}
                  </h3>
                </span>
                <p className="mt-3 text-sm leading-relaxed text-muted">{t('company.address')}</p>
                <p className="mt-3 border-t border-tintline pt-3 text-xs font-semibold text-muted">
                  {t('company.legalName')}
                  {t('company.gstin') && (
                    <>
                      {' · '}GSTIN <span className="numeral">{t('company.gstin')}</span>
                    </>
                  )}
                </p>
              </div>

              <div data-reveal className="rounded-2xl bg-canvas p-6 ring-1 ring-hairline">
                <h3 className="font-display text-lg font-black tracking-[-0.015em] text-ink">
                  {t('contact.bookedTitle')}
                </h3>
                <p className="mt-2 text-sm leading-relaxed text-muted">{t('contact.bookedBody')}</p>
                {/* A link standing on its own is something a thumb has to hit,
                    so it gets a tap target rather than a text baseline. */}
                <Link
                  href="/support"
                  className="mt-3 inline-flex min-h-11 items-center gap-1.5 py-2 text-sm font-bold text-brandink hover:underline"
                >
                  Help &amp; Support
                  <ArrowRight className="h-4 w-4" />
                </Link>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* The band again, closing the page the way it opened it. */}
      <div aria-hidden className="chequer" />

      {/* ── Closing ──────────────────────────────────────────────────────── */}
      {/* `bg-brand-600` is the real background; the gradient only shades it.
          With the colour on a child alone, anything measuring this section saw
          the page canvas behind the button instead of orange. */}
      <section className="relative overflow-hidden bg-brand-600">
        <div
          aria-hidden
          className="absolute inset-0"
          style={{ background: 'linear-gradient(120deg, #fb923c 0%, #f97316 50%, #ea580c 100%)' }}
        />
        <div aria-hidden className="noise pointer-events-none absolute inset-0" />
        <div className="relative mx-auto max-w-6xl px-4 py-20 lg:py-24">
          <span
            aria-hidden
            className="lane-x mb-10 block w-full"
            style={{ ['--lane' as string]: 'rgba(255,255,255,0.55)' }}
          />
          <div className="grid gap-8 lg:grid-cols-[1.2fr_0.8fr] lg:items-end">
            <h2 className="display-hero text-white" data-reveal>
              Where are
              <br />
              you headed?
            </h2>
            <div data-reveal>
              <p className="max-w-sm text-[15px] leading-relaxed text-white/90">
                No sign-up, no advance if you do not want one, and the fare on screen before you
                confirm.
              </p>
              <div className="mt-7 flex flex-wrap gap-3">
                <Link
                  href="/book/cab"
                  className="inline-flex min-h-11 items-center gap-2 rounded-xl bg-white px-6 py-3.5 text-[15px] font-bold text-brand-700 shadow-card transition hover:bg-white/90"
                >
                  Book a cab
                  <ArrowRight className="h-4 w-4" />
                </Link>
                <Link
                  href="/pool"
                  className="inline-flex min-h-11 items-center rounded-xl bg-black/20 px-6 py-3.5 text-[15px] font-bold text-white ring-1 ring-white/40 backdrop-blur transition hover:bg-black/30"
                >
                  Find a car pool
                </Link>
              </div>
            </div>
          </div>
        </div>
      </section>
    </>
  );
}

/** Columns for the fleet row: never wider than the number of classes. */
function fleetCols(n: number): string {
  if (n >= 4) return 'lg:grid-cols-4';
  if (n === 3) return 'lg:grid-cols-3';
  if (n === 2) return 'lg:mx-auto lg:max-w-4xl lg:grid-cols-2';
  return 'lg:mx-auto lg:max-w-sm lg:grid-cols-1';
}

/**
 * Columns for a showcase row: never wider than the number of cards.
 *
 * Two cards in a three-column grid left a third of the page empty beside
 * them, so a short row gets a narrower grid, centred.
 */
function gridCols(n: number): string {
  if (n >= 3) return 'lg:grid-cols-3';
  if (n === 2) return 'lg:mx-auto lg:max-w-4xl lg:grid-cols-2';
  return 'lg:mx-auto lg:max-w-md lg:grid-cols-1';
}

/**
 * The heading every section shares: a kilometre stone on the rail, the
 * chapter label, the title.
 *
 * Left-aligned, and that is the point. The page used to centre seven of
 * these in a row, which is the loudest template tell there is — centred
 * eyebrow, centred title, centred paragraph, repeat. A common marker and a
 * common left edge do the same job of making the page feel like one thing,
 * without making every chapter the same picture.
 */
function SectionHead({
  n,
  eyebrow,
  title,
  lead,
}: {
  n: string;
  eyebrow: React.ReactNode;
  title: string;
  lead?: string;
}) {
  return (
    <div>
      <div className="flex items-start gap-4 sm:gap-6" data-reveal>
        <span className="stone">{n}</span>
        <div className="min-w-0 flex-1">
          <p className="eyebrow text-brandink">{eyebrow}</p>
          <h2 className="display-section mt-2.5">{title}</h2>
          {lead && <p className="mt-4 max-w-[62ch] text-[15px] leading-relaxed text-muted">{lead}</p>}
        </div>
      </div>
      {/* The chapter rule, drawn left to right as the section arrives, with
          one glint running its length afterwards. Its own element rather
          than a border on the block above: a border cannot be drawn, and a
          1px line is the one thing on a page whose entire shape is a
          direction. */}
      <span
        aria-hidden
        data-reveal
        className="hairline hairline-draw hairline-glint mt-8"
        style={{ ['--d' as string]: '140ms' }}
      />
    </div>
  );
}

/**
 * Pickup, drop, go — the booking widget the reference carries in its hero.
 *
 * It hands over to the booking page with both places already filled in, not
 * straight to the fare list. Jumping to the fares saved a screen and cost
 * the customer the answer to "what am I actually booking?": the trip type,
 * the date and the time were all assumed, none of them were shown, and the
 * first thing on screen was a price for a trip nobody had described. The
 * booking page shows the trip, keeps what was typed, and is one click from
 * the same fares.
 */
function QuickBook() {
  const router = useRouter();
  const [pickup, setPickup] = useState<Geo | undefined>();
  const [drop, setDrop] = useState<Geo | undefined>();
  const [problem, setProblem] = useState('');

  // The fare is a road distance, so it needs coordinates — typed text that
  // was never resolved to a place cannot be priced.
  const ready = !!pickup?.lat && !!drop?.lat;

  const go = () => {
    if (!ready) {
      setProblem('Pick both places from the suggestions so we can price the route.');
      return;
    }
    tripDraft.set({
      serviceType: 'cab',
      subType: 'One Way',
      pickup,
      drop,
      pickupCity: pickup?.city || pickup?.address,
      dropCity: drop?.city || drop?.address,
      travelDate: toDateInput(new Date()),
      travelTime: '10:00',
    });
    router.push('/book/cab');
  };

  // Not `overflow-hidden`, however much the header strip wants it: the place
  // suggestions are an absolutely positioned list that hangs below the input,
  // and clipping the panel cut the list off inside it — the widget looked
  // right and could not be used. The strip gets its own rounded top corners.
  return (
    <div className="glass rounded-3xl shadow-2xl ring-1 ring-white/25">
      <p className="flex items-center gap-2 rounded-t-3xl border-b border-hairline px-5 py-3 text-[10px] font-bold uppercase tracking-[0.2em] text-muted">
        <Route className="h-3.5 w-3.5 text-brand-500" />
        Where to?
      </p>
      <div className="grid gap-3 p-4 sm:grid-cols-1 lg:grid-cols-1">
        <PlaceInput label="Pickup" value={pickup} onChange={setPickup} placeholder="Enter pickup location" />
        {/* The route between the two fields, so the pair reads as one trip
            rather than as two unrelated boxes. The panel is one column now
            that it stands beside the headline instead of under it, so the
            connector runs down rather than across. */}
        <span aria-hidden className="-my-1 flex items-center gap-2 pl-1">
          <span className="h-1.5 w-1.5 rounded-full bg-brand-500" />
          <span className="lane-x w-6" />
          <span className="text-[10px] font-bold uppercase tracking-[0.18em] text-muted">to</span>
          <span className="lane-x flex-1" />
          <MapPin className="h-3.5 w-3.5 text-brand-500" />
        </span>
        <PlaceInput label="Drop" value={drop} onChange={setDrop} placeholder="Enter drop location" />
      </div>
      <div className="px-4 pb-4">
        <button
          type="button"
          onClick={go}
          className="btn-sheen group inline-flex min-h-12 w-full items-center justify-center gap-2 rounded-xl bg-brand-500 px-6 py-3 text-[15px] font-bold text-white shadow-glow transition hover:bg-brand-600"
        >
          Book ride
          <ArrowRight className="h-4 w-4 transition-transform duration-300 group-hover:translate-x-1" />
        </button>
        {problem && <p className="px-1 pt-2 text-xs font-semibold text-dangerfg">{problem}</p>}
      </div>
    </div>
  );
}

/**
 * One of the operator's showcase pictures — a destination or an offer.
 *
 * The picture carries everything, so a row of these is the same height
 * whatever the admin typed in. A text block under only some of them left the
 * rest ending in blank space, because the grid stretches every card to the
 * tallest one.
 *
 * An entry with no upload is not a blank card: `Poster` draws a panel in a
 * colour taken from the title, and the type sits on that instead.
 */
function ShowcaseCard({
  item,
  ribbon,
}: {
  item: Showcase;
  /** A bar across the corner — "Offer", on the offers row. */
  ribbon?: string;
}) {
  const body = (
    <div
      data-reveal
      className="photo-in group relative h-full min-h-[16rem] overflow-hidden rounded-2xl ring-1 ring-hairline transition duration-300 hover:-translate-y-1 hover:shadow-card sm:min-h-[18rem]"
    >
      {ribbon && (
        <span className="ribbon">
          <Tag className="h-3 w-3" />
          {ribbon}
        </span>
      )}
      {/* The picture fills the card rather than standing at a fixed height
          inside it. A grid stretches every card to the tallest in its row,
          so a fixed-height picture left a band of bare card underneath —
          and the title, pinned to the card's floor, ended up sitting on it
          instead of on the photograph. */}
      <Poster
        src={item.imageUrl}
        alt={item.title ?? ''}
        seed={item.title ?? 'gora'}
        className="absolute inset-0 h-full w-full"
      >
        {/* Admin artwork is whatever it is: often bright, often with its own
            words baked in. The scrim is what keeps this card's typography
            readable over any of it. */}
        <div aria-hidden className="scrim-soft absolute inset-0" />
        <div className="absolute inset-x-5 bottom-5">
          <p className="font-display text-xl font-black tracking-[-0.02em] text-white drop-shadow sm:text-2xl">
            {item.title}
          </p>
          {item.subtitle && (
            <p className="mt-1.5 line-clamp-2 max-w-xl text-[13px] leading-relaxed text-white/85">
              {item.subtitle}
            </p>
          )}
        </div>
      </Poster>
    </div>
  );
  // Admin action URLs are app deep links as often as web links; only follow
  // the ones a browser can actually open.
  const href = item.actionUrl?.startsWith('http') ? item.actionUrl : undefined;
  return href ? (
    <a href={href} target="_blank" rel="noreferrer" className="block h-full">
      {body}
    </a>
  ) : (
    body
  );
}
