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
const VEHICLE_STATUSES = ['available', 'booked', 'expired', 'inactive'];

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
        <VehicleModal
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

function VehicleModal({ vehicle, mode, onClose, onSaved }: { vehicle: Vehicle; mode: 'view' | 'edit'; onClose: () => void; onSaved: () => void }) {
  const [form, setForm] = useState({
    status: vehicle.status,
    vehicleType: vehicle.vehicleType,
    currentCity: vehicle.currentCity,
    destinationCity: vehicle.destinationCity || '',
    vehicleNumber: vehicle.vehicleNumber || '',
    driverName: vehicle.driverName || '',
    notes: vehicle.notes || '',
  });
  const isEdit = mode === 'edit';

  const mutation = useMutation({
    mutationFn: () => adminApi.updateVehicle(vehicle._id, form),
    onSuccess: () => { toast.success('Vehicle updated'); onSaved(); },
    onError: (e: any) => toast.error(e?.message || 'Update failed'),
  });

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4" onClick={onClose}>
      <div className="w-full max-w-lg bg-white dark:bg-gray-900 rounded-2xl shadow-xl border border-gray-200 dark:border-gray-700 max-h-[90vh] overflow-y-auto" onClick={(e) => e.stopPropagation()}>
        <div className="flex items-center justify-between px-5 py-4 border-b border-gray-200 dark:border-gray-700 sticky top-0 bg-white dark:bg-gray-900">
          <h2 className="font-bold text-lg text-gray-900 dark:text-white">
            {isEdit ? 'Edit Vehicle' : 'Vehicle Details'} <span className="font-mono text-xs text-gray-400">{vehicle.listingId}</span>
          </h2>
          <button onClick={onClose} className="text-gray-400 hover:text-gray-600"><X className="w-5 h-5" /></button>
        </div>

        <div className="p-5 space-y-4">
          <Field label="Posted By">{vehicle.postedBy?.fullName} <span className="text-gray-400">({vehicle.postedBy?.membershipType})</span></Field>
          <EditableRow label="Status" isEdit={isEdit} value={form.status} onChange={(v) => setForm({ ...form, status: v })} options={VEHICLE_STATUSES} />
          <EditableRow label="Vehicle Type" isEdit={isEdit} value={form.vehicleType} onChange={(v) => setForm({ ...form, vehicleType: v })} />
          <EditableRow label="From (Current City)" isEdit={isEdit} value={form.currentCity} onChange={(v) => setForm({ ...form, currentCity: v })} />
          <EditableRow label="To (Destination)" isEdit={isEdit} value={form.destinationCity} onChange={(v) => setForm({ ...form, destinationCity: v })} />
          <EditableRow label="Reg. Number" isEdit={isEdit} value={form.vehicleNumber} onChange={(v) => setForm({ ...form, vehicleNumber: v })} />
          <EditableRow label="Driver Name" isEdit={isEdit} value={form.driverName} onChange={(v) => setForm({ ...form, driverName: v })} />
          <EditableRow label="Notes" isEdit={isEdit} value={form.notes} onChange={(v) => setForm({ ...form, notes: v })} />
          {!isEdit && <Field label="Available Date">{new Date(vehicle.availableDate).toLocaleDateString('en-IN')}</Field>}
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
  if (!isEdit) return <Field label={label}>{value || '—'}</Field>;
  return (
    <div>
      <label className="text-xs text-gray-400 mb-1 block">{label}</label>
      {options ? (
        <select value={value} onChange={(e) => onChange(e.target.value)} className="w-full border border-gray-200 dark:border-gray-700 dark:bg-gray-800 rounded-lg px-3 py-2 text-sm capitalize">
          {options.map((o) => <option key={o} value={o}>{o}</option>)}
        </select>
      ) : (
        <Input value={value} onChange={(e) => onChange(e.target.value)} />
      )}
    </div>
  );
}
