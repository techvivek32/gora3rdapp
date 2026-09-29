'use client';

import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { adminApi } from '@/lib/api';
import { DataTable } from '@/components/ui/DataTable';
import { Badge } from '@/components/ui/Badge';
import { FilterBar } from '@/components/ui/FilterBar';
import { CarTaxiFront, FileText, Loader2, Star, ShieldCheck, Crown, X, UserCheck } from 'lucide-react';
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
  acceptedCount?: number;
  status: string;
  createdAt: string;
}

interface AcceptedDriver {
  offerId: string;
  driverId: string;
  name: string;
  fullName?: string;
  profileImage?: string;
  mobile?: string;
  city?: string;
  businessCities?: string[];
  rating?: number;
  totalRatings?: number;
  membershipType?: string;
  isGolden?: boolean;
  isVerified?: boolean;
  walletBalance?: number;
  vehicleNumber?: string;
  vehicleRcImage?: string;
  offerVehicle?: string;
  offerVehicleNumber?: string;
  offerVehicleImage?: string;
  assignedDriverName?: string;
  assignedDriverPhone?: string;
  completedTrips?: number;
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

/** Modal: shows every driver who accepted a booking with their full review, and
 *  lets the admin assign one. Only meaningful while the booking is OPEN. */
function AssignModal({ booking, onClose }: { booking: CustomerBooking; onClose: () => void }) {
  const queryClient = useQueryClient();
  const [error, setError] = useState('');

  const { data, isLoading } = useQuery({
    queryKey: ['customer-booking-detail', booking._id],
    queryFn: () => adminApi.getCustomerBookingDetail(booking._id),
  });
  const detail = (data as any)?.data;
  const drivers: AcceptedDriver[] = detail?.acceptedDrivers || [];

  const assign = useMutation({
    mutationFn: (driverId: string) => adminApi.assignCustomerBookingDriver(booking._id, driverId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['customer-bookings'] });
      onClose();
    },
    onError: (e: any) => setError(e?.message || 'Failed to assign driver'),
  });

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4" onClick={onClose}>
      <div
        className="bg-white dark:bg-gray-900 rounded-xl shadow-xl w-full max-w-2xl max-h-[85vh] overflow-hidden flex flex-col"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex items-start justify-between p-5 border-b border-gray-200 dark:border-gray-700">
          <div>
            <h2 className="text-lg font-bold text-gray-900 dark:text-white">Assign a Driver</h2>
            <p className="text-xs text-gray-500 mt-0.5">
              #{booking.bookingId} · {SERVICE_LABELS[booking.serviceType] || booking.serviceType} ·{' '}
              {booking.pickup?.address || '—'} → {booking.drop?.address || '—'}
            </p>
          </div>
          <button onClick={onClose} className="text-gray-400 hover:text-gray-600"><X className="w-5 h-5" /></button>
        </div>

        <div className="p-5 overflow-y-auto">
          {booking.status !== 'open' && (
            <div className="mb-4 text-sm text-gray-500 bg-gray-50 dark:bg-gray-800 rounded-lg px-3 py-2">
              This booking is <b>{booking.status}</b>
              {booking.selectedDriverId ? ` — assigned to ${booking.selectedDriverId.fullName}.` : '.'} Assignment is only possible while it is open.
            </div>
          )}
          {error && <p className="mb-3 text-red-600 text-xs bg-red-50 border border-red-200 rounded-lg px-3 py-2">{error}</p>}

          {isLoading ? (
            <div className="flex items-center gap-2 text-gray-400 text-sm py-8 justify-center">
              <Loader2 className="w-4 h-4 animate-spin" /> Loading accepted drivers…
            </div>
          ) : drivers.length === 0 ? (
            <div className="text-center text-gray-400 text-sm py-10">No driver has accepted this booking yet.</div>
          ) : (
            <div className="space-y-3">
              {drivers.map((d) => (
                <div key={d.offerId} className="border border-gray-200 dark:border-gray-700 rounded-xl p-4 flex items-start gap-3">
                  <div className="w-11 h-11 rounded-full bg-gray-100 dark:bg-gray-800 overflow-hidden flex items-center justify-center shrink-0">
                    {d.profileImage ? (
                      // eslint-disable-next-line @next/next/no-img-element
                      <img src={d.profileImage} alt={d.name} className="w-full h-full object-cover" />
                    ) : (
                      <span className="text-gray-400 font-semibold">{d.name?.[0]?.toUpperCase() || 'D'}</span>
                    )}
                  </div>
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2 flex-wrap">
                      <p className="font-semibold text-sm text-gray-900 dark:text-white">{d.name}</p>
                      {d.isGolden && <span className="inline-flex items-center gap-0.5 text-[10px] font-semibold text-amber-600 bg-amber-50 dark:bg-amber-900/20 px-1.5 py-0.5 rounded"><Crown className="w-3 h-3" /> Golden</span>}
                      {d.isVerified && <span className="inline-flex items-center gap-0.5 text-[10px] font-semibold text-green-600 bg-green-50 dark:bg-green-900/20 px-1.5 py-0.5 rounded"><ShieldCheck className="w-3 h-3" /> Verified</span>}
                    </div>
                    <div className="flex items-center gap-2 mt-1 text-xs text-gray-600 dark:text-gray-300 flex-wrap">
                      <span className="inline-flex items-center gap-0.5"><Star className="w-3 h-3 text-amber-500 fill-amber-500" /> {(d.rating || 0).toFixed(1)} <span className="text-gray-400">({d.totalRatings || 0})</span></span>
                      <span className="text-gray-300">·</span>
                      <span>{d.completedTrips || 0} trips</span>
                      {d.mobile && <><span className="text-gray-300">·</span><span>{d.mobile}</span></>}
                      {d.city && <><span className="text-gray-300">·</span><span>{d.city}</span></>}
                    </div>
                    <div className="flex items-center gap-2 mt-1 text-xs text-gray-500 flex-wrap">
                      {(d.offerVehicle || d.offerVehicleNumber) && (
                        <span>🚗 {[d.offerVehicle, d.offerVehicleNumber].filter(Boolean).join(' · ')}</span>
                      )}
                      {(d.offerVehicle || d.offerVehicleNumber) && <span className="text-gray-300">·</span>}
                      <span>Wallet ₹{d.walletBalance ?? 0}</span>
                    </div>
                    {(d.assignedDriverName || d.assignedDriverPhone) && (
                      <div className="mt-1 text-xs text-gray-600 dark:text-gray-300">
                        👤 Driver: <b>{d.assignedDriverName || '—'}</b>{d.assignedDriverPhone ? ` · ${d.assignedDriverPhone}` : ''}
                      </div>
                    )}
                  </div>
                  <button
                    onClick={() => { setError(''); assign.mutate(d.driverId); }}
                    disabled={assign.isPending || booking.status !== 'open'}
                    className="inline-flex items-center gap-1.5 px-3 py-2 rounded-lg text-xs font-semibold bg-orange-500 text-white hover:bg-orange-600 disabled:opacity-50 shrink-0"
                  >
                    {assign.isPending ? <Loader2 className="w-3.5 h-3.5 animate-spin" /> : <UserCheck className="w-3.5 h-3.5" />}
                    Assign
                  </button>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

export default function CustomerBookingsPage() {
  const [status, setStatus] = useState('');
  const [serviceType, setServiceType] = useState('');
  const [assignFor, setAssignFor] = useState<CustomerBooking | null>(null);

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
      id: 'action',
      header: 'Action',
      cell: ({ row }) => {
        if (row.original.status === 'open') {
          const n = row.original.acceptedCount || 0;
          return (
            <button
              onClick={() => setAssignFor(row.original)}
              className="inline-flex items-center gap-1.5 px-2.5 py-1.5 rounded-lg text-xs font-semibold bg-orange-500 text-white hover:bg-orange-600"
            >
              <UserCheck className="w-3.5 h-3.5" />
              Assign{n > 0 ? ` (${n})` : ''}
            </button>
          );
        }
        if (row.original.status === 'completed') {
          return <InvoiceButton id={row.original._id} bookingId={row.original.bookingId} />;
        }
        return <span className="text-xs text-gray-300 dark:text-gray-600">—</span>;
      },
    },
  ];

  return (
    <div className="space-y-6">
      <div className="flex items-center gap-2">
        <CarTaxiFront className="w-6 h-6 text-orange-500" />
        <div>
          <h1 className="text-2xl font-bold text-gray-900 dark:text-white">Customer Bookings</h1>
          <p className="text-sm text-gray-500 mt-0.5">All rides booked by customers. Open rides show the drivers who accepted — pick one to assign.</p>
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

      {assignFor && <AssignModal booking={assignFor} onClose={() => setAssignFor(null)} />}
    </div>
  );
}
