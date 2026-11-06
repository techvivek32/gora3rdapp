'use client';

import { useState } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useQuery } from '@tanstack/react-query';
import {
  ArrowRight, Building2, CheckCircle2, Clock, Headphones, Mail,
  MapPin, MessageCircle, Phone, Route, ShieldCheck, Smartphone, Tag, Users,
  Wallet,
} from 'lucide-react';
import { apiGet } from '@/lib/api';
import { PlaceInput } from '@/components/PlaceInput';
import { TaxiHero } from '@/components/TaxiHero';
import { CarSide } from '@/components/CarSide';
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
    title: 'Cab Booking',
    blurb: 'One Way · Round Trip · Local',
    desc: 'Outstation and in-city cabs. The full fare, broken down, before you confirm.',
    tone: 'text-cabsolid',
  },
  {
    href: '/book/hire_driver',
    title: 'Hire a Driver',
    blurb: 'Hourly · Full day',
    desc: 'You have the car, we send a verified driver. Priced by the day, not the kilometre.',
    tone: 'text-drivesolid',
  },
  {
    href: '/pool',
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

  const explore = list<Showcase>(data?.explore, 6);
  const offers = list<Showcase>(data?.offers, 6);
  const fleet = list<CabCategory>(cats, 4);
  const cities = list<City>(cityRows, 60).filter((c) => c.name);
  const states = new Set(cities.map((c) => c.state).filter(Boolean)).size;

  const phone = (contact?.phone || settings?.supportPhone || '').trim();
  const phone2 = (settings?.supportPhone2 || '').trim();
  const email = (settings?.supportEmail || '').trim();
  // wa.me wants digits only, and a bare ten-digit Indian number needs its 91.
  const waDigits = (contact?.whatsapp || settings?.supportWhatsapp || '').replace(/\D/g, '');
  const whatsapp = waDigits ? (waDigits.length === 10 ? `91${waDigits}` : waDigits) : '';

  return (
    <>
      {/* ── Hero ─────────────────────────────────────────────────────────── */}
      {/* Not `overflow-hidden` on the section itself: the promise strip below
          meets it flush and the media frame's offset plate leans past the
          grid, so clipping here cost both. The swoosh gets its own clipping
          wrapper instead. */}
      <section className="hero-band relative">
        <div aria-hidden className="pointer-events-none absolute inset-0 overflow-hidden">
          {/* The brand swoosh: a wide orange sweep out of the top-right
              corner. It is sized for the desktop hero, where the right half
              is the car card. On a phone that column is hidden and the same
              shape reached down across the opening paragraph, cutting an
              orange edge through the middle of a sentence — so it shrinks
              back into the corner until there is room for it. */}
          <div
            className="absolute -right-32 -top-44 h-[18rem] w-[22rem] rotate-[-18deg] rounded-[45%] opacity-90 sm:-right-36 sm:-top-52 sm:h-[26rem] sm:w-[34rem] lg:-right-44 lg:-top-64 lg:h-[28rem] lg:w-[36rem]"
            style={{ background: 'linear-gradient(135deg, #fb923c 0%, #f97316 45%, #ea580c 100%)' }}
          />
        </div>
        {/* Grain over the swoosh as well as the wash, so the whole band has
            one surface rather than a textured background and a clean shape
            sitting on it. */}
        <div aria-hidden className="noise pointer-events-none absolute inset-0" />

        <div className="relative mx-auto grid max-w-6xl items-center gap-10 px-4 pb-20 pt-12 lg:grid-cols-[2.5rem_1.1fr_0.9fr] lg:gap-8 lg:pb-24 lg:pt-16">
          {/* The rail. A column of the grid rather than something absolutely
              positioned in the margin: at 1024px the container has no margin
              left to put it in, and an absolute rail there sat on top of the
              headline. */}
          <div aria-hidden className="hidden self-stretch lg:flex lg:flex-col lg:items-center lg:gap-4 lg:py-6">
            <span className="lane-y flex-1" />
            <span
              className="whitespace-nowrap text-[10px] font-bold uppercase tracking-[0.3em] text-muted"
              style={{ writingMode: 'vertical-rl', transform: 'rotate(180deg)' }}
            >
              Gora Taxi · All India
            </span>
            <span className="lane-y flex-1" />
          </div>

          <div>
            <span className="inline-flex items-center gap-2.5 rounded-full border border-tintline bg-surface/80 px-4 py-2 text-[11px] font-bold uppercase tracking-[0.18em] text-ink backdrop-blur">
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

            {/* A grid, not a wrapping row of items with rules between them.
                The three claims are too wide for one line in this column, and
                a separator laid between flex items follows them round the
                wrap — the second line opened with a dash pointing at nothing.
                Columns cannot do that, and they line the ticks up. */}
            <ul className="mt-7 grid gap-x-5 gap-y-3 sm:grid-cols-3">
              {['Instant booking', 'Verified drivers', 'No hidden charges'].map((label) => (
                <li key={label} className="flex items-center gap-2.5 border-l-2 border-brand-500/50 pl-3">
                  <CheckCircle2 className="h-4 w-4 shrink-0 text-brand-500" />
                  {/* 11px, not 12: at 12 the longest of the three needed two
                      lines inside its column and the row came out ragged.
                      Not `whitespace-nowrap` — that pushes the column wider
                      than the grid at 1024px and takes the page with it. */}
                  <span className="text-[11px] font-bold uppercase tracking-[0.1em] text-ink">{label}</span>
                </li>
              ))}
            </ul>
          </div>

          {/* The admin's own photograph if one is set, and a drawn Gora taxi
              if not.

              The frame is the design, not the picture: an orange plate offset
              behind it and the route strip across its foot. Operators upload
              whatever they have — a night shot, a cut-out, a stock saloon —
              and the plate and the strip are what make any of them look
              placed rather than pasted. */}
          <div className="relative hidden lg:block">
            <span
              aria-hidden
              className="absolute -bottom-4 -right-4 left-10 top-12 rounded-[2rem] opacity-95"
              style={{ background: 'linear-gradient(140deg, #fdba74 0%, #f97316 60%, #c2410c 100%)' }}
            />
            <div className="relative overflow-hidden rounded-[1.75rem] shadow-card ring-1 ring-ink/10">
              {data?.heroImage ? (
                /* eslint-disable-next-line @next/next/no-img-element */
                <img src={data.heroImage} alt="" className="h-[27rem] w-full object-cover" />
              ) : (
                <TaxiHero className="block h-[27rem] w-full" />
              )}

              {/* The trip, drawn: two pins, the lane between them and a car
                  running it. The same drawing as the opening sequence, so the
                  site has one idea of what a journey looks like. */}
              <div className="absolute inset-x-4 bottom-4 rounded-2xl bg-navy/85 px-5 pb-5 pt-4 backdrop-blur">
                <div className="flex items-center justify-between text-[10px] font-bold uppercase tracking-[0.2em] text-white/70">
                  <span>Pickup</span>
                  <span>Drop</span>
                </div>
                <div className="relative mt-9 flex items-center gap-2">
                  <span className="hero-pin h-2.5 w-2.5 shrink-0 rounded-full bg-brand-400" />
                  <span className="hero-track relative flex-1">
                    <span className="hero-runner">
                      <CarSide />
                    </span>
                  </span>
                  <span className="hero-pin h-2.5 w-2.5 shrink-0 rounded-full bg-white" />
                </div>
                <p className="mt-3 text-[11px] font-semibold text-white/80">
                  One verified driver, assigned before you travel.
                </p>
              </div>
            </div>
          </div>
        </div>

        {/* The road the whole page is laid on. */}
        <span aria-hidden className="lane-x lane-live absolute inset-x-0 bottom-0 block" />
      </section>

      {/* ── The promise strip ────────────────────────────────────────────── */}
      {/* Four claims, full bleed and dark, divided by lanes. It used to be a
          floating white card of four rounded icon tiles — the same shape as
          the five card rows below it, which is how a page starts to read as a
          template. */}
      <div className="relative bg-navy">
        <div aria-hidden className="noise pointer-events-none absolute inset-0" />
        <div className="relative mx-auto grid max-w-6xl grid-cols-2 gap-px px-4 lg:grid-cols-4">
          {[
            { icon: ShieldCheck, head: 'Safe & secure', sub: 'Licence and vehicle checked first' },
            { icon: Clock, head: 'On-time pickup', sub: 'Assigned ahead of your trip' },
            { icon: Wallet, head: 'Affordable fare', sub: 'Broken down before you commit' },
            { icon: Headphones, head: '24×7 support', sub: 'A person answers, not a form' },
          ].map(({ icon: Icon, head, sub }, i) => (
            <div key={head} className="relative py-6 pl-4 pr-3 first:pl-0 lg:py-7">
              {i > 0 && (
                <span
                  aria-hidden
                  className="lane-y absolute inset-y-5 left-0 hidden lg:block"
                  style={{ ['--lane' as string]: 'rgba(255,255,255,0.28)' }}
                />
              )}
              <Icon className="h-5 w-5 text-brand-400" />
              <p className="mt-3 text-sm font-extrabold text-white">{head}</p>
              <p className="mt-1 text-xs leading-relaxed text-white/65">{sub}</p>
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
            n="01"
            eyebrow="What we do"
            title="Three ways to travel"
            lead="Pick the one that matches the trip. Every one of them prices the whole journey before you commit to it."
          />

          <div className="mt-12">
            {SERVICES.map((s, i) => (
              <Link
                key={s.href}
                href={s.href}
                data-reveal
                className={`roadrow group ${s.tone} last:border-b last:border-hairline`}
              >
                <span className="ghost-num text-[2.5rem] sm:text-[3rem]">{`0${i + 1}`}</span>
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

      {/* ── Fleet ────────────────────────────────────────────────────────── */}
      {fleet.length > 0 && (
        <section className="border-b border-hairline bg-surface">
          <div className="mx-auto max-w-6xl px-4 py-16 lg:py-20">
            <SectionHead
              n="02"
              eyebrow="Our fleet"
              title="Travel the way you like"
              lead="Every class below is one we actually run, with the rate it is billed at."
            />

            {/* Landscape, not portrait. A row of square cards with a photo on
                top is the shape every other section already had; turning them
                on their side lets the rate be a number you can read from
                across the room. */}
            <div className="mt-12 grid gap-5 lg:grid-cols-2">
              {fleet.map((c, i) => (
                <Link
                  key={c._id ?? i}
                  href="/book/cab"
                  data-reveal
                  className="group grid grid-cols-[9rem_1fr] items-stretch gap-4 overflow-hidden rounded-2xl bg-canvas ring-1 ring-hairline transition duration-300 hover:-translate-y-1 hover:shadow-card hover:ring-brand-300 sm:grid-cols-[12rem_1fr]"
                >
                  {c.imageUrl ? (
                    /* A white stage, declared as one: these photographs are
                       cut-outs on opaque white, so on a dark card the picture
                       was a hard white rectangle with the card's own dark
                       padding around it. */
                    <div data-photo-stage className="grid place-items-center bg-white p-3">
                      {/* eslint-disable-next-line @next/next/no-img-element */}
                      <img
                        src={c.imageUrl}
                        alt={c.name ?? ''}
                        className="h-20 w-full object-contain transition-transform duration-500 group-hover:scale-105 sm:h-24"
                      />
                    </div>
                  ) : (
                    <div className="grid place-items-center bg-sunken text-muted">
                      <Users className="h-7 w-7" />
                    </div>
                  )}

                  <div className="flex min-w-0 flex-col justify-center py-4 pr-5">
                    <p className="text-[10px] font-bold uppercase tracking-[0.18em] text-brandink">
                      {c.vehicleClass}
                    </p>
                    <p className="mt-1 font-display text-xl font-black tracking-[-0.02em] text-ink">
                      {c.name}
                    </p>
                    <div className="mt-3 flex items-end gap-3">
                      {c.pricePerKm ? (
                        <span className="font-display text-2xl font-black leading-none tracking-[-0.02em] text-ink">
                          {rupees(c.pricePerKm)}
                          <span className="ml-1 text-xs font-bold text-muted">/km</span>
                        </span>
                      ) : null}
                      {c.seats ? (
                        <span className="pb-0.5 text-xs font-semibold text-muted">{c.seats} seats</span>
                      ) : null}
                    </div>
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
          <SectionHead n="03" eyebrow="About us" title="A travel network, not one more fleet" />

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
          <SectionHead n="04" eyebrow="Four steps" title="How it works" />

          <ol className="mt-14 grid gap-10 sm:grid-cols-2 lg:grid-cols-4 lg:gap-6">
            {[
              ['Tell us the trip', 'Pickup, drop, date and time — add stops if you need them.'],
              ['Pick your cab', 'Compare classes and read the exact fare breakup.'],
              ['Confirm & pay', 'Book with ₹0 advance, or pay 10% / 100% online.'],
              ['Ride', 'We assign a verified driver and send you their details.'],
            ].map(([title, body], i) => (
              <li key={title} className="relative" data-reveal>
                {/* The lane from this pin to the next one. `-right-6` is the
                    grid's own gap, so it ends exactly on the next pin's edge
                    whatever the column measures. */}
                {i < 3 && (
                  <span
                    aria-hidden
                    className="lane-x absolute -right-6 left-[3.25rem] top-[1.375rem] hidden lg:block"
                  />
                )}
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
              n="05"
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

          <div className="mx-auto max-w-6xl px-4 pb-16 pt-10">
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
              n="06"
              eyebrow={
                <>
                  <MapPin className="h-3 w-3" /> Where to next
                </>
              }
              title="Explore India"
            />
            {/* The first picture is given the room of two. A grid of equal
                thumbnails says every destination is as good as every other,
                which is not what a showcase is for. */}
            <div className="mt-12 grid gap-5 sm:grid-cols-2 lg:grid-cols-3">
              {explore.map((item, i) => (
                <ShowcaseCard
                  key={item._id ?? i}
                  item={item}
                  wide={explore.length > 2 && i === 0}
                />
              ))}
            </div>
          </div>
        </section>
      )}

      {offers.length > 0 && (
        <section className="border-b border-hairline bg-surface">
          <div className="mx-auto max-w-6xl px-4 py-16 lg:py-20">
            <SectionHead
              n="07"
              eyebrow={
                <>
                  <Tag className="h-3 w-3" /> Worth a look
                </>
              }
              title="Special offers"
            />
            <div className="mt-12 grid gap-5 sm:grid-cols-2 lg:grid-cols-3">
              {offers.map((item, i) => (
                <ShowcaseCard key={item._id ?? i} item={item} wide={offers.length > 2 && i === 0} />
              ))}
            </div>
          </div>
        </section>
      )}

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
            {FAQ.map(([q, a], i) => (
              // <details> rather than React state: it works before hydration,
              // and the browser handles the open/close and the keyboard.
              <details key={q} className="group border-b border-hairline py-5 first:border-t">
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
            ))}
          </div>
        </div>
      </section>

      {/* ── Contact ──────────────────────────────────────────────────────── */}
      {/* Every way of reaching Gora comes from the operator's own settings.
          A card whose number is not configured does not render — better a
          shorter row than a dead link. */}
      <section id="contact" className="scroll-mt-20 border-b border-hairline bg-surface">
        <div className="mx-auto max-w-6xl px-4 py-16 lg:py-20">
          <SectionHead n="08" eyebrow={t('contact.eyebrow')} title={t('contact.title')} lead={t('contact.subtitle')} />

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
    <div className="flex items-start gap-4 sm:gap-6" data-reveal>
      <span className="stone">{n}</span>
      <div className="min-w-0 flex-1">
        <p className="eyebrow text-brandink">{eyebrow}</p>
        <h2 className="display-section mt-2.5">{title}</h2>
        {lead && <p className="mt-4 max-w-[62ch] text-[15px] leading-relaxed text-muted">{lead}</p>}
      </div>
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
    <div className="mt-9 rounded-2xl bg-surface shadow-card ring-1 ring-hairline">
      <p className="flex items-center gap-2 rounded-t-2xl border-b border-hairline bg-sunken px-4 py-2.5 text-[10px] font-bold uppercase tracking-[0.2em] text-muted">
        <Route className="h-3.5 w-3.5 text-brand-500" />
        Where to?
      </p>
      <div className="grid gap-3 p-3.5 sm:grid-cols-[1fr_3rem_1fr] sm:items-end">
        <PlaceInput label="Pickup" value={pickup} onChange={setPickup} placeholder="Enter pickup location" />
        {/* The route between the two fields, so the pair reads as one trip
            rather than as two unrelated boxes. */}
        <span aria-hidden className="hidden items-center pb-5 sm:flex">
          <span className="lane-x w-full" />
        </span>
        <PlaceInput label="Drop" value={drop} onChange={setDrop} placeholder="Enter drop location" />
      </div>
      <div className="px-3.5 pb-3.5">
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

function ShowcaseCard({ item, wide = false }: { item: Showcase; wide?: boolean }) {
  const body = (
    <div
      data-reveal
      className={`zoom-card group h-full overflow-hidden rounded-2xl bg-surface ring-1 ring-hairline transition duration-300 hover:-translate-y-1 hover:shadow-card ${
        wide ? 'sm:col-span-2' : ''
      }`}
    >
      {item.imageUrl ? (
        /* Everything on the picture, so every card in a row is the same
           height whatever the admin filled in. A text block below only
           some of them left the rest ending in blank space, because the
           grid stretches each card to the tallest one. */
        <div className={`relative overflow-hidden ${wide ? 'h-64 sm:h-80' : 'h-56'}`}>
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src={item.imageUrl} alt={item.title ?? ''} className="h-full w-full object-cover" />
          {/* Admin artwork is whatever it is: often bright, often with its own
              text baked in. The scrim keeps this card's typography legible. */}
          <div className="absolute inset-0 bg-gradient-to-t from-black/80 via-black/20 to-transparent" />
          <div className="absolute inset-x-5 bottom-4">
            <p
              className={`font-display font-black tracking-[-0.02em] text-white drop-shadow ${
                wide ? 'text-2xl sm:text-3xl' : 'text-lg'
              }`}
            >
              {item.title}
            </p>
            {item.subtitle && (
              <p className="mt-1 line-clamp-2 max-w-xl text-[13px] leading-relaxed text-white/80">
                {item.subtitle}
              </p>
            )}
          </div>
        </div>
      ) : (
        <div className="p-5">
          <p className="font-display text-lg font-black tracking-[-0.02em] text-ink">{item.title}</p>
          {item.subtitle && (
            <p className="mt-1 text-sm leading-relaxed text-muted">{item.subtitle}</p>
          )}
        </div>
      )}
    </div>
  );
  // Admin action URLs are app deep links as often as web links; only follow
  // the ones a browser can actually open.
  const href = item.actionUrl?.startsWith('http') ? item.actionUrl : undefined;
  return href ? (
    <a href={href} target="_blank" rel="noreferrer" className={wide ? 'sm:col-span-2' : ''}>
      {body}
    </a>
  ) : (
    body
  );
}
