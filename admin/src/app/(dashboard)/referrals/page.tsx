'use client';

import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { adminApi } from '@/lib/api';
import { DataTable } from '@/components/ui/DataTable';
import { FilterBar } from '@/components/ui/FilterBar';
import { Button } from '@/components/ui/Button';
import { Select } from '@/components/ui/Select';
import { Trophy, Plus, Minus, X } from 'lucide-react';
import toast from 'react-hot-toast';
import type { ColumnDef } from '@tanstack/react-table';
import { useRole } from '@/hooks/useRole';

interface Row {
  rank: number;
  _id: string;
  name: string;
  mobile: string;
  city: string;
  referralCode: string;
  count: number;
}

const medalColor: Record<number, string> = {
  1: 'text-yellow-500',
  2: 'text-gray-400',
  3: 'text-amber-700',
};

const medalEmoji: Record<number, string> = { 1: '🥇', 2: '🥈', 3: '🥉' };

/**
 * All time, then the last 12 months ("June 2026"), then each year back to 2025.
 * Generated from today's date rather than hard-coded, so the list never goes stale.
 * A month is sent as "YYYY-MM" and a year as "YYYY"; the backend parses both.
 */
const PERIODS = (() => {
  const now = new Date();
  const out: { value: string; label: string }[] = [{ value: 'all', label: 'All Time' }];

  for (let i = 0; i < 12; i++) {
    const d = new Date(now.getFullYear(), now.getMonth() - i, 1);
    const value = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
    out.push({ value, label: d.toLocaleString('en-IN', { month: 'long', year: 'numeric' }) });
  }

  for (let y = now.getFullYear(); y >= 2025; y--) {
    out.push({ value: String(y), label: `Year ${y}` });
  }
  return out;
})();

