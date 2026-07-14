'use client';

import { useState } from 'react';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { adminApi } from '@/lib/api';
import { DataTable } from '@/components/ui/DataTable';
import { Button } from '@/components/ui/Button';
import { Input } from '@/components/ui/Input';
import { MembershipBadge } from '@/components/ui/MembershipBadge';
import { AdjustWalletModal } from '@/components/wallets/AdjustWalletModal';
import { Search, Wallet } from 'lucide-react';
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

