'use client';

import { useEffect, useMemo, useState } from 'react';
import { useRouter } from 'next/navigation';
import { useQuery } from '@tanstack/react-query';
import { ArrowRight, BadgeCheck, Briefcase, Fuel, Loader2, MapPin, Route, Users } from 'lucide-react';
import { CountUp } from '@/components/CountUp';
import { apiGet } from '@/lib/api';
import { formatDate, formatTime12, rupees, shortCity } from '@/lib/format';
import {
  DEFAULT_CATEGORIES,
  DEFAULT_INCLUSIONS,
  availableFuels,
  fareFor,
  isLocalTrip,
  isRoundTrip,
  localIncludedKm,
  localOffered,
  resolveFuel,
  type FareContext,
  type IncMode,
} from '@/lib/fare';
import { selectedCab, tripDraft } from '@/lib/trip-draft';
import type { CabCategory, PlatformSettings, TripDraft } from '@/lib/types';

// Open to signed-out visitors: pricing a trip is how someone decides to book,
// so it must not sit behind a login.
export default function CabsPage() {
  return <CabResults />;
}

function CabResults() {
  const router = useRouter();
  const [trip, setTrip] = useState<TripDraft | null>(null);
  const [incMode, setIncMode] = useState<IncMode>('All Inclusive');
  const [fuelByCat, setFuelByCat] = useState<Record<string, string>>({});

  // The draft lives in sessionStorage, which only exists in the browser.
  useEffect(() => {
    const t = tripDraft.get();
    if (!t) {
      router.replace('/book/cab');
      return;
    }
    setTrip(t);
  }, [router]);

  const isRound = trip ? isRoundTrip(trip) : false;
  const isLocal = trip ? isLocalTrip(trip) : false;

  /** Fresh ROAD distance through any stops (pickup;stop1;…;drop). Local has no
   *  destination, so it is skipped entirely. */
  const { data: routeKm, isLoading: routeLoading } = useQuery({
    queryKey: ['route', trip?.pickup?.lat, trip?.drop?.lat, (trip?.stops ?? []).length],
    enabled: !!trip && !isLocal && !!trip?.pickup?.lat && !!trip?.drop?.lat,
    queryFn: async () => {
      const pts = [
        `${trip!.pickup!.lat},${trip!.pickup!.lng}`,
        ...(trip!.stops ?? []).filter((s) => s.lat && s.lng).map((s) => `${s.lat},${s.lng}`),
        `${trip!.drop!.lat},${trip!.drop!.lng}`,
      ].join(';');
      const d = await apiGet<{ distanceKm?: number }>('/places/route', { points: pts });
      return Number(d?.distanceKm ?? 0);
    },
    retry: 0,
  });

  const { data: settings } = useQuery({
    queryKey: ['settings'],
    queryFn: () => apiGet<PlatformSettings>('/settings'),
  });

  const { data: categories, isLoading: catsLoading } = useQuery({
    queryKey: ['cab-categories'],
    queryFn: () => apiGet<CabCategory[]>('/home-content/cab-categories'),
    retry: 0,
  });

  const { data: inclusions } = useQuery({
    queryKey: ['inclusions'],
    queryFn: () => apiGet<string[]>('/home-content/inclusions'),
    retry: 0,
  });

  const cats = useMemo(() => {
    const list = categories && categories.length > 0 ? categories : DEFAULT_CATEGORIES;
    // Local is only offered by cabs the admin priced a package for.
    return isLocal ? list.filter(localOffered) : list;
  }, [categories, isLocal]);

  const ctx: FareContext | null = useMemo(() => {
    if (!trip) return null;
    const oneWayKm = Number(routeKm ?? trip.distanceKm ?? 0);
    const tollPerKm = Number(settings?.tollTaxPerKm ?? 0);
    const oneWayToll = tollPerKm > 0 ? Math.round(oneWayKm * tollPerKm) : 0;
    // A round trip covers the route twice — both the distance and the toll double.
    return {
      trip,
      settings: settings ?? {},
      distanceKm: isRound ? oneWayKm * 2 : oneWayKm,
      toll: isRound ? oneWayToll * 2 : oneWayToll,
      incMode,
    };
  }, [trip, routeKm, settings, isRound, incMode]);

  const loading = routeLoading || catsLoading || !trip || !ctx;

  const choose = (cat: CabCategory) => {
    if (!ctx || !trip) return;
    const fuel = resolveFuel(cat, fuelByCat[String(cat._id ?? cat.name)]);
    const b = fareFor(cat, fuel, ctx);
    selectedCab.set({
      cat,
      fuel,
      fare: b.total,
      baseFare: b.netBase,
      gst: b.gst,
      allowance: b.allowance,
      toll: b.toll,
      distanceKm: ctx.distanceKm,
      billedKm: b.billedKm,
      isRound,
      isLocal,
      packageHours: isLocal ? Number(trip.durationHours ?? 8) : 0,
      extraHourPrice: isLocal ? Number(cat.extraHourPrice ?? 0) : 0,
      dailyKmLimit: Number(cat.dailyKmLimit ?? 0),
      extraKmPrice: Number(cat.extraKmPrice ?? 0),
      includedKm: isLocal ? localIncludedKm(cat, trip, ctx.settings) : 0,
      bestPrice: incMode === 'Best Price',
    });
    router.push('/confirm');
  };

  // Before the loading state, not after: with no draft this page is on its
  // way to /book/cab, and a skeleton captioned "Pricing your trip…" would be
  // claiming to price a trip that was never given.
  if (!trip) return null;

  if (loading) {
    // The shape of what is coming, rather than a spinner in the middle of an
    // empty screen. Pricing needs a route lookup and the cab list, so this is
    // a second or two on a good connection — long enough that a blank page
    // reads as broken.
    return (
      <div className="mx-auto max-w-5xl px-4 py-10">
        <div className="card p-5">
          <div className="skel h-4 w-56" />
          <div className="skel mt-3 h-3 w-36" />
        </div>
        <div className="skel mt-6 h-9 w-52 rounded-xl" />
        <p className="mt-6 text-sm font-semibold text-muted" role="status">
          Pricing your trip…
        </p>
        <div className="mt-3 space-y-4">
          {[0, 1, 2].map((i) => (
            <div key={i} className="card p-5">
              <div className="flex flex-col gap-4 sm:flex-row">
                <div className="skel h-24 w-36 shrink-0 rounded-xl" />
                <div className="flex-1">
                  <div className="skel h-4 w-40" />
                  <div className="skel mt-2 h-3 w-24" />
                  <div className="skel mt-4 h-3 w-56" />
                </div>
                <div className="sm:w-40">
                  <div className="skel ml-auto h-7 w-28" />
                  <div className="skel ml-auto mt-3 h-9 w-24 rounded-xl" />
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>
    );
  }

  const inc = inclusions && inclusions.length > 0 ? inclusions : DEFAULT_INCLUSIONS;

  return (
    <div className="mx-auto max-w-5xl px-4 py-10">
      {/* Trip summary */}
      <div className="card p-5">
        <div className="flex flex-wrap items-start justify-between gap-4">
          <div className="min-w-0">
            <div className="flex items-center gap-2 text-sm font-bold text-ink">
              <MapPin className="h-4 w-4 text-ok" />
              <span className="truncate">{shortCity(trip.pickup?.address) || '—'}</span>
              <ArrowRight className="h-4 w-4 shrink-0 text-muted" />
              <span className="truncate">{isLocal ? 'Local package' : shortCity(trip.drop?.address) || '—'}</span>
              {/* And back, on a round trip — the fares below are for both
                  legs, so the summary has to say so. */}
              {isRound && !isLocal && (
                <>
                  <ArrowRight className="h-4 w-4 shrink-0 text-muted" />
                  <span className="truncate">{shortCity(trip.pickup?.address) || '—'}</span>
                </>
              )}
            </div>
            <p className="mt-1.5 text-xs text-muted">
              {formatDate(trip.travelDate)} · {formatTime12(trip.travelTime)}
              {isRound && trip.tripEndDate ? ` · back on ${formatDate(trip.tripEndDate)}` : ''}
              {isLocal ? ` · ${trip.durationHours ?? 8} hours` : ''}
            </p>
          </div>
          <div className="flex items-center gap-4">
            {!isLocal && (
              <span className="inline-flex items-center gap-1.5 rounded-lg bg-tint px-3 py-1.5 text-sm font-bold text-brandink">
                <Route className="h-4 w-4" />
                {Math.round(ctx.distanceKm)} km
              </span>
            )}
            <button
              type="button"
              onClick={() => router.push('/book/cab')}
              className="-mr-2 inline-flex min-h-11 items-center rounded-lg px-2 text-sm font-semibold text-brandink transition hover:bg-tint hover:underline"
            >
              Edit trip
            </button>
          </div>
        </div>
      </div>

      {/* Fare mode. Local packages never carry a separate toll, so the toggle
          would be a lie there — it is hidden instead. */}
      {!isLocal && (
        <div className="mt-6 inline-flex rounded-xl bg-surface p-1 ring-1 ring-hairline">
          {(['Best Price', 'All Inclusive'] as IncMode[]).map((m) => (
            <button
              key={m}
              type="button"
              onClick={() => setIncMode(m)}
              className={`inline-flex min-h-11 items-center justify-center rounded-lg px-4 py-2 text-sm font-bold transition ${
                incMode === m ? 'bg-brand-500 text-white' : 'text-muted hover:text-ink'
              }`}
            >
              {m}
            </button>
          ))}
        </div>
      )}
      {!isLocal && (
        <p className="mt-2 text-xs text-muted">
          {incMode === 'Best Price'
            ? 'Lowest fare — toll, state tax and parking are paid to the driver during the trip.'
            : 'Everything included — toll and state tax are already in the fare.'}
        </p>
      )}

      <h2 className="display-md mt-10">Choose your ride</h2>

      {cats.length === 0 ? (
        <div className="card mt-4 p-8 text-center">
          <p className="text-sm text-muted">No cabs are available for this package right now.</p>
        </div>
      ) : (
        <div className="mt-4 space-y-4">
          {cats.map((cat, idx) => {
            const key = String(cat._id ?? cat.name);
            const fuels = availableFuels(cat);
            const fuel = resolveFuel(cat, fuelByCat[key]);
            const b = fareFor(cat, fuel, ctx);
            return (
              <div
                key={key}
                data-reveal
                style={{ '--d': `${Math.min(idx, 6) * 70}ms` } as React.CSSProperties}
                className="card group overflow-hidden p-5 transition duration-300 hover:-translate-y-0.5 hover:shadow-[0_14px_36px_rgba(17,24,39,0.10)]"
              >
                <div className="flex flex-col gap-4 sm:flex-row">
                  {cat.imageUrl ? (
                    // eslint-disable-next-line @next/next/no-img-element
                    <img src={cat.imageUrl} alt={cat.name ?? ''} className="h-24 w-36 shrink-0 rounded-xl object-cover" />
                  ) : (
                    <div className="grid h-24 w-36 shrink-0 place-items-center rounded-xl bg-sunken text-muted">
                      <Users className="h-7 w-7" />
                    </div>
                  )}

                  <div className="min-w-0 flex-1">
                    <h3 className="text-base font-extrabold text-ink">{cat.name}</h3>
                    <p className="text-xs font-semibold uppercase tracking-wide text-brand-600">{cat.vehicleClass}</p>
                    <div className="mt-2 flex flex-wrap gap-x-4 gap-y-1 text-xs text-muted">
                      {cat.seats ? (
                        <span className="inline-flex items-center gap-1">
                          <Users className="h-3.5 w-3.5" /> {cat.seats} seats
                        </span>
                      ) : null}
                      {cat.bags ? (
                        <span className="inline-flex items-center gap-1">
                          <Briefcase className="h-3.5 w-3.5" /> {cat.bags}
                        </span>
                      ) : null}
                      <span className="inline-flex items-center gap-1">
                        <Route className="h-3.5 w-3.5" />
                        {isLocal ? `${b.billedKm} km included` : `${Math.round(b.billedKm)} km billed`}
                      </span>
                    </div>

                    {/* Fuel changes the per-km rate, so it changes the price. */}
                    {fuels.length > 1 && (
                      <div className="mt-3 flex flex-wrap gap-1.5">
                        {fuels.map((f) => (
                          <button
                            key={f}
                            type="button"
                            onClick={() => setFuelByCat((m) => ({ ...m, [key]: f }))}
                            className={`inline-flex min-h-10 items-center gap-1 rounded-full px-3.5 py-1 text-[11px] font-bold ring-1 transition ${
                              fuel === f ? 'bg-brand-500 text-white ring-brand-500' : 'bg-surface text-muted ring-hairline'
                            }`}
                          >
                            <Fuel className="h-3 w-3" /> {f}
                          </button>
                        ))}
                      </div>
                    )}

                    {b.minApplied && (
                      <p className="mt-2 text-[11px] font-semibold text-warn">
                        Minimum {Math.round(b.billedKm)} km applies to this cab for your dates.
                      </p>
                    )}
                  </div>

                  <div className="shrink-0 text-right">
                    {b.originalTotal > 0 && (
                      <p className="text-xs text-muted line-through">{rupees(b.originalTotal)}</p>
                    )}
                    {/* Counts up the first time it scrolls into view, then
                        snaps on any later change — rolling between two REAL
                        prices would look like the price moving by itself. */}
                    <p className="text-2xl font-extrabold text-ink">
                      ₹<CountUp value={Math.round(b.total)} />
                    </p>
                    <p className="text-[11px] text-muted">
                      {incMode === 'Best Price' && !isLocal ? 'Best price' : 'All inclusive'}
                    </p>
                    <button type="button" onClick={() => choose(cat)} className="btn-primary mt-3 w-full px-5">
                      Select
                    </button>
                  </div>
                </div>

                {/* Fare breakup — the same numbers the booking is created with. */}
                <details className="mt-4 border-t border-hairline pt-3">
                  <summary className="cursor-pointer text-sm font-bold text-brand-600">Fare breakup</summary>
                  <dl className="mt-3 space-y-1.5 text-sm">
                    <Row label={isLocal ? `Package (${trip.durationHours ?? 8} hrs)` : 'Ride fare'} value={rupees(b.baseFare)} />
                    {b.toll > 0 && <Row label="Toll & state tax" value={rupees(b.toll)} />}
                    {b.netBase !== b.baseFare + b.toll && <Row label="Discount applied" value={`− ${rupees(b.baseFare + b.toll - b.netBase)}`} />}
                    {b.allowance > 0 && <Row label="Driver allowance" value={rupees(b.allowance)} />}
                    {b.gst > 0 && <Row label="GST" value={rupees(b.gst)} />}
                    <div className="flex items-center justify-between border-t border-hairline pt-2 font-extrabold text-ink">
                      <dt>Total</dt>
                      <dd>{rupees(b.total)}</dd>
                    </div>
                  </dl>
                </details>
              </div>
            );
          })}
        </div>
      )}

      <div className="card mt-8 p-5">
        <h3 className="text-sm font-extrabold text-ink">What the fare includes</h3>
        <ul className="mt-3 grid gap-2 sm:grid-cols-2">
          {inc.map((t) => (
            <li key={t} className="flex items-start gap-2 text-sm text-muted">
              <BadgeCheck className="mt-0.5 h-4 w-4 shrink-0 text-ok" />
              {t}
            </li>
          ))}
        </ul>
      </div>
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
