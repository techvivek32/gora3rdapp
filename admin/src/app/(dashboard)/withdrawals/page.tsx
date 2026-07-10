'use client';

import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { adminApi } from '@/lib/api';
import { FilterBar } from '@/components/ui/FilterBar';
import { Banknote, Check, X, Clock } from 'lucide-react';
import toast from 'react-hot-toast';

interface WithdrawalUser {
  _id: string;
  fullName: string;
  mobile: string;
  email?: string;
  agencyName?: string;
  city?: string;
  walletBalance?: number;
}

interface Withdrawal {
  _id: string;
  userId: WithdrawalUser | null;
  amount: number;
  accountHolderName: string;
  bankName: string;
  accountNumber: string;
  ifsc: string;
  status: 'pending' | 'approved' | 'rejected';
  rejectionReason?: string;
  createdAt: string;
  processedAt?: string;
}

function statusBadge(status: string) {
  const map: Record<string, string> = {
    pending: 'bg-amber-100 text-amber-700',
    approved: 'bg-green-100 text-green-700',
    rejected: 'bg-red-100 text-red-700',
  };
  return map[status] || 'bg-gray-100 text-gray-600';
}

export default function WithdrawalsPage() {
  const qc = useQueryClient();
  const [filter, setFilter] = useState<'pending' | 'approved' | 'rejected' | 'all'>('pending');
  const [search, setSearch] = useState('');

  const { data: raw, isLoading } = useQuery({
    queryKey: ['withdrawals', filter, search],
    queryFn: () => adminApi.getWithdrawals({
      status: filter === 'all' ? undefined : filter,
      search: search || undefined,
    }),
    refetchInterval: 30000,
  });
  const requests: Withdrawal[] = (raw as any)?.data || [];

  const approve = useMutation({
    mutationFn: (id: string) => adminApi.approveWithdrawal(id),
    onSuccess: () => {
      toast.success('Withdrawal approved');
      qc.invalidateQueries({ queryKey: ['withdrawals'] });
    },
    onError: (e: any) => toast.error(e?.message || 'Could not approve'),
  });

  const reject = useMutation({
    mutationFn: ({ id, reason }: { id: string; reason: string }) => adminApi.rejectWithdrawal(id, reason),
    onSuccess: () => {
      toast.success('Withdrawal rejected & amount refunded');
      qc.invalidateQueries({ queryKey: ['withdrawals'] });
    },
    onError: (e: any) => toast.error(e?.message || 'Could not reject'),
  });

  const onReject = (w: Withdrawal) => {
    const reason = window.prompt('Reason for rejecting this withdrawal (shown to the user, amount refunded):');
    if (reason && reason.trim()) reject.mutate({ id: w._id, reason: reason.trim() });
  };

  return (
    <div className="space-y-4">
      <div className="flex items-center gap-2">
        <Banknote className="w-6 h-6 text-orange-500" />
        <div>
          <h1 className="text-2xl font-bold text-gray-900 dark:text-white">Withdrawal Requests</h1>
          <p className="text-sm text-gray-500">Review and process user withdrawal requests.</p>
        </div>
      </div>

      {/* Filters */}
      <FilterBar
        search={search}
        onSearch={setSearch}
        searchPlaceholder="Search name / mobile / account…"
        onClear={() => { setSearch(''); }}
      >
        <select
          value={filter}
          onChange={(e) => setFilter(e.target.value as typeof filter)}
          className="border border-gray-200 dark:border-gray-700 dark:bg-gray-800 dark:text-white rounded-lg px-3 py-2 text-sm capitalize"
        >
          <option value="pending">Pending</option>
          <option value="approved">Approved</option>
          <option value="rejected">Rejected</option>
          <option value="all">All</option>
        </select>
      </FilterBar>

      {isLoading ? (
        <p className="text-sm text-gray-400 p-6 text-center">Loading…</p>
      ) : requests.length === 0 ? (
        <div className="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-700 p-10 text-center text-gray-400">
          <Clock className="w-8 h-8 mx-auto mb-2 opacity-50" />
          No {filter === 'all' ? '' : filter} withdrawal requests.
        </div>
      ) : (
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
          {requests.map((w) => (
            <div key={w._id} className="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-700 p-4 space-y-3">
              {/* Header: amount + status */}
              <div className="flex items-center justify-between">
                <div className="text-xl font-bold text-gray-900 dark:text-white">₹{w.amount.toLocaleString('en-IN')}</div>
                <span className={`text-xs font-semibold px-2 py-1 rounded-full capitalize ${statusBadge(w.status)}`}>{w.status}</span>
              </div>

              {/* User */}
              <div className="text-sm">
                <div className="font-semibold text-gray-800 dark:text-gray-100">{w.userId?.fullName || 'Unknown user'}</div>
                <div className="text-gray-500 font-mono text-xs">{w.userId?.mobile}</div>
                {w.userId?.agencyName && <div className="text-gray-500 text-xs">{w.userId.agencyName}{w.userId?.city ? ` · ${w.userId.city}` : ''}</div>}
                {typeof w.userId?.walletBalance === 'number' && (
                  <div className="text-gray-400 text-xs mt-0.5">Current wallet: ₹{w.userId.walletBalance.toLocaleString('en-IN')}</div>
                )}
              </div>

              {/* Bank details */}
              <div className="bg-gray-50 dark:bg-gray-800/50 rounded-lg p-3 text-sm space-y-1">
                <Detail label="Account Holder" value={w.accountHolderName} />
                <Detail label="Bank" value={w.bankName} />
                <Detail label="Account No." value={w.accountNumber} mono />
                <Detail label="IFSC" value={w.ifsc} mono />
              </div>

              <div className="text-xs text-gray-400">
                Requested: {new Date(w.createdAt).toLocaleString('en-IN')}
                {w.processedAt && <> · Processed: {new Date(w.processedAt).toLocaleString('en-IN')}</>}
              </div>

              {w.status === 'rejected' && w.rejectionReason && (
                <div className="text-xs text-red-600 bg-red-50 dark:bg-red-900/20 rounded-lg px-3 py-2">
                  Rejected: {w.rejectionReason}
                </div>
              )}

              {w.status === 'pending' && (
                <div className="flex gap-2 pt-1">
                  <button
                    onClick={() => approve.mutate(w._id)}
                    disabled={approve.isPending}
                    className="flex-1 flex items-center justify-center gap-1 bg-green-500 hover:bg-green-600 text-white rounded-lg py-2 text-sm font-medium disabled:opacity-50"
                  >
                    <Check className="w-4 h-4" /> Approve
                  </button>
                  <button
                    onClick={() => onReject(w)}
                    disabled={reject.isPending}
                    className="flex-1 flex items-center justify-center gap-1 bg-red-500 hover:bg-red-600 text-white rounded-lg py-2 text-sm font-medium disabled:opacity-50"
                  >
                    <X className="w-4 h-4" /> Reject
                  </button>
                </div>
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

function Detail({ label, value, mono }: { label: string; value: string; mono?: boolean }) {
  return (
    <div className="flex justify-between gap-3">
      <span className="text-gray-500">{label}</span>
      <span className={`font-medium text-gray-800 dark:text-gray-100 text-right ${mono ? 'font-mono' : ''}`}>{value}</span>
    </div>
  );
}
