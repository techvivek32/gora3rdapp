'use client';

import { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { adminApi } from '@/lib/api';
import { DataTable } from '@/components/ui/DataTable';
import { Badge } from '@/components/ui/Badge';
import { Input } from '@/components/ui/Input';
import type { ColumnDef } from '@tanstack/react-table';

interface Vehicle {
  _id: string;
  listingId: string;
  currentCity: string;
  destinationCity?: string;
  vehicleType: string;
  vehicleNumber: string;
  driverName: string;
  status: string;
  availableDate: string;
  viewCount: number;
  postedBy: { fullName: string; membershipType: string };
}

const STATUS_COLORS: Record<string, 'default' | 'success' | 'destructive' | 'secondary'> = {
  available: 'success',
  booked: 'default',
  expired: 'secondary',
  inactive: 'destructive',
};

const columns: ColumnDef<Vehicle>[] = [
  {
    accessorKey: 'listingId',
    header: 'Listing ID',
    cell: ({ row }) => <span className="font-mono text-xs font-semibold">{row.getValue('listingId')}</span>,
  },
  {
    id: 'location',
    header: 'Location',
    cell: ({ row }) => (
      <span className="font-medium">
        {row.original.currentCity}
        {row.original.destinationCity ? ` → ${row.original.destinationCity}` : ''}
      </span>
    ),
  },
  {
    accessorKey: 'vehicleType',
    header: 'Type',
    cell: ({ row }) => <span className="capitalize">{row.getValue<string>('vehicleType').replace('_', ' ')}</span>,
  },
  { accessorKey: 'vehicleNumber', header: 'Reg. No.' },
  { accessorKey: 'driverName', header: 'Driver' },
  {
    id: 'postedBy',
    header: 'Posted By',
    cell: ({ row }) => (
      <div>
        <p className="text-sm font-medium">{row.original.postedBy?.fullName}</p>
        <span className={`badge-${row.original.postedBy?.membershipType || 'new'} text-xs`}>
          {row.original.postedBy?.membershipType}
        </span>
      </div>
    ),
  },
  {
    accessorKey: 'availableDate',
    header: 'Available',
    cell: ({ row }) => new Date(row.getValue('availableDate')).toLocaleDateString('en-IN'),
  },
  {
    accessorKey: 'status',
    header: 'Status',
    cell: ({ row }) => { const s = row.getValue('status') as string; return <Badge variant={STATUS_COLORS[s] || 'default'}>{s}</Badge>; },
  },
  { accessorKey: 'viewCount', header: 'Views' },
];

export default function VehiclesPage() {
  const [search, setSearch] = useState('');
  const [page, setPage] = useState(1);

  const { data, isLoading } = useQuery({
    queryKey: ['vehicles', page, search],
    queryFn: () => adminApi.getVehicles({ page, limit: 20, search }),
  });

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-gray-900">Available Vehicles</h1>
        <p className="text-gray-500 mt-1">All posted available cabs and vehicles</p>
      </div>

      <Input
        placeholder="Search by city or listing ID..."
        value={search}
        onChange={(e) => { setSearch(e.target.value); setPage(1); }}
        className="max-w-sm"
      />

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
