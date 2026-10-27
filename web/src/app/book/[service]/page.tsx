'use client';

import { useEffect, useMemo, useState } from 'react';
import { useParams, useRouter } from 'next/navigation';
import { useQuery } from '@tanstack/react-query';
import toast from 'react-hot-toast';
import { ArrowRight, Loader2, Plus, Trash2 } from 'lucide-react';
import { apiGet, apiPost, errorMessage } from '@/lib/api';
import { GuestFields, guestReady, type GuestInfo } from '@/components/GuestFields';
import { PlaceInput } from '@/components/PlaceInput';
import { rupees, toDateInput } from '@/lib/format';
import { tripDraft } from '@/lib/trip-draft';
import type { Booking, Geo, PlatformSettings, ServiceType, TripDraft } from '@/lib/types';

/** Per-service form shape, mirroring `_meta` in the mobile booking form. */
const META: Record<string, { title: string; subtitle: string; subTypes: string[]; needsPassengers: boolean }> = {
  cab: {
    title: 'Cab Booking',
    subtitle: 'Book a taxi to your destination',
    subTypes: ['One Way', 'Round Trip', 'Local'],
    needsPassengers: true,
  },
  hire_driver: {
    title: 'Hire a Driver',
    subtitle: 'A driver for your own car',
    subTypes: ['One Way', 'Round Trip'],
    needsPassengers: false,
  },
};

const LOCAL_HOURS = [6, 8, 10, 12];

// No sign-in wall: a visitor fills the trip and gives a name + mobile at the
// point of booking. Signing in is optional and only adds history + online payment.
export default function BookPage() {
  return <BookForm />;
}

