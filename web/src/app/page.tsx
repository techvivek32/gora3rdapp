'use client';

import Link from 'next/link';
import { useQuery } from '@tanstack/react-query';
import { ArrowRight, BadgeCheck, CarFront, Clock, ShieldCheck, Sparkles, Users } from 'lucide-react';
import { CarSide } from '@/components/CarSide';
import { apiGet } from '@/lib/api';

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
    desc: 'Outstation and in-city cabs with all-inclusive pricing and no hidden charges.',
    icon: CarFront,
    tint: 'bg-[#EAF1FF]',
  },
  {
    href: '/book/hire_driver',
    title: 'Hire a Driver',
    blurb: 'Hourly · Full day',
    desc: 'You have the car, we send a verified driver. Pay by the hour or for the day.',
    icon: BadgeCheck,
    tint: 'bg-[#F1ECFF]',
  },
  {
    href: '/pool',
    title: 'Car Pool',
    blurb: 'Share & save',
    desc: 'Book a seat on someone already making your trip. Cheaper, and one less car on the road.',
    icon: Users,
    tint: 'bg-[#FFF1E6]',
  },
];

/** Stagger helper — see the same pattern on the booking form. */
const at = (ms: number) => ({ '--d': `${ms}ms` }) as React.CSSProperties;

