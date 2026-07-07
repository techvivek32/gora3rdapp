'use client';

import { useEffect, useState } from 'react';
import { adminApi } from '@/lib/api';

const VEHICLE_TYPES = [
  { value: 'hatchback',       label: 'Hatchback Car' },
  { value: 'eeco',            label: 'Ecco Car' },
  { value: 'sedan',           label: 'Sedan Car' },
  { value: 'ertiga',          label: 'SUV Ertiga Car' },
  { value: 'rumion',          label: 'Toyota Rumion' },
  { value: 'carens',          label: 'Kia Carens' },
  { value: 'innova',          label: 'SUV Innova Car' },
  { value: 'crysta',          label: 'SUV Crysta Car' },
  { value: 'hycross',         label: 'Toyota Hycross' },
  { value: 'tempo_traveller', label: 'Tempo Traveller' },
  { value: 'urbania',         label: 'Force Urbania' },
  { value: 'trax_cruiser',    label: 'Force Trax Cruiser' },
  { value: 'small_coach',     label: 'Small Coach' },
  { value: 'luxury_coach',    label: 'Luxury Coach' },
  { value: 'premium',         label: 'Premium Car' },
];

const DEFAULT_PRICES: Record<string, number> = {
  hatchback: 12, eeco: 13, sedan: 15, ertiga: 18, rumion: 18, carens: 18,
  innova: 20, crysta: 22, hycross: 24, tempo_traveller: 28, urbania: 30,
  trax_cruiser: 28, small_coach: 35, luxury_coach: 45, premium: 25,
};

export default function SettingsPage() {
  const [vehiclePrices, setVehiclePrices] = useState<Record<string, number>>(DEFAULT_PRICES);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [saved, setSaved] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    adminApi.getSettings()
      .then((data: any) => {
        const s = data?.data ?? data;
        setVehiclePrices({ ...DEFAULT_PRICES, ...(s.vehiclePrices ?? {}) });
      })
      .catch(() => setError('Failed to load settings'))
      .finally(() => setLoading(false));
  }, []);

  const handleSave = async () => {
    for (const v of VEHICLE_TYPES) {
      if (!vehiclePrices[v.value] || vehiclePrices[v.value] < 1)
        return setError(`Price for ${v.label} must be at least ₹1`);
    }
    setError('');
    setSaving(true);
    try {
      await adminApi.updateSettings({ vehiclePrices });
      setSaved(true);
      setTimeout(() => setSaved(false), 3000);
    } catch (e: any) {
      setError(e.message || 'Failed to save');
    } finally {
      setSaving(false);
    }
  };

  const setPrice = (vehicle: string, val: string) => {
    setSaved(false);
    setVehiclePrices((prev) => ({ ...prev, [vehicle]: val === '' ? 0 : Number(val) }));
  };

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-gray-900">Settings</h1>
        <p className="text-gray-500 mt-1">Platform pricing configuration</p>
      </div>

      {/* Pricing Configuration */}
      <div className="bg-white rounded-xl border border-gray-200 p-6">
        <h2 className="font-semibold text-gray-900 mb-1">Pricing Configuration</h2>
        <p className="text-gray-500 text-sm mb-5">
          Set the price per KM for each vehicle type. The mobile app uses these rates to calculate the suggested fare when a user creates a requirement.
        </p>

        {loading ? (
          <div className="flex items-center gap-2 text-gray-400 text-sm py-4">
            <div className="w-4 h-4 border-2 border-gray-300 border-t-brand-600 rounded-full animate-spin" />
            Loading current settings...
          </div>
        ) : (
          <div className="space-y-5">
            {/* Per-vehicle price table — 2 columns */}
            <div>
              <p className="text-sm font-medium text-gray-700 mb-3">Price per KM (₹) — by Vehicle Type</p>
              <div className="grid grid-cols-2 gap-4">
                {[0, 1].map((col) => (
                  <div key={col} className="rounded-lg border border-gray-200 overflow-hidden">
                    <table className="w-full text-sm">
                      <thead className="bg-gray-50 text-gray-500">
                        <tr>
                          <th className="px-4 py-2.5 text-left font-medium">Vehicle</th>
                          <th className="px-4 py-2.5 text-right font-medium w-36">₹ / KM</th>
                        </tr>
                      </thead>
                      <tbody>
                        {VEHICLE_TYPES.filter((_, i) => i % 2 === col).map((v, i) => (
                          <tr key={v.value} className={i % 2 === 0 ? 'bg-white' : 'bg-gray-50'}>
                            <td className="px-4 py-2 text-gray-800">{v.label}</td>
                            <td className="px-4 py-2">
                              <div className="relative flex justify-end">
                                <span className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400 text-xs">₹</span>
                                <input
                                  type="number"
                                  min={1}
                                  step={0.5}
                                  value={vehiclePrices[v.value] ?? ''}
                                  onChange={(e) => setPrice(v.value, e.target.value)}
                                  className="w-28 pl-6 pr-2 py-1.5 border border-gray-200 rounded-lg text-sm text-right focus:outline-none focus:ring-2 focus:ring-brand-500"
                                />
                              </div>
                            </td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                ))}
              </div>
            </div>

            {error && (
              <div className="text-red-600 text-sm bg-red-50 border border-red-200 rounded-lg px-4 py-2">
                {error}
              </div>
            )}

            <button
              onClick={handleSave}
              disabled={saving}
              className="w-full py-2.5 bg-brand-600 hover:bg-brand-700 disabled:opacity-60 text-white font-semibold rounded-lg text-sm transition-colors flex items-center justify-center gap-2"
            >
              {saving ? (
                <>
                  <div className="w-4 h-4 border-2 border-white/40 border-t-white rounded-full animate-spin" />
                  Saving...
                </>
              ) : saved ? (
                '✓ Saved!'
              ) : (
                'Save Pricing Settings'
              )}
            </button>
          </div>
        )}
      </div>


    </div>
  );
}
