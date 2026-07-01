'use client';

import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { adminApi } from '@/lib/api';
import { DataTable } from '@/components/ui/DataTable';
import { Button } from '@/components/ui/Button';
import { Input } from '@/components/ui/Input';
import { MembershipBadge } from '@/components/ui/MembershipBadge';
import { Search, Wallet, Plus, Minus, X } from 'lucide-react';
import toast from 'react-hot-toast';
import type { ColumnDef } from '@tanstack/react-table';

interface WalletUser {
  _id: string;
  fullName: string;
  email?: string;
  mobile: string;
  agencyName?: string;
  city?: string;
  membershipType: string;
  walletBalance: number;
}

export default function WalletsPage() {
  const queryClient = useQueryClient();
  const [page, setPage] = useState(1);
  const [search, setSearch] = useState('');
  const [target, setTarget] = useState<WalletUser | null>(null);

  const { data: rawData, isLoading } = useQuery({
    queryKey: ['admin-wallets', page, search],
    queryFn: () => adminApi.getWallets({ page, limit: 20, search }),
  });
  const data = rawData as any;
  const users: WalletUser[] = data?.data?.data || [];
  const meta = data?.data?.meta;

  const columns: ColumnDef<WalletUser>[] = [
    {
      header: 'User',
      cell: ({ row }) => (
        <div className="flex items-center gap-3">
          <div className="w-9 h-9 rounded-full bg-orange-100 flex items-center justify-center text-orange-600 font-semibold text-sm">
            {row.original.fullName?.[0]?.toUpperCase()}
          </div>
          <div>
            <div className="font-medium text-sm">{row.original.fullName}</div>
            <div className="text-xs text-gray-500">{row.original.agencyName || row.original.email || '-'}</div>
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
      header: 'City',
      accessorKey: 'city',
      cell: ({ getValue }) => <span className="text-sm">{(getValue() as string) || '-'}</span>,
    },
    {
      header: 'Membership',
      accessorKey: 'membershipType',
      cell: ({ getValue }) => <MembershipBadge type={getValue() as string} />,
    },
    {
      header: 'Balance',
      accessorKey: 'walletBalance',
      cell: ({ getValue }) => {
        const bal = (getValue() as number) ?? 0;
        return (
          <span className={`font-bold text-sm ${bal >= 500 ? 'text-emerald-600' : 'text-red-500'}`}>
            ₹{bal.toLocaleString()}
          </span>
        );
      },
    },
    {
      id: 'actions',
      header: 'Actions',
      cell: ({ row }) => (
        <Button size="sm" variant="outline" onClick={() => setTarget(row.original)}>
          <Wallet className="w-3.5 h-3.5 mr-1.5" />
          Adjust
        </Button>
      ),
    },
  ];

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-gray-900 dark:text-white">Wallet Management</h1>
        <p className="text-sm text-gray-500 mt-0.5">
          {meta?.total?.toLocaleString() ?? 0} users · add or cut wallet balance with a reason
        </p>
      </div>

      <div className="relative flex-1 min-w-[200px] max-w-xs">
        <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
        <Input
          value={search}
          onChange={(e) => { setSearch(e.target.value); setPage(1); }}
          placeholder="Search by name, mobile, email..."
          className="pl-9"
        />
      </div>

      <div className="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-700 overflow-hidden">
        <DataTable
          columns={columns}
          data={users}
          isLoading={isLoading}
          pagination={{
            page,
            totalPages: meta?.totalPages || 1,
            onPageChange: setPage,
          }}
        />
      </div>

      {target && (
        <AdjustWalletModal
          user={target}
          onClose={() => setTarget(null)}
          onDone={() => {
            queryClient.invalidateQueries({ queryKey: ['admin-wallets'] });
            setTarget(null);
          }}
        />
      )}
    </div>
  );
}

