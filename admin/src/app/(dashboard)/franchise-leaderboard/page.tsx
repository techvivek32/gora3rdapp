'use client';

import { useMemo, useState } from 'react';
import Link from 'next/link';
import { useQuery } from '@tanstack/react-query';
import { adminApi } from '@/lib/api';
import { PeriodFilter, type PeriodRange } from '@/components/ui/PeriodFilter';
import { Trophy, Building2, Users, FileText, IndianRupee } from 'lucide-react';

interface Row {
  _id: string;
  name: string;
  city: string;
  state: string;
  coverage?: string;
  agencyName: string;
  commissionPercent: number;
  isActive: boolean;
  users: number;
  drivers: number;
  agencies: number;
  requirements: number;
  vehicles: number;
  revenue: number;
}

type SortKey = 'revenue' | 'users' | 'requirements' | 'drivers' | 'agencies' | 'vehicles';

const SORTS: { key: SortKey; label: string }[] = [
  { key: 'revenue', label: 'Revenue' },
  { key: 'users', label: 'Users' },
  { key: 'requirements', label: 'Requirements' },
  { key: 'drivers', label: 'Drivers' },
  { key: 'agencies', label: 'Agencies' },
];

const medalEmoji: Record<number, string> = { 1: '🥇', 2: '🥈', 3: '🥉' };

