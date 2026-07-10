'use client';

import { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { adminApi } from '@/lib/api';
import { DataTable } from '@/components/ui/DataTable';
import { Badge } from '@/components/ui/Badge';
import { FilterBar } from '@/components/ui/FilterBar';
import { Select } from '@/components/ui/Select';
import type { ColumnDef } from '@tanstack/react-table';

interface Payment {
  _id: string;
  orderId: string;
  userId: { fullName: string; mobile: string };
  planId: { name: string; membershipType: string };
  amount: number;
  currency: string;
  status: string;
  method: string;
  createdAt: string;
}

const STATUS_COLORS: Record<string, 'default' | 'success' | 'destructive' | 'warning' | 'secondary'> = {
  created: 'warning',
  paid: 'success',
  failed: 'destructive',
  refunded: 'secondary',
};

const columns: ColumnDef<Payment>[] = [
  {
    accessorKey: 'orderId',
    header: 'Order ID',
    cell: ({ row }) => <span className="font-mono text-xs">{row.getValue('orderId')}</span>,
  },
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
        <span className={`badge-${row.original.planId?.membershipType || 'new'} text-xs`}>
          {row.original.planId?.membershipType}
        </span>
      </div>
    ),
  },
  {
    accessorKey: 'amount',
    header: 'Amount',
    cell: ({ row }) => <span className="font-semibold">₹{((row.getValue('amount') as number) / 100).toFixed(2)}</span>,
  },
  {
    accessorKey: 'method',
    header: 'Method',
    cell: ({ row }) => <span className="capitalize">{row.getValue('method')}</span>,
  },
  {
    accessorKey: 'status',
    header: 'Status',
    cell: ({ row }) => { const s = row.getValue('status') as string; return <Badge variant={STATUS_COLORS[s] || 'default'}>{s}</Badge>; },
  },
  {
    accessorKey: 'createdAt',
    header: 'Date',
    cell: ({ row }) => new Date(row.getValue('createdAt')).toLocaleDateString('en-IN'),
  },
];

export default function PaymentsPage() {
  const [page, setPage] = useState(1);
  const [search, setSearch] = useState('');
  const [status, setStatus] = useState('');
  const reset = () => setPage(1);

  const { data, isLoading } = useQuery({
    queryKey: ['payments', page, search, status],
    queryFn: () => adminApi.getPayments({
      page, limit: 20,
      search: search || undefined,
      status: status || undefined,
    }),
  });

  // Revenue = successful Razorpay transactions only (plans + wallet top-ups);
  // admin adjustments (method "admin") and other non-gateway entries don't count.
  const total = data?.data?.data?.reduce((sum: number, p: Payment) =>
    p.status === 'success' && p.method === 'razorpay' ? sum + p.amount : sum, 0) ?? 0;

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900 dark:text-white">Payments</h1>
          <p className="text-gray-500 mt-1">Transaction history and revenue</p>
        </div>
        <div className="stat-card !p-4">
          <p className="text-sm text-gray-500">Page Revenue</p>
          <p className="text-2xl font-bold text-green-600">₹{(total / 100).toLocaleString('en-IN')}</p>
        </div>
      </div>

      <FilterBar
        search={search}
        onSearch={(v) => { setSearch(v); reset(); }}
        searchPlaceholder="Search order ID / payment ID…"
        onClear={() => { setSearch(''); setStatus(''); reset(); }}
      >
        <Select value={status} onChange={(e: React.ChangeEvent<HTMLSelectElement>) => { setStatus(e.target.value); reset(); }}>
          <option value="">All Status</option>
          <option value="success">Success</option>
          <option value="pending">Pending</option>
          <option value="failed">Failed</option>
          <option value="refunded">Refunded</option>
        </Select>
      </FilterBar>

      <DataTable
        columns={columns}
        data={data?.data?.data || []}
        isLoading={isLoading}
        pagination={{
          page,
          totalPages: data?.data?.meta?.totalPages || 1,
          onPageChange: setPage,
        }}
      />
    </div>
  );
}
