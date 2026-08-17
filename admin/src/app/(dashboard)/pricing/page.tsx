'use client';

import { useEffect, useState } from 'react';
import { DollarSign } from 'lucide-react';
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

export default function PricingPage() {
  const [vehiclePrices, setVehiclePrices] = useState<Record<string, number>>(DEFAULT_PRICES);
  const [appSuggestedFare, setAppSuggestedFare] = useState(true);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [saved, setSaved] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    adminApi.getSettings()
      .then((data: any) => {
        const s = data?.data ?? data;
        setVehiclePrices({ ...DEFAULT_PRICES, ...(s.vehiclePrices ?? {}) });
        setAppSuggestedFare(s.appSuggestedFareEnabled !== false);
      })
      .catch(() => setError('Failed to load pricing'))
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
      await adminApi.updateSettings({ vehiclePrices, appSuggestedFareEnabled: appSuggestedFare });
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
    <div className="space-y-4">
      <div className="flex items-center gap-2">
        <DollarSign className="w-6 h-6 text-orange-500" />
        <div>
          <h1 className="text-2xl font-bold text-gray-900 dark:text-white">Pricing Config</h1>
          <p className="text-sm text-gray-500">Set per-KM fare for each vehicle type used in the mobile app.</p>
        </div>
      </div>

      <div className="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-700 p-6">
        {loading ? (
          <div className="flex items-center gap-2 text-gray-400 text-sm py-6">
            <div className="w-4 h-4 border-2 border-gray-300 border-t-orange-500 rounded-full animate-spin" />
            Loading...
          </div>
        ) : (
          <div className="space-y-5">
            {/* App Suggested Fare toggle */}
            <div className="flex items-center justify-between gap-4 rounded-lg border border-gray-200 dark:border-gray-700 px-4 py-3">
              <div>
                <p className="text-sm font-semibold text-gray-900 dark:text-white">Show &quot;App Suggested Fare&quot; in the app</p>
                <p className="text-xs text-gray-500">When off, booking cards hide the suggested fare — a fare shows only if the poster entered a manual driver-earning + commission.</p>
              </div>
              <button
                type="button"
                onClick={() => { setAppSuggestedFare((v) => !v); setSaved(false); }}
                className={`relative inline-flex h-6 w-11 shrink-0 items-center rounded-full transition-colors ${appSuggestedFare ? 'bg-orange-500' : 'bg-gray-300 dark:bg-gray-600'}`}
                aria-pressed={appSuggestedFare}
              >
                <span className={`inline-block h-5 w-5 transform rounded-full bg-white transition-transform ${appSuggestedFare ? 'translate-x-5' : 'translate-x-0.5'}`} />
              </button>
            </div>

            <div className="grid grid-cols-2 gap-4">
              {[0, 1].map((col) => (
                <div key={col} className="rounded-lg border border-gray-200 dark:border-gray-700 overflow-hidden">
                  <table className="w-full text-sm">
                    <thead className="bg-gray-50 dark:bg-gray-800 text-gray-500">
                      <tr>
                        <th className="px-4 py-2.5 text-left font-medium">Vehicle</th>
                        <th className="px-4 py-2.5 text-right font-medium w-36">₹ / KM</th>
                      </tr>
                    </thead>
                    <tbody>
                      {VEHICLE_TYPES.filter((_, i) => i % 2 === col).map((v, i) => (
                        <tr key={v.value} className={i % 2 === 0 ? 'bg-white dark:bg-gray-900' : 'bg-gray-50 dark:bg-gray-800'}>
                          <td className="px-4 py-2 text-gray-800 dark:text-gray-200">{v.label}</td>
                          <td className="px-4 py-2">
                            <div className="relative flex justify-end">
                              <span className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400 text-xs">₹</span>
                              <input
                                type="number"
                                min={1}
                                step={0.5}
                                value={vehiclePrices[v.value] ?? ''}
                                onChange={(e) => setPrice(v.value, e.target.value)}
                                className="w-28 pl-6 pr-2 py-1.5 border border-gray-200 dark:border-gray-700 dark:bg-gray-800 rounded-lg text-sm text-right focus:outline-none focus:ring-2 focus:ring-orange-500"
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

            {error && (
              <div className="text-red-600 text-sm bg-red-50 border border-red-200 rounded-lg px-4 py-2">
                {error}
              </div>
            )}

            <button
              onClick={handleSave}
              disabled={saving}
              className="w-full py-2.5 bg-orange-500 hover:bg-orange-600 disabled:opacity-60 text-white font-semibold rounded-lg text-sm transition-colors flex items-center justify-center gap-2"
            >
              {saving ? (
                <><div className="w-4 h-4 border-2 border-white/40 border-t-white rounded-full animate-spin" />Saving...</>
              ) : saved ? '✓ Saved!' : 'Save Pricing'}
            </button>
          </div>
        )}
      </div>
    </div>
  );
}