export default function FranchiseLeaderboardPage() {
  const [search, setSearch] = useState('');
  const [sortKey, setSortKey] = useState<SortKey>('revenue');
  const [range, setRange] = useState<PeriodRange>({});

  const { data: raw, isLoading } = useQuery({
    queryKey: ['franchise-leaderboard', range.dateFrom, range.dateTo],
    queryFn: () => adminApi.getFranchiseLeaderboard({ dateFrom: range.dateFrom, dateTo: range.dateTo }),
  });
  const rows: Row[] = (raw as any)?.data || [];

  const totals = useMemo(
    () =>
      rows.reduce(
        (a, r) => ({
          franchises: a.franchises + 1,
          users: a.users + r.users,
          requirements: a.requirements + r.requirements,
          revenue: a.revenue + r.revenue,
        }),
        { franchises: 0, users: 0, requirements: 0, revenue: 0 },
      ),
    [rows],
  );

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase();
    const list = q
      ? rows.filter(
          (r) =>
            r.name.toLowerCase().includes(q) ||
            r.city.toLowerCase().includes(q) ||
            (r.coverage || '').toLowerCase().includes(q) ||
            r.agencyName.toLowerCase().includes(q),
        )
      : rows;
    return [...list].sort((a, b) => (b[sortKey] as number) - (a[sortKey] as number));
  }, [rows, search, sortKey]);

  const maxVal = Math.max(1, ...filtered.map((r) => r[sortKey] as number));

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between gap-2">
        <div className="flex items-center gap-2">
          <Trophy className="w-6 h-6 text-orange-500" />
          <div>
            <h1 className="text-2xl font-bold text-gray-900 dark:text-white">Franchise Leaderboard</h1>
            <p className="text-sm text-gray-500 dark:text-gray-400 mt-0.5">
              All franchises ranked by their city&apos;s activity — switch the metric to re-rank.
            </p>
          </div>
        </div>
        <PeriodFilter onChange={setRange} />
      </div>

      {/* KPI summary */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <StatCard icon={<Building2 className="w-5 h-5" />} label="Franchises" value={totals.franchises} color="text-indigo-600 bg-indigo-50 dark:bg-indigo-900/20" />
        <StatCard icon={<Users className="w-5 h-5" />} label="Total Users" value={totals.users} color="text-blue-600 bg-blue-50 dark:bg-blue-900/20" />
        <StatCard icon={<FileText className="w-5 h-5" />} label="Requirements" value={totals.requirements} color="text-orange-600 bg-orange-50 dark:bg-orange-900/20" />
        <StatCard icon={<IndianRupee className="w-5 h-5" />} label="Plan Revenue" value={`₹${totals.revenue.toLocaleString('en-IN')}`} color="text-emerald-600 bg-emerald-50 dark:bg-emerald-900/20" />
      </div>

      {/* Controls */}
      <div className="flex flex-col sm:flex-row sm:items-center gap-3 justify-between">
        <input
          placeholder="Search franchise, city or agency…"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          className="w-full max-w-xs border border-gray-200 dark:border-gray-700 dark:bg-gray-800 dark:text-white rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-orange-500"
        />
        <div className="flex flex-wrap gap-1.5">
          <span className="text-xs text-gray-400 self-center mr-1">Rank by:</span>
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

      {/* Table */}
      <div className="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-700 overflow-x-auto">
        {isLoading ? (
          <p className="p-6 text-sm text-gray-500">Loading…</p>
        ) : filtered.length === 0 ? (
          <p className="p-6 text-sm text-gray-500">No franchises yet.</p>
        ) : (
          <table className="w-full text-sm">
            <thead>
              <tr className="text-left text-xs uppercase tracking-wide text-gray-500 border-b border-gray-200 dark:border-gray-700">
                <th className="px-4 py-3 font-medium">#</th>
                <th className="px-4 py-3 font-medium">Franchise</th>
                <th className="px-4 py-3 font-medium text-right">Users</th>
                <th className="px-4 py-3 font-medium text-right">Drivers</th>
                <th className="px-4 py-3 font-medium text-right">Agencies</th>
                <th className="px-4 py-3 font-medium text-right">Requirements</th>
                <th className="px-4 py-3 font-medium text-right">Revenue</th>
              </tr>
            </thead>
            <tbody>
              {filtered.map((r, i) => {
                const rank = i + 1;
                const metric = r[sortKey] as number;
                return (
                  <tr key={r._id} className="border-b border-gray-100 dark:border-gray-800 last:border-0 hover:bg-gray-50 dark:hover:bg-gray-800/50">
                    <td className="px-4 py-3">
                      <span className="inline-flex items-center gap-1.5 font-bold">
                        {rank <= 3 ? <span className="text-lg leading-none">{medalEmoji[rank]}</span> : null}
                        <span className={rank <= 3 ? 'text-orange-500' : 'text-gray-500'}>#{rank}</span>
                      </span>
                    </td>
                    <td className="px-4 py-3">
                      <Link href={`/franchises/${r._id}`} className="group flex items-center gap-3">
                        <div className="w-9 h-9 rounded-full bg-orange-100 dark:bg-orange-900/30 flex items-center justify-center text-orange-600 dark:text-orange-400 font-semibold text-sm shrink-0">
                          {r.name?.[0]?.toUpperCase()}
                        </div>
                        <div className="min-w-0">
                          <div className="font-medium text-gray-900 dark:text-white group-hover:underline truncate">{r.name}</div>
                          <div className="text-xs text-gray-500 dark:text-gray-400 truncate">
                            {r.coverage || r.city || '—'}{r.agencyName ? ` · ${r.agencyName}` : ''}
                          </div>
                          {/* Relative bar for the active metric. */}
                          <div className="mt-1 h-1 w-32 max-w-full rounded bg-gray-100 dark:bg-gray-800 overflow-hidden">
                            <div className="h-full bg-orange-500" style={{ width: `${Math.round((metric / maxVal) * 100)}%` }} />
                          </div>
                        </div>
                      </Link>
                    </td>
                    <Cell value={r.users} active={sortKey === 'users'} />
                    <Cell value={r.drivers} active={sortKey === 'drivers'} />
                    <Cell value={r.agencies} active={sortKey === 'agencies'} />
                    <Cell value={r.requirements} active={sortKey === 'requirements'} />
                    <td className={`px-4 py-3 text-right font-semibold ${sortKey === 'revenue' ? 'text-orange-500' : 'text-gray-900 dark:text-white'}`}>
                      ₹{r.revenue.toLocaleString('en-IN')}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        )}
      </div>
    </div>
  );
}

function Cell({ value, active }: { value: number; active: boolean }) {
  return (
    <td className={`px-4 py-3 text-right ${active ? 'font-semibold text-orange-500' : 'text-gray-700 dark:text-gray-300'}`}>
      {value}
    </td>
  );
}

function StatCard({ icon, label, value, color }: { icon: React.ReactNode; label: string; value: string | number; color: string }) {
  return (
    <div className="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-700 p-4 flex items-center gap-3">
      <div className={`w-10 h-10 rounded-lg flex items-center justify-center ${color}`}>{icon}</div>
      <div>
        <div className="text-xl font-bold text-gray-900 dark:text-white">{value}</div>
        <div className="text-xs text-gray-500 dark:text-gray-400">{label}</div>
      </div>
    </div>
  );
}
