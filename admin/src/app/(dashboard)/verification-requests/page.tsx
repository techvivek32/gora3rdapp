'use client';

import { useState } from 'react';
import Link from 'next/link';
import { useQuery } from '@tanstack/react-query';
import { adminApi } from '@/lib/api';
import { DataTable } from '@/components/ui/DataTable';
import { Badge } from '@/components/ui/Badge';
import { FilterBar } from '@/components/ui/FilterBar';
import { PeriodFilter, type PeriodRange } from '@/components/ui/PeriodFilter';
import { Select } from '@/components/ui/Select';
import { formatDate } from '@/lib/utils';
import type { ColumnDef } from '@tanstack/react-table';

interface VerificationRequest {
  _id: string;
  fullName: string;
  email: string;
  mobile: string;
  agencyName?: string;
  role: string;
  verificationStatus: 'none' | 'pending' | 'verified' | 'rejected';
  verificationSubmittedAt?: string;
  documents?: Record<string, { number?: string; image?: string }>;
}

const STATUS_VARIANT: Record<string, 'warning' | 'success' | 'destructive' | 'secondary'> = {
  pending: 'warning',
  verified: 'success',
  rejected: 'destructive',
  none: 'secondary',
};

export default function VerificationRequestsPage() {
  const [page, setPage] = useState(1);
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState('pending');
  const [range, setRange] = useState<PeriodRange>({});

  const { data: rawData, isLoading } = useQuery({
    queryKey: ['verification-requests', page, search, statusFilter, range.dateFrom, range.dateTo],
    queryFn: () =>
      adminApi.getVerificationRequests({
        page,
        limit: 20,
        search,
        status: statusFilter || 'pending',
        dateFrom: range.dateFrom,
        dateTo: range.dateTo,
      }),
  });
  const data = rawData as any;
  const requests = data?.data?.data || [];
  const meta = data?.data?.meta;

  const columns: ColumnDef<VerificationRequest>[] = [
    {
      header: 'User',
      cell: ({ row }) => (
        <div className="flex items-center gap-3">
          <div className="w-9 h-9 rounded-full bg-orange-100 flex items-center justify-center text-orange-600 font-semibold text-sm">
            {row.original.fullName?.[0]?.toUpperCase()}
          </div>
          <div>
            <div className="font-medium text-sm">{row.original.fullName}</div>
            <div className="text-xs text-gray-500">{row.original.email}</div>
          </div>
        </div>
      ),
    },
    {
      header: 'Mobile',
      accessorKey: 'mobile',
      cell: ({ getValue }) => <span className="font-mono text-sm">{getValue() as string}</span>,
    },
    {
      header: 'Role',
      accessorKey: 'role',
      cell: ({ getValue }) => (
        <span className="text-xs bg-gray-100 dark:bg-gray-800 px-2 py-1 rounded-md capitalize">
          {(getValue() as string).replace('_', ' ')}
        </span>
      ),
    },
    {
      header: 'Documents',
      cell: ({ row }) => (
        <span className="text-sm text-gray-600">
          {Object.keys(row.original.documents || {}).length} submitted
        </span>
      ),
    },
    {
      header: 'Submitted',
      accessorKey: 'verificationSubmittedAt',
      cell: ({ getValue }) => (
        <span className="text-xs text-gray-500">
          {getValue() ? formatDate(getValue() as string) : '-'}
        </span>
      ),
    },
    {
      header: 'Status',
      accessorKey: 'verificationStatus',
      cell: ({ getValue }) => {
        const status = getValue() as string;
        return <Badge variant={STATUS_VARIANT[status] || 'secondary'} className="capitalize">{status}</Badge>;
      },
    },
    {
      id: 'actions',
      header: 'Actions',
      cell: ({ row }) => (
        <Link
          href={`/verification-requests/${row.original._id}`}
          className="text-sm font-medium text-orange-600 hover:text-orange-700"
        >
          Review →
        </Link>
      ),
    },
  ];

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-gray-900 dark:text-white">Verification Requests</h1>
        <p className="text-sm text-gray-500 mt-0.5">
          {meta?.total?.toLocaleString() ?? 0} requests
        </p>
      </div>

      <div className="flex justify-end">
        <PeriodFilter onChange={setRange} />
      </div>

      {/* Filters */}
      <FilterBar
        search={search}
        onSearch={(v) => { setSearch(v); setPage(1); }}
        searchPlaceholder="Search by name, email, mobile…"
        onClear={() => { setSearch(''); setStatusFilter('pending'); setPage(1); }}
      >
        <Select
          value={statusFilter}
          onChange={(e: React.ChangeEvent<HTMLSelectElement>) => { setStatusFilter(e.target.value); setPage(1); }}
        >
          <option value="pending">Pending</option>
          <option value="verified">Verified</option>
          <option value="rejected">Rejected</option>
          <option value="all">All</option>
        </Select>
      </FilterBar>

      {/* Table */}
      <div className="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-700 overflow-hidden">
        <DataTable
          columns={columns}
          data={requests}
          isLoading={isLoading}
          pagination={{
            page,
            totalPages: meta?.totalPages || 1,
            onPageChange: setPage,
          }}
        />
      </div>
    </div>
  );
}
