'use client';

import { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { adminApi } from '@/lib/api';
import { DataTable } from '@/components/ui/DataTable';
import { Badge } from '@/components/ui/Badge';
import { Input } from '@/components/ui/Input';
import type { ColumnDef } from '@tanstack/react-table';

interface Requirement {
  _id: string;
  bookingId: string;
  requirementId: string;
  pickupCity: string;
  dropCity: string;
  vehicleType: string;
  tripType: string;
  numberOfVehicles: number;
  travelDate: string;
  status: string;
  postedBy: { fullName: string; membershipType: string };
  viewCount: number;
  createdAt: string;
}

const STATUS_COLORS: Record<string, 'default' | 'success' | 'destructive' | 'warning' | 'secondary'> = {
  pending: 'warning',
  accepted: 'success',
  completed: 'success',
  cancelled: 'destructive',
  expired: 'secondary',
};

const TRIP_COLORS: Record<string, string> = {
  one_way: 'bg-blue-100 text-blue-700',
  round_trip: 'bg-green-100 text-green-700',
  airport_transfer: 'bg-purple-100 text-purple-700',
  local: 'bg-orange-100 text-orange-700',
  outstation: 'bg-teal-100 text-teal-700',
};

const columns: ColumnDef<Requirement>[] = [
  {
    accessorKey: 'bookingId',
    header: 'Booking ID',
    cell: ({ row }) => <span className="font-mono text-xs font-semibold">{row.getValue('bookingId')}</span>,
  },
  {
    id: 'route',
    header: 'Route',
    cell: ({ row }) => (
      <div>
        <p className="font-medium">{row.original.pickupCity} → {row.original.dropCity}</p>
        <span className={`text-xs px-2 py-0.5 rounded font-medium ${TRIP_COLORS[row.original.tripType] || 'bg-gray-100 text-gray-700'}`}>
          {row.original.tripType.replace('_', ' ').toUpperCase()}
        </span>
      </div>
    ),
  },
  {
    accessorKey: 'vehicleType',
    header: 'Vehicle',
    cell: ({ row }) => <span className="capitalize">{row.getValue<string>('vehicleType').replace('_', ' ')}</span>,
  },
  {
    accessorKey: 'numberOfVehicles',
    header: 'Qty',
  },
  {
    accessorKey: 'travelDate',
    header: 'Travel Date',
    cell: ({ row }) => new Date(row.getValue('travelDate')).toLocaleDateString('en-IN'),
  },
  {
    id: 'postedBy',
    header: 'Posted By',
    cell: ({ row }) => (
      <div>
        <p className="font-medium text-sm">{row.original.postedBy?.fullName}</p>
        <span className={`badge-${row.original.postedBy?.membershipType || 'new'} text-xs`}>
          {row.original.postedBy?.membershipType || 'new'}
        </span>
      </div>
    ),
  },
  {
    accessorKey: 'status',
    header: 'Status',
    cell: ({ row }) => { const s = row.getValue('status') as string; return <Badge variant={STATUS_COLORS[s] || 'default'}>{s}</Badge>; },
  },
  {
    accessorKey: 'viewCount',
    header: 'Views',
  },
];

export default function RequirementsPage() {
  const [search, setSearch] = useState('');
  const [page, setPage] = useState(1);
  const [status, setStatus] = useState('');

  const { data, isLoading } = useQuery({
    queryKey: ['requirements', page, search, status],
    queryFn: () => adminApi.getRequirements({ page, limit: 20, search, status }),
  });

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-gray-900">Requirements</h1>
        <p className="text-gray-500 mt-1">All posted vehicle requirements</p>
      </div>

      <div className="flex gap-3">
        <Input
          placeholder="Search by city or booking ID..."
          value={search}
          onChange={(e) => { setSearch(e.target.value); setPage(1); }}
          className="max-w-sm"
        />
        <select
          value={status}
          onChange={(e) => { setStatus(e.target.value); setPage(1); }}
          className="border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-brand-500"
        >
          <option value="">All Status</option>
          {['pending', 'accepted', 'completed', 'cancelled', 'expired'].map((s) => (
            <option key={s} value={s}>{s.charAt(0).toUpperCase() + s.slice(1)}</option>
          ))}
        </select>
      </div>

      <DataTable
        columns={columns}
        data={data?.data?.data || []}
        isLoading={isLoading}
        pagination={{
          page,
          totalPages: data?.data?.meta?.totalPages || 1,
          onPageChange: setPage,
        }}
      />
    </div>
  );
}
