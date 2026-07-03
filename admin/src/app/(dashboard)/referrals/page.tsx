'use client';

import { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { adminApi } from '@/lib/api';
import { DataTable } from '@/components/ui/DataTable';
import { Input } from '@/components/ui/Input';
import { Search, Trophy } from 'lucide-react';
import type { ColumnDef } from '@tanstack/react-table';

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

export default function ReferralsPage() {
  const [search, setSearch] = useState('');

  const { data: rawData, isLoading } = useQuery({
    queryKey: ['admin-referrals', search],
    queryFn: () => adminApi.getReferralLeaderboard({ search }),
  });
  const data = rawData as any;
  const rows: Row[] = data?.data || [];
  const top3 = rows.slice(0, 3);

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
          <div className="w-9 h-9 rounded-full bg-orange-100 flex items-center justify-center text-orange-600 font-semibold text-sm">
            {row.original.name?.[0]?.toUpperCase()}
          </div>
          <div>
            <div className="font-medium text-sm">{row.original.name}</div>
            <div className="text-xs text-gray-500">{row.original.city || '-'}</div>
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
        return <span className={`font-bold ${c > 0 ? 'text-emerald-600' : 'text-gray-400'}`}>{c}</span>;
      },
    },
  ];

  return (
    <div className="space-y-6">
      <div className="flex items-center gap-2">
        <Trophy className="w-6 h-6 text-orange-500" />
        <div>
          <h1 className="text-2xl font-bold text-gray-900 dark:text-white">Invite Leaderboard</h1>
          <p className="text-sm text-gray-500 mt-0.5">Users ranked by how many people they invited</p>
        </div>
      </div>

      {/* Top 3 podium cards */}
      {top3.length > 0 && (
        <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
          {top3.map((u) => (
            <div
              key={u._id}
              className="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-700 p-4 flex items-center gap-4"
            >
              <div className="relative">
                <div className="w-12 h-12 rounded-full bg-orange-100 flex items-center justify-center text-orange-600 font-bold text-lg">
                  {u.name?.[0]?.toUpperCase()}
                </div>
                <span className="absolute -bottom-1 -right-1 text-2xl leading-none drop-shadow">
                  {medalEmoji[u.rank]}
                </span>
              </div>
              <div className="min-w-0">
                <div className="font-semibold truncate">{u.name}</div>
                <div className="text-xs text-gray-500">Rank #{u.rank}</div>
                <div className="text-lg font-bold text-orange-500">{u.count} invites</div>
              </div>
            </div>
          ))}
        </div>
      )}

      <div className="relative flex-1 min-w-[200px] max-w-xs">
        <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
        <Input
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          placeholder="Search name, mobile, code..."
          className="pl-9"
        />
      </div>

      <div className="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-700 overflow-hidden">
        <DataTable columns={columns} data={rows} isLoading={isLoading} />
      </div>
    </div>
  );
}
