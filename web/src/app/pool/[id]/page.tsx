'use client';

import { useParams, useRouter } from 'next/navigation';
import { useState } from 'react';
import { useMutation, useQuery } from '@tanstack/react-query';
import toast from 'react-hot-toast';
import { ArrowLeft, ArrowRight, CalendarDays, Car, Loader2, Users } from 'lucide-react';
import { apiGet, apiPost, errorMessage } from '@/lib/api';
import { GuestFields, guestReady, type GuestInfo } from '@/components/GuestFields';
import { formatDate, formatTime12, rupees, shortCity } from '@/lib/format';
import type { PoolRide } from '@/lib/types';

export default function PoolRidePage() {
  return <PoolRideDetail />;
}

function PoolRideDetail() {
  const { id } = useParams<{ id: string }>();
  const router = useRouter();
  const [seats, setSeats] = useState(1);
  const [pickupPoint, setPickupPoint] = useState('');
  const [guest, setGuest] = useState<GuestInfo>({ name: '', mobile: '' });

  const { data: r, isLoading } = useQuery({
    queryKey: ['pool-ride', id],
    queryFn: () => apiGet<PoolRide>(`/car-pool/${id}`),
  });

  const book = useMutation({
    mutationFn: () =>
      apiPost(`/car-pool/${id}/guest-book`, {
        seats,
        ...(pickupPoint.trim() ? { pickupPoint: pickupPoint.trim() } : {}),
        guestName: guest.name.trim(),
        guestMobile: guest.mobile,
      }),
    onSuccess: () => {
      toast.success('Seat booked! Pay the driver directly.');
      router.push('/booked');
    },
    onError: (e) => toast.error(errorMessage(e, 'Could not book the seat')),
  });

  if (isLoading || !r) {
    return (
      <div className="grid min-h-[50vh] place-items-center">
        <Loader2 className="h-6 w-6 animate-spin text-brand-500" />
      </div>
    );
  }

  const left = Math.max(0, Number(r.totalSeats ?? 0) - Number(r.seatsBooked ?? 0));
  const total = Math.round(Number(r.pricePerSeat ?? 0) * seats);
  const isFull = left <= 0;

  return (
    <div className="mx-auto max-w-2xl px-4 py-10">
      <button type="button" onClick={() => router.push('/pool')} className="mb-4 inline-flex items-center gap-1.5 text-sm font-semibold text-muted hover:text-ink">
        <ArrowLeft className="h-4 w-4" /> Back to search
      </button>

      <div className="card p-5">
        <div className="flex items-center gap-2 text-base font-extrabold text-ink">
          <span className="truncate">{shortCity(r.fromCity || r.from?.address)}</span>
          <ArrowRight className="h-4 w-4 shrink-0 text-muted" />
          <span className="truncate">{shortCity(r.toCity || r.to?.address)}</span>
        </div>

        <div className="mt-4 flex flex-wrap gap-x-6 gap-y-3 border-t border-hairline pt-4 text-sm">
          <Meta icon={<CalendarDays className="h-3.5 w-3.5" />} label="Departs" value={`${formatDate(r.travelDate)}${r.departureTime ? ` · ${formatTime12(r.departureTime)}` : ''}`} />
          <Meta icon={<Users className="h-3.5 w-3.5" />} label="Seats left" value={`${left} of ${r.totalSeats ?? 0}`} />
          {r.vehicle ? <Meta icon={<Car className="h-3.5 w-3.5" />} label="Vehicle" value={[r.vehicle, r.vehicleNumber].filter(Boolean).join(' · ')} /> : null}
          {r.distanceKm ? <Meta label="Distance" value={`${Math.round(Number(r.distanceKm))} km`} /> : null}
        </div>

        {r.notes ? <p className="mt-4 rounded-lg bg-gray-50 p-3 text-sm leading-relaxed text-muted">{r.notes}</p> : null}

        {r.driver?.fullName ? (
          <div className="mt-4 border-t border-hairline pt-4">
            <p className="text-[10px] font-bold uppercase tracking-wide text-muted">Ride offered by</p>
            <p className="text-sm font-bold text-ink">{r.driver.agencyName || r.driver.fullName}</p>
          </div>
        ) : null}
      </div>

      <div className="card mt-4 p-5">
        <h2 className="text-sm font-extrabold text-ink">Book your seat</h2>

        <div className="mt-4 grid gap-4 sm:grid-cols-2">
          <div>
            <label className="label">Seats</label>
            <input
              type="number"
              min={1}
              max={Math.max(1, left)}
              className="field"
              value={seats}
              disabled={isFull}
              onChange={(e) => setSeats(Math.min(Math.max(1, Number(e.target.value) || 1), Math.max(1, left)))}
            />
          </div>
          <div>
            <label className="label">Pickup point (optional)</label>
            <input
              className="field"
              placeholder="Where should the driver pick you up?"
              value={pickupPoint}
              disabled={isFull}
              onChange={(e) => setPickupPoint(e.target.value)}
            />
          </div>
        </div>

        <div className="mt-4">
          <GuestFields value={guest} onChange={setGuest} />
        </div>

        <div className="mt-4 flex items-center justify-between rounded-xl bg-brand-50 px-4 py-3 ring-1 ring-brand-200">
          <span className="text-sm font-semibold text-ink">
            {rupees(r.pricePerSeat)} × {seats} seat{seats > 1 ? 's' : ''}
          </span>
          <span className="text-xl font-black text-brand-600">{rupees(total)}</span>
        </div>

        {/* Pool fares are settled with the driver in person — there is no online
            payment step here, matching the app. */}
        <p className="mt-3 text-xs leading-relaxed text-muted">
          Pay the driver directly for a car pool seat. Nothing is charged online.
        </p>

        <button
          type="button"
          className="btn-primary mt-4 w-full py-3"
          disabled={isFull || book.isPending || !guestReady(guest)}
          onClick={() => book.mutate()}
        >
          {book.isPending ? <Loader2 className="h-4 w-4 animate-spin" /> : isFull ? 'This ride is full' : `Book ${seats} seat${seats > 1 ? 's' : ''}`}
        </button>
      </div>
    </div>
  );
}

function Meta({ icon, label, value }: { icon?: React.ReactNode; label: string; value?: string }) {
  if (!value) return null;
  return (
    <div>
      <p className="inline-flex items-center gap-1 text-[10px] font-bold uppercase tracking-wide text-muted">
        {icon}
        {label}
      </p>
      <p className="text-sm font-semibold text-ink">{value}</p>
    </div>
  );
}
