'use client';

import { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { adminApi } from '@/lib/api';
import { DataTable } from '@/components/ui/DataTable';
import { Badge } from '@/components/ui/Badge';
import { FilterBar } from '@/components/ui/FilterBar';
import { CarTaxiFront, FileText, Loader2 } from 'lucide-react';
import { formatDate } from '@/lib/utils';
import type { ColumnDef } from '@tanstack/react-table';

interface CustomerBooking {
  _id: string;
  bookingId: string;
  serviceType: string;
  subType?: string;
  customerId?: { _id: string; fullName: string; mobile: string; city?: string } | null;
  selectedDriverId?: { _id: string; fullName: string; mobile: string } | null;
  pickup?: { address?: string };
  drop?: { address?: string };
  travelDate?: string;
  travelTime?: string;
  passengers?: number;
  estimatedFare?: number;
  finalFare?: number;
  commitmentPercent?: number;
  status: string;
  createdAt: string;
}

const SERVICE_LABELS: Record<string, string> = {
  cab: 'Cabs Booking',
  hire_driver: 'Hire a Driver',
  luxury: 'Luxury Car',
  car_pool: 'Car Pooling',
};

const STATUS_COLORS: Record<string, 'warning' | 'success' | 'default' | 'destructive'> = {
  open: 'warning',
  confirmed: 'default',
  ongoing: 'default',
  completed: 'success',
  cancelled: 'destructive',
  expired: 'destructive',
};

function InvoiceButton({ id, bookingId }: { id: string; bookingId: string }) {
  const [busy, setBusy] = useState(false);
  const download = async () => {
    setBusy(true);
    try {
      const blob = await adminApi.downloadCustomerBookingInvoice(id);
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `Gora-Invoice-${bookingId}.pdf`;
      document.body.appendChild(a);
      a.click();
      a.remove();
      URL.revokeObjectURL(url);
    } catch (e: any) {
      alert(e?.message || 'Could not download invoice');
    } finally {
      setBusy(false);
    }
  };
  return (
    <button
      onClick={download}
      disabled={busy}
      className="inline-flex items-center gap-1.5 text-xs font-medium text-orange-600 hover:text-orange-700 disabled:opacity-50"
      title="Download invoice PDF"
    >
      {busy ? <Loader2 className="w-3.5 h-3.5 animate-spin" /> : <FileText className="w-3.5 h-3.5" />}
      Invoice
    </button>
  );
}

export default function CustomerBookingsPage() {
  const [status, setStatus] = useState('');
  const [serviceType, setServiceType] = useState('');

  const { data, isLoading } = useQuery({
    queryKey: ['customer-bookings', status, serviceType],
    queryFn: () => adminApi.getCustomerBookings({ status: status || undefined, serviceType: serviceType || undefined }),
  });

  const columns: ColumnDef<CustomerBooking>[] = [
    {
      id: 'booking',
      header: 'Booking',
      cell: ({ row }) => (
        <div>
          <p className="font-medium text-sm text-gray-900 dark:text-white">{SERVICE_LABELS[row.original.serviceType] || row.original.serviceType}</p>
          <p className="text-xs text-gray-500 dark:text-gray-400">#{row.original.bookingId}{row.original.subType ? ` · ${row.original.subType}` : ''}</p>
        </div>
      ),
    },
    {
      id: 'customer',
      header: 'Customer',
      cell: ({ row }) => (
        <div>
          <p className="text-sm text-gray-800 dark:text-gray-200">{row.original.customerId?.fullName || '—'}</p>
          <p className="text-xs text-gray-500">{row.original.customerId?.mobile || ''}{row.original.customerId?.city ? ` · ${row.original.customerId.city}` : ''}</p>
        </div>
      ),
    },
    {
      id: 'route',
      header: 'Route',
      cell: ({ row }) => (
        <div className="max-w-xs">
          <p className="text-xs text-gray-700 dark:text-gray-300 truncate">🟢 {row.original.pickup?.address || '—'}</p>
          {row.original.drop?.address && <p className="text-xs text-gray-700 dark:text-gray-300 truncate">🔴 {row.original.drop.address}</p>}
          <p className="text-[11px] text-gray-400 mt-0.5">{row.original.travelDate ? new Date(row.original.travelDate).toLocaleDateString() : ''} {row.original.travelTime || ''} · 👥 {row.original.passengers || 1}</p>
        </div>
      ),
    },
    {
      id: 'driver',
      header: 'Driver',
      cell: ({ row }) =>
        row.original.selectedDriverId ? (
          <div>
            <p className="text-sm text-gray-800 dark:text-gray-200">{row.original.selectedDriverId.fullName}</p>
            <p className="text-xs text-gray-500">{row.original.selectedDriverId.mobile}</p>
          </div>
        ) : (
          <span className="text-xs text-gray-400">—</span>
        ),
    },
    {
      id: 'fare',
      header: 'Fare',
      cell: ({ row }) => (
        <div className="text-sm">
          {row.original.finalFare ? (
            <span className="font-semibold text-gray-900 dark:text-white">₹{row.original.finalFare}</span>
          ) : row.original.estimatedFare ? (
            <span className="text-gray-500">₹{row.original.estimatedFare} <span className="text-[10px]">budget</span></span>
          ) : (
            <span className="text-gray-400">—</span>
          )}
          {typeof row.original.commitmentPercent === 'number' && (
            <p className="text-[10px] text-gray-400">{row.original.commitmentPercent}% hold</p>
          )}
        </div>
      ),
    },
    {
      accessorKey: 'status',
      header: 'Status',
      cell: ({ row }) => <Badge variant={STATUS_COLORS[row.original.status] || 'default'}>{row.original.status}</Badge>,
    },
    {
      accessorKey: 'createdAt',
      header: 'Created',
      cell: ({ row }) => <span className="text-xs text-gray-500 dark:text-gray-400">{formatDate(row.original.createdAt)}</span>,
    },
    {
      id: 'invoice',
      header: 'Invoice',
      cell: ({ row }) =>
        row.original.status === 'completed' ? (
          <InvoiceButton id={row.original._id} bookingId={row.original.bookingId} />
        ) : (
          <span className="text-xs text-gray-300 dark:text-gray-600">—</span>
        ),
    },
  ];

  return (
    <div className="space-y-6">
      <div className="flex items-center gap-2">
        <CarTaxiFront className="w-6 h-6 text-orange-500" />
        <div>
          <h1 className="text-2xl font-bold text-gray-900 dark:text-white">Customer Bookings</h1>
          <p className="text-sm text-gray-500 mt-0.5">All rides booked by customers (Cabs, Hire a Driver, Luxury, Car Pool)</p>
        </div>
      </div>

      <FilterBar>
        <select
          value={serviceType}
          onChange={(e) => setServiceType(e.target.value)}
          className="border border-gray-200 dark:border-gray-700 dark:bg-gray-800 dark:text-white rounded-lg px-3 py-2 text-sm"
        >
          <option value="">All Services</option>
          <option value="cab">Cabs Booking</option>
          <option value="hire_driver">Hire a Driver</option>
          <option value="luxury">Luxury Car</option>
          <option value="car_pool">Car Pooling</option>
        </select>
        <select
          value={status}
          onChange={(e) => setStatus(e.target.value)}
          className="border border-gray-200 dark:border-gray-700 dark:bg-gray-800 dark:text-white rounded-lg px-3 py-2 text-sm"
        >
          <option value="">All Status</option>
          <option value="open">Open</option>
          <option value="confirmed">Confirmed</option>
          <option value="ongoing">Ongoing</option>
          <option value="completed">Completed</option>
          <option value="cancelled">Cancelled</option>
          <option value="expired">Expired</option>
        </select>
      </FilterBar>

      <div className="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-700 overflow-hidden">
        <DataTable columns={columns} data={data?.data || []} isLoading={isLoading} />
      </div>
    </div>
  );
}
