'use client';

import { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { adminApi } from '@/lib/api';
import { DataTable } from '@/components/ui/DataTable';
import { Badge } from '@/components/ui/Badge';
import { FilterBar } from '@/components/ui/FilterBar';
import { PeriodFilter, type PeriodRange } from '@/components/ui/PeriodFilter';
import { formatDate } from '@/lib/utils';
import type { ColumnDef } from '@tanstack/react-table';

interface Subscription {
  _id: string;
  userId: { fullName: string; mobile: string };
  planId: { name: string };
  membershipType: string;
  status: string;
  amount: number;
  startDate: string;
  endDate: string;
}

const STATUS_COLORS: Record<string, 'default' | 'success' | 'destructive' | 'secondary'> = {
  active: 'success',
  expired: 'secondary',
};

const columns: ColumnDef<Subscription>[] = [
  {
    id: 'user',
    header: 'User',
    cell: ({ row }) => (
      <div>
        <p className="font-medium">{row.original.userId?.fullName}</p>
        <p className="text-xs text-gray-500">{row.original.userId?.mobile}</p>
      </div>
    ),
  },
  {
    id: 'plan',
    header: 'Plan',
    cell: ({ row }) => (
      <div>
        <p className="font-medium">{row.original.planId?.name}</p>
        <span className={`badge-${row.original.membershipType || 'new'} text-xs`}>
          {row.original.membershipType}
        </span>
      </div>
    ),
  },
  {
    accessorKey: 'amount',
    header: 'Amount',
    cell: ({ row }) => <span className="font-semibold">₹{((row.getValue('amount') as number) / 100).toFixed(0)}</span>,
  },
  {
    accessorKey: 'status',
    header: 'Status',
    cell: ({ row }) => { const s = row.getValue('status') as string; return <Badge variant={STATUS_COLORS[s] || 'default'}>{s}</Badge>; },
  },
  {
    id: 'period',
    header: 'Period',
    cell: ({ row }) => {
      const start = row.original.startDate;
      const end = row.original.endDate;
      const isExpired = end && new Date(end) < new Date();
      return (
        <div className="text-sm">
          <span className="text-gray-600 dark:text-gray-400">{start ? formatDate(start) : '—'}</span>
          <span className="mx-1.5 text-gray-400">→</span>
          <span className={isExpired ? 'text-red-500 font-medium' : 'text-gray-800 dark:text-gray-200 font-medium'}>
            {end ? formatDate(end) : '—'}
          </span>
        </div>
      );
    },
  },
];

export default function SubscriptionsPage() {
  const [page, setPage] = useState(1);
  const [status, setStatus] = useState('active');
  const [search, setSearch] = useState('');
  const [range, setRange] = useState<PeriodRange>({});

  const { data, isLoading } = useQuery({
    queryKey: ['subscriptions', page, status, search, range.dateFrom, range.dateTo],
    queryFn: () => adminApi.getSubscriptions({ page, limit: 20, status, search: search || undefined, dateFrom: range.dateFrom, dateTo: range.dateTo }),
  });

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-gray-900 dark:text-white">Subscriptions</h1>
        <p className="text-gray-500 mt-1">User membership subscriptions</p>
      </div>

      <FilterBar
        search={search}
        onSearch={(v) => { setSearch(v); setPage(1); }}
        searchPlaceholder="Search by user name / mobile…"
        onClear={() => { setSearch(''); setPage(1); }}
      >
        <select
          value={status}
          onChange={(e) => { setStatus(e.target.value); setPage(1); }}
          className="border border-gray-200 dark:border-gray-700 dark:bg-gray-800 dark:text-white rounded-lg px-3 py-2 text-sm"
        >
          <option value="active">Active</option>
          <option value="expired">Expired</option>
        </select>
        <PeriodFilter onChange={setRange} />
      </FilterBar>

      <DataTable
        columns={columns}
        data={data?.data?.data || []}
        isLoading={isLoading}
        pagination={{ page, totalPages: data?.data?.meta?.totalPages || 1, onPageChange: setPage }}
      />
    </div>
  );
}
