'use client';

import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { adminApi } from '@/lib/api';
import { DataTable } from '@/components/ui/DataTable';
import { Badge } from '@/components/ui/Badge';
import { Button } from '@/components/ui/Button';
import { Input } from '@/components/ui/Input';
import { Eye, Pencil, Trash2, X } from 'lucide-react';
import toast from 'react-hot-toast';
import type { ColumnDef } from '@tanstack/react-table';

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

const TRIP_COLORS: Record<string, string> = {
  one_way: 'bg-blue-100 text-blue-700',
  round_trip: 'bg-green-100 text-green-700',
  airport_transfer: 'bg-purple-100 text-purple-700',
  local: 'bg-orange-100 text-orange-700',
  outstation: 'bg-teal-100 text-teal-700',
};
const TRIP_TYPES = ['one_way', 'round_trip', 'airport_transfer', 'local', 'outstation'];

export default function RequirementsPage() {
  const qc = useQueryClient();
  const [search, setSearch] = useState('');
  const [page, setPage] = useState(1);
  const [status, setStatus] = useState('');
  const [modal, setModal] = useState<{ mode: 'view' | 'edit'; r: Requirement } | null>(null);

  const { data, isLoading } = useQuery({
    queryKey: ['requirements', page, search, status],
    queryFn: () => adminApi.getRequirements({ page, limit: 20, search, status }),
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
      cell: ({ row }) => { const s = row.getValue('status') as string; return <Badge variant={STATUS_COLORS[s] || 'default'}>{s}</Badge>; },
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
          className="border border-gray-200 dark:border-gray-700 dark:bg-gray-800 rounded-lg px-3 py-2 text-sm"
        >
          <option value="">All Status</option>
          {REQ_STATUSES.map((s) => (
            <option key={s} value={s}>{s.replace('_', ' ').replace(/\b\w/g, (c) => c.toUpperCase())}</option>
          ))}
        </select>
      </div>

      <DataTable
        columns={columns}
        data={data?.data?.data || []}
        isLoading={isLoading}
        pagination={{ page, totalPages: data?.data?.meta?.totalPages || 1, onPageChange: setPage }}
      />

      {modal && (
        <RequirementModal
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

function RequirementModal({ req, mode, onClose, onSaved }: { req: Requirement; mode: 'view' | 'edit'; onClose: () => void; onSaved: () => void }) {
  const [form, setForm] = useState({
    status: req.status,
    vehicleType: req.vehicleType,
    tripType: req.tripType,
    pickupCity: req.pickupCity,
    dropCity: req.dropCity,
    notes: req.notes || '',
  });
  const isEdit = mode === 'edit';

  const mutation = useMutation({
    mutationFn: () => adminApi.updateRequirement(req._id, form),
    onSuccess: () => { toast.success('Requirement updated'); onSaved(); },
    onError: (e: any) => toast.error(e?.message || 'Update failed'),
  });

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4" onClick={onClose}>
      <div className="w-full max-w-lg bg-white dark:bg-gray-900 rounded-2xl shadow-xl border border-gray-200 dark:border-gray-700 max-h-[90vh] overflow-y-auto" onClick={(e) => e.stopPropagation()}>
        <div className="flex items-center justify-between px-5 py-4 border-b border-gray-200 dark:border-gray-700 sticky top-0 bg-white dark:bg-gray-900">
          <h2 className="font-bold text-lg text-gray-900 dark:text-white">
            {isEdit ? 'Edit Requirement' : 'Requirement Details'} <span className="font-mono text-xs text-gray-400">{req.bookingId}</span>
          </h2>
          <button onClick={onClose} className="text-gray-400 hover:text-gray-600"><X className="w-5 h-5" /></button>
        </div>

        <div className="p-5 space-y-4">
          <Field label="Posted By">{req.postedBy?.fullName} <span className="text-gray-400">({req.postedBy?.membershipType})</span></Field>
          <EditableRow label="Status" isEdit={isEdit} value={form.status} onChange={(v) => setForm({ ...form, status: v })} options={REQ_STATUSES} />
          <EditableRow label="From (Pickup City)" isEdit={isEdit} value={form.pickupCity} onChange={(v) => setForm({ ...form, pickupCity: v })} />
          <EditableRow label="To (Drop City)" isEdit={isEdit} value={form.dropCity} onChange={(v) => setForm({ ...form, dropCity: v })} />
          <EditableRow label="Vehicle Type" isEdit={isEdit} value={form.vehicleType} onChange={(v) => setForm({ ...form, vehicleType: v })} />
          <EditableRow label="Trip Type" isEdit={isEdit} value={form.tripType} onChange={(v) => setForm({ ...form, tripType: v })} options={TRIP_TYPES} />
          <EditableRow label="Notes" isEdit={isEdit} value={form.notes} onChange={(v) => setForm({ ...form, notes: v })} />
          {!isEdit && <Field label="Travel Date">{new Date(req.travelDate).toLocaleDateString('en-IN')}</Field>}
          {!isEdit && req.totalAmount != null && <Field label="Total Amount">₹{req.totalAmount}</Field>}
        </div>

        {isEdit && (
          <div className="flex justify-end gap-2 px-5 py-4 border-t border-gray-200 dark:border-gray-700">
            <Button variant="outline" onClick={onClose}>Cancel</Button>
            <Button onClick={() => mutation.mutate()} isLoading={mutation.isPending}>Save Changes</Button>
          </div>
        )}
      </div>
    </div>
  );
}

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div>
      <p className="text-xs text-gray-400 mb-0.5">{label}</p>
      <p className="text-sm font-medium text-gray-800 dark:text-gray-100 capitalize">{children}</p>
    </div>
  );
}

function EditableRow({ label, isEdit, value, onChange, options }: { label: string; isEdit: boolean; value: string; onChange: (v: string) => void; options?: string[] }) {
  if (!isEdit) return <Field label={label}>{(value || '—').replace(/_/g, ' ')}</Field>;
  return (
    <div>
      <label className="text-xs text-gray-400 mb-1 block">{label}</label>
      {options ? (
        <select value={value} onChange={(e) => onChange(e.target.value)} className="w-full border border-gray-200 dark:border-gray-700 dark:bg-gray-800 rounded-lg px-3 py-2 text-sm capitalize">
          {options.map((o) => <option key={o} value={o}>{o.replace(/_/g, ' ')}</option>)}
        </select>
      ) : (
        <Input value={value} onChange={(e) => onChange(e.target.value)} />
      )}
    </div>
  );
}
