'use client';

import { useState } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useQuery } from '@tanstack/react-query';
import {
  ArrowRight, BadgeCheck, Building2, CheckCircle2, Clock, Headphones, Mail,
  MapPin, MessageCircle, Phone, Route, ShieldCheck, Smartphone, Tag, Users,
  Wallet, Zap,
} from 'lucide-react';
import { apiGet } from '@/lib/api';
import { PlaceInput } from '@/components/PlaceInput';
import { TaxiHero } from '@/components/TaxiHero';
import { tripDraft } from '@/lib/trip-draft';
import { rupees, toDateInput } from '@/lib/format';
import { COMPANY } from '@/lib/company';
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
  },
  {
    href: '/book/hire_driver',
    title: 'Hire a Driver',
    blurb: 'Hourly · Full day',
    desc: 'You have the car, we send a verified driver. Priced by the day, not the kilometre.',
  },
  {
    href: '/pool',
    title: 'Car Pool',
    blurb: 'Share & save',
    desc: 'Book a seat on a trip someone is already making. Cheaper, and one less car out.',
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
      {/* Not `overflow-hidden` on the section itself: the promise bar below
          hangs past the bottom edge on purpose, and clipping the section cut
          it in half. The swoosh gets its own clipping wrapper instead. */}
      <section className="relative bg-bandwarm">
        <div aria-hidden className="pointer-events-none absolute inset-0 overflow-hidden">
          {/* The brand swoosh: a wide orange sweep out of the top-right
              corner. It is sized for the desktop hero, where the right half
              is the car card. On a phone that column is hidden and the same
              shape reached down across the opening paragraph, cutting an
              orange edge through the middle of a sentence — so it shrinks
              back into the corner until there is room for it. */}
          <div
            className="absolute -right-32 -top-44 h-[18rem] w-[22rem] rotate-[-18deg] rounded-[45%] opacity-90 sm:-right-36 sm:-top-52 sm:h-[26rem] sm:w-[34rem] lg:-right-40 lg:-top-56 lg:h-[34rem] lg:w-[46rem]"
            style={{ background: 'linear-gradient(135deg, #fb923c 0%, #f97316 45%, #ea580c 100%)' }}
          />
        </div>
        {/* Colour across the whole hero. The previous version was a faint
            wash on near-white, and the page still read as white — the one
            thing it was asked not to do. */}
        <div
          aria-hidden
          className="pointer-events-none absolute inset-0"
          style={{
            background:
              'radial-gradient(80% 90% at 5% 0%, rgba(254,215,170,0.95) 0%, transparent 62%),' +
              'radial-gradient(70% 80% at 50% 100%, rgba(253,230,138,0.80) 0%, transparent 65%),' +
              'radial-gradient(60% 70% at 95% 85%, rgba(254,205,211,0.70) 0%, transparent 65%)',
          }}
        />

        <div className="relative mx-auto grid max-w-6xl items-center gap-10 px-4 pb-24 pt-12 lg:grid-cols-[1.18fr_0.82fr] lg:gap-10 lg:pb-28 lg:pt-16">
          <div>
            <span className="inline-flex items-center gap-2 rounded-full bg-surface px-4 py-2 text-xs font-bold text-ink shadow-card ring-1 ring-tintline">
              <Zap className="h-3.5 w-3.5 text-brand-500" />
              Fast <span className="text-muted">•</span> Safe <span className="text-muted">•</span> Affordable
            </span>

            <h1 className="display mt-6 text-[2.4rem] leading-[1.05] sm:text-5xl lg:text-[3.6rem]">
              Book Your Ride
              <br />
              <span className="text-brand-600">Anywhere, Anytime</span>
            </h1>

            <p className="mt-5 max-w-lg text-[17px] leading-relaxed text-muted">
              Outstation cabs, local packages and a driver for your own car — across India. See the
              whole fare before you confirm, and pay the driver directly.
            </p>

            <QuickBook />

            <div className="mt-6 flex flex-wrap gap-x-6 gap-y-2">
              {['Instant booking', 'Verified drivers', 'No hidden charges'].map((t) => (
                <span key={t} className="inline-flex items-center gap-1.5 text-sm font-semibold text-ink">
                  <CheckCircle2 className="h-4 w-4 shrink-0 text-brand-500" />
                  {t}
                </span>
              ))}
            </div>
          </div>

          {/* The admin's own photograph if one is set, and a drawn Gora taxi
              if not.

              What was here instead was a cut-out of whichever cab class came
              first in the fleet — a white hatchback on a white stage with its
              own name under it. The Fleet section immediately below shows the
              same photograph at the same size, so the first thing on the site
              was a duplicate of the second, and neither said "Gora". */}
          <div className="relative hidden lg:block">
            {data?.heroImage ? (
              <div className="relative overflow-hidden rounded-[2rem] shadow-card ring-1 ring-white/40">
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img src={data.heroImage} alt="" className="h-[26rem] w-full object-cover" />
              </div>
            ) : (
              <div className="relative overflow-hidden rounded-[2rem] shadow-card ring-1 ring-white/40">
                <TaxiHero className="block h-[26rem] w-full" />
                <span className="absolute left-5 top-5 inline-flex items-center gap-1.5 rounded-full bg-brand-600 px-3 py-1.5 text-xs font-bold text-white shadow-glow">
                  <BadgeCheck className="h-3.5 w-3.5" />
                  Verified fleet
                </span>
              </div>
            )}
          </div>
        </div>

      </section>

      {/* The promise bar rides the seam between the hero and what follows. */}
      <div className="relative z-10 -mt-12 mb-4">
        <div className="mx-auto max-w-6xl px-4">
          <div className="grid gap-px overflow-hidden rounded-2xl bg-hairline shadow-card sm:grid-cols-2 lg:grid-cols-4">
            {[
              { icon: ShieldCheck, head: 'Safe & secure', sub: 'Licence and vehicle checked first', bg: 'bg-cabsolid' },
              { icon: Clock, head: 'On-time pickup', sub: 'Assigned ahead of your trip', bg: 'bg-drivesolid' },
              { icon: Wallet, head: 'Affordable fare', sub: 'Broken down before you commit', bg: 'bg-poolsolid' },
              { icon: Headphones, head: '24×7 support', sub: 'A person answers, not a form', bg: 'bg-luxsolid' },
            ].map(({ icon: Icon, head, sub, bg }) => (
              <div key={head} className="flex items-center gap-3 bg-surface px-5 py-5">
                <span className={`grid h-11 w-11 shrink-0 place-items-center rounded-full ${bg} text-white`}>
                  <Icon className="h-5 w-5" />
                </span>
                <span className="min-w-0">
                  <p className="text-sm font-bold text-ink">{head}</p>
                  <p className="truncate text-xs text-muted">{sub}</p>
                </span>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* ── Fleet ────────────────────────────────────────────────────────── */}
      {fleet.length > 0 && (
        <section className="border-b border-hairline bg-surface">
          <div className="mx-auto max-w-6xl px-4 pb-16 pt-14">
          <div className="text-center" data-reveal>
            <p className="eyebrow justify-center text-brandink">Our fleet</p>
            <h2 className="display mt-3 text-3xl sm:text-4xl">Travel the way you like</h2>
            <p className="mx-auto mt-4 max-w-xl text-sm leading-relaxed text-muted">
              Every class below is one we actually run, with the rate it is billed at.
            </p>
          </div>

          {/* Four columns only when there are four classes. The operator runs
              two, and a two-card row in a four-column grid sat in the left
              half of the page with the right half empty. */}
          <div className={`mt-10 grid gap-5 sm:grid-cols-2 ${fleetCols(fleet.length)}`}>
            {fleet.map((c, i) => (
              <Link
                key={c._id ?? i}
                href="/book/cab"
                data-reveal
                className="card-flat group overflow-hidden p-5 text-center transition duration-300 hover:-translate-y-1 hover:shadow-card hover:ring-brand-300"
              >
                {c.imageUrl ? (
                  /* Same white stage as the hero card, and for the same
                     reason: these photographs are cut-outs on opaque white,
                     so on a dark card the picture was a hard white rectangle
                     with the card's own dark padding around it. */
                  <div
                    data-photo-stage
                    className="grid h-28 place-items-center overflow-hidden rounded-xl bg-white"
                  >
                    {/* eslint-disable-next-line @next/next/no-img-element */}
                    <img
                      src={c.imageUrl}
                      alt={c.name ?? ''}
                      className="h-24 w-full object-contain transition-transform duration-500 group-hover:scale-105"
                    />
                  </div>
                ) : (
                  <div className="grid h-24 place-items-center text-muted">
                    <Users className="h-8 w-8" />
                  </div>
                )}
                <p className="mt-4 text-base font-extrabold text-ink">{c.name}</p>
                <p className="mt-0.5 text-xs font-bold uppercase tracking-wide text-brandink">
                  {c.vehicleClass}
                </p>
                <p className="mt-2 text-xs text-muted">
                  {c.seats ? `${c.seats} seats` : ''}
                  {c.seats && c.pricePerKm ? ' · ' : ''}
                  {c.pricePerKm ? `${rupees(c.pricePerKm)}/km` : ''}
                </p>
              </Link>
            ))}
          </div>
        </div>
        </section>
      )}

      {/* ── Services ─────────────────────────────────────────────────────── */}
      <section className="border-y border-hairline bg-bandwarm">
        <div className="mx-auto max-w-6xl px-4 py-16">
          <div className="text-center" data-reveal>
            <p className="eyebrow justify-center text-brandink">What we do</p>
            <h2 className="display mt-3 text-3xl sm:text-4xl">Three ways to travel</h2>
          </div>

          <div className="mt-10 grid gap-5 lg:grid-cols-3">
            {SERVICES.map((s, i) => (
              <Link
                key={s.href}
                href={s.href}
                data-reveal
                className="group relative overflow-hidden rounded-3xl bg-surface p-7 shadow-card ring-1 ring-hairline transition duration-300 hover:-translate-y-1 hover:ring-brand-300"
              >
                <span
                  aria-hidden
                  className="pointer-events-none absolute -right-16 -top-16 h-40 w-40 scale-0 rounded-full bg-brand-500/10 transition-transform duration-500 group-hover:scale-100"
                />
                <span
                  className={`relative grid h-14 w-14 place-items-center rounded-2xl text-white shadow-glow ${
                    ['bg-cabsolid', 'bg-drivesolid', 'bg-poolsolid'][i]
                  }`}
                >
                  <BadgeCheck className="h-6 w-6" />
                </span>
                <h3 className="relative mt-6 text-xl font-extrabold text-ink">{s.title}</h3>
                <p className="relative mt-1 text-[11px] font-bold uppercase tracking-[0.16em] text-brandink">
                  {s.blurb}
                </p>
                <p className="relative mt-3 text-sm leading-relaxed text-muted">{s.desc}</p>
                <span className="relative mt-5 inline-flex items-center gap-1.5 text-sm font-bold text-brandink">
                  Book now
                  <ArrowRight className="h-4 w-4 transition-transform duration-300 group-hover:translate-x-1" />
                </span>
              </Link>
            ))}
          </div>
        </div>
      </section>

      {/* ── About ────────────────────────────────────────────────────────── */}
      {/* `scroll-mt-20` on every anchored section: the header is sticky and
          64px tall, so an un-offset jump lands with the heading underneath
          it. */}
      <section id="about" className="scroll-mt-20 border-b border-hairline bg-canvas">
        <div className="mx-auto grid max-w-6xl gap-12 px-4 py-16 lg:grid-cols-2 lg:gap-16">
          <div data-reveal>
            <p className="eyebrow text-brandink">About us</p>
            <h2 className="display mt-3 text-3xl sm:text-4xl">
              A travel network,
              <br />
              <span className="text-brand-600">not one more fleet</span>
            </h2>
            <p className="mt-5 text-[15px] leading-relaxed text-muted">
              {COMPANY.brand} is run by {COMPANY.legalName} from {COMPANY.city}. We do not keep a yard
              full of cars. We put local travel operators, vendors and owner-drivers from across India
              on one network, and hand each booking to the one who can actually run it.
            </p>
            <p className="mt-4 text-[15px] leading-relaxed text-muted">
              That is why a trip out of a small town is priced the same way as one out of a metro. The
              operator sets the rate per kilometre, the site adds the tolls, state tax and GST that
              apply to your route, and you see the whole of it before you confirm. Nothing is added on
              the way.
            </p>

            <dl className="mt-8 grid gap-5 rounded-2xl bg-surface p-6 shadow-card ring-1 ring-hairline sm:grid-cols-2">
              <div>
                <dt className="text-[11px] font-bold uppercase tracking-[0.14em] text-brandink">
                  Registered name
                </dt>
                <dd className="mt-1 text-sm font-bold leading-snug text-ink">{COMPANY.legalName}</dd>
              </div>
              <div>
                <dt className="text-[11px] font-bold uppercase tracking-[0.14em] text-brandink">GSTIN</dt>
                <dd className="numeral mt-1 text-sm font-bold text-ink">{COMPANY.gstin}</dd>
              </div>
              <div className="sm:col-span-2">
                <dt className="text-[11px] font-bold uppercase tracking-[0.14em] text-brandink">
                  Registered office
                </dt>
                <dd className="mt-1 text-sm leading-relaxed text-muted">{COMPANY.address}</dd>
              </div>
            </dl>
          </div>

          <div className="grid content-start gap-5">
            {[
              {
                icon: Users,
                bg: 'bg-cabsolid',
                head: 'Partners in each city',
                body:
                  'Local operators and owner-drivers run the trips. You deal with one booking; they deal with the car, the paperwork and the road.',
              },
              {
                icon: Route,
                bg: 'bg-poolsolid',
                head: 'Four ways to travel',
                body:
                  'Outstation one way and round trip, local hourly packages, a driver for the car you already own, and a seat in a ride someone else is making.',
              },
              {
                icon: Wallet,
                bg: 'bg-drivesolid',
                head: 'Money stays simple',
                body:
                  'Pay the driver at the end, or part of it online if you would rather. Either way the breakup is itemised, with toll, state tax and GST shown on their own lines.',
              },
            ].map(({ icon: Icon, bg, head, body }) => (
              <div
                key={head}
                data-reveal
                className="flex gap-5 rounded-3xl bg-surface p-6 shadow-card ring-1 ring-hairline transition duration-300 hover:-translate-y-1 hover:ring-brand-300"
              >
                <span className={`grid h-12 w-12 shrink-0 place-items-center rounded-2xl text-white shadow-glow ${bg}`}>
                  <Icon className="h-5 w-5" />
                </span>
                <span>
                  <h3 className="text-base font-extrabold text-ink">{head}</h3>
                  <p className="mt-1.5 text-sm leading-relaxed text-muted">{body}</p>
                </span>
              </div>
            ))}
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
        {/*
         * One centred column and four cards, not a two-column split.
         *
         * The split wanted a picture on the left and there is none to give
         * it: the admin's hero slot is empty on the live site, and the fleet
         * photographs are cut-outs on white, which cannot sit on navy. Every
         * stand-in tried here read as a mistake — first the "Explore India"
         * card with its own headline burned into it, then a car illustration
         * adrift in a dark rectangle. These four cards carry the same four
         * claims and have nothing to break.
         */}
        <div className="relative mx-auto max-w-6xl px-4 py-20">
          <div className="mx-auto max-w-2xl text-center" data-reveal>
            <span className="inline-flex rounded-full bg-white/10 px-3 py-1 text-xs font-bold text-brand-300 ring-1 ring-white/20">
              Why choose Gora Taxi?
            </span>
            <h2 className="display mt-4 text-3xl text-white sm:text-4xl">Your trusted travel partner</h2>
            <p className="mt-4 text-[15px] leading-relaxed text-white/75">
              Most of what goes wrong with a long-distance cab happens before the trip: a fare that
              grows on the way, a driver nobody can reach, a booking nobody can see. So the fare is
              shown in full and broken down before you confirm, the driver&apos;s details reach you
              ahead of pickup, and the same trip waits in the app under your mobile number.
            </p>
          </div>

          <div className="mt-12 grid gap-5 sm:grid-cols-2 lg:grid-cols-4">
            {[
              {
                icon: Tag,
                bg: 'bg-poolsolid',
                head: 'Transparent pricing',
                sub: 'Toll, state tax, driver allowance and GST — itemised before you confirm.',
              },
              {
                icon: ShieldCheck,
                bg: 'bg-cabsolid',
                head: 'Verified drivers',
                sub: 'Licence and vehicle checked before any work is assigned.',
              },
              {
                icon: Wallet,
                bg: 'bg-drivesolid',
                head: 'Pay the driver',
                sub: 'Book with ₹0 advance if you would rather not pay online.',
              },
              {
                icon: Clock,
                /* Not `bg-luxsolid`: this band is navy in both themes, and
                   the token is tuned for page surfaces, so it would be a
                   slate square lost on slate. */
                bg: 'bg-slate-500',
                head: 'Free cancellation',
                sub: 'Any time before pickup, at no charge.',
              },
            ].map(({ icon: Icon, bg, head, sub }) => (
              <div
                key={head}
                data-reveal
                className="rounded-3xl bg-white/[0.07] p-6 ring-1 ring-white/15 transition duration-300 hover:-translate-y-1 hover:bg-white/[0.11] hover:ring-white/30"
              >
                <span className={`grid h-12 w-12 place-items-center rounded-2xl text-white shadow-glow ${bg}`}>
                  <Icon className="h-5 w-5" />
                </span>
                <h3 className="mt-5 text-base font-extrabold text-white">{head}</h3>
                <p className="mt-2 text-[13px] leading-relaxed text-white/75">{sub}</p>
              </div>
            ))}
          </div>

          <div className="mt-12 text-center" data-reveal>
            <Link
              href="/book/cab"
              className="btn-sheen group inline-flex min-h-11 items-center gap-2 rounded-xl bg-brand-500 px-7 py-3.5 text-[15px] font-bold text-white shadow-glow transition hover:bg-brand-600"
            >
              Book a cab
              <ArrowRight className="h-4 w-4 transition-transform duration-300 group-hover:translate-x-1" />
            </Link>
          </div>
        </div>
      </section>

      {/* ── How it works ─────────────────────────────────────────────────── */}
      <section className="border-y border-hairline bg-bandwarm">
        <div className="mx-auto max-w-6xl px-4 py-16">
          <div className="text-center" data-reveal>
            <p className="eyebrow justify-center text-brandink">Four steps</p>
            <h2 className="display mt-3 text-3xl sm:text-4xl">How it works</h2>
          </div>
          <ol className="mt-12 grid gap-8 sm:grid-cols-2 lg:grid-cols-4">
            {[
              ['Tell us the trip', 'Pickup, drop, date and time — add stops if you need them.'],
              ['Pick your cab', 'Compare classes and read the exact fare breakup.'],
              ['Confirm & pay', 'Book with ₹0 advance, or pay 10% / 100% online.'],
              ['Ride', 'We assign a verified driver and send you their details.'],
            ].map(([title, body], i) => (
              <li key={title} className="text-center" data-reveal>
                <span
                  className={`mx-auto grid h-14 w-14 place-items-center rounded-2xl text-lg font-extrabold text-white shadow-glow ${
                    ['bg-cabsolid', 'bg-drivesolid', 'bg-poolsolid', 'bg-luxsolid'][i]
                  }`}
                >
                  {i + 1}
                </span>
                <h3 className="mt-4 text-base font-extrabold text-ink">{title}</h3>
                <p className="mx-auto mt-2 max-w-[22rem] text-sm leading-relaxed text-muted">{body}</p>
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
        <section id="cities" className="scroll-mt-20 border-b border-hairline bg-surface">
          <div className="mx-auto max-w-6xl px-4 py-16">
            <div className="text-center" data-reveal>
              <p className="eyebrow justify-center text-brandink">
                <MapPin className="h-3 w-3" /> Where we run
              </p>
              <h2 className="display mt-3 text-3xl sm:text-4xl">
                {cities.length} cities{states > 1 ? `, ${states} states` : ''}
              </h2>
              <p className="mx-auto mt-4 max-w-xl text-sm leading-relaxed text-muted">
                These are the cities the network is set up in. Your pickup and drop can be anywhere —
                most outstation trips end somewhere that is not on this list.
              </p>
            </div>

            <div className="mt-10 flex flex-wrap justify-center gap-3">
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
        <section className="mx-auto max-w-6xl px-4 py-16">
          <div className="text-center" data-reveal>
            <p className="eyebrow justify-center text-brandink">
              <MapPin className="h-3 w-3" /> Where to next
            </p>
            <h2 className="display mt-3 text-3xl sm:text-4xl">Explore India</h2>
          </div>
          <div className={`mt-10 grid gap-5 sm:grid-cols-2 ${gridCols(explore.length)}`}>
            {explore.map((item, i) => (
              <ShowcaseCard key={item._id ?? i} item={item} />
            ))}
          </div>
        </section>
      )}

      {offers.length > 0 && (
        <section className="border-y border-hairline bg-surface">
          <div className="mx-auto max-w-6xl px-4 py-16">
            <div className="text-center" data-reveal>
              <p className="eyebrow justify-center text-brandink">
                <Tag className="h-3 w-3" /> Worth a look
              </p>
              <h2 className="display mt-3 text-3xl sm:text-4xl">Special offers</h2>
            </div>
            <div className={`mt-10 grid gap-5 sm:grid-cols-2 ${gridCols(offers.length)}`}>
              {offers.map((item, i) => (
                <ShowcaseCard key={item._id ?? i} item={item} />
              ))}
            </div>
          </div>
        </section>
      )}

      {/* ── Questions ────────────────────────────────────────────────────── */}
      <section className="border-y border-hairline bg-bandwarm">
        <div className="mx-auto grid max-w-6xl gap-12 px-4 py-16 lg:grid-cols-[0.8fr_1.2fr] lg:gap-16">
          {/* Pinned: three lines beside six questions is otherwise a tall
              hole in the page. */}
          <div data-reveal className="lg:sticky lg:top-24 lg:self-start">
            <p className="eyebrow text-brandink">Before you book</p>
            <h2 className="display mt-3 text-3xl sm:text-4xl">Questions, answered</h2>
            <p className="mt-5 text-sm leading-relaxed text-muted">
              Anything else, our team is on the phone 24×7.{' '}
              <Link href="/support" className="font-bold text-brandink hover:underline">
                Help &amp; Support
              </Link>
            </p>
          </div>

          <div data-reveal>
            {FAQ.map(([q, a]) => (
              // <details> rather than React state: it works before hydration,
              // and the browser handles the open/close and the keyboard.
              <details key={q} className="group border-b border-hairline py-4 first:border-t">
                <summary className="flex cursor-pointer list-none items-start justify-between gap-4 text-[15px] font-bold text-ink marker:hidden">
                  {q}
                  <span className="mt-0.5 shrink-0 text-xl font-normal leading-none text-brand-500 transition-transform duration-300 group-open:rotate-45">
                    +
                  </span>
                </summary>
                <p className="mt-3 max-w-[68ch] text-sm leading-relaxed text-muted">{a}</p>
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
        <div className="mx-auto max-w-6xl px-4 py-16">
          <div className="text-center" data-reveal>
            <p className="eyebrow justify-center text-brandink">Talk to us</p>
            <h2 className="display mt-3 text-3xl sm:text-4xl">Contact {COMPANY.brand}</h2>
            <p className="mx-auto mt-4 max-w-xl text-sm leading-relaxed text-muted">
              Someone is on the phone 24×7. Call before you book if you want a quote checked, or after
              you book if anything about the trip changes.
            </p>
          </div>

          <div className="mt-10 grid gap-5 sm:grid-cols-2 lg:grid-cols-4">
            {[
              {
                key: 'call',
                show: !!phone,
                icon: Phone,
                bg: 'bg-cabsolid',
                head: 'Call us',
                line: phone,
                note: '24×7, every day',
                href: `tel:${phone}`,
                external: false,
              },
              {
                key: 'whatsapp',
                show: !!whatsapp,
                icon: MessageCircle,
                bg: 'bg-poolsolid',
                head: 'WhatsApp',
                line: 'Message the team',
                note: 'Send a trip and get it booked',
                href: `https://wa.me/${whatsapp}`,
                external: true,
              },
              {
                key: 'email',
                show: !!email,
                icon: Mail,
                bg: 'bg-drivesolid',
                head: 'Email',
                line: email,
                note: 'For bills and documents',
                href: `mailto:${email}`,
                external: false,
              },
              {
                key: 'app',
                show: true,
                icon: Smartphone,
                /* The themed neutral, not a fixed slate: this card sits on a page
                   surface, which is exactly what `luxsolid` is tuned for. */
                bg: 'bg-luxsolid',
                head: 'Get the app',
                line: COMPANY.appName,
                note: 'Track the trip and keep your history',
                href: COMPANY.playStoreUrl,
                external: true,
              },
            ]
              .filter((c) => c.show)
              .map(({ key, icon: Icon, bg, head, line, note, href, external }) => (
                <a
                  key={key}
                  href={href}
                  {...(external ? { target: '_blank', rel: 'noreferrer' } : {})}
                  data-reveal
                  className="group rounded-3xl bg-surface p-6 shadow-card ring-1 ring-hairline transition duration-300 hover:-translate-y-1 hover:ring-brand-300"
                >
                  <span className={`grid h-12 w-12 place-items-center rounded-2xl text-white shadow-glow ${bg}`}>
                    <Icon className="h-5 w-5" />
                  </span>
                  <h3 className="mt-5 text-base font-extrabold text-ink">{head}</h3>
                  <p className="numeral mt-1 break-all text-sm font-bold text-brandink">{line}</p>
                  <p className="mt-1.5 text-xs leading-relaxed text-muted">{note}</p>
                </a>
              ))}
          </div>

          <div className="mt-5 grid gap-5 lg:grid-cols-[1.5fr_1fr]">
            <div
              data-reveal
              className="flex gap-5 rounded-3xl bg-bandwarm p-6 ring-1 ring-tintline"
            >
              <span className="grid h-12 w-12 shrink-0 place-items-center rounded-2xl bg-luxsolid text-white">
                <Building2 className="h-5 w-5" />
              </span>
              <span>
                <h3 className="text-base font-extrabold text-ink">Registered office</h3>
                <p className="mt-1.5 text-sm leading-relaxed text-muted">{COMPANY.address}</p>
                <p className="mt-2 text-xs font-semibold text-muted">
                  {COMPANY.legalName} · GSTIN <span className="numeral">{COMPANY.gstin}</span>
                </p>
              </span>
            </div>

            <div data-reveal className="rounded-3xl bg-bandwarm p-6 ring-1 ring-tintline">
              <h3 className="text-base font-extrabold text-ink">Already booked?</h3>
              <p className="mt-1.5 text-sm leading-relaxed text-muted">
                Keep the booking reference handy when you call.
                {phone2 && (
                  <>
                    {' '}
                    If the first line is busy, try{' '}
                    <a href={`tel:${phone2}`} className="numeral font-bold text-brandink hover:underline">
                      {phone2}
                    </a>
                    .
                  </>
                )}
              </p>
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
        <div className="relative mx-auto max-w-6xl px-4 py-20 text-center">
          <h2 className="display text-3xl text-white sm:text-5xl" data-reveal>
            Where are you headed?
          </h2>
          <p className="mx-auto mt-4 max-w-xl text-[15px] leading-relaxed text-white/90" data-reveal>
            No sign-up, no advance if you do not want one, and the fare on screen before you confirm.
          </p>
          <div className="mt-8 flex flex-wrap justify-center gap-3" data-reveal>
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
      </section>
    </>
  );
}

/**
 * Pickup, drop, go — the booking widget the reference carries in its hero.
 *
 * It writes the same trip draft the full booking form writes and hands over
 * to the results page, so this is a real shortcut rather than a decorative
 * panel that drops you on an empty form. Date and time are left at the
 * booking page's own defaults; anyone who needs to change them is one screen
 * away.
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
    router.push('/cabs');
  };

  return (
    <div className="mt-8 rounded-2xl bg-surface p-3 shadow-card ring-1 ring-hairline">
      <div className="grid gap-3 sm:grid-cols-[1fr_1fr_auto]">
        <PlaceInput label="Pickup" value={pickup} onChange={setPickup} placeholder="Enter pickup location" />
        <PlaceInput label="Drop" value={drop} onChange={setDrop} placeholder="Enter drop location" />
        <button
          type="button"
          onClick={go}
          className="btn-sheen group mt-auto inline-flex min-h-11 items-center justify-center gap-2 rounded-xl bg-brand-500 px-6 py-3 text-[15px] font-bold text-white shadow-glow transition hover:bg-brand-600"
        >
          Book ride
          <ArrowRight className="h-4 w-4 transition-transform duration-300 group-hover:translate-x-1" />
        </button>
      </div>
      {problem && <p className="px-1 pb-1 pt-2 text-xs font-semibold text-dangerfg">{problem}</p>}
    </div>
  );
}

/** Columns for the fleet row: never wider than the number of cards. */
function fleetCols(n: number): string {
  if (n >= 4) return 'lg:grid-cols-4';
  if (n === 3) return 'lg:mx-auto lg:max-w-5xl lg:grid-cols-3';
  if (n === 2) return 'lg:mx-auto lg:max-w-3xl lg:grid-cols-2';
  return 'lg:mx-auto lg:max-w-sm lg:grid-cols-1';
}

/**
 * Three columns only when there are three cards to fill them. Two cards in
 * a three-column grid left a third of the page empty beside them, so a
 * short row gets a narrower grid, centred.
 */
function gridCols(n: number): string {
  if (n >= 3) return 'lg:grid-cols-3';
  if (n === 2) return 'lg:mx-auto lg:max-w-4xl lg:grid-cols-2';
  return 'lg:mx-auto lg:max-w-md lg:grid-cols-1';
}

function ShowcaseCard({ item }: { item: Showcase }) {
  const body = (
    <div
      data-reveal
      className="zoom-card card-flat group overflow-hidden transition duration-300 hover:-translate-y-1 hover:shadow-card"
    >
      {item.imageUrl ? (
        /* Everything on the picture, so every card in a row is the same
           height whatever the admin filled in. A text block below only
           some of them left the rest ending in blank space, because the
           grid stretches each card to the tallest one. */
        <div className="relative h-56 overflow-hidden">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src={item.imageUrl} alt={item.title ?? ''} className="h-full w-full object-cover" />
          {/* Admin artwork is whatever it is: often bright, often with its own
              text baked in. The scrim keeps this card's typography legible. */}
          <div className="absolute inset-0 bg-gradient-to-t from-black/80 via-black/20 to-transparent" />
          <div className="absolute inset-x-5 bottom-4">
            <p className="text-lg font-extrabold text-white drop-shadow">{item.title}</p>
            {item.subtitle && (
              <p className="mt-1 line-clamp-2 text-[13px] leading-relaxed text-white/80">
                {item.subtitle}
              </p>
            )}
          </div>
        </div>
      ) : (
        <div className="p-5">
          <p className="text-lg font-extrabold text-ink">{item.title}</p>
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
    <a href={href} target="_blank" rel="noreferrer">
      {body}
    </a>
  ) : (
    body
  );
}
