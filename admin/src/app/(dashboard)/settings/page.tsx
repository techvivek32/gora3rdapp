'use client';

import { useSession } from 'next-auth/react';
import { useEffect, useState } from 'react';
import { Badge } from '@/components/ui/Badge';
import { adminApi } from '@/lib/api';

export default function SettingsPage() {
  const { data: session } = useSession();

  const [pricePerKm, setPricePerKm] = useState<number | ''>('');
  const [commissionPercent, setCommissionPercent] = useState<number | ''>('');
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [saved, setSaved] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    adminApi.getSettings()
      .then((data: any) => {
        const s = data?.data ?? data;
        setPricePerKm(s.pricePerKm ?? 20);
        setCommissionPercent(s.commissionPercent ?? 10);
      })
      .catch(() => setError('Failed to load settings'))
      .finally(() => setLoading(false));
  }, []);

  const handleSave = async () => {
    const pkm = Number(pricePerKm);
    const cp = Number(commissionPercent);
    if (!pkm || pkm < 1) return setError('Price per KM must be at least ₹1');
    if (cp < 0 || cp > 100) return setError('Commission must be between 0 and 100');
    setError('');
    setSaving(true);
    try {
      await adminApi.updateSettings({ pricePerKm: pkm, commissionPercent: cp });
      setSaved(true);
      setTimeout(() => setSaved(false), 3000);
    } catch (e: any) {
      setError(e.message || 'Failed to save');
    } finally {
      setSaving(false);
    }
  };

  const exampleDistance = 100;
  const suggestedFare = Number(pricePerKm || 0) * exampleDistance;
  const commission = suggestedFare * (Number(commissionPercent || 0) / 100);
  const total = suggestedFare + commission;

  return (
    <div className="space-y-6 max-w-2xl">
      <div>
        <h1 className="text-2xl font-bold text-gray-900">Settings</h1>
        <p className="text-gray-500 mt-1">Account and platform configuration</p>
      </div>

      {/* Admin Profile */}
      <div className="bg-white rounded-xl border border-gray-200 p-6">
        <h2 className="font-semibold text-gray-900 mb-4">Admin Profile</h2>
        <div className="flex items-center gap-4">
          <div className="w-16 h-16 bg-brand-100 rounded-full flex items-center justify-center">
            <span className="text-brand-600 font-bold text-2xl">
              {session?.user?.name?.[0]?.toUpperCase() || 'A'}
            </span>
          </div>
          <div>
            <p className="font-semibold text-lg">{session?.user?.name || 'Admin'}</p>
            <p className="text-gray-500">{session?.user?.email}</p>
            <Badge variant="warning" className="mt-1">
              {(session?.user as any)?.role || 'admin'}
            </Badge>
          </div>
        </div>
      </div>

      {/* Pricing Configuration */}
      <div className="bg-white rounded-xl border border-gray-200 p-6">
        <h2 className="font-semibold text-gray-900 mb-1">Pricing Configuration</h2>
        <p className="text-gray-500 text-sm mb-5">
          These values are used in the mobile app to calculate suggested fare and commission on every requirement.
        </p>

        {loading ? (
          <div className="flex items-center gap-2 text-gray-400 text-sm py-4">
            <div className="w-4 h-4 border-2 border-gray-300 border-t-brand-600 rounded-full animate-spin" />
            Loading current settings...
          </div>
        ) : (
          <div className="space-y-5">
            {/* Price per KM */}
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Price per KM (₹)
              </label>
              <div className="relative">
                <span className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-500 font-semibold">₹</span>
                <input
                  type="number"
                  min={1}
                  step={0.5}
                  value={pricePerKm}
                  onChange={(e) => { setPricePerKm(e.target.value === '' ? '' : Number(e.target.value)); setSaved(false); }}
                  className="w-full pl-8 pr-4 py-2.5 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-500 focus:border-brand-500"
                  placeholder="e.g. 15"
                />
              </div>
              <p className="text-xs text-gray-400 mt-1">Fare per kilometre shown to users as the suggested price.</p>
            </div>

            {/* Commission % */}
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Platform Commission (%)
              </label>
              <div className="relative">
                <input
                  type="number"
                  min={0}
                  max={100}
                  step={0.5}
                  value={commissionPercent}
                  onChange={(e) => { setCommissionPercent(e.target.value === '' ? '' : Number(e.target.value)); setSaved(false); }}
                  className="w-full pl-4 pr-10 py-2.5 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-500 focus:border-brand-500"
                  placeholder="e.g. 10"
                />
                <span className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-500 font-semibold">%</span>
              </div>
              <p className="text-xs text-gray-400 mt-1">Added on top of the base fare as the platform fee.</p>
            </div>

            {/* Live preview */}
            {Number(pricePerKm) > 0 && (
              <div className="bg-gray-50 border border-gray-200 rounded-lg p-4">
                <p className="text-xs font-semibold text-gray-500 uppercase tracking-wide mb-3">
                  Preview — 100 KM trip
                </p>
                <div className="space-y-2 text-sm">
                  <div className="flex justify-between">
                    <span className="text-gray-600">Base Fare (100 km × ₹{pricePerKm}/km)</span>
                    <span className="font-medium">₹{suggestedFare.toFixed(0)}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-gray-600">Commission ({commissionPercent}%)</span>
                    <span className="font-medium">₹{commission.toFixed(0)}</span>
                  </div>
                  <div className="flex justify-between pt-2 border-t border-gray-200 font-semibold">
                    <span>Total</span>
                    <span className="text-brand-600">₹{total.toFixed(0)}</span>
                  </div>
                </div>
              </div>
            )}

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

      {/* Platform Info */}
      <div className="bg-white rounded-xl border border-gray-200 p-6">
        <h2 className="font-semibold text-gray-900 mb-4">Platform Info</h2>
        <dl className="space-y-3">
          {[
            { label: 'Platform Name', value: 'Gora Cabs Admin' },
            { label: 'API Version', value: 'v1' },
            { label: 'Build', value: 'Production' },
          ].map(({ label, value }) => (
            <div key={label} className="flex justify-between py-2 border-b border-gray-100 last:border-0">
              <dt className="text-gray-500 text-sm">{label}</dt>
              <dd className="font-medium text-sm">{value}</dd>
            </div>
          ))}
        </dl>
      </div>

      <div className="bg-amber-50 border border-amber-200 rounded-xl p-5">
        <h3 className="font-semibold text-amber-800">Environment Variables Required</h3>
        <p className="text-amber-700 text-sm mt-1">
          Configure <code className="bg-amber-100 px-1 rounded">.env.local</code> with{' '}
          <code className="bg-amber-100 px-1 rounded">NEXTAUTH_SECRET</code>,{' '}
          <code className="bg-amber-100 px-1 rounded">NEXT_PUBLIC_API_URL</code>, and{' '}
          <code className="bg-amber-100 px-1 rounded">NEXTAUTH_URL</code> before deploying.
        </p>
      </div>
    </div>
  );
}
