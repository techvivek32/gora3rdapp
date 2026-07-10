'use client';

import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { adminApi } from '@/lib/api';
import { DataTable } from '@/components/ui/DataTable';
import { Badge } from '@/components/ui/Badge';
import { Button } from '@/components/ui/Button';
import { FilterBar } from '@/components/ui/FilterBar';
import { UserX, X } from 'lucide-react';
import toast from 'react-hot-toast';
import { formatDate } from '@/lib/utils';
import type { ColumnDef } from '@tanstack/react-table';

interface DeletionRequest {
  _id: string;
  userId?: { _id: string; fullName: string; mobile: string; email?: string } | null;
  fullName: string;
  mobile: string;
  email?: string;
  reason: string;
  status: 'pending' | 'approved' | 'rejected';
  rejectionReason?: string;
  createdAt: string;
  processedAt?: string;
}

const STATUS_COLORS: Record<string, 'warning' | 'success' | 'destructive'> = {
  pending: 'warning',
  approved: 'success',
  rejected: 'destructive',
};

export default function DeletionRequestsPage() {
  const qc = useQueryClient();
  const [page, setPage] = useState(1);
  const [status, setStatus] = useState('pending');
  const [search, setSearch] = useState('');
  const [dateFrom, setDateFrom] = useState('');
  const [dateTo, setDateTo] = useState('');
  const [rejectTarget, setRejectTarget] = useState<DeletionRequest | null>(null);
  const [rejectReason, setRejectReason] = useState('');

  const { data, isLoading } = useQuery({
    queryKey: ['deletion-requests', page, status, search, dateFrom, dateTo],
    queryFn: () => adminApi.getDeletionRequests({
      page, limit: 20,
      status: status || undefined,
      search: search || undefined,
      dateFrom: dateFrom || undefined,
      dateTo: dateTo || undefined,
    }),
  });

  const invalidate = () => {
    qc.invalidateQueries({ queryKey: ['deletion-requests'] });
    qc.invalidateQueries({ queryKey: ['admin-users'] });
  };

  const approveMutation = useMutation({
    mutationFn: (id: string) => adminApi.approveDeletionRequest(id),
    onSuccess: () => { toast.success('Account deleted'); invalidate(); },
    onError: (e: any) => toast.error(e?.message || 'Could not delete account'),
  });

  const rejectMutation = useMutation({
    mutationFn: ({ id, reason }: { id: string; reason: string }) => adminApi.rejectDeletionRequest(id, reason),
    onSuccess: () => {
      toast.success('Request rejected');
      setRejectTarget(null);
      setRejectReason('');
      invalidate();
    },
    onError: (e: any) => toast.error(e?.message || 'Could not reject request'),
  });

  const columns: ColumnDef<DeletionRequest>[] = [
    {
      id: 'user',
      header: 'User',
      cell: ({ row }) => (
        <div>
          <p className="font-medium text-sm text-gray-900 dark:text-white">{row.original.fullName || '—'}</p>
          <p className="text-xs text-gray-500 dark:text-gray-400">{row.original.mobile}</p>
        </div>
      ),
    },
    {
      accessorKey: 'reason',
      header: 'Reason',
      cell: ({ row }) => (
        <p className="text-sm text-gray-700 dark:text-gray-300 max-w-md whitespace-pre-wrap">{row.original.reason}</p>
      ),
    },
    {
      accessorKey: 'status',
      header: 'Status',
      cell: ({ row }) => {
        const s = row.original.status;
        return (
          <div>
            <Badge variant={STATUS_COLORS[s] || 'default'}>{s}</Badge>
            {s === 'rejected' && row.original.rejectionReason && (
              <p className="text-xs text-gray-400 mt-1 max-w-[200px]">{row.original.rejectionReason}</p>
            )}
          </div>
        );
      },
    },
    {
      accessorKey: 'createdAt',
      header: 'Requested',
      cell: ({ row }) => <span className="text-xs text-gray-500 dark:text-gray-400">{formatDate(row.original.createdAt)}</span>,
    },
    {
      id: 'actions',
      header: 'Actions',
      cell: ({ row }) => {
        if (row.original.status !== 'pending') return <span className="text-xs text-gray-400">—</span>;
        return (
          <div className="flex gap-2">
            <button
              onClick={() => {
                if (confirm(`Permanently delete ${row.original.fullName || 'this user'}? This cannot be undone.`)) {
                  approveMutation.mutate(row.original._id);
                }
              }}
              className="px-3 py-1.5 text-xs font-semibold rounded-lg bg-red-500 text-white hover:bg-red-600 transition-colors"
            >
              Approve &amp; Delete
            </button>
            <button
              onClick={() => { setRejectTarget(row.original); setRejectReason(''); }}
              className="px-3 py-1.5 text-xs font-semibold rounded-lg border border-gray-300 dark:border-gray-700 dark:text-gray-200 hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors"
            >
              Reject
            </button>
          </div>
        );
      },
    },
  ];

  return (
    <div className="space-y-6">
      <div className="flex items-center gap-2">
        <UserX className="w-6 h-6 text-red-500" />
        <div>
          <h1 className="text-2xl font-bold text-gray-900 dark:text-white">Account Deletion Requests</h1>
          <p className="text-sm text-gray-500 mt-0.5">Users who asked to delete their account — approving removes them permanently</p>
        </div>
      </div>

      <FilterBar
        search={search}
        onSearch={(v) => { setSearch(v); setPage(1); }}
        searchPlaceholder="Search name, mobile, reason…"
        dateFrom={dateFrom}
        dateTo={dateTo}
        onDateFrom={(v) => { setDateFrom(v); setPage(1); }}
        onDateTo={(v) => { setDateTo(v); setPage(1); }}
        onClear={() => { setSearch(''); setDateFrom(''); setDateTo(''); setPage(1); }}
      >
        <select
          value={status}
          onChange={(e) => { setStatus(e.target.value); setPage(1); }}
          className="border border-gray-200 dark:border-gray-700 dark:bg-gray-800 dark:text-white rounded-lg px-3 py-2 text-sm"
        >
          <option value="pending">Pending</option>
          <option value="approved">Approved</option>
          <option value="rejected">Rejected</option>
          <option value="">All</option>
        </select>
      </FilterBar>

      <div className="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-700 overflow-hidden">
        <DataTable
          columns={columns}
          data={data?.data?.data || []}
          isLoading={isLoading}
          pagination={{ page, totalPages: data?.data?.meta?.totalPages || 1, onPageChange: setPage }}
        />
      </div>

      {/* Reject modal */}
      {rejectTarget && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4" onClick={() => setRejectTarget(null)}>
          <div className="w-full max-w-md bg-white dark:bg-gray-900 rounded-2xl border border-gray-200 dark:border-gray-700" onClick={(e) => e.stopPropagation()}>
            <div className="flex items-center justify-between px-5 py-4 border-b border-gray-200 dark:border-gray-700">
              <h2 className="font-bold text-lg text-gray-900 dark:text-white">Reject Deletion Request</h2>
              <button onClick={() => setRejectTarget(null)} className="text-gray-400 hover:text-gray-600"><X className="w-5 h-5" /></button>
            </div>
            <div className="p-5 space-y-3">
              <p className="text-sm text-gray-500">
                Rejecting keeps <span className="font-semibold text-gray-800 dark:text-gray-200">{rejectTarget.fullName}</span>&apos;s account active.
              </p>
              <div>
                <label className="text-xs font-medium text-gray-500 dark:text-gray-300 mb-1 block">Reason (optional)</label>
                <textarea
                  value={rejectReason}
                  onChange={(e) => setRejectReason(e.target.value)}
                  rows={3}
                  placeholder="Why is this request being rejected?"
                  className="w-full border border-gray-200 dark:border-gray-700 dark:bg-gray-800 dark:text-white rounded-lg px-3 py-2 text-sm"
                />
              </div>
            </div>
            <div className="flex justify-end gap-2 px-5 py-4 border-t border-gray-200 dark:border-gray-700">
              <Button variant="outline" onClick={() => setRejectTarget(null)}>Cancel</Button>
              <Button
                isLoading={rejectMutation.isPending}
                onClick={() => rejectMutation.mutate({ id: rejectTarget._id, reason: rejectReason })}
              >
                Reject Request
              </Button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
