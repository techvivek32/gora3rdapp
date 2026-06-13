'use client';

import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { adminApi } from '@/lib/api';
import { DataTable } from '@/components/ui/DataTable';
import { Badge } from '@/components/ui/Badge';
import { Button } from '@/components/ui/Button';
import toast from 'react-hot-toast';
import type { ColumnDef } from '@tanstack/react-table';

interface Report {
  _id: string;
  reportedBy: { fullName: string };
  targetType: string;
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
  const queryClient = useQueryClient();

  const { data, isLoading } = useQuery({
    queryKey: ['reports', page, status],
    queryFn: () => adminApi.getReports({ page, limit: 20, status }),
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
      cell: ({ row }) => row.original.status === 'pending' ? (
        <div className="flex gap-2">
          <Button size="sm" onClick={() => resolveMutation.mutate({ id: row.original._id, action: 'resolved' })}>
            Resolve
          </Button>
          <Button size="sm" variant="ghost" onClick={() => resolveMutation.mutate({ id: row.original._id, action: 'dismissed' })}>
            Dismiss
          </Button>
        </div>
      ) : null,
    },
  ];

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-gray-900">Reports</h1>
        <p className="text-gray-500 mt-1">User-submitted content reports</p>
      </div>

      <div className="flex gap-2">
        {['pending', 'under_review', 'resolved', 'dismissed'].map((s) => (
          <button
            key={s}
            onClick={() => { setStatus(s); setPage(1); }}
            className={`px-4 py-2 rounded-lg text-sm font-medium transition-colors ${
              status === s ? 'bg-brand-500 text-white' : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
            }`}
          >
            {s.charAt(0).toUpperCase() + s.slice(1).replace('_', ' ')}
          </button>
        ))}
      </div>

      <DataTable
        columns={columns}
        data={data?.data?.data || []}
        isLoading={isLoading}
        pagination={{ page, totalPages: data?.data?.meta?.totalPages || 1, onPageChange: setPage }}
      />
    </div>
  );
}
