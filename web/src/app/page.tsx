'use client';

import Link from 'next/link';
import { useQuery } from '@tanstack/react-query';
import { ArrowRight, BadgeCheck, CarFront, Clock, ShieldCheck, Users } from 'lucide-react';
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
            className="absolute inset-0 h-full w-full object-cover opacity-40"
          />
        )}
        <div className="absolute inset-0 bg-gradient-to-b from-navy/80 via-navy/50 to-navy/90" />
        <div className="relative mx-auto max-w-6xl px-4 py-20 sm:py-28">
          <p className="text-sm font-bold uppercase tracking-[0.2em] text-brand-400">India Ka Apna App</p>
          <h1 className="mt-3 max-w-2xl text-4xl font-black leading-tight text-white sm:text-5xl">
            Har Safar, <span className="text-brand-500">Gora</span> Ke Saath
          </h1>
          <p className="mt-4 max-w-xl text-[15px] leading-relaxed text-white/80">
            Book an outstation cab, a local package, or a driver for your own car — and see the full
            fare before you confirm. No hidden charges.
          </p>
          <div className="mt-8 flex flex-wrap gap-3">
            <Link href="/book/cab" className="btn-primary px-5 py-3">
              Book a cab <ArrowRight className="h-4 w-4" />
            </Link>
            <Link href="/pool" className="btn px-5 py-3 bg-white/10 text-white ring-1 ring-white/30 hover:bg-white/20">
              Find a car pool
            </Link>
          </div>

          <div className="mt-10 flex flex-wrap gap-x-8 gap-y-3 text-sm text-white/75">
            <span className="inline-flex items-center gap-2"><ShieldCheck className="h-4 w-4 text-brand-400" /> Verified drivers</span>
            <span className="inline-flex items-center gap-2"><Clock className="h-4 w-4 text-brand-400" /> 24×7 support</span>
            <span className="inline-flex items-center gap-2"><BadgeCheck className="h-4 w-4 text-brand-400" /> Transparent fare breakup</span>
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
      <section className="border-t border-hairline bg-white">
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
