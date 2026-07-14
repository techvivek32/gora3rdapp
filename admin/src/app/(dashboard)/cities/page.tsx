'use client';

import { useMemo, useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { adminApi } from '@/lib/api';
import { Input } from '@/components/ui/Input';
import { MapPin, ClipboardList, UserRound, Users, TrendingUp } from 'lucide-react';

interface CityRow {
  key: string;
  city: string;
  state: string;
  requirements: number;
  drivers: number;
  agencies: number;
  total: number;
}
interface Totals { cities: number; requirements: number; drivers: number; agencies: number; }

type SortKey = 'total' | 'requirements' | 'drivers' | 'agencies';

const SORTS: { key: SortKey; label: string }[] = [
  { key: 'total', label: 'Most Active' },
  { key: 'requirements', label: 'Requirements' },
  { key: 'drivers', label: 'Drivers' },
  { key: 'agencies', label: 'Agencies' },
];

export default function CitiesPage() {
  const [search, setSearch] = useState('');
  const [sortKey, setSortKey] = useState<SortKey>('total');

  const { data, isLoading } = useQuery({
    queryKey: ['city-insights'],
    queryFn: () => adminApi.getCityInsights(),
  });

  const rows: CityRow[] = data?.data?.rows || [];
  const totals: Totals = data?.data?.totals || { cities: 0, requirements: 0, drivers: 0, agencies: 0 };

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase();
    const list = q
      ? rows.filter((r) => r.city.toLowerCase().includes(q) || r.state.toLowerCase().includes(q))
      : rows;
    return [...list].sort((a, b) => b[sortKey] - a[sortKey]);
  }, [rows, search, sortKey]);

  // Largest value of the active metric — drives the relative bar widths.
  const maxVal = Math.max(1, ...filtered.map((r) => r[sortKey]));

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-gray-900 dark:text-white">City Insights</h1>
        <p className="text-gray-500 mt-1">Where the demand and supply is — cities ranked by requirements, available cabs and agencies.</p>
      </div>

      {/* KPI summary */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <StatCard icon={<MapPin className="w-5 h-5" />} label="Active Cities" value={totals.cities} color="text-indigo-600 bg-indigo-50 dark:bg-indigo-900/20" />
        <StatCard icon={<ClipboardList className="w-5 h-5" />} label="Requirements" value={totals.requirements} color="text-orange-600 bg-orange-50 dark:bg-orange-900/20" />
        <StatCard icon={<UserRound className="w-5 h-5" />} label="Drivers" value={totals.drivers} color="text-emerald-600 bg-emerald-50 dark:bg-emerald-900/20" />
        <StatCard icon={<Users className="w-5 h-5" />} label="Agencies" value={totals.agencies} color="text-blue-600 bg-blue-50 dark:bg-blue-900/20" />
      </div>

      {/* Controls */}
      <div className="flex flex-col sm:flex-row sm:items-center gap-3 justify-between">
        <Input
          placeholder="Search city or state…"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          className="max-w-xs"
        />
        <div className="flex flex-wrap gap-1.5">
          {SORTS.map((s) => (
            <button
              key={s.key}
              onClick={() => setSortKey(s.key)}
              className={`px-3 py-1.5 rounded-lg text-sm font-medium border transition-colors ${
                sortKey === s.key
                  ? 'bg-orange-500 text-white border-orange-500'
                  : 'border-gray-200 dark:border-gray-700 text-gray-600 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-800'
              }`}
            >
              {s.label}
            </button>
          ))}
        </div>
      </div>

      {/* Ranked list */}
      {isLoading ? (
        <div className="space-y-2">
          {Array.from({ length: 8 }).map((_, i) => <div key={i} className="h-16 bg-gray-100 dark:bg-gray-800 rounded-xl animate-pulse" />)}
        </div>
      ) : filtered.length === 0 ? (
        <div className="text-center py-16 text-gray-400">
          <TrendingUp className="w-10 h-10 mx-auto mb-2 opacity-40" />
          <p>No city activity yet.</p>
        </div>
      ) : (
        <div className="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-800 overflow-hidden">
          {/* Header row */}
          <div className="hidden md:grid grid-cols-12 gap-2 px-5 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide border-b border-gray-100 dark:border-gray-800">
            <div className="col-span-1">#</div>
            <div className="col-span-4">City</div>
            <div className="col-span-2 text-center">Requirements</div>
            <div className="col-span-2 text-center">Drivers</div>
            <div className="col-span-2 text-center">Agencies</div>
            <div className="col-span-1 text-right">Total</div>
          </div>

          {filtered.map((r, i) => (
            <div key={r.key} className="grid grid-cols-2 md:grid-cols-12 gap-2 items-center px-5 py-3 border-b border-gray-50 dark:border-gray-800/60 last:border-0 hover:bg-gray-50/60 dark:hover:bg-gray-800/40">
              {/* Rank + name */}
              <div className="md:col-span-1 order-1">
                <span className={`inline-flex items-center justify-center w-7 h-7 rounded-full text-xs font-bold ${
                  i < 3 ? 'bg-orange-100 text-orange-700 dark:bg-orange-900/30 dark:text-orange-300' : 'bg-gray-100 text-gray-500 dark:bg-gray-800'
                }`}>{i + 1}</span>
              </div>
              <div className="md:col-span-4 order-2">
                <p className="font-semibold text-gray-900 dark:text-white capitalize leading-tight">{r.city}</p>
                {r.state && <p className="text-xs text-gray-400 capitalize">{r.state}</p>}
                {/* Relative-activity bar (of the selected metric) */}
                <div className="mt-1.5 h-1.5 bg-gray-100 dark:bg-gray-800 rounded-full overflow-hidden max-w-[220px]">
                  <div className="h-full bg-orange-400 rounded-full" style={{ width: `${Math.round((r[sortKey] / maxVal) * 100)}%` }} />
                </div>
              </div>
              <Metric className="md:col-span-2" label="Requirements" value={r.requirements} active={sortKey === 'requirements'} />
              <Metric className="md:col-span-2" label="Drivers" value={r.drivers} active={sortKey === 'drivers'} />
              <Metric className="md:col-span-2" label="Agencies" value={r.agencies} active={sortKey === 'agencies'} />
              <div className="md:col-span-1 order-6 text-right">
                <span className="text-xs text-gray-400 md:hidden">Total </span>
                <span className="font-bold text-gray-900 dark:text-white">{r.total}</span>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

function StatCard({ icon, label, value, color }: { icon: React.ReactNode; label: string; value: number; color: string }) {
  return (
    <div className="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-800 p-4 flex items-center gap-3">
      <div className={`w-10 h-10 rounded-lg flex items-center justify-center ${color}`}>{icon}</div>
      <div>
        <p className="text-2xl font-bold text-gray-900 dark:text-white leading-none">{value.toLocaleString('en-IN')}</p>
        <p className="text-xs text-gray-500 mt-1">{label}</p>
      </div>
    </div>
  );
}

function Metric({ label, value, active, className }: { label: string; value: number; active?: boolean; className?: string }) {
  return (
    <div className={`${className} order-3 flex items-center md:justify-center gap-1.5`}>
      <span className="text-xs text-gray-400 md:hidden">{label}:</span>
      <span className={`font-semibold ${active ? 'text-orange-600' : 'text-gray-700 dark:text-gray-200'}`}>{value}</span>
    </div>
  );
}
