'use client';

import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { adminApi } from '@/lib/api';
import { DataTable } from '@/components/ui/DataTable';
import { Badge } from '@/components/ui/Badge';
import { Button } from '@/components/ui/Button';
import { Input } from '@/components/ui/Input';
import { Select } from '@/components/ui/Select';
import { UserActionsMenu } from '@/components/users/UserActionsMenu';
import { MembershipBadge } from '@/components/ui/MembershipBadge';
import { formatDate, getRelativeTime } from '@/lib/utils';
import { Search, Filter, Download, UserCheck, Shield } from 'lucide-react';
import toast from 'react-hot-toast';
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

export default function UsersPage() {
  const queryClient = useQueryClient();
  const [page, setPage] = useState(1);
  const [search, setSearch] = useState('');
  const [roleFilter, setRoleFilter] = useState('');
  const [membershipFilter, setMembershipFilter] = useState('');

  const { data: rawData, isLoading } = useQuery({
    queryKey: ['admin-users', page, search, roleFilter, membershipFilter],
    queryFn: () =>
      adminApi.getUsers({
        page,
        limit: 20,
        search,
        role: roleFilter || undefined,
        membershipType: membershipFilter || undefined,
      }),
  });
  const data = rawData as any;

  const verifyMutation = useMutation({
    mutationFn: (userId: string) => adminApi.verifyUser(userId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin-users'] });
      toast.success('User verified successfully');
    },
  });

  const blockMutation = useMutation({
    mutationFn: (userId: string) => adminApi.blockUser(userId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin-users'] });
      toast.success('User blocked');
    },
  });

  const columns: ColumnDef<User>[] = [
    {
      header: 'User',
      cell: ({ row }) => (
        <div className="flex items-center gap-3">
          <div className="w-9 h-9 rounded-full bg-orange-100 flex items-center justify-center text-orange-600 font-semibold text-sm">
            {row.original.fullName?.[0]?.toUpperCase()}
          </div>
          <div>
            <div className="font-medium text-sm flex items-center gap-1">
              {row.original.fullName}
              {row.original.isVerified && (
                <Shield className="w-3.5 h-3.5 text-emerald-500" />
              )}
            </div>
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
      header: 'Agency',
      accessorKey: 'agencyName',
      cell: ({ getValue }) => <span className="text-sm text-gray-600">{(getValue() as string) || '-'}</span>,
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
      header: 'Role',
      accessorKey: 'role',
      cell: ({ getValue }) => (
        <span className="text-xs bg-gray-100 dark:bg-gray-800 px-2 py-1 rounded-md capitalize">
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
      header: 'Posts',
      cell: ({ row }) => (
        <div className="text-sm">
          <span className="text-blue-600">{row.original.requirementsPosted}</span>
          <span className="text-gray-400 mx-1">/</span>
          <span className="text-green-600">{row.original.vehiclesPosted}</span>
        </div>
      ),
    },
    {
      header: 'Last Active',
      accessorKey: 'lastActive',
      cell: ({ getValue }) => (
        <span className="text-xs text-gray-500">
          {getValue() ? getRelativeTime(getValue() as string) : 'Never'}
        </span>
      ),
    },
    {
      header: 'Joined',
      accessorKey: 'createdAt',
      cell: ({ getValue }) => (
        <span className="text-xs text-gray-500">{formatDate(getValue() as string)}</span>
      ),
    },
    {
      id: 'actions',
      header: 'Actions',
      cell: ({ row }) => (
        <UserActionsMenu
          user={row.original}
          onVerify={() => verifyMutation.mutate(row.original._id)}
          onBlock={() => blockMutation.mutate(row.original._id)}
        />
      ),
    },
  ];

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900 dark:text-white">Users</h1>
          <p className="text-sm text-gray-500 mt-0.5">
            {data?.meta?.total?.toLocaleString()} total users
          </p>
        </div>
        <Button variant="outline" size="sm">
          <Download className="w-4 h-4 mr-2" />
          Export
        </Button>
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
          <option value="fleet_owner">Fleet Owner</option>
        </Select>
        <Select value={membershipFilter} onChange={(e: React.ChangeEvent<HTMLSelectElement>) => { setMembershipFilter(e.target.value); setPage(1); }}>
          <option value="">All Memberships</option>
          <option value="new">New</option>
          <option value="active">Active</option>
          <option value="verified">Verified</option>
          <option value="premium">Premium</option>
          <option value="golden">Golden</option>
        </Select>
      </div>

      {/* Table */}
      <div className="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-700 overflow-hidden">
        <DataTable
          columns={columns}
          data={data?.data || []}
          isLoading={isLoading}
          pagination={{
            page,
            totalPages: data?.meta?.totalPages || 1,
            onPageChange: setPage,
          }}
        />
      </div>
    </div>
  );
}