function AdjustWalletModal({
  user,
  onClose,
  onDone,
}: {
  user: WalletUser;
  onClose: () => void;
  onDone: () => void;
}) {
  const [type, setType] = useState<'credit' | 'debit'>('credit');
  const [amount, setAmount] = useState('');
  const [reason, setReason] = useState('');

  const mutation = useMutation({
    mutationFn: () =>
      adminApi.adjustWallet(user._id, { amount: Number(amount), type, reason: reason.trim() }),
    onSuccess: (res: any) => {
      toast.success(res?.message || 'Wallet updated');
      onDone();
    },
    onError: (e: any) => toast.error(e?.message || 'Could not update wallet'),
  });

  const amt = Number(amount);
  const valid = amt >= 1 && reason.trim().length > 0 &&
    !(type === 'debit' && amt > (user.walletBalance ?? 0));

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4" onClick={onClose}>
      <div
        className="w-full max-w-md bg-white dark:bg-gray-900 rounded-2xl shadow-xl border border-gray-200 dark:border-gray-700"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex items-center justify-between px-5 py-4 border-b border-gray-200 dark:border-gray-700">
          <h2 className="font-bold text-lg text-gray-900 dark:text-white">Adjust Wallet</h2>
          <button onClick={onClose} className="text-gray-400 hover:text-gray-600">
            <X className="w-5 h-5" />
          </button>
        </div>

        <div className="p-5 space-y-4">
          <div className="flex items-center justify-between bg-gray-50 dark:bg-gray-800 rounded-lg px-4 py-3">
            <div>
              <div className="font-medium text-sm">{user.fullName}</div>
              <div className="text-xs text-gray-500 font-mono">{user.mobile}</div>
            </div>
            <div className="text-right">
              <div className="text-xs text-gray-500">Current balance</div>
              <div className="font-bold text-gray-900 dark:text-white">₹{(user.walletBalance ?? 0).toLocaleString()}</div>
            </div>
          </div>

          {/* Add / Cut toggle */}
          <div className="grid grid-cols-2 gap-2">
            <button
              type="button"
              onClick={() => setType('credit')}
              className={`flex items-center justify-center gap-1.5 py-2.5 rounded-lg border text-sm font-medium transition-colors ${
                type === 'credit'
                  ? 'bg-emerald-500 border-emerald-500 text-white'
                  : 'border-gray-300 dark:border-gray-600 text-gray-600 dark:text-gray-300'
              }`}
            >
              <Plus className="w-4 h-4" /> Add money
            </button>
            <button
              type="button"
              onClick={() => setType('debit')}
              className={`flex items-center justify-center gap-1.5 py-2.5 rounded-lg border text-sm font-medium transition-colors ${
                type === 'debit'
                  ? 'bg-red-500 border-red-500 text-white'
                  : 'border-gray-300 dark:border-gray-600 text-gray-600 dark:text-gray-300'
              }`}
            >
              <Minus className="w-4 h-4" /> Cut money
            </button>
          </div>

          <div>
            <label className="block text-xs font-medium text-gray-500 mb-1">Amount (₹)</label>
            <Input
              type="number"
              min={1}
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
              placeholder="e.g. 500"
            />
            {type === 'debit' && amt > (user.walletBalance ?? 0) && (
              <p className="text-xs text-red-500 mt-1">Amount is more than the user&apos;s balance.</p>
            )}
          </div>

          <div>
            <label className="block text-xs font-medium text-gray-500 mb-1">Reason (shown to the user)</label>
            <textarea
              value={reason}
              onChange={(e) => setReason(e.target.value)}
              maxLength={200}
              rows={3}
              placeholder={type === 'credit' ? 'e.g. Refund for cancelled ride' : 'e.g. Penalty for fake requirement'}
              className="w-full rounded-lg border border-gray-300 dark:border-gray-600 bg-transparent px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-orange-500"
            />
          </div>

          <div className="rounded-lg bg-gray-50 dark:bg-gray-800 px-4 py-2.5 text-sm">
            New balance:{' '}
            <span className="font-bold">
              ₹{Math.max(0, (user.walletBalance ?? 0) + (type === 'credit' ? amt || 0 : -(amt || 0))).toLocaleString()}
            </span>
          </div>
        </div>

        <div className="flex justify-end gap-2 px-5 py-4 border-t border-gray-200 dark:border-gray-700">
          <Button variant="outline" onClick={onClose}>Cancel</Button>
          <Button
            variant={type === 'debit' ? 'destructive' : 'default'}
            disabled={!valid}
            isLoading={mutation.isPending}
            onClick={() => mutation.mutate()}
          >
            {type === 'credit' ? 'Add money' : 'Cut money'}
          </Button>
        </div>
      </div>
    </div>
  );
}
