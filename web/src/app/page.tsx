'use client';

import { useState } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useQuery } from '@tanstack/react-query';
import {
  ArrowLeftRight, ArrowRight, Building2, Car, CarTaxiFront, CheckCircle2, Clock, FileCheck2,
  Headphones, Mail, MapPin, MessageCircle, Phone, Search, ShieldCheck,
  Star, ThumbsUp, Users, Wallet,
} from 'lucide-react';
import { apiGet } from '@/lib/api';
import { PlaceInput } from '@/components/PlaceInput';
import { Poster } from '@/components/Poster';
import { GetAppRow, StoreBadges } from '@/components/GetApp';
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
  },
  {
    href: '/book/hire_driver',
    icon: Car,
    title: 'Hire a Driver',
    blurb: 'Hourly · Full day',
    desc: 'You have the car, we send a verified driver. Priced by the day, not the kilometre.',
  },
  {
    href: '/pool',
    icon: Users,
    title: 'Car Pool',
    blurb: 'Share & save',
    desc: 'Book a seat on a trip someone is already making. Cheaper, and one less car out.',
  },
];

/** The four steps, the way the reference lays its own process out. */
const STEPS = [
  { icon: Search, title: 'Tell us the trip', body: 'Pickup, drop, date and time. No account needed to get a price.' },
  { icon: FileCheck2, title: 'Pick your cab', body: 'Compare classes and fare modes side by side, with the whole breakdown shown.' },
  { icon: CarTaxiFront, title: 'Driver assigned', body: 'We send the driver’s name, vehicle and number before your pickup.' },
  { icon: ThumbsUp, title: 'Travel and pay', body: 'Pay nothing up front if you like, and settle with the driver at the end.' },
];

/**
 * Why book here, numbered.
 *
 * Every line is a claim this product can actually keep — the fare modes, the
 * ₹0 advance, the verified driver, the app handover are all real behaviour
 * described elsewhere in this repo. Nothing aspirational, because a promise
 * on a landing page that the booking flow then breaks is worse than no
 * promise at all.
 */
