import Link from 'next/link';

export function SiteFooter() {
  return (
    <footer className="mt-16 border-t border-hairline bg-white">
      <div className="mx-auto grid max-w-6xl gap-8 px-4 py-10 sm:grid-cols-2 md:grid-cols-4">
        <div>
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src="/gora-logo.png" alt="Gora Taxi" className="h-12 w-auto" />
          <p className="mt-2 text-xs font-semibold text-brand-600">India Ka Apna App</p>
          <p className="mt-3 text-sm leading-relaxed text-muted">
            Outstation cabs, local packages, drivers for your own car, and shared rides across India.
          </p>
        </div>
        <div>
          <p className="text-sm font-bold text-ink">Book</p>
          <ul className="mt-3 space-y-2 text-sm text-muted">
            <li><Link href="/book/cab" className="hover:text-brand-600">Cab Booking</Link></li>
            <li><Link href="/book/hire_driver" className="hover:text-brand-600">Hire a Driver</Link></li>
            <li><Link href="/pool" className="hover:text-brand-600">Car Pool</Link></li>
          </ul>
        </div>
        <div>
          <p className="text-sm font-bold text-ink">Track your trip</p>
          <p className="mt-3 text-sm leading-relaxed text-muted">
            Booked here? Open the Gora Cabs app with the same mobile number and your trip is already
            waiting for you.
          </p>
        </div>
        <div>
          <p className="text-sm font-bold text-ink">Help</p>
          <ul className="mt-3 space-y-2 text-sm text-muted">
            <li><Link href="/support" className="hover:text-brand-600">Help &amp; Support</Link></li>
          </ul>
          {/* The same caution the app shows above every booking feed. */}
          <p className="mt-4 rounded-lg bg-rose-50 px-3 py-2 text-[11px] font-semibold leading-snug text-rose-700">
            Caution: never make advance payments to an unknown person without a reference.
          </p>
        </div>
      </div>
      <div className="border-t border-hairline py-4 text-center text-xs text-muted">
        © {new Date().getFullYear()} Gora Cabs. All rights reserved.
      </div>
    </footer>
  );
}
