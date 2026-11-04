'use client';

import { useEffect, useMemo, useState } from 'react';
import { useParams, useRouter } from 'next/navigation';
import { useQuery } from '@tanstack/react-query';
import toast from 'react-hot-toast';
import { ArrowRight, BadgeIndianRupee, Loader2, Plus, ShieldCheck, Sparkles, Trash2 } from 'lucide-react';
import { apiGet, apiPost, errorMessage } from '@/lib/api';
import { GuestFields, guestReady, type GuestInfo } from '@/components/GuestFields';
import { PlaceInput } from '@/components/PlaceInput';
import { rupees, toDateInput } from '@/lib/format';
import { tripDraft } from '@/lib/trip-draft';
import type { Booking, Geo, PlatformSettings, ServiceType, TripDraft } from '@/lib/types';

/** Per-service form shape, mirroring `_meta` in the mobile booking form. */
const META: Record<string, { title: string; subtitle: string; subTypes: string[] }> = {
  cab: {
    title: 'Cab Booking',
    subtitle: 'Book a taxi to your destination',
    subTypes: ['One Way', 'Round Trip', 'Local'],
  },
  hire_driver: {
    title: 'Hire a Driver',
    subtitle: 'A driver for your own car',
    subTypes: ['One Way', 'Round Trip'],
  },
};

const LOCAL_HOURS = [6, 8, 10, 12];

