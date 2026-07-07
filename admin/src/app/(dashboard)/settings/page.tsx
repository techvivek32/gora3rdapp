'use client';

import { useEffect, useState } from 'react';
import { Settings } from 'lucide-react';
import { adminApi } from '@/lib/api';

export default function SettingsPage() {
  const [rzKeyId, setRzKeyId] = useState('');
  const [rzKeySecret, setRzKeySecret] = useState('');
  const [showSecret, setShowSecret] = useState(false);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [saved, setSaved] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    adminApi.getSettings()
      .then((data: any) => {
        const s = data?.data ?? data;
        setRzKeyId(s.razorpayKeyId ?? '');
      })
      .catch(() => setError('Failed to load settings'))
      .finally(() => setLoading(false));
  }, []);

  const handleSave = async () => {
    if (!rzKeyId.trim()) return setError('Key ID is required');
    if (!rzKeySecret.trim()) return setError('Key Secret is required');
    setError('');
    setSaving(true);
    try {
      await adminApi.updateSettings({
        razorpayKeyId: rzKeyId.trim(),
        razorpayKeySecret: rzKeySecret.trim(),
      });
      setSaved(true);
      setRzKeySecret('');
      setTimeout(() => setSaved(false), 3000);
    } catch (e: any) {
      setError(e.message || 'Failed to save');
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="space-y-4">
      <div className="flex items-center gap-2">
        <Settings className="w-6 h-6 text-orange-500" />
        <div>
          <h1 className="text-2xl font-bold text-gray-900 dark:text-white">Settings</h1>
          <p className="text-sm text-gray-500">Payment gateway configuration</p>
        </div>
      </div>

      <div className="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-700 p-6 max-w-xl">
        <h2 className="font-semibold text-gray-900 dark:text-white mb-1">Razorpay Configuration</h2>
        <p className="text-gray-500 text-sm mb-5">Payment gateway credentials. Key Secret is cleared after saving for security.</p>

        {loading ? (
          <div className="flex items-center gap-2 text-gray-400 text-sm py-4">
            <div className="w-4 h-4 border-2 border-gray-300 border-t-orange-500 rounded-full animate-spin" />
            Loading...
          </div>
        ) : (
          <div className="space-y-4">
            <div>
              <label className="block text-xs font-medium text-gray-600 dark:text-gray-400 mb-1">Key ID</label>
              <input
                type="text"
                value={rzKeyId}
                onChange={(e) => { setRzKeyId(e.target.value); setSaved(false); }}
                placeholder="rzp_live_xxxxxxxxxxxx"
                className="w-full border border-gray-200 dark:border-gray-700 dark:bg-gray-800 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-orange-500 font-mono"
              />
            </div>
            <div>
              <label className="block text-xs font-medium text-gray-600 dark:text-gray-400 mb-1">Key Secret</label>
              <div className="relative">
                <input
                  type={showSecret ? 'text' : 'password'}
                  value={rzKeySecret}
                  onChange={(e) => { setRzKeySecret(e.target.value); setSaved(false); }}
                  placeholder="Enter secret to update"
                  className="w-full border border-gray-200 dark:border-gray-700 dark:bg-gray-800 rounded-lg px-3 py-2 pr-16 text-sm focus:outline-none focus:ring-2 focus:ring-orange-500 font-mono"
                />
                <button
                  type="button"
                  onClick={() => setShowSecret((v) => !v)}
                  className="absolute right-3 top-1/2 -translate-y-1/2 text-xs text-gray-400 hover:text-gray-600"
                >
                  {showSecret ? 'Hide' : 'Show'}
                </button>
              </div>
            </div>

            {error && (
              <p className="text-red-600 text-xs bg-red-50 border border-red-200 rounded-lg px-3 py-2">{error}</p>
            )}

            <button
              onClick={handleSave}
              disabled={saving}
              className="w-full py-2.5 bg-orange-500 hover:bg-orange-600 disabled:opacity-60 text-white font-semibold rounded-lg text-sm transition-colors flex items-center justify-center gap-2"
            >
              {saving ? (
                <><div className="w-4 h-4 border-2 border-white/40 border-t-white rounded-full animate-spin" />Saving...</>
              ) : saved ? '✓ Saved!' : 'Save Razorpay Keys'}
            </button>
          </div>
        )}
      </div>
    </div>
  );
}
