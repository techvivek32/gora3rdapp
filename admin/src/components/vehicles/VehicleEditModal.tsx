'use client';

import { useState } from 'react';
import { useMutation } from '@tanstack/react-query';
import { adminApi } from '@/lib/api';
import { Button } from '@/components/ui/Button';
import { AddressAutocomplete } from '@/components/ui/AddressAutocomplete';
import { X } from 'lucide-react';
import toast from 'react-hot-toast';
import { VEHICLE_TYPES } from '@/components/requirements/RequirementEditModal';

// Mirror of the mobile create-available-cab trip choices (cabs are one-way or round-trip only).
export const VEHICLE_TRIP_TYPES = ['one_way', 'round_trip'];
// Availability statuses (values match the AvailabilityStatus enum) with friendly labels.
export const VEHICLE_STATUSES = [
  { value: 'available', label: 'Active' },
  { value: 'booked', label: 'Booked' },
  { value: 'on_hold', label: 'Hold' },
  { value: 'cancelled', label: 'Cancelled' },
];
const vehicleStatusLabel = (s: string) =>
  VEHICLE_STATUSES.find((o) => o.value === s)?.label || s.replace(/_/g, ' ');

/** Full available-cab editor — mirrors the mobile "Post Available Cab" page:
 *  city autocomplete for current + destination, vehicle/trip type, available
 *  date/time, plus admin-only reg/driver fields. Shared by the Vehicles page
 *  and the User-detail page. */