const REASONS: [string, string][] = [
  ['Fixed, gate-to-gate fare', 'The number you see is the number for the whole route — not a per-kilometre estimate that moves once you are in the car.'],
  ['You see the breakdown', 'Toll, state tax, driver allowance and GST are itemised before you confirm, on both fare modes.'],
  ['Book with ₹0 advance', 'Reserve the cab without paying anything, or pay 10% or 100% online if you would rather lock it in.'],
  ['A verified driver, named', 'Licence and vehicle checked first, and their name, car and number shared with you ahead of pickup.'],
  ['Free cancellation', 'Change your mind any time before pickup and it costs you nothing.'],
  ['The app picks it up', 'Book on the website and the trip is already in the Gora Taxi app under the same number.'],
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
    .slice(0, 8);
  const states = new Set(cities.map((c) => c.state).filter(Boolean)).size;

  const phone = (contact?.phone || settings?.supportPhone || '').trim();
  const phone2 = (settings?.supportPhone2 || '').trim();
  const email = (settings?.supportEmail || '').trim();
  // wa.me wants digits only, and a bare ten-digit Indian number needs its 91.
  const waDigits = (contact?.whatsapp || settings?.supportWhatsapp || '').replace(/\D/g, '');
  const whatsapp = waDigits ? (waDigits.length === 10 ? `91${waDigits}` : waDigits) : '';

  return (
    <>
      {/* ── Hero ──────────────────────────────────────────────────────────
       *
       * Centred, with the booking card as the centre of gravity.
       *
       * This replaced a left-aligned poster hero: an 83px headline on the
       * left, an illustrated cab on the right, and the booking form tucked
       * underneath the paragraph. It looked good and it buried the one thing
       * the page exists to do. The reference puts pickup and drop in the
       * middle of the first screen and lets the headline be a caption, and
       * that is the right order of importance for a cab site.
       *
       * The band behind it is a barely-there wash — warm at one corner, cool
       * at the other — rather than a picture, because the picture here is the
       * operator's upload and there is no frame that fixes a bad one.
       */}
      <section className="relative isolate overflow-hidden bg-bandcool">
        <div
          aria-hidden
          className="pointer-events-none absolute inset-0"
          style={{
            background:
              'radial-gradient(46% 50% at 8% 0%, rgba(249,115,22,0.10) 0%, transparent 64%),'
              + 'radial-gradient(52% 56% at 96% 8%, rgba(0,134,214,0.12) 0%, transparent 64%)',
          }}
        />

        <div className="relative mx-auto max-w-5xl px-4 pb-16 pt-12 sm:pt-16 lg:pb-20">
          <div className="text-center">
            <h1 className="display-hero">
              Book a Cab Anywhere in India
            </h1>
            <p className="mx-auto mt-3 max-w-2xl text-[17px] font-medium text-muted sm:text-[19px]">
              Outstation, local and a driver for your own car — {t('company.tagline')}
            </p>
          </div>

          <QuickBook />

          {/* The app, directly under the form — where the reference puts it,
              and the one spot on the page every visitor reaches. It sits
              OUTSIDE the booking card so it cannot compete with "Check fare":
              the next step here is still to price a trip. */}
          <GetAppRow className="mt-8" label="Prefer the app? Book and track on your phone" />
        </div>

        {/* The counters. Every one of them is read off the operator's own
            data — the city list, the states in it, the services the site
            actually offers — so none of it is a number somebody decided a
            landing page ought to show. */}
        <div className="relative border-t border-blue/15 bg-bandblue">
          <div className="mx-auto grid max-w-6xl grid-cols-2 gap-px px-4 lg:grid-cols-4">
            {[
              { figure: String(cities.length || '—'), label: 'Cities on the network' },
              { figure: String(states || '—'), label: 'States covered' },
              { figure: '3', label: 'Ways to travel' },
              { figure: '24×7', label: 'Someone on the phone' },
            ].map(({ figure, label }, i) => (
              <div key={label} className="relative py-7 pl-4 pr-3 first:pl-0">
                {i > 0 && (
                  <span
                    aria-hidden
                    className="absolute inset-y-6 left-0 hidden w-px bg-white/25 lg:block"
                  />
                )}
                <p className="font-display text-[32px] font-extrabold leading-none text-white sm:text-[40px]">
                  {figure}
                </p>
                <p className="mt-2 text-[13px] font-semibold text-white">{label}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* The one mark only a taxi company gets to use. The reference has no
          equivalent — it has no reason to, it is not called OneWay Taxi — and
          this is the single place the page is allowed to be a cab company
          rather than a clone of it. One strip, closing the blue band. */}
      <div aria-hidden className="chequer" />

      {/* ── Why travel with us ────────────────────────────────────────────
          Four cards with a rounded icon tile on top, alternating blue and
          orange. Straight out of the reference, and the one place on the page
          where the two brand colours sit side by side. */}
      <section className="bg-surface">
        <div className="mx-auto max-w-6xl px-4 py-16 lg:py-20">
          <div className="grid gap-5 sm:grid-cols-2 lg:grid-cols-4">
            {[
              { icon: Wallet, title: 'Pay for one way', body: 'Travelling one way? Pay for one way. No return fare on a journey you are not making.' },
              { icon: Clock, title: 'On-time pickup', body: 'The driver is assigned ahead of your trip, not scrambled for at the last minute.' },
              { icon: ShieldCheck, title: 'Verified drivers', body: 'Licence and vehicle checked before anyone is allowed to take a booking.' },
              { icon: Headphones, title: '24×7 support', body: 'A person answers the phone — a number in the header, not a contact form.' },
            ].map(({ icon: Icon, title, body }, i) => (
              <div
                key={title}
                data-reveal
                style={{ ['--d' as string]: `${i * 70}ms` }}
                className="card lift p-6 text-center"
              >
                <span className={`${i % 2 === 0 ? 'tile-blue' : 'tile-accent'} mx-auto`}>
                  <Icon className="h-7 w-7" />
                </span>
                <h3 className="mt-5 font-display text-[19px] font-bold text-ink">{title}</h3>
                <p className="mt-2.5 text-[15px] leading-relaxed text-muted">{body}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* ── How it works ──────────────────────────────────────────────── */}
      <section className="bg-bandmint">
        <div className="mx-auto max-w-6xl px-4 py-16 lg:py-20">
          <SectionHead
            pill="Simple Process"
            tone="accent"
            title="How Gora Taxi Works"
            lead="Four steps from a pickup point to a driver on their way."
          />

          <div className="mt-12 grid gap-5 sm:grid-cols-2 lg:grid-cols-4">
            {STEPS.map(({ icon: Icon, title, body }, i) => (
              <div
                key={title}
                data-reveal
                style={{ ['--d' as string]: `${i * 70}ms` }}
                className="card lift relative p-6"
              >
                {/* The step number, ringed, in the corner the reference puts
                    it: top-right, out of the way of the icon and the title. */}
                <span className="absolute right-5 top-5 grid h-8 w-8 place-items-center rounded-full bg-bluesoft text-[13px] font-bold tabular-nums text-blueink ring-1 ring-blueline">
                  {i + 1}
                </span>
                <span className="tile-blue">
                  <Icon className="h-7 w-7" />
                </span>
                <h3 className="mt-5 font-display text-[18px] font-bold text-ink">{title}</h3>
                <p className="mt-2 text-[15px] leading-relaxed text-muted">{body}</p>
              </div>
            ))}
          </div>

          {/* The one-line promise, in a tinted strip. */}
          <div className="mx-auto mt-10 max-w-readable rounded-tile bg-bluesoft px-6 py-5 text-center ring-1 ring-blueline">
            <p className="text-[15px] text-ink/75">Pay only for the distance you travel. No return charges.</p>
            <p className="mt-1 font-display text-[17px] font-bold text-blueink">One way fare, not one and a half ✓</p>
          </div>
        </div>
      </section>

      {/* ── The three services ────────────────────────────────────────── */}
      <section className="bg-surface">
        <div className="mx-auto max-w-6xl px-4 py-16 lg:py-20">
          <SectionHead
            pill="What we do"
            tone="blue"
            title="Three ways to travel"
            lead="Pick the one that matches the trip. Every one of them prices the whole journey before you commit to it."
          />

          <div className="mt-12 grid gap-5 lg:grid-cols-3">
            {SERVICES.map(({ href, icon: Icon, title, blurb, desc }, i) => (
              <Link
                key={href}
                href={href}
                data-reveal
                style={{ ['--d' as string]: `${i * 80}ms` }}
                className="card lift group flex flex-col p-7"
              >
                <span className={i === 1 ? 'tile-accent' : 'tile-blue'}>
                  <Icon className="h-7 w-7" />
                </span>
                <h3 className="mt-5 font-display text-[21px] font-bold text-ink">{title}</h3>
                <p className="mt-1 text-[14px] font-semibold text-blueink">{blurb}</p>
                <p className="mt-3 flex-1 text-[15px] leading-relaxed text-muted">{desc}</p>
                <span className="mt-5 inline-flex items-center gap-1.5 text-[15px] font-bold text-ink">
                  Book now
                  <ArrowRight className="h-4 w-4 transition-transform duration-300 group-hover:translate-x-1" />
                </span>
              </Link>
            ))}
          </div>
        </div>
      </section>

      {/* ── Travel categories (operator's own) ────────────────────────── */}
      {travel.length > 0 && (
        <section className="bg-bandwarm">
          <div className="mx-auto max-w-6xl px-4 py-16 lg:py-20">
            <SectionHead
              pill="Where are you going"
              tone="accent"
              title="Travel made better"
              lead="The trips people book most often, straight from our own network."
            />
            <div className={`mt-12 grid gap-5 sm:grid-cols-2 ${gridCols(travel.length)}`}>
              {travel.map((item, i) => (
                <ShowcaseCard key={item._id ?? `${item.title}-${i}`} item={item} />
              ))}
            </div>
          </div>
        </section>
      )}

      {/* ── Fleet ─────────────────────────────────────────────────────── */}
      {fleet.length > 0 && (
        <section className="bg-surface">
          <div className="mx-auto max-w-6xl px-4 py-16 lg:py-20">
            <SectionHead
              pill="Our fleet"
              tone="blue"
              title="The cabs we actually run"
              lead="Real classes and real per-kilometre rates, kept in the admin panel — not stock photographs of cars we do not have."
            />
            <div className={`mt-12 grid gap-5 sm:grid-cols-2 ${fleetCols(fleet.length)}`}>
              {fleet.map((c, i) => (
                <div
                  key={c._id ?? c.name}
                  data-reveal
                  style={{ ['--d' as string]: `${i * 70}ms` }}
                  className="card lift overflow-hidden"
                >
                  <Poster
                    src={c.imageUrl}
                    alt={c.name ?? ''}
                    seed={c.name ?? 'cab'}
                    className="h-44 w-full"
                  />
                  <div className="p-5">
                    <h3 className="font-display text-[19px] font-bold text-ink">{c.name}</h3>
                    <p className="mt-1 text-[14px] text-muted">
                      {c.seats ? `${c.seats} seats` : 'Sedan'}
                      {c.acType ? ` · ${c.acType}` : ''}
                    </p>
                    {typeof c.perKmRate === 'number' && c.perKmRate > 0 && (
                      <p className="mt-3 text-[15px] font-bold text-blueink">
                        from <span className="numeral">{rupees(c.perKmRate)}</span>/km
                      </p>
                    )}
                  </div>
                </div>
              ))}
            </div>
          </div>
        </section>
      )}

      {/* ── Why book with us ──────────────────────────────────────────── */}
      <section id="about" className="scroll-mt-24 bg-bandmint">
        <div className="mx-auto max-w-6xl px-4 py-16 lg:py-20">
          <SectionHead
            pill="Why Choose Us"
            tone="accent"
            title="Why book your cab with Gora Taxi?"
            lead="Six things this product actually does, each one of them something you can hold us to."
          />
          <div className="mt-12 grid gap-5 sm:grid-cols-2 lg:grid-cols-3">
            {REASONS.map(([title, body], i) => (
              <div
                key={title}
                data-reveal
                style={{ ['--d' as string]: `${(i % 3) * 70}ms` }}
                className="card lift flex gap-4 p-6"
              >
                <span className="grid h-11 w-11 shrink-0 place-items-center rounded-xl bg-bandblue font-display text-[15px] font-bold tabular-nums text-white">
                  {String(i + 1).padStart(2, '0')}
                </span>
                <span className="min-w-0">
                  <h3 className="font-display text-[17px] font-bold leading-snug text-ink">{title}</h3>
                  <p className="mt-2 text-[15px] leading-relaxed text-muted">{body}</p>
                </span>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* ── Cities ────────────────────────────────────────────────────── */}
      {cities.length > 0 && (
        <section id="cities" className="scroll-mt-24 bg-surface">
          <div className="mx-auto max-w-6xl px-4 py-16 lg:py-20">
            <SectionHead
              pill="Pan-India coverage"
              tone="blue"
              title="Service areas across India"
              lead={`Outstation and local cabs in ${cities.length} ${cities.length === 1 ? 'city' : 'cities'}${states ? ` across ${states} states` : ''}.`}
            />

            {featured.length > 0 && (
              <div className="mt-12 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
                {featured.map((c, i) => (
                  <div
                    key={c._id ?? c.name}
                    data-reveal
                    style={{ ['--d' as string]: `${(i % 4) * 70}ms` }}
                    className="card lift flex items-center gap-3 p-5"
                  >
                    <MapPin className="h-5 w-5 shrink-0 text-blue" />
                    <span className="min-w-0">
                      <p className="truncate font-display text-[17px] font-bold text-ink">{c.name}</p>
                      {c.state && <p className="truncate text-[14px] text-muted">{c.state}</p>}
                    </span>
                  </div>
                ))}
              </div>
            )}

            {/* The whole list, as chips. The operator picks each chip's
                colour in the admin panel; `cityChip` is what turns that
                choice into a class, which is why src/lib is scanned by
                Tailwind. */}
            <div className="mt-10 flex flex-wrap justify-center gap-2.5">
              {cities.map((c, i) => (
                <span
                  key={c._id ?? `${c.name}-${i}`}
                  className={cityChip(c.color, c.isFeatured, i).className}
                >
                  {c.name}
                </span>
              ))}
            </div>

            <div className="mt-10 text-center">
              <p className="text-[16px] text-muted">Don&rsquo;t see your city? We are adding more.</p>
              <Link href="#contact" className="btn-primary mt-4">
                Contact us
              </Link>
            </div>
          </div>
        </section>
      )}

      {/* ── Offers ────────────────────────────────────────────────────── */}
      {offers.length > 0 && (
        <section className="bg-bandwarm">
          <div className="mx-auto max-w-6xl px-4 py-16 lg:py-20">
            <SectionHead
              pill="Offers"
              tone="accent"
              title="Running right now"
              lead="Live from the admin panel — when an offer ends it leaves this page with it."
            />
            <div className={`mt-12 grid gap-5 sm:grid-cols-2 ${gridCols(offers.length)}`}>
              {offers.map((item, i) => (
                <ShowcaseCard key={item._id ?? `${item.title}-${i}`} item={item} ribbon="Offer" />
              ))}
            </div>
          </div>
        </section>
      )}

      {/* ── Explore ───────────────────────────────────────────────────── */}
      {explore.length > 0 && (
        <section className="bg-surface">
          <div className="mx-auto max-w-6xl px-4 py-16 lg:py-20">
            <SectionHead
              pill="Explore"
              tone="blue"
              title="Places worth the drive"
              lead="Destinations the operator has picked out, with the cab to get you there."
            />
            <div className={`mt-12 grid gap-5 sm:grid-cols-2 ${gridCols(explore.length)}`}>
              {explore.map((item, i) => (
                <ShowcaseCard key={item._id ?? `${item.title}-${i}`} item={item} />
              ))}
            </div>
          </div>
        </section>
      )}

      {/* ── The app ───────────────────────────────────────────────────────
          A solid blue section with a white card floated inside it — the
          reference's download band, and the only full-bleed colour block
          below the fold. One band of real colour is what stops a long white
          page going flat. */}
      <section className="bg-bandblue">
        <div className="mx-auto max-w-5xl px-4 py-16 lg:py-20">
          <div className="card p-8 text-center sm:p-12" data-reveal>
            <span className="eyebrow-accent">Download now</span>
            <h2 className="section-title mt-5">Book your cab in seconds</h2>
            <p className="section-sub mt-4">
              {t('footer.appNote') || 'Track the driver, keep every invoice and rebook a favourite route in two taps.'}
            </p>
            {/* The store's own badge rather than a button that says the same
                words: this is the page's main download CTA, and a badge is
                recognised before it is read. */}
            <StoreBadges size="lg" className="mt-8 justify-center" />
            <div className="mt-6 flex flex-wrap items-center justify-center gap-3">
              <Link href="/book/cab" className="btn-ghost">
                Book on the website
              </Link>
            </div>
            <p className="mt-5 text-[14px] text-muted">
              Book here and the trip is already in the app under the same number.
            </p>
          </div>
        </div>
      </section>

      {/* ── FAQ ───────────────────────────────────────────────────────────
          Separated cards rather than a divided list, and a narrow measure.
          A question is a thing you scan for, and a gap between rows is what
          makes a list scannable. */}
      <section id="faq" className="scroll-mt-24 bg-surface">
        <div className="mx-auto max-w-6xl px-4 py-16 lg:py-20">
          <SectionHead
            pill="Before you book"
            tone="blue"
            title="Questions people ask"
          />
          <div className="mx-auto mt-12 max-w-readable space-y-3.5">
            {FAQ.map(([q, a], i) => (
              <details
                key={q}
                className="faq-item group"
                data-reveal
                style={{ ['--d' as string]: `${i * 50}ms` }}
              >
                <summary className="flex cursor-pointer list-none items-center gap-4 px-6 py-5">
                  <span className="min-w-0 flex-1 font-display text-[17px] font-bold text-ink">{q}</span>
                  {/* A chevron that turns, drawn in CSS so the closed and open
                      states cannot disagree with the element's own state. */}
                  <span
                    aria-hidden
                    className="shrink-0 text-blue transition-transform duration-300 group-open:rotate-180"
                  >
                    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
                      <path d="m6 9 6 6 6-6" />
                    </svg>
                  </span>
                </summary>
                <p className="px-6 pb-5 text-[15px] leading-relaxed text-muted">{a}</p>
              </details>
            ))}
          </div>
        </div>
      </section>

      {/* ── Contact ───────────────────────────────────────────────────── */}
      <section id="contact" className="scroll-mt-24 bg-bandmint">
        <div className="mx-auto max-w-6xl px-4 py-16 lg:py-20">
          <SectionHead
            pill={t('contact.eyebrow')}
            tone="accent"
            title={t('contact.title')}
            lead={t('contact.subtitle')}
          />

          <div className="mt-12 grid gap-5 lg:grid-cols-3">
            {phone && (
              <a href={`tel:${phone}`} className="card lift p-6" data-reveal>
                <span className="tile-blue">
                  <Phone className="h-6 w-6" />
                </span>
                <h3 className="mt-5 font-display text-[18px] font-bold text-ink">Call us</h3>
                <p className="mt-2 text-[17px] font-bold text-blueink">
                  <span className="numeral">{phone}</span>
                </p>
                {phone2 && (
                  <p className="mt-0.5 text-[15px] text-muted">
                    <span className="numeral">{phone2}</span>
                  </p>
                )}
                {t('contact.callNote') && (
                  <p className="mt-2 text-[14px] leading-relaxed text-muted">{t('contact.callNote')}</p>
                )}
              </a>
            )}

            {whatsapp && (
              <a
                href={`https://wa.me/${whatsapp}`}
                target="_blank"
                rel="noreferrer"
                className="card lift p-6"
                data-reveal
                style={{ ['--d' as string]: '70ms' }}
              >
                <span className="tile-accent">
                  <MessageCircle className="h-6 w-6" />
                </span>
                <h3 className="mt-5 font-display text-[18px] font-bold text-ink">WhatsApp</h3>
                <p className="mt-2 text-[15px] leading-relaxed text-muted">
                  {t('contact.whatsappLine') || 'Message us and we will take the booking there.'}
                </p>
                {t('contact.whatsappNote') && (
                  <p className="mt-2 text-[14px] leading-relaxed text-muted">{t('contact.whatsappNote')}</p>
                )}
              </a>
            )}

            {email && (
              <a
                href={`mailto:${email}`}
                className="card lift p-6"
                data-reveal
                style={{ ['--d' as string]: '140ms' }}
              >
                <span className="tile-blue">
                  <Mail className="h-6 w-6" />
                </span>
                <h3 className="mt-5 font-display text-[18px] font-bold text-ink">Email</h3>
                <p className="mt-2 break-all text-[15px] font-semibold text-blueink">{email}</p>
                {t('contact.emailNote') && (
                  <p className="mt-2 text-[14px] leading-relaxed text-muted">{t('contact.emailNote')}</p>
                )}
              </a>
            )}
          </div>

          {t('company.address') && (
            <div className="card mt-5 flex gap-4 p-6" data-reveal>
              <Building2 className="h-5 w-5 shrink-0 text-blue" />
              <span className="min-w-0">
                <h3 className="font-display text-[17px] font-bold text-ink">
                  {t('contact.officeTitle') || 'Our office'}
                </h3>
                <p className="mt-2 text-[15px] leading-relaxed text-muted">{t('company.address')}</p>
              </span>
            </div>
          )}
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
 * The heading every section shares: a coloured pill, one large centred
 * title, one muted line.
 *
 * Centred, and that is a reversal. This used to be a left-aligned block with
 * a numbered "kilometre stone" beside it, chosen specifically so the page
 * would not look like a template. The reference centres every one of its
 * section heads and the result reads as a product, not as a portfolio — the
 * repetition is what makes a 7,000px page feel like one page rather than
 * eight stapled together.
 *
 * `tone` alternates down the page so no two neighbouring sections open on
 * the same colour.
 */
function SectionHead({
  pill,
  tone = 'blue',
  title,
  lead,
}: {
  pill: React.ReactNode;
  tone?: 'blue' | 'accent';
  title: string;
  lead?: string;
}) {
  return (
    <div className="text-center" data-reveal>
      {pill ? <span className={tone === 'accent' ? 'eyebrow-accent' : 'eyebrow-blue'}>{pill}</span> : null}
      <h2 className="section-title mt-5">{title}</h2>
      {lead && <p className="section-sub mt-4">{lead}</p>}
    </div>
  );
}

/**
 * The hero books a cab, and only a cab.
 *
 * It used to switch between the three services, which put the least-asked-for
 * two in the most expensive space on the site and made a visitor choose a
 * product before they could type where they were going. Hiring a driver and
 * car pooling are still a tap away — in the header, in the footer, and on
 * their own cards further down — but the first screen now asks the question
 * almost everyone arrives with.
 *
 * So the tabs became the choice that is actually useful this early: which kind
 * of cab trip. These are the cab page's own `subTypes`, and the one picked here
 * carries over in the draft rather than being asked again.
 */
const TRIP_TYPES = [
  { key: 'One Way', label: 'One Way', sub: 'Drop-off only' },
  { key: 'Round Trip', label: 'Round Trip', sub: 'Return in same cab' },
  { key: 'Local', label: 'Local', sub: 'Hourly rental' },
] as const;

/**
 * Pickup, drop, go — the booking widget, now the centrepiece of the hero
 * rather than a panel beside the headline.
 *
 * Three changes from the version this replaces, all of them the reference's:
 * the card is centred and wide instead of a narrow column; the service is
 * chosen here, on tabs, instead of being assumed to be a cab; and the two
 * places sit side by side on a desktop, which is how a route reads.
 *
 * It still hands over to the booking page with both places already filled in,
 * not straight to the fare list. Jumping to the fares saved a screen and cost
 * the customer the answer to "what am I actually booking?": the trip type, the
 * date and the time were all assumed, none of them were shown, and the first
 * thing on screen was a price for a trip nobody had described.
 */
function QuickBook() {
  const router = useRouter();
  const [tripType, setTripType] = useState<(typeof TRIP_TYPES)[number]['key']>('One Way');
  const [pickup, setPickup] = useState<Geo | undefined>();
  const [drop, setDrop] = useState<Geo | undefined>();
  const [problem, setProblem] = useState('');

  // Local is an in-city hourly package — there is nowhere to drop, so that one
  // asks for a single place. Same rule the booking page applies.
  const needsDrop = tripType !== 'Local';
  // The fare is a road distance, so it needs coordinates — typed text that
  // was never resolved to a place cannot be priced.
  const ready = !!pickup?.lat && (!needsDrop || !!drop?.lat);

  const go = () => {
    if (!ready) {
      setProblem(
        needsDrop
          ? 'Pick both places from the suggestions so we can price the route.'
          : 'Pick the pick-up from the suggestions so we can price it.',
      );
      return;
    }
    tripDraft.set({
      serviceType: 'cab',
      subType: tripType,
      pickup,
      drop: needsDrop ? drop : undefined,
      pickupCity: pickup?.city || pickup?.address,
      dropCity: needsDrop ? drop?.city || drop?.address : undefined,
      travelDate: toDateInput(new Date()),
      travelTime: '10:00',
    });
    router.push('/book/cab');
  };

  // Not `overflow-hidden`, however much the rounded corners want it: the
  // place suggestions are an absolutely positioned list that hangs below the
  // input, and clipping the panel cut the list off inside it — the widget
  // looked right and could not be used.
  return (
    <div className="mx-auto mt-10 max-w-4xl rounded-card bg-surface p-5 shadow-lift ring-1 ring-hairline/70 sm:p-7">
      {/* The trip-type tabs. The selected one is a solid blue block, which is
          the single loudest element on the first screen and is meant to be:
          it is the answer to "what kind of trip?". */}
      <div className="grid grid-cols-3 gap-2.5 sm:gap-3">
        {TRIP_TYPES.map(({ key, label, sub }) => {
          const on = tripType === key;
          return (
            <button
              key={key}
              type="button"
              aria-pressed={on}
              onClick={() => { setTripType(key); setProblem(''); }}
              className={`flex min-h-[64px] flex-col items-center justify-center gap-0.5 rounded-tile px-2 py-3 text-center transition ${
                on
                  ? 'bg-bandblue text-white shadow-[0_6px_18px_rgba(11,116,190,0.3)]'
                  : 'bg-surface text-ink ring-1 ring-hairline hover:bg-sunken'
              }`}
            >
              <span className="text-[13px] font-bold leading-tight sm:text-[14px]">{label}</span>
              {/* Full white, not white/80. On this blue that was 3.74:1 —
                  an 11px label is exactly the size that cannot afford it. */}
              <span className={`hidden text-[11px] leading-tight sm:block ${on ? 'text-white' : 'text-muted'}`}>
                {sub}
              </span>
            </button>
          );
        })}
      </div>

      {/* `relative` so the swap button can sit on the seam between the two
          fields. It is not decoration: "Jaipur to Delhi" and "Delhi to Jaipur"
          are different prices, and getting them the wrong way round otherwise
          means retyping both. */}
      <div className={`relative mt-6 grid gap-4 ${needsDrop ? 'sm:grid-cols-2' : ''}`}>
        <PlaceInput
          label="Pickup"
          value={pickup}
          onChange={(v) => { setPickup(v); setProblem(''); }}
          placeholder="Enter pick-up city"
        />
        {needsDrop && (
          <>
            <PlaceInput
              label="Drop"
              value={drop}
              onChange={(v) => { setDrop(v); setProblem(''); }}
              placeholder="Enter drop city"
            />
            <button
              type="button"
              onClick={() => { const p = pickup; setPickup(drop); setDrop(p); setProblem(''); }}
              aria-label="Swap pick-up and drop"
              className="absolute left-1/2 top-1/2 z-10 hidden h-9 w-9 -translate-x-1/2 -translate-y-1/2 place-items-center rounded-full border border-hairline bg-surface text-blue shadow-sm transition hover:bg-bluesoft sm:grid"
            >
              <ArrowLeftRight className="h-4 w-4" />
            </button>
          </>
        )}
      </div>

      <button
        type="button"
        onClick={go}
        className="btn-primary btn-sheen group mt-5 w-full text-[16px]"
      >
        Check fare
        <ArrowRight className="h-4 w-4 transition-transform duration-300 group-hover:translate-x-1" />
      </button>
      {problem && <p className="px-1 pt-2.5 text-[13px] font-semibold text-dangerfg">{problem}</p>}

      {/* The trust line under the button, where the reference puts its
          rating. Ours says what we can stand behind rather than a star
          average nobody has collected. */}
      <ul className="mt-6 flex flex-wrap items-center justify-center gap-x-6 gap-y-2.5 border-t border-hairline pt-5">
        {['No account needed', 'Verified drivers', 'Free cancellation'].map((label) => (
          <li key={label} className="flex items-center gap-1.5 text-[13px] font-semibold text-muted">
            <CheckCircle2 className="h-4 w-4 shrink-0 text-blue" />
            {label}
          </li>
        ))}
      </ul>
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
      className="photo-in group relative h-full min-h-[16rem] overflow-hidden rounded-card shadow-card ring-1 ring-hairline/70 transition duration-300 hover:-translate-y-1 hover:shadow-lift sm:min-h-[18rem]"
    >
      {ribbon && (
        <span className="ribbon">
          <Star className="h-3 w-3" />
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
          <p className="font-display text-[20px] font-bold text-white drop-shadow sm:text-[22px]">
            {item.title}
          </p>
          {item.subtitle && (
            <p className="mt-1.5 line-clamp-2 max-w-xl text-[14px] leading-relaxed text-white/85">
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
