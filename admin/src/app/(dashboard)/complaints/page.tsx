'use client';

import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { adminApi } from '@/lib/api';
import { DataTable } from '@/components/ui/DataTable';
import { Badge } from '@/components/ui/Badge';
import { Button } from '@/components/ui/Button';
import { FilterBar } from '@/components/ui/FilterBar';
import { MessageSquareWarning, X } from 'lucide-react';
import toast from 'react-hot-toast';
import { formatDate } from '@/lib/utils';
import type { ColumnDef } from '@tanstack/react-table';

interface Complaint {
  _id: string;
  customerId?: { _id: string; fullName: string; mobile: string; city?: string } | null;
  category: string;
  message?: string;
  bookingId?: string;
  status: 'open' | 'in_progress' | 'resolved';
  adminNote?: string;
  createdAt: string;
}

const CATEGORY_LABELS: Record<string, string> = {
  driver_no_show: 'Driver did not come',
  overcharged: 'Asked for more money',
  vehicle_problem: 'Vehicle problem',
  booking_cancelled: 'Booking cancelled',
  payment_problem: 'Payment problem',
  wrong_fare: 'Wrong fare',
  other: 'Other',
};

const STATUS_COLORS: Record<string, 'warning' | 'success' | 'default'> = {
  open: 'warning',
  in_progress: 'default',
  resolved: 'success',
};

