'use client';

import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { adminApi } from '@/lib/api';
import { DataTable } from '@/components/ui/DataTable';
import { Badge } from '@/components/ui/Badge';
import { Button } from '@/components/ui/Button';
import { Input } from '@/components/ui/Input';
import { Eye, Pencil, Trash2, X, Plus } from 'lucide-react';
import toast from 'react-hot-toast';
import type { ColumnDef } from '@tanstack/react-table';
import { AddressAutocomplete } from '@/components/ui/AddressAutocomplete';

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

// Mirror of the mobile kVehicleTypes list.
const VEHICLE_TYPES = [
  { value: 'hatchback', label: 'Hatchback Car' },
  { value: 'eeco', label: 'Ecco Car' },
  { value: 'sedan', label: 'Sedan Car' },
  { value: 'ertiga', label: 'SUV Ertiga Car' },
  { value: 'rumion', label: 'Toyota Rumion' },
  { value: 'carens', label: 'Kia Carens' },
  { value: 'innova', label: 'SUV Innova Car' },
  { value: 'crysta', label: 'SUV Crysta Car' },
  { value: 'hycross', label: 'Toyota Hycross' },
  { value: 'tempo_traveller', label: 'Tempo Traveller' },
  { value: 'urbania', label: 'Force Urbania' },
  { value: 'trax_cruiser', label: 'Force Trax Cruiser' },
  { value: 'small_coach', label: 'Small Coach' },
  { value: 'luxury_coach', label: 'Luxury Coach' },
  { value: 'premium', label: 'Premium Car' },
];
const FUEL_TYPES = [
  { value: 'any', label: 'Any Fuel' },
  { value: 'diesel', label: 'Diesel' },
  { value: 'petrol', label: 'Petrol' },
  { value: 'cng', label: 'CNG' },
];

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

interface Stop { address: string; lat?: number; lng?: number; }

