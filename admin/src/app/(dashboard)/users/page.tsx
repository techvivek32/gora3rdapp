'use client';

import { Suspense, useState } from 'react';
import Link from 'next/link';
import { useSearchParams } from 'next/navigation';
import { useQuery } from '@tanstack/react-query';
import { adminApi } from '@/lib/api';
import { DataTable } from '@/components/ui/DataTable';
import { Badge } from '@/components/ui/Badge';
import { Input } from '@/components/ui/Input';
import { Select } from '@/components/ui/Select';
import { MembershipBadge } from '@/components/ui/MembershipBadge';
import { PeriodFilter, type PeriodRange } from '@/components/ui/PeriodFilter';
import { Search, Shield, Eye } from 'lucide-react';
import type { ColumnDef } from '@tanstack/react-table';

interface User {
  _id: string;
  fullName: string;
  email: string;
  mobile: string;
  agencyName?: string;
  city?: string;
  membershipType: string;
  role: string;
  isVerified: boolean;
  isBlocked: boolean;
  isActive: boolean;
  lastActive?: string;
  createdAt: string;
  requirementsPosted: number;
  vehiclesPosted: number;
}

function UsersPageInner() {
  const params = useSearchParams();
  const [page, setPage] = useState(1);
  const [search, setSearch] = useState('');
  // Filters seeded from the URL so dashboard cards can deep-link into a filtered view.
  const [roleFilter, setRoleFilter] = useState(params.get('role') || '');
  const [membershipFilter, setMembershipFilter] = useState(params.get('membership') || '');
  // Account status: '' all | 'true' active | 'false' inactive.
  const [statusFilter, setStatusFilter] = useState('');
  const [range, setRange] = useState<PeriodRange>({});

  // No dropdowns for these two any more, but the dashboard's "Verified Users" and
  // "Active Users" cards still deep-link with ?verified=true / ?active=true — keep
  // honouring them so those cards don't silently show every user.
  const verifiedFromUrl = params.get('verified') === 'true';
  const activeFromUrl = params.get('active') === 'true';

  const { data: rawData, isLoading } = useQuery({
    queryKey: ['admin-users', page, search, roleFilter, membershipFilter, statusFilter, verifiedFromUrl, activeFromUrl, range.dateFrom, range.dateTo],
    queryFn: () =>
      adminApi.getUsers({
        page,
        limit: 20,
        search,
        role: roleFilter || undefined,
        membershipType: membershipFilter || undefined,
        isActive: statusFilter || undefined,
        isVerified: verifiedFromUrl ? 'true' : undefined,
        active: activeFromUrl ? 'true' : undefined,
        dateFrom: range.dateFrom,
        dateTo: range.dateTo,
      }),
  });
  const data = rawData as any;
  const users = data?.data?.data || [];
  const meta = data?.data?.meta;

  const columns: ColumnDef<User>[] = [
    {
      header: 'User',
      cell: ({ row }) => (
        <div className="flex items-center gap-3">
          <div className="w-9 h-9 rounded-full bg-orange-100 flex items-center justify-center text-orange-600 font-semibold text-sm">
            {row.original.fullName?.[0]?.toUpperCase()}
          </div>
          <div>
            <div className="font-medium text-sm flex items-center gap-1 text-gray-900 dark:text-white">
              {row.original.fullName}
              {row.original.isVerified && (
                <Shield className="w-3.5 h-3.5 text-emerald-500" />
              )}
            </div>
            <div className="text-xs text-gray-500 dark:text-gray-400">{row.original.email}</div>
          </div>
        </div>
      ),
    },
    {
      header: 'Mobile',
      accessorKey: 'mobile',
      cell: ({ getValue }) => <span className="font-mono text-sm text-gray-900 dark:text-gray-100">{getValue() as string}</span>,
    },
    {
      header: 'Agency',
      accessorKey: 'agencyName',
      cell: ({ getValue }) => <span className="text-sm text-gray-600 dark:text-gray-300">{(getValue() as string) || '-'}</span>,
    },
    {
      header: 'City',
      accessorKey: 'city',
      cell: ({ getValue }) => <span className="text-sm text-gray-900 dark:text-gray-100">{(getValue() as string) || '-'}</span>,
    },
    {
      header: 'Membership',
      accessorKey: 'membershipType',
      cell: ({ getValue }) => <MembershipBadge type={getValue() as string} />,
    },
    {
      header: 'Role',
      accessorKey: 'role',
      cell: ({ getValue }) => (
        <span className="text-xs bg-gray-100 dark:bg-gray-800 text-gray-700 dark:text-gray-200 px-2 py-1 rounded-md capitalize">
          {(getValue() as string).replace('_', ' ')}
        </span>
      ),
    },
    {
      header: 'Status',
      cell: ({ row }) => (
        <div className="flex items-center gap-1">
          {row.original.isBlocked ? (
            <Badge variant="destructive">Blocked</Badge>
          ) : row.original.isActive ? (
            <Badge variant="success">Active</Badge>
          ) : (
            <Badge variant="secondary">Inactive</Badge>
          )}
        </div>
      ),
    },
    {
      id: 'actions',
      header: 'Actions',
      cell: ({ row }) => (
        <Link
          href={`/users/${row.original._id}`}
          className="inline-flex items-center gap-1.5 text-sm font-medium text-orange-600 hover:text-orange-700"
        >
          <Eye className="w-4 h-4" />
          View
        </Link>
      ),
    },
  ];

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900 dark:text-white">Users</h1>
          <p className="text-sm text-gray-500 mt-0.5">
            {meta?.total?.toLocaleString()} total users
          </p>
        </div>
        <div className="flex items-center gap-2">
          <PeriodFilter onChange={setRange} />
        </div>
      </div>

      {/* Filters */}
      <div className="flex flex-wrap gap-3">
        <div className="relative flex-1 min-w-[200px] max-w-xs">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
          <Input
            value={search}
            onChange={(e) => { setSearch(e.target.value); setPage(1); }}
            placeholder="Search users..."
            className="pl-9"
          />
        </div>
        <Select value={roleFilter} onChange={(e: React.ChangeEvent<HTMLSelectElement>) => { setRoleFilter(e.target.value); setPage(1); }}>
          <option value="">All Roles</option>
          <option value="driver">Driver</option>
          <option value="travel_agency">Travel Agency</option>
        </Select>
        <Select value={membershipFilter} onChange={(e: React.ChangeEvent<HTMLSelectElement>) => { setMembershipFilter(e.target.value); setPage(1); }}>
          <option value="">All Memberships</option>
          <option value="new">New</option>
          <option value="active">Active</option>
          <option value="premium">Premium</option>
          <option value="golden">Golden</option>
        </Select>
        <Select value={statusFilter} onChange={(e: React.ChangeEvent<HTMLSelectElement>) => { setStatusFilter(e.target.value); setPage(1); }}>
          <option value="">All Status</option>
          <option value="true">Active</option>
          <option value="false">Inactive</option>
        </Select>
      </div>

      {/* Table */}
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
    </div>
  );
}

export default function UsersPage() {
  // useSearchParams (inside UsersPageInner) must sit under a Suspense boundary.
  return (
    <Suspense fallback={null}>
      <UsersPageInner />
    </Suspense>
  );
}
