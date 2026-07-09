'use client';

import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { adminApi } from '@/lib/api';
import { DataTable } from '@/components/ui/DataTable';
import { Badge } from '@/components/ui/Badge';
import { Button } from '@/components/ui/Button';
import { FilterBar } from '@/components/ui/FilterBar';
import toast from 'react-hot-toast';
import type { ColumnDef } from '@tanstack/react-table';

interface Person {
  fullName?: string;
  email?: string;
  mobile?: string;
  agencyName?: string;
  city?: string;
  state?: string;
  membershipType?: string;
}

interface Report {
  _id: string;
  reportedBy: Person;
  target?: Person | null;
  targetType: string;
  targetId?: string;
  reason: string;
  description?: string;
  status: string;
  createdAt: string;
}

const STATUS_COLORS: Record<string, 'default' | 'warning' | 'success' | 'destructive'> = {
  pending: 'warning',
  under_review: 'default',
  resolved: 'success',
  dismissed: 'destructive',
};

export default function ReportsPage() {
  const [page, setPage] = useState(1);
  const [status, setStatus] = useState('pending');
  const [search, setSearch] = useState('');
  const [dateFrom, setDateFrom] = useState('');
  const [dateTo, setDateTo] = useState('');
  const [selected, setSelected] = useState<Report | null>(null);
  const queryClient = useQueryClient();

  const { data, isLoading } = useQuery({
    queryKey: ['reports', page, status, search, dateFrom, dateTo],
    queryFn: () => adminApi.getReports({ page, limit: 20, status, search: search || undefined, dateFrom: dateFrom || undefined, dateTo: dateTo || undefined }),
  });

  const resolveMutation = useMutation({
    mutationFn: ({ id, action }: { id: string; action: string }) =>
      adminApi.resolveReport(id, { status: action }),
    onSuccess: () => {
      toast.success('Report updated');
      queryClient.invalidateQueries({ queryKey: ['reports'] });
    },
    onError: () => toast.error('Failed to update report'),
  });

  const columns: ColumnDef<Report>[] = [
    {
      id: 'reporter',
      header: 'Reported By',
      cell: ({ row }) => <span className="font-medium">{row.original.reportedBy?.fullName}</span>,
    },
    { accessorKey: 'targetType', header: 'Target Type', cell: ({ row }) => <span className="capitalize">{row.getValue('targetType')}</span> },
    { accessorKey: 'reason', header: 'Reason', cell: ({ row }) => <span className="capitalize">{(row.getValue('reason') as string).replace('_', ' ')}</span> },
    {
      accessorKey: 'description',
      header: 'Description',
      cell: ({ row }) => <span className="text-sm text-gray-600 line-clamp-2">{row.getValue('description') || '—'}</span>,
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
    {
      id: 'actions',
      header: 'Actions',
      cell: ({ row }) => (
        <div className="flex gap-2 items-center">
          <button
            onClick={() => setSelected(row.original)}
            className="text-sm font-medium text-orange-600 hover:text-orange-700"
          >
            View
          </button>
          {row.original.status === 'pending' && (
            <>
              <Button size="sm" onClick={() => resolveMutation.mutate({ id: row.original._id, action: 'resolved' })}>
                Resolve
              </Button>
              <Button size="sm" variant="ghost" onClick={() => resolveMutation.mutate({ id: row.original._id, action: 'dismissed' })}>
                Dismiss
              </Button>
            </>
          )}
        </div>
      ),
    },
  ];

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-gray-900 dark:text-white">Reports</h1>
        <p className="text-gray-500 mt-1">User-submitted content reports</p>
      </div>

      <FilterBar
        search={search}
        onSearch={(v) => { setSearch(v); setPage(1); }}
        searchPlaceholder="Search reason / description…"
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
          <option value="under_review">Under Review</option>
          <option value="resolved">Resolved</option>
          <option value="dismissed">Dismissed</option>
        </select>
      </FilterBar>

      <DataTable
        columns={columns}
        data={data?.data?.data || []}
        isLoading={isLoading}
        pagination={{ page, totalPages: data?.data?.meta?.totalPages || 1, onPageChange: setPage }}
      />

      {selected && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4" onClick={() => setSelected(null)}>
          <div className="bg-white rounded-xl w-full max-w-2xl max-h-[90vh] overflow-y-auto" onClick={(e) => e.stopPropagation()}>
            <div className="flex items-center justify-between px-6 py-4 border-b border-gray-200">
              <h2 className="text-lg font-bold text-gray-900">Report Details</h2>
              <button onClick={() => setSelected(null)} className="text-gray-400 hover:text-gray-600 text-xl leading-none">×</button>
            </div>
            <div className="p-6 space-y-5">
              <div className="grid grid-cols-2 gap-4">
                <_Field label="Reason"><span className="capitalize">{selected.reason.replace('_', ' ')}</span></_Field>
                <_Field label="Target Type"><span className="capitalize">{selected.targetType}</span></_Field>
                <_Field label="Status"><Badge variant={STATUS_COLORS[selected.status] || 'default'}>{selected.status}</Badge></_Field>
                <_Field label="Date">{new Date(selected.createdAt).toLocaleString('en-IN')}</_Field>
              </div>

              <div>
                <p className="text-xs font-semibold text-gray-400 uppercase mb-1">Description</p>
                <p className="text-sm text-gray-800 whitespace-pre-wrap rounded-lg bg-gray-50 p-3 border border-gray-200">
                  {selected.description || '—'}
                </p>
              </div>

              <_PersonBlock title="Reported By (who filed it)" person={selected.reportedBy} />
              {selected.targetType === 'user' && <_PersonBlock title="Reported User (who was reported)" person={selected.target} />}

              {selected.status === 'pending' && (
                <div className="flex gap-3 pt-2">
                  <Button onClick={() => { resolveMutation.mutate({ id: selected._id, action: 'resolved' }); setSelected(null); }}>
                    Resolve
                  </Button>
                  <Button variant="outline" onClick={() => { resolveMutation.mutate({ id: selected._id, action: 'dismissed' }); setSelected(null); }}>
                    Dismiss
                  </Button>
                </div>
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

function _Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div>
      <p className="text-xs font-semibold text-gray-400 uppercase mb-1">{label}</p>
      <div className="text-sm text-gray-800">{children}</div>
    </div>
  );
}

function _PersonBlock({ title, person }: { title: string; person?: Person | null }) {
  if (!person) {
    return (
      <div>
        <p className="text-xs font-semibold text-gray-400 uppercase mb-1">{title}</p>
        <p className="text-sm text-gray-500">Not available</p>
      </div>
    );
  }
  const rows: [string, string | undefined][] = [
    ['Name', person.fullName],
    ['Mobile', person.mobile],
    ['Email', person.email],
    ['Agency', person.agencyName],
    ['City', [person.city, person.state].filter(Boolean).join(', ') || undefined],
    ['Membership', person.membershipType],
  ];
  return (
    <div className="rounded-lg border border-gray-200 p-4">
      <p className="text-xs font-semibold text-gray-400 uppercase mb-2">{title}</p>
      <div className="grid grid-cols-2 gap-x-6 gap-y-2">
        {rows.filter(([, v]) => v).map(([k, v]) => (
          <div key={k}>
            <span className="text-xs text-gray-400">{k}: </span>
            <span className="text-sm font-medium text-gray-800 capitalize">{v}</span>
          </div>
        ))}
      </div>
    </div>
  );
}
