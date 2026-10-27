'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { useState } from 'react';
import { CarFront, Menu, Phone, X } from 'lucide-react';

// No account area: the site exists to take a booking, and a visitor never has
// to sign in to make one.
const NAV = [
  { href: '/book/cab', label: 'Book a Cab' },
  { href: '/book/hire_driver', label: 'Hire a Driver' },
  { href: '/pool', label: 'Car Pool' },
  { href: '/support', label: 'Help' },
];

export function SiteHeader() {
  const pathname = usePathname();
  const [open, setOpen] = useState(false);

  return (
    <header className="sticky top-0 z-40 border-b border-hairline bg-white/95 backdrop-blur">
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
            const active = pathname === item.href || pathname.startsWith(`${item.href}/`);
            return (
              <Link
                key={item.href}
                href={item.href}
                className={`rounded-lg px-3 py-2 text-sm font-semibold transition ${
                  active ? 'bg-brand-50 text-brand-700' : 'text-muted hover:bg-gray-50 hover:text-ink'
                }`}
              >
                {item.label}
              </Link>
            );
          })}
        </nav>

        <div className="ml-auto hidden md:block">
          <Link href="/book/cab" className="btn-primary px-5 py-2 text-sm">
            <CarFront className="h-4 w-4" />
            Book now
          </Link>
        </div>

        <button
          type="button"
          className="ml-auto grid h-10 w-10 place-items-center rounded-xl border border-hairline md:hidden"
          onClick={() => setOpen((v) => !v)}
          aria-label={open ? 'Close menu' : 'Open menu'}
        >
          {open ? <X className="h-5 w-5" /> : <Menu className="h-5 w-5" />}
        </button>
      </div>

      {open && (
        <div className="border-t border-hairline bg-white md:hidden">
          <div className="mx-auto max-w-6xl px-4 py-3">
            {NAV.map((item) => (
              <Link
                key={item.href}
                href={item.href}
                onClick={() => setOpen(false)}
                className="flex items-center gap-2 rounded-lg px-2 py-3 text-sm font-semibold text-ink hover:bg-gray-50"
              >
                <Phone className="h-4 w-4 text-brand-500" />
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