export default function ComplaintsPage() {
  const qc = useQueryClient();
  const [status, setStatus] = useState('');
  const [target, setTarget] = useState<Complaint | null>(null);
  const [note, setNote] = useState('');
  const [newStatus, setNewStatus] = useState<Complaint['status']>('in_progress');

  const { data, isLoading } = useQuery({
    queryKey: ['customer-complaints', status],
    queryFn: () => adminApi.getCustomerComplaints({ status: status || undefined }),
  });

  const updateMutation = useMutation({
    mutationFn: ({ id, status, adminNote }: { id: string; status: string; adminNote: string }) =>
      adminApi.updateCustomerComplaint(id, { status, adminNote }),
    onSuccess: () => {
      toast.success('Complaint updated');
      setTarget(null);
      setNote('');
      qc.invalidateQueries({ queryKey: ['customer-complaints'] });
    },
    onError: (e: any) => toast.error(e?.message || 'Could not update'),
  });

  const columns: ColumnDef<Complaint>[] = [
    {
      id: 'customer',
      header: 'Customer',
      cell: ({ row }) => (
        <div>
          <p className="font-medium text-sm text-gray-900 dark:text-white">{row.original.customerId?.fullName || '—'}</p>
          <p className="text-xs text-gray-500 dark:text-gray-400">{row.original.customerId?.mobile || ''}{row.original.customerId?.city ? ` · ${row.original.customerId.city}` : ''}</p>
        </div>
      ),
    },
    {
      accessorKey: 'category',
      header: 'Issue',
      cell: ({ row }) => (
        <div>
          <p className="text-sm font-medium text-gray-800 dark:text-gray-200">{CATEGORY_LABELS[row.original.category] || row.original.category}</p>
          {row.original.message && <p className="text-xs text-gray-500 max-w-xs whitespace-pre-wrap">{row.original.message}</p>}
          {row.original.bookingId && <p className="text-xs text-gray-400 mt-0.5">Booking: {row.original.bookingId}</p>}
        </div>
      ),
    },
    {
      accessorKey: 'status',
      header: 'Status',
      cell: ({ row }) => {
        const s = row.original.status;
        return (
          <div>
            <Badge variant={STATUS_COLORS[s] || 'default'}>{s.replace('_', ' ')}</Badge>
            {row.original.adminNote && <p className="text-xs text-gray-400 mt-1 max-w-[200px]">{row.original.adminNote}</p>}
          </div>
        );
      },
    },
    {
      accessorKey: 'createdAt',
      header: 'Raised',
      cell: ({ row }) => <span className="text-xs text-gray-500 dark:text-gray-400">{formatDate(row.original.createdAt)}</span>,
    },
    {
      id: 'actions',
      header: 'Actions',
      cell: ({ row }) => (
        <button
          onClick={() => { setTarget(row.original); setNote(row.original.adminNote || ''); setNewStatus(row.original.status === 'open' ? 'in_progress' : row.original.status); }}
          className="px-3 py-1.5 text-xs font-semibold rounded-lg border border-gray-300 dark:border-gray-700 dark:text-gray-200 hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors"
        >
          Respond
        </button>
      ),
    },
  ];

  return (
    <div className="space-y-6">
      <div className="flex items-center gap-2">
        <MessageSquareWarning className="w-6 h-6 text-orange-500" />
        <div>
          <h1 className="text-2xl font-bold text-gray-900 dark:text-white">Customer Complaints</h1>
          <p className="text-sm text-gray-500 mt-0.5">Complaints raised by customers from Help &amp; Support</p>
        </div>
      </div>

      <FilterBar>
        <select
          value={status}
          onChange={(e) => setStatus(e.target.value)}
          className="border border-gray-200 dark:border-gray-700 dark:bg-gray-800 dark:text-white rounded-lg px-3 py-2 text-sm"
        >
          <option value="">All</option>
          <option value="open">Open</option>
          <option value="in_progress">In progress</option>
          <option value="resolved">Resolved</option>
        </select>
      </FilterBar>

      <div className="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-700 overflow-hidden">
        <DataTable columns={columns} data={data?.data?.data || []} isLoading={isLoading} />
      </div>

      {target && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4" onClick={() => setTarget(null)}>
          <div className="w-full max-w-md bg-white dark:bg-gray-900 rounded-2xl border border-gray-200 dark:border-gray-700" onClick={(e) => e.stopPropagation()}>
            <div className="flex items-center justify-between px-5 py-4 border-b border-gray-200 dark:border-gray-700">
              <h2 className="font-bold text-lg text-gray-900 dark:text-white">Respond to Complaint</h2>
              <button onClick={() => setTarget(null)} className="text-gray-400 hover:text-gray-600"><X className="w-5 h-5" /></button>
            </div>
            <div className="p-5 space-y-3">
              <p className="text-sm text-gray-500">
                {CATEGORY_LABELS[target.category] || target.category} — <span className="font-semibold text-gray-800 dark:text-gray-200">{target.customerId?.fullName}</span>
              </p>
              <div>
                <label className="text-xs font-medium text-gray-500 dark:text-gray-300 mb-1 block">Status</label>
                <select
                  value={newStatus}
                  onChange={(e) => setNewStatus(e.target.value as Complaint['status'])}
                  className="w-full border border-gray-200 dark:border-gray-700 dark:bg-gray-800 dark:text-white rounded-lg px-3 py-2 text-sm"
                >
                  <option value="open">Open</option>
                  <option value="in_progress">In progress</option>
                  <option value="resolved">Resolved</option>
                </select>
              </div>
              <div>
                <label className="text-xs font-medium text-gray-500 dark:text-gray-300 mb-1 block">Note to customer (optional)</label>
                <textarea
                  value={note}
                  onChange={(e) => setNote(e.target.value)}
                  rows={3}
                  placeholder="Reply / resolution note"
                  className="w-full border border-gray-200 dark:border-gray-700 dark:bg-gray-800 dark:text-white rounded-lg px-3 py-2 text-sm"
                />
              </div>
            </div>
            <div className="flex justify-end gap-2 px-5 py-4 border-t border-gray-200 dark:border-gray-700">
              <Button variant="outline" onClick={() => setTarget(null)}>Cancel</Button>
              <Button
                isLoading={updateMutation.isPending}
                onClick={() => updateMutation.mutate({ id: target._id, status: newStatus, adminNote: note })}
              >
                Save
              </Button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
