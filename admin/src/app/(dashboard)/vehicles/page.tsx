'use client';

import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { adminApi } from '@/lib/api';
import { DataTable } from '@/components/ui/DataTable';
import { Badge } from '@/components/ui/Badge';
import { Input } from '@/components/ui/Input';
import { Eye, Pencil, Trash2 } from 'lucide-react';
import toast from 'react-hot-toast';
import type { ColumnDef } from '@tanstack/react-table';
import { VehicleEditModal } from '@/components/vehicles/VehicleEditModal';

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
  notes?: string;
  postedBy: { fullName: string; membershipType: string };
}

const STATUS_COLORS: Record<string, 'default' | 'success' | 'destructive' | 'secondary'> = {
  available: 'success',
  booked: 'default',
  expired: 'secondary',
  inactive: 'destructive',
};

export default function VehiclesPage() {
  const qc = useQueryClient();
  const [search, setSearch] = useState('');
  const [page, setPage] = useState(1);
  const [modal, setModal] = useState<{ mode: 'view' | 'edit'; v: Vehicle } | null>(null);

  const { data, isLoading } = useQuery({
    queryKey: ['vehicles', page, search],
    queryFn: () => adminApi.getVehicles({ page, limit: 20, search }),
  });

  const deleteMutation = useMutation({
    mutationFn: (id: string) => adminApi.deleteVehicle(id),
    onSuccess: () => { toast.success('Vehicle deleted'); qc.invalidateQueries({ queryKey: ['vehicles'] }); },
    onError: (e: any) => toast.error(e?.message || 'Could not delete'),
  });

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
      cell: ({ row }) => <span className="capitalize">{row.getValue<string>('vehicleType')?.replace('_', ' ')}</span>,
    },
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
    {
      id: 'actions',
      header: 'Actions',
      cell: ({ row }) => (
        <div className="flex items-center gap-1">
          <IconBtn title="View" onClick={() => setModal({ mode: 'view', v: row.original })}><Eye className="w-4 h-4" /></IconBtn>
          <IconBtn title="Edit" onClick={() => setModal({ mode: 'edit', v: row.original })}><Pencil className="w-4 h-4" /></IconBtn>
          <IconBtn title="Delete" danger onClick={() => { if (confirm('Delete this vehicle listing?')) deleteMutation.mutate(row.original._id); }}><Trash2 className="w-4 h-4" /></IconBtn>
        </div>
      ),
    },
  ];

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-gray-900 dark:text-white">Available Vehicles</h1>
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
        pagination={{ page, totalPages: data?.data?.meta?.totalPages || 1, onPageChange: setPage }}
      />

      {modal && (
        <VehicleEditModal
          vehicle={modal.v}
          mode={modal.mode}
          onClose={() => setModal(null)}
          onSaved={() => { qc.invalidateQueries({ queryKey: ['vehicles'] }); setModal(null); }}
        />
      )}
    </div>
  );
}

function IconBtn({ children, onClick, title, danger }: { children: React.ReactNode; onClick: () => void; title: string; danger?: boolean }) {
  return (
    <button
      title={title}
      onClick={onClick}
      className={`p-1.5 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-800 ${danger ? 'text-red-500' : 'text-gray-500'}`}
    >
      {children}
    </button>
  );
}

