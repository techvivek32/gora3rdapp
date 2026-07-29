'use client';

import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { adminApi } from '@/lib/api';
import { DataTable } from '@/components/ui/DataTable';
import { Badge } from '@/components/ui/Badge';
import { FilterBar } from '@/components/ui/FilterBar';
import { PeriodFilter, type PeriodRange } from '@/components/ui/PeriodFilter';
import { Eye, Pencil, Trash2 } from 'lucide-react';
import toast from 'react-hot-toast';
import type { ColumnDef } from '@tanstack/react-table';
import { RequirementEditModal } from '@/components/requirements/RequirementEditModal';

interface Requirement {
  _id: string;
  bookingId: string;
  requirementId: string;
  pickupCity: string;
  dropCity: string;
  vehicleType: string;
  tripType: string;
  travelDate: string;
  status: string;
  notes?: string;
  totalAmount?: number;
  postedBy: { fullName: string; membershipType: string };
  viewCount: number;
  createdAt: string;
}

const STATUS_COLORS: Record<string, 'default' | 'success' | 'destructive' | 'warning' | 'secondary'> = {
  active: 'success',
  pending: 'warning',
  accepted: 'success',
  completed: 'success',
  cancelled: 'destructive',
  on_hold: 'warning',
  expired: 'secondary',
};
const REQ_STATUSES = ['active', 'accepted', 'completed', 'cancelled', 'on_hold', 'expired'];
// The app treats the 'accepted' status as "Booked", so show it that way in admin.
const STATUS_LABEL: Record<string, string> = { accepted: 'Booked' };
const statusLabel = (s: string) =>
  STATUS_LABEL[s] || s.replace(/_/g, ' ').replace(/\b\w/g, (c) => c.toUpperCase());

const TRIP_COLORS: Record<string, string> = {
  one_way: 'bg-blue-100 text-blue-700',
  round_trip: 'bg-green-100 text-green-700',
  airport_transfer: 'bg-purple-100 text-purple-700',
  local: 'bg-orange-100 text-orange-700',
  outstation: 'bg-teal-100 text-teal-700',
};
export default function RequirementsPage() {
  const qc = useQueryClient();
  const [search, setSearch] = useState('');
  const [page, setPage] = useState(1);
  const [status, setStatus] = useState('');
  const [range, setRange] = useState<PeriodRange>({});
  const [modal, setModal] = useState<{ mode: 'view' | 'edit'; r: Requirement } | null>(null);

  const { data, isLoading } = useQuery({
    queryKey: ['requirements', page, search, status, range.dateFrom, range.dateTo],
    queryFn: () => adminApi.getRequirements({ page, limit: 20, search, status, dateFrom: range.dateFrom, dateTo: range.dateTo }),
  });

  const deleteMutation = useMutation({
    mutationFn: (id: string) => adminApi.deleteRequirement(id),
    onSuccess: () => { toast.success('Requirement deleted'); qc.invalidateQueries({ queryKey: ['requirements'] }); },
    onError: (e: any) => toast.error(e?.message || 'Could not delete'),
  });

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
            {row.original.tripType?.replace('_', ' ').toUpperCase()}
          </span>
        </div>
      ),
    },
    {
      accessorKey: 'vehicleType',
      header: 'Vehicle',
      cell: ({ row }) => <span className="capitalize">{row.getValue<string>('vehicleType')?.replace('_', ' ')}</span>,
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
      cell: ({ row }) => { const s = row.getValue('status') as string; return <Badge variant={STATUS_COLORS[s] || 'default'}>{statusLabel(s)}</Badge>; },
    },
    { accessorKey: 'viewCount', header: 'Views' },
    {
      id: 'actions',
      header: 'Actions',
      cell: ({ row }) => (
        <div className="flex items-center gap-1">
          <IconBtn title="View" onClick={() => setModal({ mode: 'view', r: row.original })}><Eye className="w-4 h-4" /></IconBtn>
          <IconBtn title="Edit" onClick={() => setModal({ mode: 'edit', r: row.original })}><Pencil className="w-4 h-4" /></IconBtn>
          <IconBtn title="Delete" danger onClick={() => { if (confirm('Delete this requirement?')) deleteMutation.mutate(row.original._id); }}><Trash2 className="w-4 h-4" /></IconBtn>
        </div>
      ),
    },
  ];

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-gray-900 dark:text-white">Requirements</h1>
        <p className="text-gray-500 mt-1">All posted vehicle requirements</p>
      </div>

      <div className="flex justify-end">
        <PeriodFilter onChange={setRange} />
      </div>

      <FilterBar
        search={search}
        onSearch={(v) => { setSearch(v); setPage(1); }}
        searchPlaceholder="Search by city or booking ID…"
        onClear={() => { setSearch(''); setStatus(''); setPage(1); }}
      >
        <select
          value={status}
          onChange={(e) => { setStatus(e.target.value); setPage(1); }}
          className="border border-gray-200 dark:border-gray-700 dark:bg-gray-800 dark:text-white rounded-lg px-3 py-2 text-sm"
        >
          <option value="">All Status</option>
          {REQ_STATUSES.map((s) => (
            <option key={s} value={s}>{statusLabel(s)}</option>
          ))}
        </select>
      </FilterBar>

      <DataTable
        columns={columns}
        data={data?.data?.data || []}
        isLoading={isLoading}
        pagination={{ page, totalPages: data?.data?.meta?.totalPages || 1, onPageChange: setPage }}
      />

      {modal && (
        <RequirementEditModal
          req={modal.r}
          mode={modal.mode}
          onClose={() => setModal(null)}
          onSaved={() => { qc.invalidateQueries({ queryKey: ['requirements'] }); setModal(null); }}
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