/** The three things a visitor wants to know before they start typing. */
const TRUST = [
  { icon: ShieldCheck, text: 'Verified drivers' },
  { icon: BadgeIndianRupee, text: 'No hidden charges' },
  { icon: Sparkles, text: 'Instant fare estimate' },
];

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
        contactName: guest.name.trim(),
        contactMobile: guest.mobile,
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


  // Each section fades up a beat after the one above it, so the form assembles
  // itself instead of arriving all at once. A counter rather than hard-coded
  // numbers, because sections appear and disappear with the trip type.
  let step = 0;
  const rise = () => ({ '--d': `${step++ * 70 + 90}ms` }) as React.CSSProperties;
  const at = (ms: number) => ({ '--d': `${ms}ms` }) as React.CSSProperties;

  return (
    <div className="relative">
      {/* ── Hero ─────────────────────────────────────────────────────────── */}
      <div className="relative overflow-hidden border-b border-hairline bg-surface pb-12 pt-14">
        {/* One warm wash, the same device the home hero uses. */}
        <div
          aria-hidden
          className="pointer-events-none absolute inset-x-0 top-0 h-56 opacity-60"
          style={{ background: 'radial-gradient(55% 100% at 18% 0%, rgb(var(--tint)) 0%, transparent 70%)' }}
        />

        <div className="relative mx-auto max-w-3xl px-4">
          <p className="eyebrow reveal" style={at(40)}>
            <Sparkles className="h-3 w-3 text-brand-500" />
            {isHire ? 'Your car, our driver' : 'Outstation · Local · Round trip'}
          </p>

          <h1 className="display-lg reveal mt-5" style={at(110)}>
            {meta.title}
          </h1>
          <p className="prose-measure reveal mt-4" style={at(180)}>
            {meta.subtitle}
          </p>

          <div className="reveal mt-7 flex flex-wrap gap-x-6 gap-y-2" style={at(250)}>
            {TRUST.map(({ icon: Icon, text }) => (
              <span key={text} className="inline-flex items-center gap-2 text-xs font-semibold text-muted">
                <Icon className="h-3.5 w-3.5 shrink-0 text-brand-500" />
                {text}
              </span>
            ))}
          </div>
        </div>
      </div>

      {/* ── The form ─────────────────────────────────────────────────────── */}
      <div className="relative z-10 mx-auto max-w-3xl px-4 pb-16 pt-8">
        <div className="reveal lift card space-y-6 p-5 sm:p-7" style={at(300)}>
          {/* Trip type */}
          <div className="reveal" style={rise()}>
            <p className="label">{isHire ? 'Duration' : 'Trip type'}</p>
            <Segmented options={meta.subTypes} value={subType} onChange={setSubType} />
          </div>

          {/* Route */}
          <div className="reveal" style={rise()}>
            {/* Both stops are themed. `to-white` survived the first pass here
                and painted a bright slab across the middle of the dark page —
                a gradient stop is not a background-color, so the sweep for
                hardcoded surfaces walked straight past it. */}
            <div className="relative rounded-2xl bg-gradient-to-br from-tint/70 to-surface p-4 ring-1 ring-tintline">
              <div className="grid gap-4 sm:grid-cols-2 sm:gap-7">
                <PlaceInput label="Pickup" value={pickup} onChange={setPickup} required placeholder="Where from?" />
                {needsDrop && <PlaceInput label="Drop" value={drop} onChange={setDrop} required placeholder="Where to?" />}
              </div>
              {/* Centred in the panel rather than at a fixed offset, so it stays
                  put whatever the fields above it do. Desktop only — stacked
                  fields read fine without it. */}
              {needsDrop && (
                <span
                  aria-hidden
                  className="absolute left-1/2 top-1/2 hidden h-7 w-7 -translate-x-1/2 -translate-y-1/2 place-items-center rounded-full bg-surface text-brand-500 shadow-card ring-1 ring-tintline sm:grid"
                >
                  <ArrowRight className="h-3.5 w-3.5" />
                </span>
              )}
            </div>
          </div>

          {/* Stops — only meaningful when there is a route to route THROUGH. */}
          {needsDrop && (
            <div className="reveal" style={rise()}>
              {stops.map((s, i) => (
                <div key={i} className="unfold mb-3 flex items-end gap-2">
                  <div className="flex-1">
                    <PlaceInput label={`Stop ${i + 1}`} value={s} onChange={(g) => setStopAt(i, g)} placeholder="Add a via point" />
                  </div>
                  <button
                    type="button"
                    onClick={() => removeStop(i)}
                    className="mb-0.5 grid h-11 w-11 shrink-0 place-items-center rounded-xl border border-hairline text-muted transition hover:border-bad/40 hover:bg-bad/5 hover:text-bad"
                    aria-label={`Remove stop ${i + 1}`}
                  >
                    <Trash2 className="h-4 w-4" />
                  </button>
                </div>
              ))}
              {stops.length < 5 && (
                <button
                  type="button"
                  onClick={addStop}
                  className="btn-ghost group px-3 py-2 text-sm hover:border-brand-300 hover:text-brand-600"
                >
                  <Plus className="h-4 w-4 transition-transform duration-300 group-hover:rotate-90" /> Add a stop
                </button>
              )}
            </div>
          )}

          {/* When */}
          <div className="reveal grid gap-4 sm:grid-cols-2" style={rise()}>
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
                <div className="unfold">
                  <label className="label">{isHire ? 'End date *' : 'Return date *'}</label>
                  <input type="date" className="field" value={endDate} min={date} onChange={(e) => setEndDate(e.target.value)} />
                </div>
                <div className="unfold" style={at(60)}>
                  <label className="label">{isHire ? 'End time' : 'Return time'}</label>
                  <input type="time" className="field" value={endTime} onChange={(e) => setEndTime(e.target.value)} />
                </div>
              </>
            )}
          </div>

          {/* Local package hours */}
          {isLocal && (
            <div className="unfold">
              <p className="label">Package</p>
              <Segmented
                options={LOCAL_HOURS.map((h) => `${h} hours`)}
                value={`${hours} hours`}
                onChange={(v) => setHours(Number(v.split(' ')[0]))}
              />
            </div>
          )}

          {isHire && (
            <div className="reveal" style={rise()}>
              <p className="label">Transmission</p>
              <Segmented options={['Manual', 'Automatic']} value={transmission} onChange={setTransmission} />
            </div>
          )}

          {/* Collected here only for Hire, which books straight from this page.
              Cab asks on the confirm page instead, once the fare is known. */}
          {isHire && (
            <div className="reveal" style={rise()}>
              <GuestFields value={guest} onChange={setGuest} />
            </div>
          )}

          <div className="reveal" style={rise()}>
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
            <div className="unfold overflow-hidden rounded-2xl bg-gradient-to-br from-tint to-brand-100/60 p-4 ring-1 ring-tintline">
              <div className="flex items-center justify-between gap-3">
                <span className="text-sm font-semibold text-ink">
                  {rupees(hirePerDay)} / day × {hireDays} day{hireDays > 1 ? 's' : ''}
                </span>
                <span className="text-2xl font-extrabold tracking-tight text-brand-600">{rupees(hireTotal)}</span>
              </div>
              <p className="mt-2 text-xs leading-relaxed text-muted">
                {hireKmPerDay > 0
                  ? `${Math.round(hireKmPerDay)} km per day included (total ${Math.round(hireKmPerDay * hireDays)} km).`
                  : 'No km limit.'}{' '}
                The driver drives your own car.
              </p>
            </div>
          )}

          <button
            className="btn-sheen group w-full rounded-xl bg-gradient-to-r from-brand-500 to-brand-600 py-3.5 text-[15px] font-bold text-white shadow-[0_8px_24px_rgba(249,115,22,0.35)] transition hover:shadow-[0_10px_30px_rgba(249,115,22,0.45)] active:scale-[0.99] disabled:cursor-not-allowed disabled:opacity-60"
            onClick={submit}
            disabled={busy}
            type="button"
          >
            <span className="inline-flex items-center justify-center gap-2">
              {busy ? (
                <>
                  <Loader2 className="h-4 w-4 animate-spin" /> Just a moment…
                </>
              ) : (
                <>
                  {isHire ? 'Confirm booking' : 'See cabs & fares'}
                  <ArrowRight className="h-4 w-4 transition-transform duration-300 group-hover:translate-x-1" />
                </>
              )}
            </span>
          </button>
        </div>

        <p className="mt-4 text-center text-xs text-muted">
          No sign-up needed · Pay the driver directly · Free cancellation before pickup
        </p>
      </div>
    </div>
  );
}

/** A pill group whose selection is drawn as one indicator sliding between the
 *  options, rather than each pill colouring itself — the movement is what tells
 *  you the choice changed. An unknown value simply highlights the first. */
function Segmented({
  options,
  value,
  onChange,
}: {
  options: string[];
  value: string;
  onChange: (v: string) => void;
}) {
  const index = Math.max(0, options.indexOf(value));
  return (
    // No gap between the pills: the indicator is sized at one nth of the inner
    // width and moved by exactly its own width, so any gap would make it drift
    // further out of line with every step along.
    <div className="relative flex rounded-full bg-sunken p-1 ring-1 ring-hairline">
      <span
        aria-hidden
        className="absolute inset-y-1 left-1 rounded-full bg-brand-500 shadow-[0_2px_10px_rgba(249,115,22,0.4)] transition-transform duration-300 ease-[cubic-bezier(0.22,1,0.36,1)]"
        style={{
          width: `calc((100% - 0.5rem) / ${options.length})`,
          transform: `translateX(${index * 100}%)`,
        }}
      />
      {options.map((o) => (
        <button
          key={o}
          type="button"
          onClick={() => onChange(o)}
          aria-pressed={o === value}
          className={`seg-pill ${o === value ? 'text-white' : 'text-muted hover:text-ink'}`}
        >
          {o}
        </button>
      ))}
    </div>
  );
}