export default function HomePage() {
  // Admin-managed showcase content. There is no signed-in city to narrow it to,
  // so the website shows the global set. It is decoration — failures leave the
  // page fully usable, so no error state.
  const { data } = useQuery({
    queryKey: ['home-content'],
    queryFn: () => apiGet<HomeContent>('/home-content'),
    retry: 0,
  });

  const explore = (data?.explore ?? []).slice(0, 6);
  const offers = (data?.offers ?? []).slice(0, 6);

  return (
    <>
      {/* ── Hero ─────────────────────────────────────────────────────────── */}
      <section className="relative overflow-hidden bg-navy">
        {data?.heroImage && (
          // eslint-disable-next-line @next/next/no-img-element
          <img
            src={data.heroImage}
            alt=""
            className="absolute inset-0 h-full w-full object-cover opacity-30"
          />
        )}
        <div className="absolute inset-0 bg-gradient-to-b from-navy/85 via-navy/60 to-navy/95" />

        {/* Lighting, not content: drifting colour and a grid that fades out. */}
        <div aria-hidden className="pointer-events-none absolute inset-0 overflow-hidden">
          <div className="aurora -left-32 -top-40 h-[26rem] w-[26rem] bg-brand-500/40" />
          <div className="aurora -right-24 top-20 h-96 w-96 bg-sky-400/25" style={{ animationDelay: '-7s' }} />
          <div
            className="absolute inset-0 opacity-[0.06]"
            style={{
              backgroundImage:
                'linear-gradient(to right, #fff 1px, transparent 1px), linear-gradient(to bottom, #fff 1px, transparent 1px)',
              backgroundSize: '48px 48px',
              maskImage: 'radial-gradient(ellipse at 30% 0%, #000 35%, transparent 72%)',
              WebkitMaskImage: 'radial-gradient(ellipse at 30% 0%, #000 35%, transparent 72%)',
            }}
          />
        </div>

        <div className="relative mx-auto grid max-w-6xl items-center gap-12 px-4 py-16 sm:py-20 lg:grid-cols-[1.05fr_0.95fr]">
          <div>
            <p
              className="reveal inline-flex items-center gap-2 rounded-full bg-white/10 px-3 py-1 text-[11px] font-bold uppercase tracking-[0.2em] text-brand-200 ring-1 ring-white/15 backdrop-blur"
              style={at(40)}
            >
              <Sparkles className="h-3 w-3" />
              India Ka Apna App
            </p>
            <h1
              className="reveal mt-5 text-4xl font-black leading-[1.08] text-white sm:text-[52px]"
              style={at(110)}
            >
              Har Safar,{' '}
              <span className="bg-gradient-to-r from-brand-400 via-brand-500 to-amber-400 bg-clip-text text-transparent">
                Gora
              </span>{' '}
              Ke Saath
            </h1>
            <p className="reveal mt-5 max-w-xl text-[15px] leading-relaxed text-white/75" style={at(180)}>
              Book an outstation cab, a local package, or a driver for your own car — and see the full
              fare before you confirm. No hidden charges.
            </p>
            <div className="reveal mt-8 flex flex-wrap gap-3" style={at(250)}>
              <Link
                href="/book/cab"
                className="btn-sheen group inline-flex items-center justify-center gap-2 rounded-xl bg-gradient-to-r from-brand-500 to-brand-600 px-6 py-3.5 text-[15px] font-bold text-white shadow-glow transition hover:shadow-[0_12px_34px_rgba(249,115,22,0.5)] active:scale-[0.99]"
              >
                Book a cab
                <ArrowRight className="h-4 w-4 transition-transform duration-300 group-hover:translate-x-1" />
              </Link>
              <Link
                href="/pool"
                className="btn px-5 py-3.5 bg-white/10 text-white ring-1 ring-white/25 backdrop-blur transition hover:bg-white/20"
              >
                Find a car pool
              </Link>
            </div>

            {/* The same three promises, but as cards — they were a row of grey
                text that the eye slid straight past. */}
            <div className="reveal mt-10 grid gap-2.5 sm:grid-cols-3" style={at(320)}>
              {[
                { icon: ShieldCheck, text: 'Verified drivers' },
                { icon: Clock, text: '24×7 support' },
                { icon: BadgeCheck, text: 'Transparent fare breakup' },
              ].map(({ icon: Icon, text }) => (
                <span
                  key={text}
                  className="lift inline-flex items-center gap-2 rounded-xl bg-white/[0.07] px-3 py-2.5 text-xs font-semibold text-white/85 ring-1 ring-white/10 backdrop-blur"
                >
                  <Icon className="h-4 w-4 shrink-0 text-brand-300" />
                  {text}
                </span>
              ))}
            </div>
          </div>

          {/* A trip, drawn. No fare is shown on purpose — the whole promise
              above is that you see the real one before you confirm, and a
              decorative number here would undercut it. */}
          <div
            className="reveal relative rounded-3xl bg-white/[0.07] p-6 ring-1 ring-white/15 backdrop-blur-xl sm:p-7"
            style={at(400)}
          >
            <div className="flex items-center justify-between">
              <p className="text-[10px] font-bold uppercase tracking-[0.18em] text-white/50">
                Your trip
              </p>
              <span className="chip bg-brand-500/15 text-brand-200 ring-brand-400/30">One Way</span>
            </div>

            <div className="mt-6 flex items-start justify-between gap-3">
              <div>
                <p className="text-[10px] font-bold uppercase tracking-wide text-white/40">From</p>
                <p className="mt-0.5 text-lg font-extrabold text-white">Udaipur</p>
              </div>
              <div className="pt-1 text-right">
                <p className="text-[10px] font-bold uppercase tracking-wide text-white/40">To</p>
                <p className="mt-0.5 text-lg font-extrabold text-white">Ahmedabad</p>
              </div>
            </div>

            {/* The road between them, with the car running it on a loop. */}
            <div className="relative mt-7 flex items-center gap-2">
              <span className="relative grid h-3 w-3 shrink-0 place-items-center">
                <span className="hero-pin absolute inset-0 rounded-full bg-brand-400/60" />
                <span className="relative h-2 w-2 rounded-full bg-brand-400" />
              </span>
              <div className="hero-track relative flex-1">
                <span className="hero-runner">
                  <CarSide />
                </span>
              </div>
              <span className="relative grid h-3 w-3 shrink-0 place-items-center">
                <span
                  className="hero-pin absolute inset-0 rounded-full bg-emerald-400/60"
                  style={{ animationDelay: '1.2s' }}
                />
                <span className="relative h-2 w-2 rounded-full bg-emerald-400" />
              </span>
            </div>

            <div className="mt-8 space-y-2 border-t border-white/10 pt-5">
              {[
                'Toll, state tax and driver allowance included',
                'Pay the driver directly — nothing charged online',
                'Free cancellation before pickup',
              ].map((line) => (
                <p key={line} className="flex items-start gap-2 text-xs leading-relaxed text-white/70">
                  <BadgeCheck className="mt-[1px] h-3.5 w-3.5 shrink-0 text-brand-300" />
                  {line}
                </p>
              ))}
            </div>
          </div>
        </div>
      </section>

      {/* ── Services ─────────────────────────────────────────────────────── */}
      <section className="mx-auto max-w-6xl px-4 py-14">
        <h2 className="text-xl font-extrabold text-ink">What would you like to book?</h2>
        <div className="mt-6 grid gap-4 md:grid-cols-3">
          {SERVICES.map((s) => (
            <Link key={s.href} href={s.href} className="card group p-6 transition hover:-translate-y-0.5 hover:shadow-lg">
              <span className={`grid h-12 w-12 place-items-center rounded-2xl ${s.tint}`}>
                <s.icon className="h-6 w-6 text-brand-600" />
              </span>
              <h3 className="mt-4 text-lg font-extrabold text-ink">{s.title}</h3>
              <p className="text-xs font-bold uppercase tracking-wide text-brand-600">{s.blurb}</p>
              <p className="mt-2 text-sm leading-relaxed text-muted">{s.desc}</p>
              <span className="mt-4 inline-flex items-center gap-1.5 text-sm font-bold text-brand-600">
                Continue <ArrowRight className="h-4 w-4 transition group-hover:translate-x-0.5" />
              </span>
            </Link>
          ))}
        </div>
      </section>

      {/* ── Admin-managed showcases (hidden when the admin has added none) ── */}
      {explore.length > 0 && (
        <section className="mx-auto max-w-6xl px-4 pb-14">
          <h2 className="text-xl font-extrabold text-ink">Explore India</h2>
          <div className="mt-6 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {explore.map((item, i) => (
              <ShowcaseCard key={item._id ?? i} item={item} />
            ))}
          </div>
        </section>
      )}

      {offers.length > 0 && (
        <section className="mx-auto max-w-6xl px-4 pb-14">
          <h2 className="text-xl font-extrabold text-ink">Special offers</h2>
          <div className="mt-6 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {offers.map((item, i) => (
              <ShowcaseCard key={item._id ?? i} item={item} />
            ))}
          </div>
        </section>
      )}

      {/* ── How it works ─────────────────────────────────────────────────── */}
      <section className="border-t border-hairline bg-surface">
        <div className="mx-auto max-w-6xl px-4 py-14">
          <h2 className="text-xl font-extrabold text-ink">How it works</h2>
          <ol className="mt-6 grid gap-6 md:grid-cols-4">
            {[
              ['Tell us the trip', 'Pickup, drop, date and time — add stops if you need them.'],
              ['Pick your cab', 'Compare classes and see the exact fare breakup before you commit.'],
              ['Confirm & pay', 'Book with ₹0 advance, or pay 10% / 100% online to lock it in.'],
              ['Ride', 'Our team assigns a verified driver and shares their details with you.'],
            ].map(([title, body], i) => (
              <li key={title} className="relative">
                <span className="grid h-9 w-9 place-items-center rounded-full bg-brand-500 text-sm font-extrabold text-white">
                  {i + 1}
                </span>
                <h3 className="mt-3 text-base font-bold text-ink">{title}</h3>
                <p className="mt-1 text-sm leading-relaxed text-muted">{body}</p>
              </li>
            ))}
          </ol>
        </div>
      </section>
    </>
  );
}

function ShowcaseCard({ item }: { item: Showcase }) {
  const body = (
    <div className="card overflow-hidden transition hover:-translate-y-0.5 hover:shadow-lg">
      {item.imageUrl && (
        // eslint-disable-next-line @next/next/no-img-element
        <img src={item.imageUrl} alt={item.title ?? ''} className="h-40 w-full object-cover" />
      )}
      <div className="p-4">
        <p className="text-base font-bold text-ink">{item.title}</p>
        {item.subtitle && <p className="mt-1 text-sm text-muted">{item.subtitle}</p>}
      </div>
    </div>
  );
  // Admin action URLs are app deep links as often as web links; only follow the
  // ones a browser can actually open.
  const href = item.actionUrl?.startsWith('http') ? item.actionUrl : undefined;
  return href ? (
    <a href={href} target="_blank" rel="noreferrer">
      {body}
    </a>
  ) : (
    body
  );
}
