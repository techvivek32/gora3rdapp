'use client';

import Link from 'next/link';
import { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { ArrowRight, CalendarDays, Loader2, Search, Users } from 'lucide-react';
import { apiGet } from '@/lib/api';
import { PlaceInput } from '@/components/PlaceInput';
import { formatDate, formatTime12, rupees, shortCity, toDateInput } from '@/lib/format';
import type { Geo, PoolRide } from '@/lib/types';

export default function PoolPage() {
  return <PoolSearch />;
}

function PoolSearch() {
  const [from, setFrom] = useState<Geo | undefined>();
  const [to, setTo] = useState<Geo | undefined>();
  const [date, setDate] = useState('');
  // Only query after the first explicit search, so the page doesn't dump every
  // ride in the country on arrival.
  const [query, setQuery] = useState<{ from?: string; to?: string; date?: string } | null>(null);

  const { data, isLoading, isFetching } = useQuery({
    queryKey: ['pool-available', query],
    enabled: query !== null,
    queryFn: () => apiGet<PoolRide[]>('/car-pool/available', query ?? undefined),
  });

  const search = () => {
    setQuery({
      ...(from?.city || from?.address ? { from: from.city || from.address } : {}),
      ...(to?.city || to?.address ? { to: to.city || to.address } : {}),
      ...(date ? { date } : {}),
    });
  };

  const rides = data ?? [];

  return (
    <div className="mx-auto max-w-4xl px-4 py-10">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 className="text-2xl font-extrabold text-ink">Car Pool</h1>
          <p className="mt-1 text-sm text-muted">Book a seat on a ride someone is already making.</p>
        </div>
        <Link href="/book/cab" className="btn-ghost px-4 py-2 text-sm">
          Book a cab instead
        </Link>
      </div>

      <div className="card mt-6 p-5">
        <div className="grid gap-4 sm:grid-cols-2">
          <PlaceInput label="From" value={from} onChange={setFrom} cityOnly placeholder="Leaving from" />
          <PlaceInput label="To" value={to} onChange={setTo} cityOnly placeholder="Going to" />
        </div>
        <div className="mt-4 flex flex-wrap items-end gap-4">
          <div className="min-w-[12rem] flex-1">
            <label className="label">Travel date</label>
            <input type="date" className="field" value={date} min={toDateInput(new Date())} onChange={(e) => setDate(e.target.value)} />
          </div>
          <button type="button" className="btn-primary px-6 py-2.5" onClick={search}>
            <Search className="h-4 w-4" /> Search rides
          </button>
        </div>
        <p className="mt-3 text-xs text-muted">Leave a field blank to widen the search.</p>
      </div>

      {query === null ? null : isLoading || isFetching ? (
        <div className="grid min-h-[25vh] place-items-center">
          <Loader2 className="h-6 w-6 animate-spin text-brand-500" />
        </div>
      ) : rides.length === 0 ? (
        <div className="card mt-6 p-10 text-center">
          <p className="text-sm text-muted">No rides match that search yet. Try a different date or a nearby city.</p>
        </div>
      ) : (
        <div className="mt-6 space-y-4">
          {rides.map((r) => {
            const left = Math.max(0, Number(r.totalSeats ?? 0) - Number(r.seatsBooked ?? 0));
            return (
              <Link key={r._id} href={`/pool/${r._id}`} className="card block p-5 transition hover:-translate-y-0.5 hover:shadow-lg">
                <div className="flex flex-wrap items-start justify-between gap-3">
                  <div className="flex items-center gap-2 text-sm font-bold text-ink">
                    <span className="truncate">{shortCity(r.fromCity || r.from?.address)}</span>
                    <ArrowRight className="h-4 w-4 shrink-0 text-muted" />
                    <span className="truncate">{shortCity(r.toCity || r.to?.address)}</span>
                  </div>
                  <p className="text-xl font-black text-ink">
                    {rupees(r.pricePerSeat)}
                    <span className="ml-1 text-xs font-semibold text-muted">/ seat</span>
                  </p>
                </div>

                <div className="mt-3 flex flex-wrap items-center gap-x-5 gap-y-2 border-t border-hairline pt-3 text-xs text-muted">
                  <span className="inline-flex items-center gap-1.5">
                    <CalendarDays className="h-3.5 w-3.5" />
                    {formatDate(r.travelDate)}
                    {r.departureTime ? ` · ${formatTime12(r.departureTime)}` : ''}
                  </span>
                  <span className={`inline-flex items-center gap-1.5 font-bold ${left > 0 ? 'text-ok' : 'text-bad'}`}>
                    <Users className="h-3.5 w-3.5" />
                    {left > 0 ? `${left} seat${left > 1 ? 's' : ''} left` : 'Full'}
                  </span>
                  {r.vehicle ? <span>{r.vehicle}</span> : null}
                  {r.driver?.fullName ? <span className="ml-auto">by {r.driver.agencyName || r.driver.fullName}</span> : null}
                </div>
              </Link>
            );
          })}
        </div>
      )}
    </div>
  );
}
