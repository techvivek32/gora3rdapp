'use client';

import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { adminApi } from '@/lib/api';
import { Badge } from '@/components/ui/Badge';
import toast from 'react-hot-toast';
import type { CabCategory } from './CabCategoryForm';

export default function CabCategoriesPage() {
  const router = useRouter();
  const queryClient = useQueryClient();

  const { data, isLoading } = useQuery({
    queryKey: ['cab-categories'],
    queryFn: () => adminApi.getCabCategories(),
  });

  // Interceptor extracts data?.data, so response.data = categoriesArray
  const items: CabCategory[] = Array.isArray((data as any)?.data) ? (data as any).data : [];

  // ── Global cab settings (apply to ALL cabs) ───────────────────────────────────
  const [minBillKm, setMinBillKm] = useState<number>(0);
  const [tollTaxPerKm, setTollTaxPerKm] = useState<number>(0);
  const { data: settingsData } = useQuery({
    queryKey: ['admin-settings-cab'],
    queryFn: () => adminApi.getAdminSettings(),
  });
  useEffect(() => {
    const s = (settingsData as any)?.data;
    if (typeof s?.minBillKm === 'number') setMinBillKm(s.minBillKm);
    if (typeof s?.tollTaxPerKm === 'number') setTollTaxPerKm(s.tollTaxPerKm);
  }, [settingsData]);
  const saveMinKmMutation = useMutation({
    mutationFn: () => adminApi.updateSettings({ minBillKm: Number(minBillKm) || 0, tollTaxPerKm: Number(tollTaxPerKm) || 0 }),
    onSuccess: () => {
      toast.success('Cab settings saved');
      queryClient.invalidateQueries({ queryKey: ['admin-settings-cab'] });
    },
    onError: () => toast.error('Failed to save cab settings'),
  });

  const toggleMutation = useMutation({
    mutationFn: ({ id, isActive }: { id: string; isActive: boolean }) =>
      adminApi.updateCabCategory(id, { isActive }),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['cab-categories'] }),
  });

  const deleteMutation = useMutation({
    mutationFn: (id: string) => adminApi.deleteCabCategory(id),
    onSuccess: () => {
      toast.success('Category deleted');
      queryClient.invalidateQueries({ queryKey: ['cab-categories'] });
    },
    onError: () => toast.error('Failed to delete category'),
  });

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900 dark:text-white">Cab Categories</h1>
          <p className="text-gray-500 mt-1">Manage the vehicle classes shown on the customer app&apos;s Explore Cabs results</p>
        </div>
        <button
          onClick={() => router.push('/cab-categories/new')}
          className="px-4 py-2 rounded-lg text-sm font-semibold bg-brand-600 text-white hover:bg-brand-700 transition-colors"
        >
          + Add Category
        </button>
      </div>

      {/* Global cab settings — apply to every cab */}
      <div className="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-700 p-4 space-y-4">
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Minimum Bill KM (all cabs)</label>
            <input
              type="number"
              min={0}
              placeholder="e.g. 200 (0 = no minimum)"
              value={minBillKm}
              onChange={(e) => setMinBillKm(Number(e.target.value))}
              className="w-full px-3 py-2 border border-gray-300 dark:border-gray-700 dark:bg-gray-800 dark:text-white rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-500"
            />
            <p className="text-xs text-gray-500 mt-1">
              Shorter trips are billed for at least this many km — e.g. min 200 → a 69 km ride is charged as 200 km.
            </p>
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Toll &amp; State Tax estimate (₹/km)</label>
            <input
              type="number"
              min={0}
              step="0.5"
              placeholder="e.g. 1.5 (0 = off)"
              value={tollTaxPerKm}
              onChange={(e) => setTollTaxPerKm(Number(e.target.value))}
              className="w-full px-3 py-2 border border-gray-300 dark:border-gray-700 dark:bg-gray-800 dark:text-white rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-500"
            />
            <p className="text-xs text-gray-500 mt-1">
              Used for the “All Inclusive” fare only when Google has no toll amount for a route (long/inter-state trips + state tax). e.g. 1200 km × ₹1.5 = ₹1800.
            </p>
          </div>
        </div>
        <button
          onClick={() => saveMinKmMutation.mutate()}
          disabled={saveMinKmMutation.isPending}
          className="px-4 py-2 rounded-lg text-sm font-semibold bg-brand-600 text-white hover:bg-brand-700 disabled:opacity-60 transition-colors"
        >
          {saveMinKmMutation.isPending ? 'Saving…' : 'Save'}
        </button>
      </div>

      {/* Categories table */}
      {isLoading ? (
        <div className="space-y-4">
          {Array.from({ length: 3 }).map((_, i) => (
            <div key={i} className="h-16 bg-gray-100 rounded-xl animate-pulse" />
          ))}
        </div>
      ) : items.length === 0 ? (
        <div className="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-700 p-12 text-center">
          <div className="text-4xl mb-3">🚕</div>
          <p className="text-gray-500 font-medium">No categories yet</p>
          <p className="text-gray-400 text-sm mt-1">Add your first cab category to show it in the app</p>
        </div>
      ) : (
        <div className="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-700 overflow-hidden">
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-gray-200 dark:border-gray-700 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">
                  <th className="px-4 py-3">Image</th>
                  <th className="px-4 py-3">Name</th>
                  <th className="px-4 py-3">Class</th>
                  <th className="px-4 py-3">₹ / km</th>
                  <th className="px-4 py-3">Rental</th>
                  <th className="px-4 py-3">Seats</th>
                  <th className="px-4 py-3">Bags</th>
                  <th className="px-4 py-3">Order</th>
                  <th className="px-4 py-3">Active</th>
                  <th className="px-4 py-3 text-right">Actions</th>
                </tr>
              </thead>
              <tbody>
                {items.map((it) => (
                  <tr key={it._id} className="border-b border-gray-100 dark:border-gray-800 last:border-0">
                    <td className="px-4 py-3">
                      <div className="w-16 h-12 rounded-lg overflow-hidden bg-gray-100 dark:bg-gray-800 flex-shrink-0">
                        {it.imageUrl && (
                          // eslint-disable-next-line @next/next/no-img-element
                          <img
                            src={it.imageUrl}
                            alt={it.name}
                            className="w-full h-full object-cover"
                            onError={(e) => { (e.target as HTMLImageElement).style.display = 'none'; }}
                          />
                        )}
                      </div>
                    </td>
                    <td className="px-4 py-3">
                      <div className="font-semibold text-gray-900 dark:text-white">{it.name}</div>
                    </td>
                    <td className="px-4 py-3 text-gray-600 dark:text-gray-300">{it.vehicleClass || '—'}</td>
                    <td className="px-4 py-3 text-gray-600 dark:text-gray-300">₹{it.pricePerKm}</td>
                    <td className="px-4 py-3 text-gray-600 dark:text-gray-300">{it.dailyKmLimit ? `${it.dailyKmLimit} km/day · ₹${it.extraKmPrice || 0}/extra` : '—'}</td>
                    <td className="px-4 py-3 text-gray-600 dark:text-gray-300">{it.seats ? it.seats : '—'}</td>
                    <td className="px-4 py-3 text-gray-600 dark:text-gray-300">{it.bags || '—'}</td>
                    <td className="px-4 py-3 text-gray-600 dark:text-gray-300">{it.order}</td>
                    <td className="px-4 py-3">
                      <button onClick={() => toggleMutation.mutate({ id: it._id, isActive: !it.isActive })}>
                        <Badge variant={it.isActive ? 'success' : 'secondary'}>
                          {it.isActive ? 'Active' : 'Inactive'}
                        </Badge>
                      </button>
                    </td>
                    <td className="px-4 py-3">
                      <div className="flex gap-2 justify-end">
                        <button
                          onClick={() => router.push(`/cab-categories/${it._id}/edit`)}
                          className="px-3 py-1.5 text-xs font-semibold border border-gray-300 dark:border-gray-700 dark:text-gray-200 rounded-lg hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors"
                        >
                          Edit
                        </button>
                        <button
                          onClick={() => { if (confirm('Delete this category?')) deleteMutation.mutate(it._id); }}
                          className="px-3 py-1.5 text-xs font-semibold border border-red-300 text-red-600 rounded-lg hover:bg-red-50 transition-colors"
                        >
                          Delete
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </div>
  );
}
