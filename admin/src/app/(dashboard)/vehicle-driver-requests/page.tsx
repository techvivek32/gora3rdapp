'use client';

import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { adminApi } from '@/lib/api';
import { DataTable } from '@/components/ui/DataTable';
import { Badge } from '@/components/ui/Badge';
import { Button } from '@/components/ui/Button';
import { Car, User, X, Check, ClipboardList } from 'lucide-react';
import toast from 'react-hot-toast';
import { formatDate } from '@/lib/utils';
import type { ColumnDef } from '@tanstack/react-table';

type Tab = 'vehicles' | 'drivers';
type Status = 'pending' | 'approved' | 'rejected' | 'all';

interface Owner { _id: string; name: string; mobile: string; city?: string; state?: string }

interface GarageVehicle {
  _id: string;
  vehicleType?: string;
  modelName?: string;
  registrationNumber?: string;
  fuelType?: string;
  seatingCapacity?: number;
  color?: string;
  carPhotos?: string[];
  rcFrontImage?: string;
  rcBackImage?: string;
  approvalStatus: 'pending' | 'approved' | 'rejected';
  rejectionReason?: string;
  createdAt: string;
  owner?: Owner;
}

interface GarageDriver {
  _id: string;
  fullName?: string;
  phone?: string;
  dlNumber?: string;
  aadharNumber?: string;
  address?: string;
  photo?: string;
  dlFrontImage?: string;
  dlBackImage?: string;
  aadharFrontImage?: string;
  aadharBackImage?: string;
  approvalStatus: 'pending' | 'approved' | 'rejected';
  rejectionReason?: string;
  createdAt: string;
  owner?: Owner;
}

const STATUS_COLORS: Record<string, 'warning' | 'success' | 'destructive'> = {
  pending: 'warning',
  approved: 'success',
  rejected: 'destructive',
};

/** A tiny labelled document/photo link that opens full-size in a new tab. */
function DocLink({ label, url }: { label: string; url?: string }) {
  if (!url) return <span className="text-[11px] text-gray-300 dark:text-gray-600">{label}: —</span>;
  return (
    <a href={url} target="_blank" rel="noreferrer" className="group inline-flex items-center gap-1">
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img src={url} alt={label} className="w-8 h-8 rounded object-cover border border-gray-200 dark:border-gray-700" />
      <span className="text-[11px] text-orange-500 group-hover:underline">{label}</span>
    </a>
  );
}

