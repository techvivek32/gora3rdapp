'use client';

import { useState } from 'react';
import Link from 'next/link';
import { useQuery } from '@tanstack/react-query';
import { adminApi } from '@/lib/api';
import { Building2, Plus } from 'lucide-react';
import { PeriodFilter, type PeriodRange } from '@/components/ui/PeriodFilter';
import { FranchiseFormModal, type Franchise } from '@/components/franchises/FranchiseFormModal';

const inputCls =
  'w-full border border-gray-200 dark:border-gray-700 dark:bg-gray-800 dark:text-white rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-orange-500';

export default function FranchisesPage() {
  // Add opens the create form; editing/deleting live on the detail page.
  const [creating, setCreating] = useState(false);
  const [search, setSearch] = useState('');
  const [range, setRange] = useState<PeriodRange>({});

  const { data: raw, isLoading } = useQuery({
    queryKey: ['franchises', search, range.dateFrom, range.dateTo],
    queryFn: () => adminApi.getFranchises({ search: search || undefined, dateFrom: range.dateFrom, dateTo: range.dateTo }),
  });
  const franchises: Franchise[] = Array.isArray((raw as any)?.data) ? (raw as any).data : [];

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <Building2 className="w-6 h-6 text-orange-500" />
          <div>
            <h1 className="text-2xl font-bold text-gray-900 dark:text-white">Franchises</h1>
            <p className="text-sm text-gray-500">Create &amp; manage franchise accounts, commission and payout details.</p>
          </div>
        </div>
        <div className="flex items-center gap-2">
          <PeriodFilter onChange={setRange} />
          <button onClick={() => setCreating(true)} className="inline-flex items-center gap-1.5 px-4 py-2 rounded-lg bg-orange-500 hover:bg-orange-600 text-white text-sm font-semibold">
            <Plus className="w-4 h-4" /> Add Franchise
          </button>
        </div>
      </div>

      <input className={`${inputCls} max-w-sm`} placeholder="Search name / phone / email / city…" value={search} onChange={(e) => setSearch(e.target.value)} />

      <div className="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-700 overflow-x-auto">
        {isLoading ? (
          <p className="p-6 text-sm text-gray-500">Loading…</p>
        ) : franchises.length === 0 ? (
          <p className="p-6 text-sm text-gray-500">No franchises yet.</p>
        ) : (
          <table className="w-full text-sm">
            <thead>
              <tr className="text-left text-xs uppercase tracking-wide text-gray-500 border-b border-gray-200 dark:border-gray-700">
                <th className="px-4 py-3 font-medium">Name</th>
                <th className="px-4 py-3 font-medium">Phone</th>
                <th className="px-4 py-3 font-medium">City</th>
                <th className="px-4 py-3 font-medium">Agency</th>
                <th className="px-4 py-3 font-medium text-right">Commission</th>
                <th className="px-4 py-3 font-medium">Payouts</th>
                <th className="px-4 py-3 font-medium">Status</th>
                <th className="px-4 py-3 font-medium text-right">Actions</th>
              </tr>
            </thead>
            <tbody>
              {franchises.map((f) => (
                <tr key={f._id} className="border-b border-gray-100 dark:border-gray-800 last:border-0">
                  <td className="px-4 py-3 font-medium text-gray-900 dark:text-white">{f.name}</td>
                  <td className="px-4 py-3 font-mono text-xs text-gray-600 dark:text-gray-400">{f.phone}</td>
                  <td className="px-4 py-3 text-gray-600 dark:text-gray-400">
                    {(() => {
                      const cities: string[] = (f as any).cities?.length ? (f as any).cities : (f.city ? [f.city] : []);
                      const states: string[] = (f as any).states || [];
                      const parts = [...cities, ...states.map((s) => `${s} (whole state)`)];
                      return parts.length ? parts.join(', ') : '—';
                    })()}
                  </td>
                  <td className="px-4 py-3 text-gray-600 dark:text-gray-400">{f.agencyName || '—'}</td>
                  <td className="px-4 py-3 text-right text-gray-900 dark:text-white">{f.commissionPercent ?? 0}%</td>
                  <td className="px-4 py-3 text-gray-500">{f.payoutAccounts?.length ?? 0}</td>
                  <td className="px-4 py-3">
                    <span className={`text-xs px-2 py-0.5 rounded-full font-medium ${f.isActive ? 'bg-emerald-500/15 text-emerald-500' : 'bg-gray-400/15 text-gray-500'}`}>
                      {f.isActive ? 'Active' : 'Inactive'}
                    </span>
                  </td>
                  <td className="px-4 py-3 text-right whitespace-nowrap">
                    <Link href={`/franchises/${f._id}`} className="text-blue-600 hover:underline font-medium">View</Link>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>

      {creating && (
        <FranchiseFormModal
          onClose={() => setCreating(false)}
          onSaved={() => setCreating(false)}
        />
      )}
    </div>
  );
}