function RequirementModal({ req, mode, onClose, onSaved }: { req: Requirement; mode: 'view' | 'edit'; onClose: () => void; onSaved: () => void }) {
  const r = req as any;
  const [form, setForm] = useState({
    status: req.status,
    vehicleType: req.vehicleType,
    tripType: req.tripType,
    fuelType: (r.fuelType as string) || 'any',
    pickupCity: req.pickupCity, // full display address
    pickupCityName: (r.pickupCityName as string) || '',
    pickupCoordinates: r.pickupCoordinates || undefined,
    dropCity: req.dropCity, // full display address
    dropCityName: (r.dropCityName as string) || '',
    dropCoordinates: r.dropCoordinates || undefined,
    stops: (Array.isArray(r.stops) ? r.stops : []).map((s: any) => ({ address: s.address || '', lat: s.lat, lng: s.lng })) as Stop[],
    travelDate: String(r.travelDate || '').slice(0, 10), // yyyy-mm-dd
    travelTime: (r.travelTime as string) || '',
    returnDate: String(r.returnDate || '').slice(0, 10),
    returnTime: (r.returnTime as string) || '',
    // App-Suggested (default) vs Enter-Your-Own fare — matches the mobile create page.
    useCustomFare: r.isAppSuggested === false,
    fare: r.fare != null ? String(r.fare) : '',
    commission: r.commission != null ? String(r.commission) : '',
    notes: req.notes || '',
  });
  const isEdit = mode === 'edit';
  const set = (patch: Partial<typeof form>) => setForm((f) => ({ ...f, ...patch }));

  // Per-vehicle pricing (₹/km) from platform settings, used to auto-recompute the
  // fare when the vehicle type changes — same behaviour as the mobile create page.
  const { data: settingsRaw } = useQuery({ queryKey: ['settings'], queryFn: () => adminApi.getSettings() });
  const settings = (settingsRaw as any)?.data || {};
  const vehiclePrices: Record<string, number> = settings.vehiclePrices || {};
  const globalRate: number = Number(settings.pricePerKm) || 20;
  const distanceKm = Number(r.estimatedDistance) || 0;
  const rateFor = (vt: string) => vehiclePrices[vt] ?? globalRate;
  const suggestedFare = distanceKm > 0 ? Math.round(distanceKm * rateFor(form.vehicleType)) : 0;
  const onVehicleChange = (v: string) => {
    // In App-Suggested mode the fare follows the new vehicle's rate; in custom
    // mode the admin's manual fare is kept.
    const fare = form.useCustomFare ? form.fare : (distanceKm > 0 ? String(Math.round(distanceKm * rateFor(v))) : form.fare);
    set({ vehicleType: v, fare });
  };
  // Effective fare/commission for saving (App-Suggested ignores manual commission).
  const effFare = form.useCustomFare ? (Number(form.fare) || 0) : suggestedFare;
  const effCommission = form.useCustomFare ? (Number(form.commission) || 0) : 0;

  const mutation = useMutation({
    mutationFn: () => {
      return adminApi.updateRequirement(req._id, {
        status: form.status,
        vehicleType: form.vehicleType,
        tripType: form.tripType,
        fuelType: form.fuelType,
        pickupCity: form.pickupCity,       // full display address
        pickupCityName: form.pickupCityName || undefined, // clean city (for filtering)
        pickupCoordinates: form.pickupCoordinates,
        dropCity: form.dropCity,           // full display address
        dropCityName: form.dropCityName || undefined,
        dropCoordinates: form.dropCoordinates,
        stops: form.stops.filter((s) => s.address.trim()),
        travelDate: form.travelDate || undefined,
        travelTime: form.travelTime || undefined,
        returnDate: form.tripType === 'round_trip' ? (form.returnDate || undefined) : undefined,
        returnTime: form.tripType === 'round_trip' ? (form.returnTime || undefined) : undefined,
        isAppSuggested: !form.useCustomFare,
        fare: effFare,
        commission: effCommission,
        totalAmount: effFare + effCommission,
        notes: form.notes,
      });
    },
    onSuccess: () => { toast.success('Requirement updated'); onSaved(); },
    onError: (e: any) => toast.error(e?.message || 'Update failed'),
  });

  // ── View mode (read-only) ──────────────────────────────────────────────────
  if (!isEdit) {
    return (
      <Shell title="Requirement Details" bookingId={req.bookingId} onClose={onClose}>
        <div className="p-5 space-y-3">
          <Field label="Posted By">{req.postedBy?.fullName} <span className="text-gray-400">({req.postedBy?.membershipType})</span></Field>
          <Field label="Status">{req.status.replace(/_/g, ' ')}</Field>
          <Field label="From">{req.pickupCity}</Field>
          {form.stops.map((s, i) => <Field key={i} label={`Stop ${i + 1}`}>{s.address}</Field>)}
          <Field label="To">{req.dropCity}</Field>
          <Field label="Vehicle">{req.vehicleType?.replace(/_/g, ' ')} · {form.fuelType} · {req.tripType?.replace(/_/g, ' ')}</Field>
          <Field label="Travel">{form.travelDate} {form.travelTime}</Field>
          {req.totalAmount != null && <Field label="Total Amount">₹{req.totalAmount}</Field>}
          {req.notes && <Field label="Notes">{req.notes}</Field>}
        </div>
      </Shell>
    );
  }

  // ── Edit mode (full form, like the mobile create page) ─────────────────────
  return (
    <Shell title="Edit Requirement" bookingId={req.bookingId} onClose={onClose}>
      <div className="p-5 space-y-4">
        {/* Route */}
        <div>
          <label className="text-xs font-medium text-gray-500 mb-1 block">From (Pickup)</label>
          <AddressAutocomplete
            value={form.pickupCity}
            placeholder="Search pickup address…"
            onSelect={(p) => set({ pickupCity: p.address, pickupCityName: p.city || '', pickupCoordinates: p.lat != null ? { lat: p.lat, lng: p.lng } : form.pickupCoordinates })}
          />
        </div>

        {/* Stops */}
        <div>
          <div className="flex items-center justify-between mb-1">
            <label className="text-xs font-medium text-gray-500">Stops</label>
            <button type="button" onClick={() => set({ stops: [...form.stops, { address: '' }] })}
              className="text-xs text-orange-600 font-medium flex items-center gap-1">
              <Plus className="w-3 h-3" /> Add stop
            </button>
          </div>
          <div className="space-y-2">
            {form.stops.map((s, i) => (
              <div key={i} className="flex gap-2 items-start">
                <div className="flex-1">
                  <AddressAutocomplete
                    value={s.address}
                    placeholder={`Stop ${i + 1} address…`}
                    onSelect={(p) => {
                      const next = [...form.stops];
                      next[i] = { address: p.address, lat: p.lat, lng: p.lng };
                      set({ stops: next });
                    }}
                  />
                </div>
                <button type="button" onClick={() => set({ stops: form.stops.filter((_, j) => j !== i) })}
                  className="p-2 text-red-500 hover:bg-red-50 dark:hover:bg-red-900/20 rounded-lg mt-0.5">
                  <Trash2 className="w-4 h-4" />
                </button>
              </div>
            ))}
            {form.stops.length === 0 && <p className="text-xs text-gray-400">No stops. Click “Add stop” to insert one between pickup and drop.</p>}
          </div>
        </div>

        <div>
          <label className="text-xs font-medium text-gray-500 mb-1 block">To (Drop)</label>
          <AddressAutocomplete
            value={form.dropCity}
            placeholder="Search drop address…"
            onSelect={(p) => set({ dropCity: p.address, dropCityName: p.city || '', dropCoordinates: p.lat != null ? { lat: p.lat, lng: p.lng } : form.dropCoordinates })}
          />
        </div>

        {/* Vehicle / fuel / trip */}
        <div className="grid grid-cols-2 gap-3">
          <SelectField label="Vehicle Type" value={form.vehicleType} onChange={onVehicleChange}
            options={VEHICLE_TYPES} />
          <SelectField label="Fuel Type" value={form.fuelType} onChange={(v) => set({ fuelType: v })}
            options={FUEL_TYPES} />
          <SelectField label="Trip Type" value={form.tripType} onChange={(v) => set({ tripType: v })}
            options={TRIP_TYPES.map((t) => ({ value: t, label: t.replace(/_/g, ' ') }))} />
          <SelectField label="Status" value={form.status} onChange={(v) => set({ status: v })}
            options={REQ_STATUSES.map((s) => ({ value: s, label: s.replace(/_/g, ' ') }))} />
        </div>

        {/* Date & time */}
        <div className="grid grid-cols-2 gap-3">
          <div>
            <label className="text-xs font-medium text-gray-500 mb-1 block">Travel Date</label>
            <input type="date" value={form.travelDate} onChange={(e) => set({ travelDate: e.target.value })}
              className="w-full border border-gray-200 dark:border-gray-700 dark:bg-gray-800 rounded-lg px-3 py-2 text-sm" />
          </div>
          <div>
            <label className="text-xs font-medium text-gray-500 mb-1 block">Travel Time</label>
            <input type="time" value={form.travelTime} onChange={(e) => set({ travelTime: e.target.value })}
              className="w-full border border-gray-200 dark:border-gray-700 dark:bg-gray-800 rounded-lg px-3 py-2 text-sm" />
          </div>
        </div>

        {/* Return date & time — only for round trips */}
        {form.tripType === 'round_trip' && (
          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="text-xs font-medium text-gray-500 mb-1 block">Return Date</label>
              <input type="date" value={form.returnDate} min={form.travelDate || undefined}
                onChange={(e) => set({ returnDate: e.target.value })}
                className="w-full border border-gray-200 dark:border-gray-700 dark:bg-gray-800 rounded-lg px-3 py-2 text-sm" />
            </div>
            <div>
              <label className="text-xs font-medium text-gray-500 mb-1 block">Return Time</label>
              <input type="time" value={form.returnTime} onChange={(e) => set({ returnTime: e.target.value })}
                className="w-full border border-gray-200 dark:border-gray-700 dark:bg-gray-800 rounded-lg px-3 py-2 text-sm" />
            </div>
          </div>
        )}

        {/* Fare mode: App Suggested vs Enter Your Own (same as mobile) */}
        <div>
          <label className="text-xs font-medium text-gray-500 mb-1 block">Fare</label>
          <div className="grid grid-cols-2 gap-2">
            <button type="button"
              onClick={() => set({ useCustomFare: false })}
              className={`py-2 rounded-lg text-sm font-medium border ${!form.useCustomFare ? 'bg-orange-500 text-white border-orange-500' : 'border-gray-200 dark:border-gray-700 text-gray-600 dark:text-gray-300'}`}>
              App Suggested
            </button>
            <button type="button"
              onClick={() => set({ useCustomFare: true, fare: form.fare || String(suggestedFare) })}
              className={`py-2 rounded-lg text-sm font-medium border ${form.useCustomFare ? 'bg-orange-500 text-white border-orange-500' : 'border-gray-200 dark:border-gray-700 text-gray-600 dark:text-gray-300'}`}>
              Enter Your Own
            </button>
          </div>
        </div>

        {!form.useCustomFare ? (
          <div className="bg-orange-50 dark:bg-orange-900/10 rounded-lg px-4 py-3">
            <div className="flex items-center justify-between">
              <span className="text-sm font-medium text-gray-700 dark:text-gray-200">App Suggested Fare</span>
              <span className="text-lg font-bold text-orange-600">₹{suggestedFare}</span>
            </div>
            <p className="text-xs text-gray-400 mt-0.5">
              {distanceKm > 0 ? <>Rate ₹{rateFor(form.vehicleType)}/km × {distanceKm.toFixed(1)} km · no commission</> : 'No route distance stored — switch to “Enter Your Own”.'}
            </p>
          </div>
        ) : (
          <>
            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="text-xs font-medium text-gray-500 mb-1 block">Driver Fare (₹)</label>
                <input type="number" value={form.fare} onChange={(e) => set({ fare: e.target.value })}
                  className="w-full border border-gray-200 dark:border-gray-700 dark:bg-gray-800 rounded-lg px-3 py-2 text-sm" />
              </div>
              <div>
                <label className="text-xs font-medium text-gray-500 mb-1 block">Commission (₹)</label>
                <input type="number" value={form.commission} onChange={(e) => set({ commission: e.target.value })}
                  className="w-full border border-gray-200 dark:border-gray-700 dark:bg-gray-800 rounded-lg px-3 py-2 text-sm" />
              </div>
            </div>
            <p className="text-xs text-gray-400">Total Amount: ₹{effFare + effCommission}</p>
          </>
        )}

        {/* Notes */}
        <div>
          <label className="text-xs font-medium text-gray-500 mb-1 block">Notes</label>
          <textarea value={form.notes} onChange={(e) => set({ notes: e.target.value })} rows={2}
            className="w-full border border-gray-200 dark:border-gray-700 dark:bg-gray-800 rounded-lg px-3 py-2 text-sm" />
        </div>
      </div>

      <div className="flex justify-end gap-2 px-5 py-4 border-t border-gray-200 dark:border-gray-700 sticky bottom-0 bg-white dark:bg-gray-900">
        <Button variant="outline" onClick={onClose}>Cancel</Button>
        <Button onClick={() => mutation.mutate()} isLoading={mutation.isPending}>Save Changes</Button>
      </div>
    </Shell>
  );
}

