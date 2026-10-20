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
  const [gstPercent, setGstPercent] = useState<number>(0);
  const [driverHirePerDay, setDriverHirePerDay] = useState<number>(0);
  const [driverHireKmPerDay, setDriverHireKmPerDay] = useState<number>(0);
  const [driverHireExtraKmPrice, setDriverHireExtraKmPrice] = useState<number>(0);
  const [driverHireFoodPerDay, setDriverHireFoodPerDay] = useState<number>(0);
  const [driverHireReturnByCustomer, setDriverHireReturnByCustomer] = useState<boolean>(true);
  const [platformCommissionPercent, setPlatformCommissionPercent] = useState<number>(0);
  const { data: settingsData } = useQuery({
    queryKey: ['admin-settings-cab'],
    queryFn: () => adminApi.getAdminSettings(),
  });
  useEffect(() => {
    const s = (settingsData as any)?.data;
    if (typeof s?.minBillKm === 'number') setMinBillKm(s.minBillKm);
    if (Array.isArray(s?.localPackageKm)) setLocalPackageKm(s.localPackageKm);
    if (typeof s?.tollTaxPerKm === 'number') setTollTaxPerKm(s.tollTaxPerKm);
    if (typeof s?.gstPercent === 'number') setGstPercent(s.gstPercent);
    if (typeof s?.driverHirePerDay === 'number') setDriverHirePerDay(s.driverHirePerDay);
    if (typeof s?.driverHireKmPerDay === 'number') setDriverHireKmPerDay(s.driverHireKmPerDay);
    if (typeof s?.driverHireExtraKmPrice === 'number') setDriverHireExtraKmPrice(s.driverHireExtraKmPrice);
    if (typeof s?.driverHireFoodPerDay === 'number') setDriverHireFoodPerDay(s.driverHireFoodPerDay);
    if (typeof s?.driverHireReturnByCustomer === 'boolean') setDriverHireReturnByCustomer(s.driverHireReturnByCustomer);
    if (typeof s?.platformCommissionPercent === 'number') setPlatformCommissionPercent(s.platformCommissionPercent);
  }, [settingsData]);
  const saveMinKmMutation = useMutation({
    mutationFn: () => adminApi.updateSettings({ minBillKm: Number(minBillKm) || 0, tollTaxPerKm: Number(tollTaxPerKm) || 0, gstPercent: Number(gstPercent) || 0, driverHirePerDay: Number(driverHirePerDay) || 0, platformCommissionPercent: Number(platformCommissionPercent) || 0, driverHireKmPerDay: Number(driverHireKmPerDay) || 0, driverHireExtraKmPrice: Number(driverHireExtraKmPrice) || 0, driverHireFoodPerDay: Number(driverHireFoodPerDay) || 0, driverHireReturnByCustomer: !!driverHireReturnByCustomer, localPackageKm: LOCAL_HOURS.map((h) => ({ hours: h, km: Number(localPackageKm.find((p) => p.hours === h)?.km) || 0 })).filter((p) => p.km > 0) }),
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

  /** The page does two separate jobs; show one at a time. */
  // Km included in each Local package - the same for every cab, so it is set
  // once here instead of on each one.
  const LOCAL_HOURS = [6, 8, 10, 12];
  const [localPackageKm, setLocalPackageKm] = useState<{ hours: number; km: number }[]>([]);

  const [tab, setTab] = useState<'pricing' | 'cabs'>('pricing');

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900 dark:text-white">Cab Categories</h1>
          <p className="text-gray-500 mt-1">
            {tab === 'pricing'
              ? 'Rates and allowances that apply to every cab'
              : 'The vehicle classes shown on the customer app’s Explore Cabs results'}
          </p>
        </div>
        {tab === 'cabs' && (
          <button
            onClick={() => router.push('/cab-categories/new')}
            className="px-4 py-2 rounded-lg text-sm font-semibold bg-brand-600 text-white hover:bg-brand-700 transition-colors"
          >
            + Add Category
          </button>
        )}
      </div>

      {/* Two modules: the rates, and the cabs themselves. */}
      <div className="flex gap-1 border-b border-gray-200 dark:border-gray-700">
        {([
          { key: 'pricing', label: 'Pricing' },
          { key: 'cabs', label: `Cabs${items.length ? ` (${items.length})` : ''}` },
        ] as const).map((t) => (
          <button
            key={t.key}
            onClick={() => setTab(t.key)}
            className={`px-4 py-2.5 text-sm font-semibold -mb-px border-b-2 transition-colors ${
              tab === t.key
                ? 'border-brand-600 text-brand-600'
                : 'border-transparent text-gray-500 hover:text-gray-700 dark:hover:text-gray-300'
            }`}
          >
            {t.label}
          </button>
        ))}
      </div>

      {/* Module 1 — rates that apply to every cab */}
      {tab === 'pricing' && (
      <div className="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-700 p-4 space-y-4">
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
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
          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">GST (%)</label>
            <input
              type="number"
              min={0}
              max={100}
              step="0.5"
              placeholder="e.g. 5 (0 = no GST)"
              value={gstPercent}
              onChange={(e) => setGstPercent(Number(e.target.value))}
              className="w-full px-3 py-2 border border-gray-300 dark:border-gray-700 dark:bg-gray-800 dark:text-white rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-500"
            />
            <p className="text-xs text-gray-500 mt-1">
              Added to the “All Inclusive” fare for all cabs. e.g. 5% on a ₹1,000 fare → +₹50.
            </p>
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Platform Commission (%)</label>
            <input
              type="number"
              min={0}
              max={100}
              step="0.5"
              placeholder="e.g. 10 (0 = no commission)"
              value={platformCommissionPercent}
              onChange={(e) => setPlatformCommissionPercent(Number(e.target.value))}
              className="w-full px-3 py-2 border border-gray-300 dark:border-gray-700 dark:bg-gray-800 dark:text-white rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-500"
            />
            <p className="text-xs text-gray-500 mt-1">
              Our cut, charged on base fare + driver allowance (never on GST). The driver must hold
              this <strong>plus the booking&apos;s GST</strong> in their wallet to accept a booking, and it is
              deducted when you assign them. e.g. 10% on ₹10,300 ride + ₹560 GST → ₹1,590 taken,
              driver keeps ₹9,270 of a ₹10,860 fare.
            </p>
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Hire a Driver — Per Day (₹)</label>
            <input
              type="number"
              min={0}
              placeholder="e.g. 1200 (0 = not set)"
              value={driverHirePerDay}
              onChange={(e) => setDriverHirePerDay(Number(e.target.value))}
              className="w-full px-3 py-2 border border-gray-300 dark:border-gray-700 dark:bg-gray-800 dark:text-white rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-500"
            />
            <p className="text-xs text-gray-500 mt-1">
              Daily rate for “Hire a Driver”. Total = this × number of days selected. e.g. ₹1200 × 3 days = ₹3600.
            </p>
          </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Hire a Driver &mdash; Km Included Per Day</label>
              <input
                type="number"
                min={0}
                placeholder="e.g. 250 (0 = unlimited)"
                value={driverHireKmPerDay}
                onChange={(e) => setDriverHireKmPerDay(Number(e.target.value))}
                className="w-full px-3 py-2 border border-gray-300 dark:border-gray-700 dark:bg-gray-800 dark:text-white rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-500"
              />
              <p className="text-xs text-gray-500 mt-1">
                Km the driver covers per day before extra-km billing starts. Shown to the customer on
                the booking page. 0 = unlimited (no km cap).
              </p>
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Hire a Driver &mdash; Extra Km Rate (&#8377;/km)</label>
              <input
                type="number"
                min={0}
                placeholder="e.g. 12 (0 = no extra charge)"
                value={driverHireExtraKmPrice}
                onChange={(e) => setDriverHireExtraKmPrice(Number(e.target.value))}
                className="w-full px-3 py-2 border border-gray-300 dark:border-gray-700 dark:bg-gray-800 dark:text-white rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-500"
              />
              <p className="text-xs text-gray-500 mt-1">
                Charged for every km beyond the daily allowance. e.g. 250 km included, drove 300 km
                &rarr; 50 &times; &#8377;12 = &#8377;600 extra.
              </p>
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Hire a Driver &mdash; Food Allowance Per Day (&#8377;)</label>
              <input
                type="number"
                min={0}
                placeholder="e.g. 300 (0 = not charged)"
                value={driverHireFoodPerDay}
                onChange={(e) => setDriverHireFoodPerDay(Number(e.target.value))}
                className="w-full px-3 py-2 border border-gray-300 dark:border-gray-700 dark:bg-gray-800 dark:text-white rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-500"
              />
              <p className="text-xs text-gray-500 mt-1">
                The driver&apos;s food cost per day, paid by the customer. Listed as an extra on the
                booking page so there is no dispute later.
              </p>
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">One Way &mdash; Driver&apos;s Return Ticket</label>
              <label className="flex items-center gap-2 mt-2">
                <input
                  type="checkbox"
                  checked={driverHireReturnByCustomer}
                  onChange={(e) => setDriverHireReturnByCustomer(e.target.checked)}
                  className="h-4 w-4 rounded border-gray-300 text-brand-600 focus:ring-brand-500"
                />
                <span className="text-sm text-gray-700 dark:text-gray-300">Customer pays the driver&apos;s return travel</span>
              </label>
              <p className="text-xs text-gray-500 mt-1">
                On a <strong>One Way</strong> hire the driver still has to get back. When ticked, the
                booking page tells the customer the return train/bus fare is on them, settled directly
                with the driver.
              </p>
            </div>
        </div>
        <div className="pt-2">
          <h3 className="text-sm font-semibold text-gray-900 dark:text-white mb-1">Local (hourly package) — included KM</h3>
          <p className="text-xs text-gray-500 mb-3">
            Km included in each Local package. The same for every cab — only the price differs, and that is set on
            the cab itself under <b>Cabs → Edit → KM &amp; Rental</b>. Leave a row at 0 and that package falls
            back to the cab&apos;s own KM/hour rule.
          </p>
          <div className="rounded-lg border border-gray-200 dark:border-gray-700 overflow-hidden max-w-md">
            <div className="grid grid-cols-2 gap-px bg-gray-200 dark:bg-gray-700 text-xs font-semibold text-gray-600 dark:text-gray-400">
              <div className="bg-white dark:bg-gray-900 px-3 py-2">Package</div>
              <div className="bg-white dark:bg-gray-900 px-3 py-2">Included KM</div>
            </div>
            {LOCAL_HOURS.map((h) => {
              const row = localPackageKm.find((p) => p.hours === h);
              return (
                <div key={h} className="grid grid-cols-2 gap-px bg-gray-200 dark:bg-gray-700">
                  <div className="bg-white dark:bg-gray-900 px-3 py-2 text-sm font-semibold text-gray-900 dark:text-white flex items-center">
                    {h} hrs
                  </div>
                  <div className="bg-white dark:bg-gray-900 px-2 py-1.5">
                    <input
                      type="number" min={0} placeholder="e.g. 60"
                      value={row?.km ?? 0}
                      onChange={(e) => {
                        const rest = localPackageKm.filter((p) => p.hours !== h);
                        setLocalPackageKm([...rest, { hours: h, km: Number(e.target.value) }].sort((a, b) => a.hours - b.hours));
                      }}
                      className="w-full border border-gray-200 dark:border-gray-700 dark:bg-gray-800 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-orange-500 font-mono"
                    />
                  </div>
                </div>
              );
            })}
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
      )}

      {/* Module 2 — the cabs themselves */}
      {tab === 'cabs' && (isLoading ? (
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
      ))}
    </div>
  );
}