function BookForm() {
  const router = useRouter();
  const params = useParams<{ service: string }>();
  const service = (params.service === 'hire_driver' ? 'hire_driver' : 'cab') as ServiceType;
  const meta = META[service];
  const isHire = service === 'hire_driver';

  const { data: settings } = useQuery({
    queryKey: ['settings'],
    queryFn: () => apiGet<PlatformSettings>('/settings'),
  });

  const [subType, setSubType] = useState(meta.subTypes[0]);
  const [pickup, setPickup] = useState<Geo | undefined>();
  const [drop, setDrop] = useState<Geo | undefined>();
  const [stops, setStops] = useState<(Geo | undefined)[]>([]);
  const [date, setDate] = useState(toDateInput(new Date()));
  const [time, setTime] = useState('10:00');
  const [endDate, setEndDate] = useState('');
  const [endTime, setEndTime] = useState('18:00');
  const [passengers, setPassengers] = useState(2);
  const [hours, setHours] = useState(8);
  const [transmission, setTransmission] = useState('Manual');
  const [notes, setNotes] = useState('');
  const [busy, setBusy] = useState(false);
  const [guest, setGuest] = useState<GuestInfo>({ name: '', mobile: '' });

  const isRound = subType === 'Round Trip';
  const isLocal = subType === 'Local';
  // Local is an in-city hourly package — there is no destination to give.
  const needsDrop = !isLocal;

  // Round trip and Hire both span days, so seed a sensible end date once.
  useEffect(() => {
    if ((isRound || isHire) && !endDate) {
      const d = new Date(date);
      d.setDate(d.getDate() + 1);
      setEndDate(toDateInput(d));
    }
  }, [isRound, isHire, date, endDate]);

  // Hire a Driver is priced by the admin's flat per-day rate, not by distance.
  const hirePerDay = Number(settings?.driverHirePerDay ?? 0);
  const hireKmPerDay = Number(settings?.driverHireKmPerDay ?? 0);
  const hireDays = useMemo(() => {
    if (!endDate) return 1;
    const s = new Date(date);
    const e = new Date(endDate);
    const diff = Math.round(
      (Date.UTC(e.getFullYear(), e.getMonth(), e.getDate()) - Date.UTC(s.getFullYear(), s.getMonth(), s.getDate())) /
        86400000,
    );
    return diff < 0 ? 1 : diff + 1;
  }, [date, endDate]);
  const hireTotal = Math.round(hirePerDay * hireDays);

  const addStop = () => setStops((s) => (s.length >= 5 ? s : [...s, undefined]));
  const setStopAt = (i: number, g: Geo | undefined) => setStops((s) => s.map((v, j) => (j === i ? g : v)));
  const removeStop = (i: number) => setStops((s) => s.filter((_, j) => j !== i));

  /** Everything the fare depends on must be a RESOLVED place (lat/lng), not just
   *  typed text — the road distance call needs coordinates. */
  const validate = (): string | null => {
    if (!pickup?.address) return 'Please select a pickup location';
    if (needsDrop && !drop?.address) return 'Please select a drop location';
    if (!isHire && !pickup?.lat) return 'Pick the pickup from the suggestions so we can price the route';
    if (!isHire && needsDrop && !drop?.lat) return 'Pick the drop from the suggestions so we can price the route';
    if ((isRound || isHire) && !endDate) return 'Please select the trip end (return) date';
    // Hire books straight from this page, so a guest's details are needed here.
    // Cab collects them on the confirm page instead, after the fare is shown.
    if (isHire && !guestReady(guest)) return 'Enter your name and a valid 10-digit mobile number';
    return null;
  };

  const buildDraft = (): TripDraft => ({
    serviceType: service,
    subType,
    pickup,
    drop: needsDrop ? drop : undefined,
    stops: stops.filter((s): s is Geo => !!s?.address),
    pickupCity: pickup?.city || pickup?.address,
    dropCity: needsDrop ? drop?.city || drop?.address : undefined,
    travelDate: date,
    travelTime: time,
    tripEndDate: isRound || isHire ? endDate : undefined,
    tripEndTime: isRound || isHire ? endTime : undefined,
    passengers: meta.needsPassengers ? passengers : undefined,
    durationHours: isLocal ? hours : undefined,
    notes: notes.trim() || undefined,
  });

  /** Cab → price it on the results page. Hire → the fare is already known, so
   *  the booking is created straight away (same as the app). */
  const submit = async () => {
    const problem = validate();
    if (problem) return toast.error(problem);

    const draft = buildDraft();
    if (!isHire) {
      tripDraft.set(draft);
      router.push('/cabs');
      return;
    }

    setBusy(true);
    const lines: string[] = [];
    if (notes.trim()) lines.push(notes.trim());
    lines.push(`Transmission: ${transmission}`);
    lines.push(`${hireDays} day${hireDays > 1 ? 's' : ''} (to ${endDate})`);
    if (hirePerDay > 0) lines.push(`Rate: ₹${Math.round(hirePerDay)}/day → ₹${hireTotal}`);
    if (hireKmPerDay > 0) lines.push(`Included: ${Math.round(hireKmPerDay)} km per day`);

    try {
      const booking = await apiPost<Booking>('/customer-bookings/guest', {
        guestName: guest.name.trim(),
        guestMobile: guest.mobile,
        serviceType: 'hire_driver',
        subType,
        pickup: { address: pickup!.address, lat: pickup!.lat ?? 0, lng: pickup!.lng ?? 0 },
        pickupCity: draft.pickupCity,
        ...(drop?.address ? { drop: { address: drop.address, lat: drop.lat ?? 0, lng: drop.lng ?? 0 }, dropCity: draft.dropCity } : {}),
        travelDate: date,
        travelTime: time,
        tripEndDate: endDate,
        tripEndTime: endTime,
        durationHours: hireDays,
        ...(hireTotal > 0 ? { estimatedFare: hireTotal } : {}),
        notes: lines.join(' • '),
      });
      toast.success('Request posted — our team will assign a driver');
      router.push(`/booked?id=${booking?.bookingId ?? ''}`);
    } catch (e) {
      toast.error(errorMessage(e, 'Could not post the request'));
      setBusy(false);
    }
  };

  return (
    <div className="mx-auto max-w-3xl px-4 py-10">
      <h1 className="text-2xl font-extrabold text-ink">{meta.title}</h1>
      <p className="mt-1 text-sm text-muted">{meta.subtitle}</p>

      <div className="card mt-6 space-y-6 p-6">
        {/* Trip type */}
        <div>
          <p className="label">{isHire ? 'Duration' : 'Trip type'}</p>
          <div className="flex flex-wrap gap-2">
            {meta.subTypes.map((t) => (
              <button
                key={t}
                type="button"
                onClick={() => setSubType(t)}
                className={`rounded-full px-4 py-2 text-sm font-bold ring-1 transition ${
                  subType === t
                    ? 'bg-brand-500 text-white ring-brand-500'
                    : 'bg-white text-muted ring-hairline hover:bg-gray-50'
                }`}
              >
                {t}
              </button>
            ))}
          </div>
        </div>

        {/* Route */}
        <div className="grid gap-4 sm:grid-cols-2">
          <PlaceInput label="Pickup" value={pickup} onChange={setPickup} required placeholder="Where from?" />
          {needsDrop && <PlaceInput label="Drop" value={drop} onChange={setDrop} required placeholder="Where to?" />}
        </div>

        {/* Stops — only meaningful when there is a route to route THROUGH. */}
        {needsDrop && (
          <div>
            {stops.map((s, i) => (
              <div key={i} className="mb-3 flex items-end gap-2">
                <div className="flex-1">
                  <PlaceInput label={`Stop ${i + 1}`} value={s} onChange={(g) => setStopAt(i, g)} placeholder="Add a via point" />
                </div>
                <button
                  type="button"
                  onClick={() => removeStop(i)}
                  className="mb-0.5 grid h-11 w-11 shrink-0 place-items-center rounded-xl border border-hairline text-muted hover:bg-gray-50"
                  aria-label={`Remove stop ${i + 1}`}
                >
                  <Trash2 className="h-4 w-4" />
                </button>
              </div>
            ))}
            {stops.length < 5 && (
              <button type="button" onClick={addStop} className="btn-ghost px-3 py-2 text-sm">
                <Plus className="h-4 w-4" /> Add a stop
              </button>
            )}
          </div>
        )}

        {/* When */}
        <div className="grid gap-4 sm:grid-cols-2">
          <div>
            <label className="label">Travel date *</label>
            <input type="date" className="field" value={date} min={toDateInput(new Date())} onChange={(e) => setDate(e.target.value)} />
          </div>
          <div>
            <label className="label">Pickup time *</label>
            <input type="time" className="field" value={time} onChange={(e) => setTime(e.target.value)} />
          </div>
          {(isRound || isHire) && (
            <>
              <div>
                <label className="label">{isHire ? 'End date *' : 'Return date *'}</label>
                <input type="date" className="field" value={endDate} min={date} onChange={(e) => setEndDate(e.target.value)} />
              </div>
              <div>
                <label className="label">{isHire ? 'End time' : 'Return time'}</label>
                <input type="time" className="field" value={endTime} onChange={(e) => setEndTime(e.target.value)} />
              </div>
            </>
          )}
        </div>

        {/* Local package hours */}
        {isLocal && (
          <div>
            <p className="label">Package</p>
            <div className="flex flex-wrap gap-2">
              {LOCAL_HOURS.map((h) => (
                <button
                  key={h}
                  type="button"
                  onClick={() => setHours(h)}
                  className={`rounded-full px-4 py-2 text-sm font-bold ring-1 transition ${
                    hours === h ? 'bg-brand-500 text-white ring-brand-500' : 'bg-white text-muted ring-hairline hover:bg-gray-50'
                  }`}
                >
                  {h} hours
                </button>
              ))}
            </div>
          </div>
        )}

        {isHire && (
          <div>
            <p className="label">Transmission</p>
            <div className="flex flex-wrap gap-2">
              {['Manual', 'Automatic'].map((t) => (
                <button
                  key={t}
                  type="button"
                  onClick={() => setTransmission(t)}
                  className={`rounded-full px-4 py-2 text-sm font-bold ring-1 transition ${
                    transmission === t ? 'bg-brand-500 text-white ring-brand-500' : 'bg-white text-muted ring-hairline hover:bg-gray-50'
                  }`}
                >
                  {t}
                </button>
              ))}
            </div>
          </div>
        )}

        {meta.needsPassengers && (
          <div className="max-w-[12rem]">
            <label className="label">Passengers</label>
            <input
              type="number"
              min={1}
              max={20}
              className="field"
              value={passengers}
              onChange={(e) => setPassengers(Math.max(1, Number(e.target.value) || 1))}
            />
          </div>
        )}

        {/* Collected here only for Hire, which books straight from this page.
            Cab asks on the confirm page instead, once the fare is known. */}
        {isHire && <GuestFields value={guest} onChange={setGuest} />}

        <div>
          <label className="label">Notes for the driver (optional)</label>
          <textarea
            className="field min-h-[88px] resize-y"
            placeholder="Anything the driver should know"
            value={notes}
            onChange={(e) => setNotes(e.target.value)}
          />
        </div>

        {/* Hire shows its price here because there is no cab-picking step. */}
        {isHire && hirePerDay > 0 && (
          <div className="rounded-xl bg-brand-50 p-4 ring-1 ring-brand-200">
            <div className="flex items-center justify-between">
              <span className="text-sm font-semibold text-ink">
                {rupees(hirePerDay)} / day × {hireDays} day{hireDays > 1 ? 's' : ''}
              </span>
              <span className="text-xl font-black text-brand-600">{rupees(hireTotal)}</span>
            </div>
            <p className="mt-2 text-xs leading-relaxed text-muted">
              {hireKmPerDay > 0
                ? `${Math.round(hireKmPerDay)} km per day included (total ${Math.round(hireKmPerDay * hireDays)} km).`
                : 'No km limit.'}{' '}
              The driver drives your own car.
            </p>
          </div>
        )}

        <button className="btn-primary w-full py-3" onClick={submit} disabled={busy} type="button">
          {busy ? <Loader2 className="h-4 w-4 animate-spin" /> : (
            <>
              {isHire ? 'Confirm booking' : 'See cabs & fares'} <ArrowRight className="h-4 w-4" />
            </>
          )}
        </button>
      </div>
    </div>
  );
}