export default function VehicleDriverRequestsPage() {
  const qc = useQueryClient();
  const [tab, setTab] = useState<Tab>('vehicles');
  const [status, setStatus] = useState<Status>('pending');
  const [page, setPage] = useState(1);
  const [rejectTarget, setRejectTarget] = useState<{ id: string; label: string; kind: Tab } | null>(null);
  const [rejectReason, setRejectReason] = useState('');

  const { data: vData, isLoading: vLoading } = useQuery({
    queryKey: ['vd-vehicles', status, page],
    queryFn: () => adminApi.getGarageVehicles({ status, page, limit: 20 }),
    enabled: tab === 'vehicles',
  });
  const { data: dData, isLoading: dLoading } = useQuery({
    queryKey: ['vd-drivers', status, page],
    queryFn: () => adminApi.getGarageDrivers({ status, page, limit: 20 }),
    enabled: tab === 'drivers',
  });

  const invalidate = () => {
    qc.invalidateQueries({ queryKey: ['vd-vehicles'] });
    qc.invalidateQueries({ queryKey: ['vd-drivers'] });
  };

  const approveMutation = useMutation({
    mutationFn: ({ id, kind }: { id: string; kind: Tab }) =>
      kind === 'vehicles' ? adminApi.approveGarageVehicle(id) : adminApi.approveGarageDriver(id),
    onSuccess: () => { toast.success('Approved'); invalidate(); },
    onError: (e: any) => toast.error(e?.response?.data?.message || e?.message || 'Could not approve'),
  });

  const rejectMutation = useMutation({
    mutationFn: ({ id, reason, kind }: { id: string; reason: string; kind: Tab }) =>
      kind === 'vehicles' ? adminApi.rejectGarageVehicle(id, reason) : adminApi.rejectGarageDriver(id, reason),
    onSuccess: () => { toast.success('Rejected'); setRejectTarget(null); setRejectReason(''); invalidate(); },
    onError: (e: any) => toast.error(e?.response?.data?.message || e?.message || 'Could not reject'),
  });

  const StatusCell = ({ s, reason }: { s: string; reason?: string }) => (
    <div>
      <Badge variant={STATUS_COLORS[s] || 'default'}>{s}</Badge>
      {s === 'rejected' && reason && <p className="text-xs text-gray-400 mt-1 max-w-[180px]">{reason}</p>}
    </div>
  );

  const OwnerCell = ({ owner }: { owner?: Owner }) => (
    <div>
      <p className="font-medium text-sm text-gray-900 dark:text-white">{owner?.name || '—'}</p>
      <p className="text-xs text-gray-500 dark:text-gray-400">{owner?.mobile || ''}{owner?.city ? ` • ${owner.city}` : ''}</p>
    </div>
  );

  const ActionsCell = ({ id, label, kind, s }: { id: string; label: string; kind: Tab; s: string }) => {
    if (s !== 'pending') return <span className="text-xs text-gray-400">—</span>;
    return (
      <div className="flex gap-2">
        <button
          onClick={() => approveMutation.mutate({ id, kind })}
          disabled={approveMutation.isPending}
          className="inline-flex items-center gap-1 px-3 py-1.5 text-xs font-semibold rounded-lg bg-green-500 text-white hover:bg-green-600 disabled:opacity-60 transition-colors"
        >
          <Check className="w-3.5 h-3.5" /> Approve
        </button>
        <button
          onClick={() => { setRejectTarget({ id, label, kind }); setRejectReason(''); }}
          className="inline-flex items-center gap-1 px-3 py-1.5 text-xs font-semibold rounded-lg border border-gray-300 dark:border-gray-700 dark:text-gray-200 hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors"
        >
          <X className="w-3.5 h-3.5" /> Reject
        </button>
      </div>
    );
  };

  const vehicleColumns: ColumnDef<GarageVehicle>[] = [
    {
      id: 'vehicle',
      header: 'Vehicle',
      cell: ({ row }) => (
        <div>
          <p className="font-semibold text-sm text-gray-900 dark:text-white">{row.original.modelName || row.original.vehicleType || 'Vehicle'}</p>
          <p className="text-xs text-gray-500 dark:text-gray-400">
            {[row.original.vehicleType, row.original.fuelType && row.original.fuelType !== 'any' ? row.original.fuelType : '', row.original.seatingCapacity ? `${row.original.seatingCapacity} seats` : '', row.original.color].filter(Boolean).join(' • ')}
          </p>
        </div>
      ),
    },
    { accessorKey: 'registrationNumber', header: 'Reg No', cell: ({ row }) => <span className="text-sm text-gray-700 dark:text-gray-300">{row.original.registrationNumber || '—'}</span> },
    { id: 'owner', header: 'Owner', cell: ({ row }) => <OwnerCell owner={row.original.owner} /> },
    {
      id: 'docs',
      header: 'Documents',
      cell: ({ row }) => (
        <div className="flex flex-wrap items-center gap-2">
          {(row.original.carPhotos || []).filter(Boolean).slice(0, 2).map((p, i) => <DocLink key={i} label={`Photo ${i + 1}`} url={p} />)}
          <DocLink label="RC F" url={row.original.rcFrontImage} />
          <DocLink label="RC B" url={row.original.rcBackImage} />
        </div>
      ),
    },
    { id: 'status', header: 'Status', cell: ({ row }) => <StatusCell s={row.original.approvalStatus} reason={row.original.rejectionReason} /> },
    { accessorKey: 'createdAt', header: 'Added', cell: ({ row }) => <span className="text-xs text-gray-500 dark:text-gray-400">{formatDate(row.original.createdAt)}</span> },
    { id: 'actions', header: 'Actions', cell: ({ row }) => <ActionsCell id={row.original._id} label={row.original.modelName || row.original.registrationNumber || 'vehicle'} kind="vehicles" s={row.original.approvalStatus} /> },
  ];

  const driverColumns: ColumnDef<GarageDriver>[] = [
    {
      id: 'driver',
      header: 'Driver',
      cell: ({ row }) => (
        <div className="flex items-center gap-2">
          {row.original.photo ? (
            // eslint-disable-next-line @next/next/no-img-element
            <img src={row.original.photo} alt={row.original.fullName} className="w-9 h-9 rounded-full object-cover border border-gray-200 dark:border-gray-700" />
          ) : (
            <div className="w-9 h-9 rounded-full bg-orange-100 dark:bg-orange-900/30 flex items-center justify-center"><User className="w-4 h-4 text-orange-500" /></div>
          )}
          <div>
            <p className="font-semibold text-sm text-gray-900 dark:text-white">{row.original.fullName || 'Driver'}</p>
            {row.original.dlNumber && <p className="text-xs text-gray-500 dark:text-gray-400">DL {row.original.dlNumber}</p>}
          </div>
        </div>
      ),
    },
    { accessorKey: 'phone', header: 'Phone', cell: ({ row }) => <span className="text-sm text-gray-700 dark:text-gray-300">{row.original.phone || '—'}</span> },
    { id: 'owner', header: 'Owner', cell: ({ row }) => <OwnerCell owner={row.original.owner} /> },
    {
      id: 'docs',
      header: 'Documents',
      cell: ({ row }) => (
        <div className="flex flex-wrap items-center gap-2">
          <DocLink label="DL F" url={row.original.dlFrontImage} />
          <DocLink label="DL B" url={row.original.dlBackImage} />
          <DocLink label="Aadhaar F" url={row.original.aadharFrontImage} />
          <DocLink label="Aadhaar B" url={row.original.aadharBackImage} />
        </div>
      ),
    },
    { id: 'status', header: 'Status', cell: ({ row }) => <StatusCell s={row.original.approvalStatus} reason={row.original.rejectionReason} /> },
    { accessorKey: 'createdAt', header: 'Added', cell: ({ row }) => <span className="text-xs text-gray-500 dark:text-gray-400">{formatDate(row.original.createdAt)}</span> },
    { id: 'actions', header: 'Actions', cell: ({ row }) => <ActionsCell id={row.original._id} label={row.original.fullName || 'driver'} kind="drivers" s={row.original.approvalStatus} /> },
  ];

  return (
    <div className="space-y-6">
      <div className="flex items-center gap-2">
        <ClipboardList className="w-6 h-6 text-orange-500" />
        <div>
          <h1 className="text-2xl font-bold text-gray-900 dark:text-white">Vehicle / Driver Requests</h1>
          <p className="text-sm text-gray-500 mt-0.5">Review vehicles &amp; drivers partners submit — only approved ones can accept bookings</p>
        </div>
      </div>

      <div className="flex flex-wrap items-center justify-between gap-3">
        <div className="inline-flex rounded-lg border border-gray-200 dark:border-gray-700 overflow-hidden">
          {(['vehicles', 'drivers'] as Tab[]).map((t) => (
            <button
              key={t}
              onClick={() => { setTab(t); setPage(1); }}
              className={`inline-flex items-center gap-2 px-4 py-2 text-sm font-semibold transition-colors ${
                tab === t ? 'bg-orange-500 text-white' : 'bg-white dark:bg-gray-900 text-gray-600 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-800'
              }`}
            >
              {t === 'vehicles' ? <Car className="w-4 h-4" /> : <User className="w-4 h-4" />}
              {t === 'vehicles' ? 'Vehicles' : 'Drivers'}
            </button>
          ))}
        </div>
        <select
          value={status}
          onChange={(e) => { setStatus(e.target.value as Status); setPage(1); }}
          className="border border-gray-200 dark:border-gray-700 dark:bg-gray-800 dark:text-white rounded-lg px-3 py-2 text-sm"
        >
          <option value="pending">Pending</option>
          <option value="approved">Approved</option>
          <option value="rejected">Rejected</option>
          <option value="all">All</option>
        </select>
      </div>

      <div className="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-700 overflow-hidden">
        {tab === 'vehicles' ? (
          <DataTable
            columns={vehicleColumns}
            data={(vData?.data?.data as GarageVehicle[]) || []}
            isLoading={vLoading}
            pagination={{ page, totalPages: vData?.data?.meta?.totalPages || 1, onPageChange: setPage }}
          />
        ) : (
          <DataTable
            columns={driverColumns}
            data={(dData?.data?.data as GarageDriver[]) || []}
            isLoading={dLoading}
            pagination={{ page, totalPages: dData?.data?.meta?.totalPages || 1, onPageChange: setPage }}
          />
        )}
      </div>

      {/* Reject modal */}
      {rejectTarget && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4" onClick={() => setRejectTarget(null)}>
          <div className="w-full max-w-md bg-white dark:bg-gray-900 rounded-2xl border border-gray-200 dark:border-gray-700" onClick={(e) => e.stopPropagation()}>
            <div className="flex items-center justify-between px-5 py-4 border-b border-gray-200 dark:border-gray-700">
              <h2 className="font-bold text-lg text-gray-900 dark:text-white">Reject {rejectTarget.kind === 'vehicles' ? 'Vehicle' : 'Driver'}</h2>
              <button onClick={() => setRejectTarget(null)} className="text-gray-400 hover:text-gray-600"><X className="w-5 h-5" /></button>
            </div>
            <div className="p-5 space-y-3">
              <p className="text-sm text-gray-500">
                Tell the partner why <span className="font-semibold text-gray-800 dark:text-gray-200">{rejectTarget.label}</span> was not approved. They can fix it and resubmit.
              </p>
              <textarea
                value={rejectReason}
                onChange={(e) => setRejectReason(e.target.value)}
                rows={3}
                placeholder="e.g. RC photo is blurry / number plate doesn't match"
                className="w-full border border-gray-200 dark:border-gray-700 dark:bg-gray-800 dark:text-white rounded-lg px-3 py-2 text-sm"
              />
            </div>
            <div className="flex justify-end gap-2 px-5 py-4 border-t border-gray-200 dark:border-gray-700">
              <Button variant="outline" onClick={() => setRejectTarget(null)}>Cancel</Button>
              <Button isLoading={rejectMutation.isPending} onClick={() => rejectMutation.mutate({ id: rejectTarget.id, reason: rejectReason, kind: rejectTarget.kind })}>Reject</Button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
