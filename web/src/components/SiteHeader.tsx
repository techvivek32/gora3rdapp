'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { ChevronRight, Download, Menu, Phone, X } from 'lucide-react';
import { apiGet } from '@/lib/api';
import { useSiteText } from '@/lib/site-text';
import { StoreBadges } from '@/components/GetApp';
import type { PlatformSettings, SupportContact } from '@/lib/types';

// No account area: the site exists to take a booking, and a visitor never has
// to sign in to make one.
const NAV = [
  { href: '/book/cab', label: 'Book a Cab' },
  { href: '/book/hire_driver', label: 'Hire a Driver' },
  { href: '/pool', label: 'Car Pool' },
  // Sections of the home page. `secondary` keeps them out of the nav between
  // md and lg, where six links plus the logo and the Book now button do not
  // fit — and these are the two a visitor can most afford to lose.
  { href: '/#about', label: 'About', secondary: true },
  { href: '/#cities', label: 'Cities', secondary: true },
  { href: '/support', label: 'Help' },
];

/**
 * The header, in two bars.
 *
 * The thin blue strip on top is the reference's, and it earns its place: on a
 * cab site the single most valuable link is the phone number, and putting it
 * in the main bar means competing with the Book button. Up there it is always
 * reachable and never in the way. It scrolls away with the page — only the
 * white bar below it sticks — so it costs nothing after the first screen.
 */
export function SiteHeader() {
  const pathname = usePathname();
  const [open, setOpen] = useState(false);
  const t = useSiteText();

  // The same two queries the footer and the contact section use, so on the
  // landing page this costs nothing: React Query serves what is already there.
  const { data: contact } = useQuery({
    queryKey: ['support-contact'],
    queryFn: () => apiGet<SupportContact>('/settings/support-contact'),
    staleTime: 5 * 60 * 1000,
    retry: 0,
  });
  const { data: settings } = useQuery({
    queryKey: ['public-settings'],
    queryFn: () => apiGet<PlatformSettings>('/settings'),
    staleTime: 5 * 60 * 1000,
    retry: 0,
  });
  const phone = (contact?.phone || settings?.supportPhone || '').trim();
  const playStore = t('company.playStoreUrl');

  return (
    <>
      {/* ── Utility strip ────────────────────────────────────────────────
          Not sticky. A second fixed bar on a phone eats most of the screen,
          and the number is a first-screen decision, not a constant one. */}
      <div className="bg-bandblue text-white">
        <div className="mx-auto flex h-9 max-w-6xl items-center justify-end gap-5 px-4 text-[13px] font-semibold">
          <span className="mr-auto hidden sm:block text-white">{t('company.tagline')}</span>
          {phone ? (
            <a href={`tel:${phone}`} className="inline-flex items-center gap-1.5 transition hover:text-white/80">
              <Phone className="h-3.5 w-3.5" />
              <span className="numeral">{phone}</span>
            </a>
          ) : null}
          {/* A text link, not a badge: the strip is 36px tall and a store
              badge in it would either be illegible or burst the bar. Hidden
              on the narrowest phones, where the number has to win. */}
          {playStore ? (
            <a
              href={playStore}
              target="_blank"
              rel="noreferrer"
              className="hidden items-center gap-1.5 transition hover:text-white/80 sm:inline-flex"
            >
              <Download className="h-3.5 w-3.5" />
              Get the App
            </a>
          ) : null}
          <Link href="/support" className="inline-flex items-center gap-1.5 transition hover:text-white/80">
            Help
          </Link>
        </div>
      </div>

      <header className="relative sticky top-0 z-40 border-b border-hairline bg-surface/90 backdrop-blur-xl">
        <div className="mx-auto flex h-[72px] max-w-6xl items-center gap-3 px-4">
          <Link href="/" className="flex shrink-0 items-center gap-2.5" onClick={() => setOpen(false)}>
            {/* The real brand mark, shared with the app (gora_logo_white.png). */}
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img src="/gora-logo.png" alt={t('company.brand')} className="h-11 w-auto" />
          </Link>

          {/* Centred, the way the reference sets it: the logo and the actions
              are the anchors and the nav floats between them. `absolute` so
              its width cannot push the two apart. */}
          <nav className="absolute left-1/2 hidden -translate-x-1/2 items-center gap-1 md:flex">
            {NAV.map((item) => {
              // An anchor is never "the page you are on", so only real routes
              // can light up.
              const active =
                !item.href.includes('#') &&
                (pathname === item.href || pathname.startsWith(`${item.href}/`));
              return (
                <Link
                  key={item.href}
                  href={item.href}
                  className={`rounded-lg px-3 py-2 text-[15px] font-semibold transition ${
                    item.secondary ? 'hidden lg:block' : ''
                  } ${active ? 'text-blueink' : 'text-ink/75 hover:text-blueink'}`}
                >
                  {item.label}
                </Link>
              );
            })}
          </nav>

          <div className="ml-auto hidden items-center gap-2.5 md:flex">
            {/* An outlined blue secondary next to a filled accent primary —
                the reference's exact pair, and the reason the Book button
                reads as the one thing to press. */}
            <Link
              href="/pool"
              className="rounded-xl border border-blue/60 px-4 py-2.5 text-[15px] font-semibold text-blueink transition hover:bg-bluesoft"
            >
              Car Pool
            </Link>
            <Link href="/book/cab" className="btn-primary px-5 py-2.5 text-[15px]">
              Book Cab
            </Link>
          </div>

          <div className="ml-auto flex items-center gap-2 md:hidden">
            <button
              type="button"
              className="grid h-10 w-10 place-items-center rounded-xl border border-hairline text-ink transition hover:bg-sunken"
              onClick={() => setOpen((v) => !v)}
              aria-label={open ? 'Close menu' : 'Open menu'}
            >
              {open ? <X className="h-5 w-5" /> : <Menu className="h-5 w-5" />}
            </button>
          </div>
        </div>

        {/* Reading progress. Inside the header so it rides along with it, and
            driven by ScrollFx rather than React state — a scroll handler that
            called setState would re-render the whole header on every frame. */}
        <span id="gora-progress" className="progress" aria-hidden />

        {open && (
          <div className="border-t border-hairline bg-surface md:hidden">
            <div className="mx-auto max-w-6xl px-4 py-3">
              {NAV.map((item) => (
                <Link
                  key={item.href}
                  href={item.href}
                  onClick={() => setOpen(false)}
                  className="flex items-center gap-2 rounded-lg px-2 py-3 text-[15px] font-semibold text-ink hover:bg-sunken"
                >
                  <ChevronRight className="h-4 w-4 text-blue" />
                  {item.label}
                </Link>
              ))}
              <Link href="/book/cab" onClick={() => setOpen(false)} className="btn-primary mt-2 w-full">
                Book Cab
              </Link>
              {/* The strip's "Get the App" link is hidden at this width, so
                  the phone gets the badge here instead — not nowhere. */}
              <StoreBadges size="sm" className="mt-4 justify-center pb-1" />
            </div>
          </div>
        )}
      </header>
    </>
  );
}