function Shell({ title, bookingId, onClose, children }: { title: string; bookingId: string; onClose: () => void; children: React.ReactNode }) {
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4" onClick={onClose}>
      <div className="w-full max-w-lg bg-white dark:bg-gray-900 rounded-2xl shadow-xl border border-gray-200 dark:border-gray-700 max-h-[92vh] overflow-y-auto" onClick={(e) => e.stopPropagation()}>
        <div className="flex items-center justify-between px-5 py-4 border-b border-gray-200 dark:border-gray-700 sticky top-0 bg-white dark:bg-gray-900 z-10">
          <h2 className="font-bold text-lg text-gray-900 dark:text-white">
            {title} <span className="font-mono text-xs text-gray-400">{bookingId}</span>
          </h2>
          <button onClick={onClose} className="text-gray-400 hover:text-gray-600"><X className="w-5 h-5" /></button>
        </div>
        {children}
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

function SelectField({ label, value, onChange, options }: { label: string; value: string; onChange: (v: string) => void; options: { value: string; label: string }[] }) {
  return (
    <div>
      <label className="text-xs font-medium text-gray-500 mb-1 block">{label}</label>
      <select value={value} onChange={(e) => onChange(e.target.value)}
        className="w-full border border-gray-200 dark:border-gray-700 dark:bg-gray-800 rounded-lg px-3 py-2 text-sm capitalize">
        {options.map((o) => <option key={o.value} value={o.value}>{o.label}</option>)}
      </select>
    </div>
  );
}
