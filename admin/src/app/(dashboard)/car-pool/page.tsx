'use client';

import { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { adminApi } from '@/lib/api';
import { DataTable } from '@/components/ui/DataTable';
import { Badge } from '@/components/ui/Badge';
import { FilterBar } from '@/components/ui/FilterBar';
import { Car } from 'lucide-react';
import type { ColumnDef } from '@tanstack/react-table';

interface PoolRideBooking {
  _id: string;
  passengerName?: string;
  passengerMobile?: string;
  seats?: number;
  amount?: number;
  status?: string;
  rating?: number;
}

interface PoolRide {
  _id: string;
  rideId: string;
  status: string;
  driverId?: { _id: string; fullName: string; mobile: string; city?: string; rating?: number } | null;
  fromCity?: string;
  toCity?: string;
  from?: { address?: string; lat?: number; lng?: number };
  to?: { address?: string; lat?: number; lng?: number };
  travelDate?: string;
  departureTime?: string;
  totalSeats?: number;
  seatsAvailable?: number;
  pricePerSeat?: number;
  vehicle?: string;
  vehicleNumber?: string;
  distanceKm?: number;
  totalEarning?: number;
  distanceTravelled?: number;
  bookings?: PoolRideBooking[];
  createdAt: string;
  completedAt?: string;
}

const STATUS_COLORS: Record<string, 'warning' | 'success' | 'default' | 'destructive'> = {
  active: 'warning',
  started: 'default',
  completed: 'success',
  cancelled: 'destructive',
};

export default function CarPoolPage() {
  const [status, setStatus] = useState('');

  const { data, isLoading } = useQuery({
    queryKey: ['car-pool', status],
    queryFn: () => adminApi.getCarPoolRides(status || undefined),
  });

  const columns: ColumnDef<PoolRide>[] = [
    {
      id: 'rideId',
      header: 'Ride ID',
      cell: ({ row }) => (
        <p className="font-medium text-sm text-gray-900 dark:text-white">#{row.original.rideId}</p>
      ),
    },
    {
      id: 'driver',
      header: 'Driver',
      cell: ({ row }) =>
        row.original.driverId ? (
          <div>
            <p className="text-sm text-gray-800 dark:text-gray-200">{row.original.driverId.fullName}</p>
            <p className="text-xs text-gray-500">{row.original.driverId.mobile}</p>
          </div>
        ) : (
          <span className="text-xs text-gray-400">—</span>
        ),
    },
    {
      id: 'route',
      header: 'Route',
      cell: ({ row }) => (
        <div className="max-w-xs">
          <p className="text-sm text-gray-700 dark:text-gray-300 truncate">{row.original.fromCity || '—'} → {row.original.toCity || '—'}</p>
        </div>
      ),
    },
    {
      id: 'datetime',
      header: 'Date/Time',
      cell: ({ row }) => (
        <div>
          <p className="text-xs text-gray-700 dark:text-gray-300">{row.original.travelDate ? new Date(row.original.travelDate).toLocaleDateString() : '—'}</p>
          <p className="text-[11px] text-gray-400">{row.original.departureTime || ''}</p>
        </div>
      ),
    },
    {
      id: 'seats',
      header: 'Seats',
      cell: ({ row }) => {
        const total = row.original.totalSeats || 0;
        const booked = total - (row.original.seatsAvailable ?? total);
        return <span className="text-sm text-gray-800 dark:text-gray-200">{booked}/{total}</span>;
      },
    },
    {
      id: 'pricePerSeat',
      header: 'Price/Seat',
      cell: ({ row }) => (
        <span className="text-sm text-gray-800 dark:text-gray-200">{typeof row.original.pricePerSeat === 'number' ? `₹${row.original.pricePerSeat}` : '—'}</span>
      ),
    },
    {
      accessorKey: 'status',
      header: 'Status',
      cell: ({ row }) => <Badge variant={STATUS_COLORS[row.original.status] || 'default'}>{row.original.status}</Badge>,
    },
    {
      id: 'passengers',
      header: 'Passengers',
      cell: ({ row }) => (
        <span className="text-sm text-gray-800 dark:text-gray-200">{row.original.bookings?.length || 0}</span>
      ),
    },
    {
      id: 'totalEarning',
      header: 'Total Earning',
      cell: ({ row }) => (
        <span className="font-semibold text-sm text-gray-900 dark:text-white">{typeof row.original.totalEarning === 'number' ? `₹${row.original.totalEarning}` : '—'}</span>
      ),
    },
  ];

  return (
    <div className="space-y-6">
      <div className="flex items-center gap-2">
        <Car className="w-6 h-6 text-orange-500" />
        <div>
          <h1 className="text-2xl font-bold text-gray-900 dark:text-white">Car Pool</h1>
          <p className="text-sm text-gray-500 mt-0.5">All pool rides offered by drivers with passenger bookings</p>
        </div>
      </div>

      <FilterBar>
        <select
          value={status}
          onChange={(e) => setStatus(e.target.value)}
          className="border border-gray-200 dark:border-gray-700 dark:bg-gray-800 dark:text-white rounded-lg px-3 py-2 text-sm"
        >
          <option value="">All Status</option>
          <option value="active">Active</option>
          <option value="started">Started</option>
          <option value="completed">Completed</option>
          <option value="cancelled">Cancelled</option>
        </select>
      </FilterBar>

      <div className="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-700 overflow-hidden">
        <DataTable columns={columns} data={data?.data || []} isLoading={isLoading} />
      </div>
    </div>
  );
}
