'use client';

import { useState } from 'react';
import { useMutation } from '@tanstack/react-query';
import { adminApi } from '@/lib/api';
import { Button } from '@/components/ui/Button';
import { Input } from '@/components/ui/Input';
import { X } from 'lucide-react';
import toast from 'react-hot-toast';

/**
 * Add a vehicle or a driver straight into a member's garage.
 *
 * The same fields the member fills in the app, minus the photos — an admin
 * adding on someone's behalf has the paperwork in front of them, not on their
 * phone, and the member can attach images later from My Garage.
 *
 * Every rule the app enforces still applies: the server refuses a registration
 * number, phone, Aadhaar or licence number that already exists in anyone's
 * garage, and it reports which it was. Those come back as plain messages, so
 * they are shown as-is rather than reworded here.
 */
export function AddGarageEntryModal({
  userId,
  kind,
  onClose,
  onSaved,
}: {
  userId: string;
  kind: 'vehicle' | 'driver';
  onClose: () => void;
  onSaved: () => void;
}) {
  const isVehicle = kind === 'vehicle';

  const [vehicle, setVehicle] = useState({
    vehicleType: '',
    modelName: '',
    registrationNumber: '',
    fuelType: '',
    seatingCapacity: '',
    color: '',
    notes: '',
  });
  const [driver, setDriver] = useState({
    fullName: '',
    phone: '',
    dlNumber: '',
    aadharNumber: '',
    address: '',
    notes: '',
  });

  // Only send what was filled in: the DTO treats every optional field as
  // absent-or-valid, and empty strings would be stored as empty values.
  const payload = () => {
    if (isVehicle) {
      const v = vehicle;
      return {
        vehicleType: v.vehicleType.trim(),
        ...(v.modelName.trim() ? { modelName: v.modelName.trim() } : {}),
        ...(v.registrationNumber.trim() ? { registrationNumber: v.registrationNumber.trim().toUpperCase() } : {}),
        ...(v.fuelType.trim() ? { fuelType: v.fuelType.trim() } : {}),
        ...(v.seatingCapacity.trim() ? { seatingCapacity: Number(v.seatingCapacity) } : {}),
        ...(v.color.trim() ? { color: v.color.trim() } : {}),
        ...(v.notes.trim() ? { notes: v.notes.trim() } : {}),
      };
    }
    const d = driver;
    return {
      fullName: d.fullName.trim(),
      ...(d.phone.trim() ? { phone: d.phone.trim() } : {}),
      ...(d.dlNumber.trim() ? { dlNumber: d.dlNumber.trim().toUpperCase() } : {}),
      ...(d.aadharNumber.trim() ? { aadharNumber: d.aadharNumber.trim() } : {}),
      ...(d.address.trim() ? { address: d.address.trim() } : {}),
      ...(d.notes.trim() ? { notes: d.notes.trim() } : {}),
    };
  };

  const canSave = isVehicle ? vehicle.vehicleType.trim().length > 0 : driver.fullName.trim().length > 0;

  const mutation = useMutation({
    mutationFn: () =>
      isVehicle
        ? adminApi.addUserGarageVehicle(userId, payload())
        : adminApi.addUserGarageDriver(userId, payload()),
    onSuccess: () => {
      toast.success(isVehicle ? 'Vehicle added to the garage' : 'Driver added to the garage');
      onSaved();
    },
    // The duplicate rules answer with a sentence worth reading ("already
    // registered in another account…"), so surface it rather than a generic one.
    onError: (e: any) => toast.error(e?.message || `Could not add the ${kind}`),
  });

  const field = (
    label: string,
    value: string,
    onChange: (v: string) => void,
    opts: { placeholder?: string; mono?: boolean; required?: boolean } = {},
  ) => (
    <div>
      <label className="block text-xs font-medium text-gray-600 dark:text-gray-400 mb-1">
        {label}
        {opts.required && <span className="text-red-500"> *</span>}
      </label>
      <Input
        value={value}
        onChange={(e) => onChange(e.target.value)}
        placeholder={opts.placeholder}
        className={opts.mono ? 'font-mono' : undefined}
      />
    </div>
  );

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4" onClick={onClose}>
      <div
        className="w-full max-w-xl bg-white dark:bg-gray-900 rounded-2xl shadow-xl border border-gray-200 dark:border-gray-700 max-h-[90vh] overflow-y-auto"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex items-center justify-between px-5 py-4 border-b border-gray-200 dark:border-gray-700">
          <div>
            <h2 className="font-bold text-lg text-gray-900 dark:text-white">
              {isVehicle ? 'Add Vehicle' : 'Add Driver'}
            </h2>
            <p className="text-xs text-gray-500">
              Added straight to this member&apos;s garage and approved — no separate review needed.
            </p>
          </div>
          <button onClick={onClose} className="text-gray-400 hover:text-gray-600">
            <X className="w-5 h-5" />
          </button>
        </div>

        <div className="p-5 space-y-4">
          {isVehicle ? (
            <>
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                {field('Vehicle Type', vehicle.vehicleType, (v) => setVehicle({ ...vehicle, vehicleType: v }), {
                  placeholder: 'e.g. sedan',
                  required: true,
                })}
                {field('Model Name', vehicle.modelName, (v) => setVehicle({ ...vehicle, modelName: v }), {
                  placeholder: 'e.g. Toyota Innova Crysta 2022',
                })}
                {field(
                  'Registration Number',
                  vehicle.registrationNumber,
                  (v) => setVehicle({ ...vehicle, registrationNumber: v }),
                  { placeholder: 'e.g. GJ01AB1234', mono: true },
                )}
                {field('Fuel Type', vehicle.fuelType, (v) => setVehicle({ ...vehicle, fuelType: v }), {
                  placeholder: 'e.g. diesel',
                })}
                {field(
                  'Seating Capacity',
                  vehicle.seatingCapacity,
                  (v) => setVehicle({ ...vehicle, seatingCapacity: v.replace(/\D/g, '') }),
                  { placeholder: 'e.g. 7' },
                )}
                {field('Colour', vehicle.color, (v) => setVehicle({ ...vehicle, color: v }), {
                  placeholder: 'e.g. White',
                })}
              </div>
              {field('Notes', vehicle.notes, (v) => setVehicle({ ...vehicle, notes: v }))}
            </>
          ) : (
            <>
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                {field('Full Name', driver.fullName, (v) => setDriver({ ...driver, fullName: v }), {
                  placeholder: 'e.g. Suresh Kumar',
                  required: true,
                })}
                {field('Phone', driver.phone, (v) => setDriver({ ...driver, phone: v.replace(/\D/g, '').slice(0, 10) }), {
                  placeholder: 'e.g. 9876543210',
                  mono: true,
                })}
                {field('Licence Number', driver.dlNumber, (v) => setDriver({ ...driver, dlNumber: v }), {
                  placeholder: 'e.g. GJ0120210001234',
                  mono: true,
                })}
                {field(
                  'Aadhaar Number',
                  driver.aadharNumber,
                  (v) => setDriver({ ...driver, aadharNumber: v.replace(/\D/g, '').slice(0, 12) }),
                  { placeholder: 'e.g. 123456789012', mono: true },
                )}
              </div>
              {field('Address', driver.address, (v) => setDriver({ ...driver, address: v }))}
              {field('Notes', driver.notes, (v) => setDriver({ ...driver, notes: v }))}
            </>
          )}

          <p className="text-xs text-gray-500">
            Photos are not collected here — the member can add them from My Garage in the app.
          </p>
        </div>

        <div className="flex justify-end gap-3 px-5 py-4 border-t border-gray-200 dark:border-gray-700">
          <Button variant="outline" onClick={onClose}>
            Cancel
          </Button>
          <Button onClick={() => mutation.mutate()} disabled={!canSave || mutation.isPending}>
            {mutation.isPending ? 'Adding…' : isVehicle ? 'Add Vehicle' : 'Add Driver'}
          </Button>
        </div>
      </div>
    </div>
  );
}