export function VehicleEditModal({
  vehicle,
  mode,
  userId,
  onClose,
  onSaved,
}: {
  /** Omitted in 'create' mode. */
  vehicle?: any;
  mode: 'view' | 'edit' | 'create';
  /** Required in 'create' mode — the user the cab is listed for. */
  userId?: string;
  onClose: () => void;
  onSaved: () => void;
}) {
  const isCreate = mode === 'create';
  const v = (vehicle ?? {}) as any;
  const [form, setForm] = useState({
    status: v.status ?? 'available',
    vehicleType: v.vehicleType ?? VEHICLE_TYPES[0]?.value ?? 'sedan',
    tripType: (v.tripType as string) || 'one_way',
    currentCity: v.currentCity || '',
    currentState: (v.currentState as string) || '',
    currentCoordinates: v.currentCoordinates || undefined,
    destinationCity: v.destinationCity || '',
    destinationState: (v.destinationState as string) || '',
    destinationCoordinates: v.destinationCoordinates || undefined,
    availableDate: String(v.availableDate || '').slice(0, 10), // yyyy-mm-dd
    availableTime: (v.availableTime as string) || '',
    notes: v.notes || '',
  });
  // Fields are editable when creating as well as editing — only 'view' is read-only.
  const isEdit = mode === 'edit' || isCreate;
  const set = (patch: Partial<typeof form>) => setForm((f) => ({ ...f, ...patch }));

  const payload = () => ({
    status: form.status,
    vehicleType: form.vehicleType,
    tripType: form.tripType,
    currentCity: form.currentCity,
    currentState: form.currentState || undefined,
    currentCoordinates: form.currentCoordinates,
    destinationCity: form.destinationCity || undefined,
    destinationState: form.destinationState || undefined,
    destinationCoordinates: form.destinationCoordinates,
    availableDate: form.availableDate || undefined,
    availableTime: form.availableTime || undefined,
    notes: form.notes,
  });

  const mutation = useMutation({
    mutationFn: () =>
      isCreate
        ? adminApi.createVehicleFor(userId!, payload())
        : adminApi.updateVehicle(v._id, payload()),
    onSuccess: () => {
      toast.success(isCreate ? 'Available cab added' : 'Vehicle updated');
      onSaved();
    },
    onError: (e: any) => toast.error(e?.message || (isCreate ? 'Could not add cab' : 'Update failed')),
  });

  const canSave = !isCreate || (form.currentCity.trim() && form.availableDate && form.availableTime);

  // ── View mode (read-only) ──────────────────────────────────────────────────
  if (!isEdit) {
    return (
      <Shell title="Vehicle Details" listingId={v.listingId} onClose={onClose}>
        <div className="p-5 space-y-3">
          <Field label="Posted By">{v.postedBy?.fullName} <span className="text-gray-400">({v.postedBy?.membershipType})</span></Field>
          <Field label="Status">{vehicleStatusLabel(form.status)}</Field>
          <Field label="Current City">{[form.currentCity, form.currentState].filter(Boolean).join(', ')}</Field>
          <Field label="Available For">{[form.destinationCity, form.destinationState].filter(Boolean).join(', ') || '—'}</Field>
          <Field label="Vehicle">{v.vehicleType?.replace(/_/g, ' ')} · {form.tripType?.replace(/_/g, ' ')}</Field>
          <Field label="Available">{form.availableDate} {form.availableTime}</Field>
          {form.notes && <Field label="Notes">{form.notes}</Field>}
        </div>
      </Shell>
    );
  }

  // ── Edit mode (full form, like the mobile create page) ─────────────────────
  return (
    <Shell title={isCreate ? 'Add Available Cab' : 'Edit Available Cab'} listingId={v.listingId} onClose={onClose}>
      <div className="p-5 space-y-4">
        {/* Location */}
        <div>
          <label className="text-xs font-medium text-gray-500 mb-1 block">Current City *</label>
          <AddressAutocomplete value={form.currentCity} placeholder="Search current city…"
            onSelect={(p) => set({ currentCity: p.city || p.address, currentState: p.state || form.currentState, currentCoordinates: p.lat != null ? { lat: p.lat, lng: p.lng, address: p.address } : form.currentCoordinates })} />
        </div>
        <div>
          <label className="text-xs font-medium text-gray-500 mb-1 block">Available For (Destination City)</label>
          <AddressAutocomplete value={form.destinationCity} placeholder="Search destination city…"
            onSelect={(p) => set({ destinationCity: p.city || p.address, destinationState: p.state || form.destinationState, destinationCoordinates: p.lat != null ? { lat: p.lat, lng: p.lng, address: p.address } : form.destinationCoordinates })} />
        </div>

        {/* Vehicle / trip / status */}
        <div className="grid grid-cols-2 gap-3">
          <SelectField label="Vehicle Type" value={form.vehicleType} onChange={(v) => set({ vehicleType: v })} options={VEHICLE_TYPES} />
          <SelectField label="Trip Type" value={form.tripType} onChange={(v) => set({ tripType: v })} options={VEHICLE_TRIP_TYPES.map((t) => ({ value: t, label: t.replace(/_/g, ' ') }))} />
          <SelectField label="Status" value={form.status} onChange={(v) => set({ status: v })} options={VEHICLE_STATUSES} />
        </div>

        {/* Availability date & time */}
        <div className="grid grid-cols-2 gap-3">
          <div>
            <label className="text-xs font-medium text-gray-500 mb-1 block">Available Date</label>
            <input type="date" value={form.availableDate} onChange={(e) => set({ availableDate: e.target.value })}
              className="w-full border border-gray-200 dark:border-gray-700 dark:bg-gray-800 rounded-lg px-3 py-2 text-sm" />
          </div>
          <div>
            <label className="text-xs font-medium text-gray-500 mb-1 block">Available Time</label>
            <input type="time" value={form.availableTime} onChange={(e) => set({ availableTime: e.target.value })}
              className="w-full border border-gray-200 dark:border-gray-700 dark:bg-gray-800 rounded-lg px-3 py-2 text-sm" />
          </div>
        </div>

        {/* Notes */}
        <div>
          <label className="text-xs font-medium text-gray-500 mb-1 block">Notes</label>
          <textarea value={form.notes} onChange={(e) => set({ notes: e.target.value })} rows={2}
            className="w-full border border-gray-200 dark:border-gray-700 dark:bg-gray-800 rounded-lg px-3 py-2 text-sm" />
        </div>
      </div>

      <div className="flex justify-end gap-2 px-5 py-4 border-t border-gray-200 dark:border-gray-700 sticky bottom-0 bg-white dark:bg-gray-900">
        <Button variant="outline" onClick={onClose}>Cancel</Button>
        <Button onClick={() => mutation.mutate()} isLoading={mutation.isPending} disabled={!canSave}>
          {isCreate ? 'Add Cab' : 'Save Changes'}
        </Button>
      </div>
    </Shell>
  );
}

function Shell({ title, listingId, onClose, children }: { title: string; listingId: string; onClose: () => void; children: React.ReactNode }) {
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4" onClick={onClose}>
      <div className="w-full max-w-lg bg-white dark:bg-gray-900 rounded-2xl shadow-xl border border-gray-200 dark:border-gray-700 max-h-[92vh] overflow-y-auto" onClick={(e) => e.stopPropagation()}>
        <div className="flex items-center justify-between px-5 py-4 border-b border-gray-200 dark:border-gray-700 sticky top-0 bg-white dark:bg-gray-900 z-10">
          <h2 className="font-bold text-lg text-gray-900 dark:text-white">{title} <span className="font-mono text-xs text-gray-400">{listingId}</span></h2>
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
