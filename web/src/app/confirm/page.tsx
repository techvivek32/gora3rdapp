'use client';

import { useEffect, useRef, useState } from 'react';
import { useRouter } from 'next/navigation';
import toast from 'react-hot-toast';
import { ArrowRight, Loader2, ShieldCheck } from 'lucide-react';
import { apiPost, errorMessage } from '@/lib/api';
import { GuestFields, guestReady, type GuestInfo } from '@/components/GuestFields';
import { formatDate, formatTime12, rupees, shortCity } from '@/lib/format';
import { payBookingAdvance } from '@/lib/razorpay';
import { selectedCab, tripDraft } from '@/lib/trip-draft';
import type { Booking, SelectedCab, TripDraft } from '@/lib/types';

const PERCENTS = [0, 10, 100] as const;

export default function ConfirmPage() {
  return <Confirm />;
}

function Confirm() {
  const router = useRouter();

  const [trip, setTrip] = useState<TripDraft | null>(null);
  const [cab, setCab] = useState<SelectedCab | null>(null);
  const [percent, setPercent] = useState<number>(0);
  const [busy, setBusy] = useState(false);
  const [guest, setGuest] = useState<GuestInfo>({ name: '', mobile: '' });

  /** The booking reference created for a payment that hasn't completed yet.
   *  Held in a ref so a retry reuses it instead of creating a second booking.
   *  It is the human-readable `bookingId` because that — paired with the mobile
   *  — is what authorises a guest's advance order. */
  const pendingRef = useRef<string | null>(null);

  useEffect(() => {
    const t = tripDraft.get();
    const c = selectedCab.get();
    if (!t || !c) {
      router.replace('/book/cab');
      return;
    }
    setTrip(t);
    setCab(c);
  }, [router]);

  if (!trip || !cab) {
    return (
      <div className="grid min-h-[50vh] place-items-center">
        <Loader2 className="h-6 w-6 animate-spin text-brand-500" />
      </div>
    );
  }

  const advance = Math.round((cab.fare * percent) / 100);

  const createBooking = async (): Promise<string | null> => {
    if (pendingRef.current) return pendingRef.current;
    const notes: string[] = [];
    if (trip.notes) notes.push(trip.notes);
    if (cab.isRound && trip.tripEndDate) notes.push(`Return date: ${trip.tripEndDate}`);
    notes.push(cab.bestPrice ? 'Best Price — toll, state tax & parking excluded (collect from customer)' : 'All inclusive');
    if (cab.fuel) notes.push(`Fuel: ${cab.fuel}`);

    try {
      const booking = await apiPost<Booking>('/customer-bookings/guest', {
        guestName: guest.name.trim(),
        guestMobile: guest.mobile,
        serviceType: 'cab',
        subType: trip.subType,
        pickup: { address: trip.pickup?.address, lat: trip.pickup?.lat ?? 0, lng: trip.pickup?.lng ?? 0 },
        pickupCity: trip.pickupCity,
        ...(trip.drop?.address
          ? { drop: { address: trip.drop.address, lat: trip.drop.lat ?? 0, lng: trip.drop.lng ?? 0 }, dropCity: trip.dropCity }
          : {}),
        ...(trip.stops && trip.stops.length
          ? { stops: trip.stops.map((s) => ({ address: s.address, lat: s.lat ?? 0, lng: s.lng ?? 0, city: s.city })) }
          : {}),
        travelDate: trip.travelDate,
        travelTime: trip.travelTime,
        ...(trip.tripEndDate ? { tripEndDate: trip.tripEndDate, tripEndTime: trip.tripEndTime } : {}),
        ...(trip.passengers ? { passengers: trip.passengers } : {}),
        vehicleType: cab.cat.name,
        // The fare breakdown is snapshotted onto the booking so a later pricing
        // change can never rewrite what this customer agreed to.
        estimatedFare: cab.fare,
        baseFare: cab.baseFare,
        driverAllowance: cab.allowance,
        gstAmount: cab.gst,
        estimatedDistance: Math.round(cab.distanceKm),
        ...(cab.isRound ? { dailyKmLimit: cab.dailyKmLimit, extraKmPrice: cab.extraKmPrice, includedKm: Math.round(cab.billedKm) } : {}),
        ...(cab.isLocal ? { packageHours: cab.packageHours, extraHourPrice: cab.extraHourPrice, durationHours: cab.packageHours } : {}),
        notes: notes.join(' • '),
      });
      // The guest endpoint returns only the booking, never account data. The
      // human-readable reference is what the customer sees and what they can
      // pay against.
      return String(booking?.bookingId ?? '') || null;
    } catch (e) {
      toast.error(errorMessage(e, 'Could not place the booking'));
      return null;
    }
  };

  /** Payment abandoned. The booking stays placed (a guest has no session to
   *  cancel it with), so the customer is told plainly that it is live and will
   *  be treated as pay-later rather than being left guessing. */
  const abandonPayment = () => {
    pendingRef.current = null;
  };

  const submit = async () => {
    if (!guestReady(guest)) {
      toast.error('Enter your name and a valid 10-digit mobile number');
      return;
    }
    setBusy(true);
    const ref = await createBooking();
    if (!ref) {
      setBusy(false);
      return;
    }

    if (percent === 0) {
      pendingRef.current = null;
      tripDraft.clear();
      toast.success('Booking confirmed — waiting for a driver');
      router.push(`/booked?id=${ref}`);
      return;
    }

    pendingRef.current = ref;
    const result = await payBookingAdvance(ref, guest.mobile, percent, guest.name.trim());

    if (result.ok) {
      pendingRef.current = null;
      tripDraft.clear();
      toast.success('Advance paid — booking confirmed');
      router.push(`/booked?id=${ref}&paid=1`);
      return;
    }

    // The booking is already placed, so don't pretend otherwise — send them to
    // the confirmation page and say the advance didn't go through.
    abandonPayment();
    tripDraft.clear();
    toast.error(result.dismissed ? 'Payment cancelled — your booking is still placed.' : result.error ?? 'Payment failed');
    router.push(`/booked?id=${ref}`);
  };

  return (
    <div className="mx-auto max-w-3xl px-4 py-10">
      <h1 className="text-2xl font-extrabold text-ink">Review & confirm</h1>
      <p className="mt-1 text-sm text-muted">Check the trip and fare before you book.</p>

      {/* Route */}
      <div className="card mt-6 p-5">
        <div className="space-y-3">
          <RoutePoint color="bg-ok" label="FROM" text={trip.pickup?.address ?? '—'} />
          {(trip.stops ?? []).map((s, i) => (
            <RoutePoint key={i} color="bg-brand-500" label={`STOP ${i + 1}`} text={s.address ?? ''} />
          ))}
          {!cab.isLocal && <RoutePoint color="bg-bad" label="TO" text={trip.drop?.address ?? '—'} />}
        </div>
        <div className="mt-4 flex flex-wrap gap-x-6 gap-y-2 border-t border-hairline pt-4 text-sm">
          <Meta label="Trip type" value={trip.subType} />
          <Meta label="Date" value={`${formatDate(trip.travelDate)} · ${formatTime12(trip.travelTime)}`} />
          {cab.isRound && trip.tripEndDate && <Meta label="Return" value={formatDate(trip.tripEndDate)} />}
          {!cab.isLocal && <Meta label="Distance" value={`${Math.round(cab.distanceKm)} km`} />}
          {cab.isLocal && <Meta label="Package" value={`${cab.packageHours} hours · ${cab.includedKm} km`} />}
          {trip.passengers ? <Meta label="Passengers" value={String(trip.passengers)} /> : null}
        </div>
      </div>

      {/* Cab + fare */}
      <div className="card mt-4 p-5">
        <div className="flex items-center gap-4">
          {cab.cat.imageUrl ? (
            // eslint-disable-next-line @next/next/no-img-element
            <img src={cab.cat.imageUrl} alt="" className="h-16 w-24 rounded-xl object-cover" />
          ) : null}
          <div className="min-w-0">
            <p className="font-extrabold text-ink">{cab.cat.name}</p>
            <p className="text-xs font-semibold uppercase tracking-wide text-brand-600">
              {cab.cat.vehicleClass}
              {cab.fuel ? ` · ${cab.fuel}` : ''}
            </p>
          </div>
          <p className="ml-auto text-2xl font-black text-ink">{rupees(cab.fare)}</p>
        </div>

        <dl className="mt-4 space-y-1.5 border-t border-hairline pt-4 text-sm">
          <Row label={cab.isLocal ? 'Package fare' : 'Ride fare'} value={rupees(cab.baseFare - cab.toll)} />
          {cab.toll > 0 && <Row label="Toll & state tax" value={rupees(cab.toll)} />}
          {cab.allowance > 0 && <Row label="Driver allowance" value={rupees(cab.allowance)} />}
          {cab.gst > 0 && <Row label="GST" value={rupees(cab.gst)} />}
          <div className="flex items-center justify-between border-t border-hairline pt-2 text-base font-extrabold text-ink">
            <dt>Total fare</dt>
            <dd>{rupees(cab.fare)}</dd>
          </div>
        </dl>

        {cab.bestPrice && !cab.isLocal && (
          <p className="mt-3 rounded-lg bg-amber-50 px-3 py-2 text-xs font-semibold text-amber-800">
            Best Price — toll, state tax and parking are paid to the driver during the trip.
          </p>
        )}
      </div>

      {/* Advance */}
      <div className="mt-4">
        <GuestFields value={guest} onChange={setGuest} />
      </div>

      <div className="card mt-4 p-5">
        <h2 className="text-sm font-extrabold text-ink">How much would you like to pay now?</h2>
        <div className="mt-3 grid gap-2 sm:grid-cols-3">
          {PERCENTS.map((p) => (
            <button
              key={p}
              type="button"
              onClick={() => setPercent(p)}
              className={`rounded-xl border px-4 py-3 text-left transition disabled:cursor-not-allowed disabled:opacity-40 ${
                percent === p ? 'border-brand-500 bg-brand-50 ring-2 ring-brand-100' : 'border-hairline bg-white hover:bg-gray-50'
              }`}
            >
              <span className="block text-sm font-extrabold text-ink">
                {p === 0 ? 'Pay later' : `${p}% now`}
              </span>
              <span className="block text-xs text-muted">
                {p === 0 ? 'Pay the driver directly' : rupees(Math.round((cab.fare * p) / 100))}
              </span>
            </button>
          ))}
        </div>

        {percent > 0 && (
          <p className="mt-3 flex items-start gap-2 text-xs leading-relaxed text-muted">
            <ShieldCheck className="mt-0.5 h-4 w-4 shrink-0 text-ok" />
            {rupees(advance)} is paid securely via Razorpay now; the remaining {rupees(cab.fare - advance)} is
            paid to the driver. Your booking is placed first — if the payment does not go through it
            simply stays a pay-later booking.
          </p>
        )}

        <button className="btn-primary mt-5 w-full py-3" onClick={submit} disabled={busy} type="button">
          {busy ? (
            <Loader2 className="h-4 w-4 animate-spin" />
          ) : (
            <>
              {percent === 0 ? 'Confirm booking' : `Pay ${rupees(advance)} & confirm`}
              <ArrowRight className="h-4 w-4" />
            </>
          )}
        </button>
        <p className="mt-3 text-center text-[11px] text-muted">
          Caution: never make advance payments to an unknown person outside the app.
        </p>
      </div>
    </div>
  );
}

function RoutePoint({ color, label, text }: { color: string; label: string; text: string }) {
  return (
    <div className="flex items-start gap-3">
      <span className={`mt-1.5 h-2.5 w-2.5 shrink-0 rounded-full ${color}`} />
      <div className="min-w-0">
        <p className="text-[10px] font-bold uppercase tracking-wide text-muted">{label}</p>
        <p className="truncate text-sm font-bold text-ink">{text}</p>
      </div>
    </div>
  );
}

function Meta({ label, value }: { label: string; value?: string }) {
  if (!value) return null;
  return (
    <div>
      <p className="text-[10px] font-bold uppercase tracking-wide text-muted">{label}</p>
      <p className="text-sm font-semibold text-ink">{value}</p>
    </div>
  );
}

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-center justify-between">
      <dt className="text-muted">{label}</dt>
      <dd className="font-semibold text-ink">{value}</dd>
    </div>
  );
}
