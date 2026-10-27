'use client';

import { Suspense } from 'react';
import Link from 'next/link';
import { useSearchParams } from 'next/navigation';
import { CheckCircle2, Loader2, Phone, Smartphone } from 'lucide-react';

/**
 * Confirmation shown after a booking is placed.
 *
 * The website has no accounts, so there is no "my bookings" to send anyone to.
 * This page closes the loop instead: it shows the booking reference, says what
 * happens next, and points at the app for anyone who wants to follow the trip.
 */
function BookedInner() {
  const params = useSearchParams();
  const ref = params.get('id') ?? '';
  const paid = params.get('paid') === '1';

  return (
    <div className="mx-auto max-w-lg px-4 py-16 text-center">
      <span className="mx-auto grid h-16 w-16 place-items-center rounded-full bg-emerald-50 text-ok">
        <CheckCircle2 className="h-9 w-9" />
      </span>
      <h1 className="mt-5 text-2xl font-extrabold text-ink">Booking placed</h1>
      <p className="mt-2 text-sm leading-relaxed text-muted">
        Our team is assigning a verified driver for your trip. They will call you on the number you gave.
      </p>
      {paid && (
        <p className="mt-3 inline-block rounded-lg bg-emerald-50 px-3 py-2 text-sm font-semibold text-ok">
          Advance paid — pay the rest to the driver.
        </p>
      )}

      {ref && (
        <div className="card mt-6 p-5">
          <p className="text-[10px] font-bold uppercase tracking-wide text-muted">Your booking reference</p>
          <p className="mt-1 text-xl font-black tracking-wide text-ink">{ref}</p>
          <p className="mt-2 text-xs text-muted">Keep this handy if you call support.</p>
        </div>
      )}

      <div className="card mt-4 p-5 text-left">
        <h2 className="text-sm font-extrabold text-ink">Want to track it?</h2>
        <p className="mt-2 flex items-start gap-2 text-sm leading-relaxed text-muted">
          <Smartphone className="mt-0.5 h-4 w-4 shrink-0 text-brand-500" />
          Open the Gora Cabs app with the same mobile number and this booking will already be there —
          with the driver's details once our team assigns one.
        </p>
      </div>

      <div className="mt-6 flex flex-wrap justify-center gap-3">
        <Link href="/book/cab" className="btn-primary px-5">
          Book another trip
        </Link>
        <Link href="/" className="btn-ghost px-5">
          Back to home
        </Link>
      </div>

      <p className="mt-8 inline-flex items-center gap-1.5 text-xs text-muted">
        <Phone className="h-3.5 w-3.5" />
        Something wrong? <Link href="/support" className="ml-1 font-semibold text-brand-600 hover:underline">Help &amp; Support</Link>
      </p>
    </div>
  );
}

export default function BookedPage() {
  return (
    <Suspense
      fallback={
        <div className="grid min-h-[50vh] place-items-center">
          <Loader2 className="h-6 w-6 animate-spin text-brand-500" />
        </div>
      }
    >
      <BookedInner />
    </Suspense>
  );
}