export default function ReferralsPage() {
  const [search, setSearch] = useState('');
  const [period, setPeriod] = useState('all');
  // Franchise view: 'city' (their city, default) or 'all' (all-India). Ignored for admins.
  const [scope, setScope] = useState<'city' | 'all'>('city');
  const [modal, setModal] = useState<{ mode: 'add' | 'deduct'; userId: string; name: string } | null>(null);
  const [amount, setAmount] = useState(1);
  const queryClient = useQueryClient();
  const { isFranchise } = useRole();

  const { data: rawData, isLoading } = useQuery({
    queryKey: ['admin-referrals', search, period, scope],
    queryFn: () => adminApi.getReferralLeaderboard({ search, period, scope }),
  });
  const data = rawData as any;
  const rows: Row[] = data?.data || [];
  const top3 = rows.slice(0, 3);

  const mutation = useMutation({
    mutationFn: (delta: number) => adminApi.updateUserReferralCount(modal!.userId, delta),
    onSuccess: () => {
      toast.success(`Referral count ${modal?.mode === 'add' ? 'increased' : 'decreased'}`);
      queryClient.invalidateQueries({ queryKey: ['admin-referrals'] });
      setModal(null);
      setAmount(1);
    },
    onError: (e: any) => toast.error(e?.message || 'Failed to update'),
  });

  const columns: ColumnDef<Row>[] = [
    {
      header: 'Rank',
      accessorKey: 'rank',
      cell: ({ getValue }) => {
        const r = getValue() as number;
        return (
          <div className="flex items-center gap-1.5 font-bold">
            {r <= 3 ? <span className="text-lg leading-none">{medalEmoji[r]}</span> : null}
            <span className={r <= 3 ? medalColor[r] : 'text-gray-500'}>#{r}</span>
          </div>
        );
      },
    },
    {
      header: 'User',
      cell: ({ row }) => (
        <div className="flex items-center gap-3">
          <div className="w-9 h-9 rounded-full bg-orange-100 dark:bg-orange-900/30 flex items-center justify-center text-orange-600 dark:text-orange-400 font-semibold text-sm">
            {row.original.name?.[0]?.toUpperCase()}
          </div>
          <div>
            <div className="font-medium text-sm">{row.original.name}</div>
            <div className="text-xs text-gray-500 dark:text-gray-400">{row.original.city || '-'}</div>
          </div>
        </div>
      ),
    },
    {
      header: 'Mobile',
      accessorKey: 'mobile',
      cell: ({ getValue }) => <span className="font-mono text-sm">{(getValue() as string) || '-'}</span>,
    },
    {
      header: 'Referral Code',
      accessorKey: 'referralCode',
      cell: ({ getValue }) => (
        <span className="font-mono text-xs bg-gray-100 dark:bg-gray-800 px-2 py-1 rounded-md">
          {(getValue() as string) || '-'}
        </span>
      ),
    },
    {
      header: 'Invites',
      accessorKey: 'count',
      cell: ({ getValue }) => {
        const c = getValue() as number;
        return <span className={`font-bold ${c > 0 ? 'text-emerald-600 dark:text-emerald-400' : 'text-gray-400'}`}>{c}</span>;
      },
    },
    // Add/deduct invites is admin-only — omit the column entirely for franchises.
    ...(isFranchise
      ? []
      : [{
          id: 'actions',
          header: 'Actions',
          cell: ({ row }: { row: { original: Row } }) => (
            <div className="flex items-center gap-1">
              <button
                onClick={() => {
                  setModal({ mode: 'add', userId: row.original._id, name: row.original.name });
                  setAmount(1);
                }}
                title="Add referral"
                className="p-1.5 rounded-lg hover:bg-green-100 dark:hover:bg-green-900/30 text-green-600 dark:text-green-400 transition-colors"
              >
                <Plus className="w-4 h-4" />
              </button>
              <button
                onClick={() => {
                  setModal({ mode: 'deduct', userId: row.original._id, name: row.original.name });
                  setAmount(1);
                }}
                title="Deduct referral"
                className="p-1.5 rounded-lg hover:bg-red-100 dark:hover:bg-red-900/30 text-red-600 dark:text-red-400 transition-colors"
              >
                <Minus className="w-4 h-4" />
              </button>
            </div>
          ),
        } as ColumnDef<Row>]),
  ];

  return (
    <div className="space-y-6">
      <div className="flex items-center gap-2">
        <Trophy className="w-6 h-6 text-orange-500" />
        <div>
          <h1 className="text-2xl font-bold text-gray-900 dark:text-white">Invite Leaderboard</h1>
          <p className="text-sm text-gray-500 dark:text-gray-400 mt-0.5">Users ranked by how many people they invited</p>
        </div>
      </div>

      <FilterBar
        search={search}
        onSearch={setSearch}
        searchPlaceholder="Search name, mobile, code…"
        onClear={() => { setSearch(''); setPeriod('all'); setScope('city'); }}
      >
        {/* Franchise-only: switch between their city and the all-India leaderboard. */}
        {isFranchise && (
          <div className="inline-flex rounded-lg border border-gray-200 dark:border-gray-700 overflow-hidden">
            <button
              type="button"
              onClick={() => setScope('city')}
              className={`px-3 py-2 text-sm font-medium transition-colors ${
                scope === 'city'
                  ? 'bg-orange-500 text-white'
                  : 'bg-transparent text-gray-600 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-800'
              }`}
            >
              My City
            </button>
            <button
              type="button"
              onClick={() => setScope('all')}
              className={`px-3 py-2 text-sm font-medium transition-colors ${
                scope === 'all'
                  ? 'bg-orange-500 text-white'
                  : 'bg-transparent text-gray-600 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-800'
              }`}
            >
              All India
            </button>
          </div>
        )}
        <Select value={period} onChange={(e: React.ChangeEvent<HTMLSelectElement>) => setPeriod(e.target.value)}>
          {PERIODS.map((p) => (
            <option key={p.value} value={p.value}>{p.label}</option>
          ))}
        </Select>
      </FilterBar>

      {top3.length > 0 && (
        <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
          {top3.map((u) => (
            <div
              key={u._id}
              className="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-700 p-4 flex items-center gap-4"
            >
              <div className="relative">
                <div className="w-12 h-12 rounded-full bg-orange-100 dark:bg-orange-900/30 flex items-center justify-center text-orange-600 dark:text-orange-400 font-bold text-lg">
                  {u.name?.[0]?.toUpperCase()}
                </div>
                <span className="absolute -bottom-1 -right-1 text-2xl leading-none drop-shadow">
                  {medalEmoji[u.rank]}
                </span>
              </div>
              <div className="min-w-0">
                <div className="font-semibold truncate text-gray-900 dark:text-white">{u.name}</div>
                <div className="text-xs text-gray-500 dark:text-gray-400">Rank #{u.rank}</div>
                <div className="text-lg font-bold text-orange-500">{u.count} invites</div>
              </div>
            </div>
          ))}
        </div>
      )}

      <div className="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-700 overflow-hidden">
        <DataTable columns={columns} data={rows} isLoading={isLoading} />
      </div>

      {modal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4" onClick={() => setModal(null)}>
          <div
            className="w-full max-w-sm bg-white dark:bg-gray-900 rounded-2xl shadow-xl border border-gray-200 dark:border-gray-700"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="flex items-center justify-between px-5 py-4 border-b border-gray-200 dark:border-gray-700">
              <h2 className="font-bold text-lg text-gray-900 dark:text-white">
                {modal.mode === 'add' ? 'Add Referrals' : 'Deduct Referrals'}
              </h2>
              <button onClick={() => setModal(null)} className="text-gray-400 hover:text-gray-600 dark:hover:text-gray-300">
                <X className="w-5 h-5" />
              </button>
            </div>
            <div className="p-5 space-y-4">
              <div>
                <p className="text-xs text-gray-400 mb-0.5">User</p>
                <p className="text-sm font-medium text-gray-800 dark:text-gray-100">{modal.name}</p>
              </div>
              <div>
                <label className="text-xs text-gray-400 mb-1 block">
                  {modal.mode === 'add' ? 'Referrals to Add' : 'Referrals to Deduct'}
                </label>
                <input
                  type="number"
                  min="1"
                  value={amount}
                  onChange={(e) => setAmount(Math.max(1, parseInt(e.target.value) || 1))}
                  className="w-full border border-gray-200 dark:border-gray-700 dark:bg-gray-800 rounded-lg px-3 py-2 text-sm"
                />
              </div>
            </div>
            <div className="flex justify-end gap-2 px-5 py-4 border-t border-gray-200 dark:border-gray-700">
              <Button variant="outline" onClick={() => setModal(null)}>
                Cancel
              </Button>
              <Button
                onClick={() => mutation.mutate(modal.mode === 'add' ? amount : -amount)}
                isLoading={mutation.isPending}
                variant={modal.mode === 'add' ? 'default' : 'destructive'}
              >
                {modal.mode === 'add' ? 'Add' : 'Deduct'}
              </Button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
