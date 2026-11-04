'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { useState } from 'react';
import { CarFront, ChevronRight, Menu, X } from 'lucide-react';
import { ThemeToggle } from './ThemeToggle';

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
  { href: '/#contact', label: 'Contact', secondary: true },
  { href: '/support', label: 'Help' },
];

export function SiteHeader() {
  const pathname = usePathname();
  const [open, setOpen] = useState(false);

  return (
    <header className="relative sticky top-0 z-40 border-b border-hairline bg-surface/85 backdrop-blur-xl">
      <div className="mx-auto flex h-16 max-w-6xl items-center gap-3 px-4">
        <Link href="/" className="flex items-center gap-2.5" onClick={() => setOpen(false)}>
          {/* The real brand mark, shared with the app (gora_logo_white.png). */}
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src="/gora-logo.png" alt="Gora Taxi" className="h-10 w-auto" />
          <span className="hidden leading-tight sm:block">
            <span className="block text-[10px] font-semibold tracking-wide text-brand-600">India Ka Apna App</span>
          </span>
        </Link>

        <nav className="ml-6 hidden items-center gap-1 md:flex">
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
                className={`rounded-lg px-3 py-2 text-sm font-semibold transition ${
                  item.secondary ? 'hidden lg:block' : ''
                } ${active ? 'bg-tint text-brandink' : 'text-muted hover:bg-sunken hover:text-ink'}`}
              >
                {item.label}
              </Link>
            );
          })}
        </nav>

        <div className="ml-auto hidden items-center gap-2 md:flex">
          <ThemeToggle />
          <Link href="/book/cab" className="btn-primary px-5 py-2 text-sm shadow-glow">
            <CarFront className="h-4 w-4" />
            Book now
          </Link>
        </div>

        {/* On a phone the switch sits beside the menu button rather than inside
            it: changing the theme should not cost two taps. */}
        <div className="ml-auto flex items-center gap-2 md:hidden">
          <ThemeToggle />
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
                className="flex items-center gap-2 rounded-lg px-2 py-3 text-sm font-semibold text-ink hover:bg-sunken"
              >
                {item.href.includes('#') ? (
                  <ChevronRight className="h-4 w-4 text-brand-500" />
                ) : (
                  <CarFront className="h-4 w-4 text-brand-500" />
                )}
                {item.label}
              </Link>
            ))}
            <Link href="/book/cab" onClick={() => setOpen(false)} className="btn-primary mt-2 w-full text-sm">
              Book now
            </Link>
          </div>
        </div>
      )}
    </header>
  );
}
