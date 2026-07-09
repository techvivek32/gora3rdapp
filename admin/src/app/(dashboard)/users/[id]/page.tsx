'use client';

import { use, useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { adminApi } from '@/lib/api';
import { Badge } from '@/components/ui/Badge';
import { Button } from '@/components/ui/Button';
import { MembershipBadge } from '@/components/ui/MembershipBadge';
import { DataTable } from '@/components/ui/DataTable';
import { formatDate } from '@/lib/utils';
import { useRouter } from 'next/navigation';
import toast from 'react-hot-toast';
import {
  ArrowLeft, Phone, Mail, Building2, MapPin, ShieldCheck,
  FileText, ClipboardList, Car, Star, Wallet, Ban, CheckCircle2,
  Calendar, User, CreditCard, ArrowUpRight, FileCheck, CheckSquare,
  Eye, Pencil, Trash2, X,
} from 'lucide-react';
import type { ColumnDef } from '@tanstack/react-table';
import { RequirementEditModal } from '@/components/requirements/RequirementEditModal';
import { VehicleEditModal } from '@/components/vehicles/VehicleEditModal';

interface Requirement {
  _id: string;
  bookingId: string;
  requirementId: string;
  pickupCity: string;
  dropCity: string;
  vehicleType: string;
  tripType: string;
  travelDate: string;
  status: string;
  notes?: string;
  totalAmount?: number;
  fare?: number;
  postedBy: { fullName: string; membershipType: string };
  viewCount: number;
  createdAt: string;
}

interface Vehicle {
  _id: string;
  listingId: string;
  currentCity: string;
  destinationCity?: string;
  vehicleType: string;
  vehicleNumber: string;
  driverName: string;
  status: string;
  availableDate: string;
  viewCount: number;
  notes?: string;
  postedBy: { fullName: string; membershipType: string };
}

const STATUS_COLORS: Record<string, 'default' | 'success' | 'destructive' | 'warning' | 'secondary'> = {
  active: 'success',
  pending: 'warning',
  accepted: 'success',
  completed: 'success',
  cancelled: 'destructive',
  on_hold: 'warning',
  expired: 'secondary',
};

const VEHICLE_STATUS_COLORS: Record<string, 'default' | 'success' | 'destructive' | 'secondary'> = {
  available: 'success',
  booked: 'default',
  expired: 'secondary',
  inactive: 'destructive',
};

const TRIP_COLORS: Record<string, string> = {
  one_way: 'bg-blue-100 text-blue-700',
  round_trip: 'bg-green-100 text-green-700',
  airport_transfer: 'bg-purple-100 text-purple-700',
  local: 'bg-orange-100 text-orange-700',
  outstation: 'bg-teal-100 text-teal-700',
};

const DOCS = [
  { key: 'aadhar', label: 'Aadhaar Card' },
  { key: 'pan', label: 'PAN Card' },
  { key: 'drivingLicense', label: 'Driving License' },
  { key: 'vehicleRc', label: 'Vehicle RC' },
];

const TABS = [
  { id: 'profile', label: 'User Profile', icon: User },
  { id: 'requests', label: 'Request List', icon: ClipboardList },
  { id: 'payments', label: 'Payment History', icon: CreditCard },
  { id: 'withdrawals', label: 'Withdrawal History', icon: ArrowUpRight },
  { id: 'reviews', label: 'Review History', icon: Star },
  { id: 'documents', label: 'Documents', icon: FileCheck },
  { id: 'subscription', label: 'Subscription', icon: CheckSquare },
];

function verificationBadge(status?: string) {
  switch (status) {
    case 'verified':
      return <Badge variant="success">Verified</Badge>;
    case 'pending':
      return <Badge variant="warning">Pending Review</Badge>;
    case 'rejected':
      return <Badge variant="destructive">Rejected</Badge>;
    default:
      return <Badge variant="secondary">Not Submitted</Badge>;
  }
}

export default function UserDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const router = useRouter();
  const queryClient = useQueryClient();
  const [activeTab, setActiveTab] = useState('profile');
  const [activeView, setActiveView] = useState<'requirements' | 'vehicles'>('requirements');
  const [modal, setModal] = useState<{ mode: 'view' | 'edit'; r: Requirement } | null>(null);
  const [vehicleModal, setVehicleModal] = useState<{ mode: 'view' | 'edit'; v: Vehicle } | null>(null);
  const [reviewModal, setReviewModal] = useState<any | null>(null);
  const [assignPlanModal, setAssignPlanModal] = useState(false);
  const [editSubModal, setEditSubModal] = useState<any | null>(null);

  const { data, isLoading } = useQuery({
    queryKey: ['user', id],
    queryFn: () => adminApi.getUser(id),
  });

  const { data: requestsData } = useQuery({
    queryKey: ['user-requests', id],
    queryFn: () => adminApi.getUserRequirements(id),
    enabled: activeTab === 'requests',
  });

  const { data: vehiclesData } = useQuery({
    queryKey: ['user-vehicles', id],
    queryFn: () => adminApi.getUserVehicles(id),
    enabled: activeTab === 'requests',
  });

  const deleteMutation = useMutation({
    mutationFn: (reqId: string) => adminApi.deleteRequirement(reqId),
    onSuccess: () => { toast.success('Requirement deleted'); queryClient.invalidateQueries({ queryKey: ['user-requests', id] }); queryClient.invalidateQueries({ queryKey: ['user', id] }); },
    onError: (e: any) => toast.error(e?.message || 'Could not delete'),
  });

  const deleteVehicleMutation = useMutation({
    mutationFn: (vehicleId: string) => adminApi.deleteVehicle(vehicleId),
    onSuccess: () => { toast.success('Vehicle deleted'); queryClient.invalidateQueries({ queryKey: ['user-vehicles', id] }); queryClient.invalidateQueries({ queryKey: ['user', id] }); },
    onError: (e: any) => toast.error(e?.message || 'Could not delete'),
  });

  const deleteReviewMutation = useMutation({
    mutationFn: (reviewId: string) => adminApi.deleteReview(reviewId),
    onSuccess: () => { toast.success('Review deleted'); queryClient.invalidateQueries({ queryKey: ['user-reviews', id] }); queryClient.invalidateQueries({ queryKey: ['user', id] }); },
    onError: (e: any) => toast.error(e?.message || 'Could not delete'),
  });

  const cancelSubMutation = useMutation({
    mutationFn: (subId: string) => adminApi.cancelSubscription(subId),
    onSuccess: () => { toast.success('Subscription cancelled'); queryClient.invalidateQueries({ queryKey: ['user-subscriptions', id] }); queryClient.invalidateQueries({ queryKey: ['user', id] }); },
    onError: (e: any) => toast.error(e?.message || 'Could not cancel'),
  });

  const columns: ColumnDef<Requirement>[] = [
    {
      accessorKey: 'bookingId',
      header: 'Booking ID',
      cell: ({ row }) => <span className="font-mono text-xs font-semibold">{row.getValue('bookingId')}</span>,
    },
    {
      id: 'route',
      header: 'Route',
      cell: ({ row }) => (
        <div>
          <p className="font-medium">{row.original.pickupCity} → {row.original.dropCity}</p>
          <span className={`text-xs px-2 py-0.5 rounded font-medium ${TRIP_COLORS[row.original.tripType] || 'bg-gray-100 text-gray-700'}`}>
            {row.original.tripType?.replace('_', ' ').toUpperCase()}
          </span>
        </div>
      ),
    },
    {
      accessorKey: 'vehicleType',
      header: 'Vehicle',
      cell: ({ row }) => <span className="capitalize">{row.getValue<string>('vehicleType')?.replace('_', ' ')}</span>,
    },
    {
      accessorKey: 'travelDate',
      header: 'Travel Date',
      cell: ({ row }) => new Date(row.getValue('travelDate')).toLocaleDateString('en-IN'),
    },
    {
      accessorKey: 'totalAmount',
      header: 'Fare',
      cell: ({ row }) => `₹${row.original.totalAmount ?? row.original.fare ?? 0}`,
    },
    {
      accessorKey: 'status',
      header: 'Status',
      cell: ({ row }) => { const s = row.getValue('status') as string; return <Badge variant={STATUS_COLORS[s] || 'default'}>{s}</Badge>; },
    },
    {
      id: 'actions',
      header: 'Actions',
      cell: ({ row }) => (
        <div className="flex items-center gap-1">
          <IconBtn title="View" onClick={() => setModal({ mode: 'view', r: row.original })}><Eye className="w-4 h-4" /></IconBtn>
          <IconBtn title="Edit" onClick={() => setModal({ mode: 'edit', r: row.original })}><Pencil className="w-4 h-4" /></IconBtn>
          <IconBtn title="Delete" danger onClick={() => { if (confirm('Delete this requirement?')) deleteMutation.mutate(row.original._id); }}><Trash2 className="w-4 h-4" /></IconBtn>
        </div>
      ),
    },
  ];

  const vehicleColumns: ColumnDef<Vehicle>[] = [
    {
      accessorKey: 'listingId',
      header: 'Listing ID',
      cell: ({ row }) => <span className="font-mono text-xs font-semibold">{row.getValue('listingId')}</span>,
    },
    {
      id: 'location',
      header: 'Location',
      cell: ({ row }) => (
        <span className="font-medium">
          {row.original.currentCity}
          {row.original.destinationCity ? ` → ${row.original.destinationCity}` : ''}
        </span>
      ),
    },
    {
      accessorKey: 'vehicleType',
      header: 'Type',
      cell: ({ row }) => <span className="capitalize">{row.getValue<string>('vehicleType')?.replace('_', ' ')}</span>,
    },
    {
      accessorKey: 'driverName',
      header: 'Driver',
    },
    {
      accessorKey: 'availableDate',
      header: 'Available',
      cell: ({ row }) => new Date(row.getValue('availableDate')).toLocaleDateString('en-IN'),
    },
    {
      accessorKey: 'status',
      header: 'Status',
      cell: ({ row }) => { const s = row.getValue('status') as string; return <Badge variant={VEHICLE_STATUS_COLORS[s] || 'default'}>{s}</Badge>; },
    },
    { accessorKey: 'viewCount', header: 'Views' },
    {
      id: 'actions',
      header: 'Actions',
      cell: ({ row }) => (
        <div className="flex items-center gap-1">
          <IconBtn title="View" onClick={() => setVehicleModal({ mode: 'view', v: row.original })}><Eye className="w-4 h-4" /></IconBtn>
          <IconBtn title="Edit" onClick={() => setVehicleModal({ mode: 'edit', v: row.original })}><Pencil className="w-4 h-4" /></IconBtn>
          <IconBtn title="Delete" danger onClick={() => { if (confirm('Delete this vehicle listing?')) deleteVehicleMutation.mutate(row.original._id); }}><Trash2 className="w-4 h-4" /></IconBtn>
        </div>
      ),
    },
  ];

  const { data: paymentsData } = useQuery({
    queryKey: ['user-payments', id],
    queryFn: () => adminApi.getUserPayments(id),
    enabled: activeTab === 'payments',
  });

  const { data: withdrawalsData } = useQuery({
    queryKey: ['user-withdrawals', id],
    queryFn: () => adminApi.getUserWithdrawals(id),
    enabled: activeTab === 'withdrawals',
  });

  const { data: reviewsData } = useQuery({
    queryKey: ['user-reviews', id],
    queryFn: () => adminApi.getUserReviews(id),
    enabled: activeTab === 'reviews',
  });

  const { data: subscriptionsData } = useQuery({
    queryKey: ['user-subscriptions', id],
    queryFn: () => adminApi.getUserSubscriptions(id),
    enabled: activeTab === 'subscription',
  });

  const blockMutation = useMutation({
    mutationFn: (block: boolean) => adminApi[block ? 'blockUser' : 'unblockUser'](id),
    onSuccess: (_, block) => { toast.success(block ? 'User blocked' : 'User unblocked'); queryClient.invalidateQueries({ queryKey: ['user', id] }); },
  });

  if (isLoading) return <div className="h-96 bg-gray-100 dark:bg-gray-800 rounded-xl animate-pulse" />;

  const user = (data as any)?.data;
  if (!user) return <div className="text-center py-12 text-gray-500">User not found</div>;

  const providedDocs = DOCS
    .map((d) => ({ ...d, doc: user.documents?.[d.key] }))
    .filter((d) => d.doc && (d.doc.number || d.doc.image || d.doc.backImage));

  const cardCls = 'bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-700';

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <button
          onClick={() => router.back()}
          className="inline-flex items-center gap-1.5 text-sm font-medium text-gray-500 hover:text-gray-800 dark:hover:text-gray-200"
        >
          <ArrowLeft className="w-4 h-4" /> Back to Users
        </button>
        <Button
          variant={user.isBlocked ? 'default' : 'destructive'}
          onClick={() => blockMutation.mutate(!user.isBlocked)}
          isLoading={blockMutation.isPending}
        >
          {user.isBlocked ? <CheckCircle2 className="w-4 h-4 mr-2" /> : <Ban className="w-4 h-4 mr-2" />}
          {user.isBlocked ? 'Unblock' : 'Block'}
        </Button>
      </div>

      {/* Top Profile Section */}
      <div className={`${cardCls} p-6`}>
        <div className="flex flex-col lg:flex-row lg:items-center gap-6">
          {/* Left Side - Profile */}
          <div className="flex items-center gap-4 flex-1">
            <div className="w-28 h-28 rounded-full bg-gray-100 dark:bg-gray-800 flex items-center justify-center overflow-hidden shadow-lg ring-4 ring-orange-500/20">
              {user.profileImage ? (
                <img src={user.profileImage} alt={user.fullName} className="w-full h-full object-cover" />
              ) : (
                <span className="text-4xl font-bold text-orange-500">{user.fullName?.[0]?.toUpperCase()}</span>
              )}
            </div>
            <div>
              {user.agencyName && (
                <p className="text-sm text-gray-500 dark:text-gray-400">{user.agencyName}</p>
              )}
              <h2 className="text-2xl font-bold text-gray-900 dark:text-white">{user.fullName}</h2>
              {user.city && (
                <div className="flex items-center gap-1.5 text-gray-600 dark:text-gray-300 mt-1">
                  <MapPin className="w-4 h-4" />
                  <span>{user.city}</span>
                </div>
              )}
            </div>
          </div>

          {/* Middle - Contact Info */}
          <div className="flex-1 border-l border-gray-200 dark:border-gray-700 pl-6 space-y-3">
            <div className="flex items-center gap-3">
              <Phone className="w-6 h-6 text-gray-400" />
              <div>
                <p className="text-xs text-gray-500">Phone</p>
                <p className="font-semibold text-gray-800 dark:text-gray-200">{user.mobile}</p>
              </div>
            </div>
            <div className="flex items-center gap-3">
              <Mail className="w-6 h-6 text-gray-400" />
              <div>
                <p className="text-xs text-gray-500">Email</p>
                <p className="font-semibold text-gray-800 dark:text-gray-200">{user.email}</p>
              </div>
            </div>
            <div className="flex items-center gap-3">
              <Calendar className="w-6 h-6 text-gray-400" />
              <div>
                <p className="text-xs text-gray-500">Join Date</p>
                <p className="font-semibold text-gray-800 dark:text-gray-200">{user.createdAt ? formatDate(user.createdAt) : '—'}</p>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Tabs */}
      <div className={`${cardCls} overflow-hidden`}>
        <div className="border-b border-gray-200 dark:border-gray-700 overflow-x-auto">
          <div className="flex min-w-max">
            {TABS.map((tab) => {
              const Icon = tab.icon;
              return (
                <button
                  key={tab.id}
                  onClick={() => setActiveTab(tab.id)}
                  className={`px-6 py-4 font-medium text-sm whitespace-nowrap transition-colors relative
                    ${activeTab === tab.id
                      ? 'text-orange-600 dark:text-orange-400 bg-orange-50 dark:bg-orange-900/20'
                      : 'text-gray-600 dark:text-gray-400 hover:text-gray-800 dark:hover:text-gray-200 hover:bg-gray-50 dark:hover:bg-gray-800'
                    }`}
                >
                  <div className="flex items-center gap-2">
                    <Icon className="w-4 h-4" />
                    {tab.label}
                  </div>
                  {activeTab === tab.id && (
                    <div className="absolute bottom-0 left-0 right-0 h-0.5 bg-orange-500" />
                  )}
                </button>
              );
            })}
          </div>
        </div>

        {/* Tab Content */}
        <div className="p-6">
          {/* User Profile Tab */}
          {activeTab === 'profile' && (
            <div className="space-y-6">
              {/* Activity Stats */}
              <div>
                <h3 className="font-semibold mb-4 text-gray-900 dark:text-white">Activity Stats</h3>
                <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
                  {[
                    { label: 'Requirements', value: user.requirementsPosted ?? 0, icon: ClipboardList, color: 'text-blue-500' },
                    { label: 'Vehicles', value: user.vehiclesPosted ?? 0, icon: Car, color: 'text-green-500' },
                    { label: 'Rating', value: user.rating ? user.rating.toFixed(1) : '—', icon: Star, color: 'text-amber-500' },
                    { label: 'Wallet', value: `₹${user.walletBalance ?? 0}`, icon: Wallet, color: 'text-orange-500' },
                  ].map(({ label, value, icon: Icon, color }) => (
                    <div key={label} className="bg-gray-50 dark:bg-gray-800 rounded-xl p-4 text-center">
                      <Icon className={`w-5 h-5 mx-auto mb-1.5 ${color}`} />
                      <p className="text-xl font-bold text-gray-900 dark:text-white">{value}</p>
                      <p className="text-xs text-gray-500 mt-0.5">{label}</p>
                    </div>
                  ))}
                </div>
              </div>

              {/* Basic Info */}
              <div>
                <h3 className="font-semibold mb-4 text-gray-900 dark:text-white">Basic Information</h3>
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                  {[
                    { key: 'mobile', label: 'Mobile', value: user.mobile, icon: Phone },
                    { key: 'email', label: 'Email', value: user.email, icon: Mail },
                    { key: 'agencyName', label: 'Agency', value: user.agencyName, icon: Building2 },
                    { key: 'city', label: 'City', value: user.city, icon: MapPin },
                    { key: 'state', label: 'State', value: user.state, icon: MapPin },
                    { key: 'role', label: 'Role', value: user.role, icon: User },
                  ].filter(f => f.value).map(({ label, value, icon: Icon }) => (
                    <div key={label} className="flex items-start gap-3 p-3 bg-gray-50 dark:bg-gray-800 rounded-lg">
                      <div className="w-9 h-9 rounded-lg bg-white dark:bg-gray-900 flex items-center justify-center flex-shrink-0">
                        <Icon className="w-4 h-4 text-gray-500" />
                      </div>
                      <div className="min-w-0">
                        <p className="text-xs text-gray-400">{label}</p>
                        <p className="font-medium text-sm text-gray-800 dark:text-gray-100 truncate capitalize">
                          {String(value).replace(/_/g, ' ')}
                        </p>
                      </div>
                    </div>
                  ))}
                </div>
              </div>

              {/* Business Cities */}
              {user.businessCities?.length > 0 && (
                <div>
                  <h3 className="font-semibold mb-3 text-gray-900 dark:text-white">Business Cities</h3>
                  <div className="flex flex-wrap gap-2">
                    {user.businessCities.map((city: string) => (
                      <span key={city} className="bg-orange-50 dark:bg-orange-900/20 text-orange-700 dark:text-orange-300 px-3 py-1 rounded-full text-sm font-medium">{city}</span>
                    ))}
                  </div>
                </div>
              )}

            </div>
          )}

          {/* Documents Tab */}
          {activeTab === 'documents' && (
            <div>
              <div className="flex items-center justify-between mb-4">
                <h3 className="font-semibold flex items-center gap-2 text-gray-900 dark:text-white">
                  <ShieldCheck className="w-5 h-5 text-orange-500" /> KYC Documents
                </h3>
                {verificationBadge(user.verificationStatus)}
              </div>

              {user.verificationSubmittedAt && (
                <p className="text-xs text-gray-400 mb-3">Submitted on {formatDate(user.verificationSubmittedAt)}</p>
              )}
              {user.verificationStatus === 'rejected' && user.verificationRejectionReason && (
                <div className="mb-4 rounded-lg bg-red-50 dark:bg-red-900/20 text-red-600 dark:text-red-300 px-3 py-2 text-sm">
                  <span className="font-semibold">Rejection reason:</span> {user.verificationRejectionReason}
                </div>
              )}

              {providedDocs.length > 0 ? (
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                  {providedDocs.map(({ key, label, doc }) => (
                    <div key={key} className="rounded-xl border border-gray-200 dark:border-gray-700 overflow-hidden">
                      <div className="flex items-center justify-between px-3 py-2 bg-gray-50 dark:bg-gray-800">
                        <span className="text-sm font-medium flex items-center gap-1.5 text-gray-700 dark:text-gray-200">
                          <FileText className="w-4 h-4 text-gray-400" /> {label}
                        </span>
                        {doc.number && (
                          <span className="text-xs font-mono bg-white dark:bg-gray-900 px-2 py-0.5 rounded border border-gray-200 dark:border-gray-700">
                            {doc.number}
                          </span>
                        )}
                      </div>
                      <div className="p-2 space-y-2">
                        <DocImage label="Front Side" src={doc.image} alt={`${label} front`} />
                        <DocImage label="Back Side" src={doc.backImage} alt={`${label} back`} />
                      </div>
                    </div>
                  ))}
                </div>
              ) : (
                <div className="flex flex-col items-center justify-center py-12 text-center">
                  <ClipboardList className="w-10 h-10 text-gray-300 mb-2" />
                  <p className="text-sm text-gray-400">This user hasn&apos;t submitted any KYC documents yet.</p>
                </div>
              )}
            </div>
          )}

          {/* Request List Tab */}
          {activeTab === 'requests' && (
            <div>
              <div className="flex items-center justify-between mb-4">
                <h3 className="font-semibold text-gray-900 dark:text-white">
                  {activeView === 'requirements' ? 'Requirements Posted' : 'Available Cabs'}
                </h3>
                <div className="flex bg-gray-100 dark:bg-gray-800 rounded-lg p-1">
                  <button
                    onClick={() => setActiveView('requirements')}
                    className={`px-4 py-2 rounded-md text-sm font-medium transition-colors ${
                      activeView === 'requirements'
                        ? 'bg-white dark:bg-gray-700 text-gray-900 dark:text-white shadow-sm'
                        : 'text-gray-600 dark:text-gray-400 hover:text-gray-900 dark:hover:text-gray-200'
                    }`}
                  >
                    Requirements
                  </button>
                  <button
                    onClick={() => setActiveView('vehicles')}
                    className={`px-4 py-2 rounded-md text-sm font-medium transition-colors ${
                      activeView === 'vehicles'
                        ? 'bg-white dark:bg-gray-700 text-gray-900 dark:text-white shadow-sm'
                        : 'text-gray-600 dark:text-gray-400 hover:text-gray-900 dark:hover:text-gray-200'
                    }`}
                  >
                    Available Cabs
                  </button>
                </div>
              </div>
              
              {activeView === 'requirements' ? (
                <DataTable
                  columns={columns}
                  data={(requestsData as any)?.data ?? []}
                  isLoading={false}
                />
              ) : (
                <DataTable
                  columns={vehicleColumns}
                  data={(vehiclesData as any)?.data ?? []}
                  isLoading={false}
                />
              )}
            </div>
          )}

          {/* Payment History Tab */}
          {activeTab === 'payments' && (
            <div>
              <h3 className="font-semibold mb-4 text-gray-900 dark:text-white">Payment History</h3>
              {(() => {
                const items = (paymentsData as any)?.data ?? [];
                if (!items.length) return (
                  <div className="flex flex-col items-center justify-center py-12 text-center">
                    <CreditCard className="w-10 h-10 text-gray-300 mb-2" />
                    <p className="text-sm text-gray-400">No payments found.</p>
                  </div>
                );
                return (
                  <div className="overflow-x-auto">
                    <table className="w-full text-sm">
                      <thead>
                        <tr className="border-b border-gray-200 dark:border-gray-700 text-left">
                          <th className="pb-3 pr-4 font-medium text-gray-500">Order ID</th>
                          <th className="pb-3 pr-4 font-medium text-gray-500">Plan</th>
                          <th className="pb-3 pr-4 font-medium text-gray-500">Amount</th>
                          <th className="pb-3 pr-4 font-medium text-gray-500">Method</th>
                          <th className="pb-3 pr-4 font-medium text-gray-500">Date</th>
                          <th className="pb-3 font-medium text-gray-500">Status</th>
                        </tr>
                      </thead>
                      <tbody className="divide-y divide-gray-100 dark:divide-gray-800">
                        {items.map((p: any) => (
                          <tr key={p._id} className="hover:bg-gray-50 dark:hover:bg-gray-800/50">
                            <td className="py-3 pr-4 font-mono text-xs text-gray-600 dark:text-gray-400">{p.orderId ?? '—'}</td>
                            <td className="py-3 pr-4 text-gray-800 dark:text-gray-200">{p.planId?.name ?? '—'}</td>
                            <td className="py-3 pr-4 font-semibold text-gray-800 dark:text-gray-200">₹{((p.amount ?? 0) / 100).toFixed(0)}</td>
                            <td className="py-3 pr-4 capitalize text-gray-600 dark:text-gray-400">{p.method ?? 'razorpay'}</td>
                            <td className="py-3 pr-4 text-gray-600 dark:text-gray-400">{p.createdAt ? formatDate(p.createdAt) : '—'}</td>
                            <td className="py-3">
                              <Badge variant={p.status === 'success' ? 'success' : p.status === 'failed' ? 'destructive' : 'warning'}>
                                {p.status}
                              </Badge>
                            </td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                );
              })()}
            </div>
          )}

          {/* Withdrawal History Tab */}
          {activeTab === 'withdrawals' && (
            <div>
              <h3 className="font-semibold mb-4 text-gray-900 dark:text-white">Withdrawal History</h3>
              {(() => {
                const items = (withdrawalsData as any)?.data ?? [];
                if (!items.length) return (
                  <div className="flex flex-col items-center justify-center py-12 text-center">
                    <ArrowUpRight className="w-10 h-10 text-gray-300 mb-2" />
                    <p className="text-sm text-gray-400">No withdrawal requests found.</p>
                  </div>
                );
                return (
                  <div className="overflow-x-auto">
                    <table className="w-full text-sm">
                      <thead>
                        <tr className="border-b border-gray-200 dark:border-gray-700 text-left">
                          <th className="pb-3 pr-4 font-medium text-gray-500">Amount</th>
                          <th className="pb-3 pr-4 font-medium text-gray-500">Bank</th>
                          <th className="pb-3 pr-4 font-medium text-gray-500">Account</th>
                          <th className="pb-3 pr-4 font-medium text-gray-500">IFSC</th>
                          <th className="pb-3 pr-4 font-medium text-gray-500">Date</th>
                          <th className="pb-3 font-medium text-gray-500">Status</th>
                        </tr>
                      </thead>
                      <tbody className="divide-y divide-gray-100 dark:divide-gray-800">
                        {items.map((w: any) => (
                          <tr key={w._id} className="hover:bg-gray-50 dark:hover:bg-gray-800/50">
                            <td className="py-3 pr-4 font-semibold text-gray-800 dark:text-gray-200">₹{w.amount}</td>
                            <td className="py-3 pr-4 text-gray-800 dark:text-gray-200">{w.bankName}</td>
                            <td className="py-3 pr-4 font-mono text-xs text-gray-600 dark:text-gray-400">{w.accountNumber}</td>
                            <td className="py-3 pr-4 font-mono text-xs text-gray-600 dark:text-gray-400">{w.ifsc}</td>
                            <td className="py-3 pr-4 text-gray-600 dark:text-gray-400">{w.createdAt ? formatDate(w.createdAt) : '—'}</td>
                            <td className="py-3">
                              <Badge variant={w.status === 'approved' ? 'success' : w.status === 'rejected' ? 'destructive' : 'warning'}>
                                {w.status}
                              </Badge>
                            </td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                );
              })()}
            </div>
          )}

          {/* Review History Tab */}
          {activeTab === 'reviews' && (
            <div>
              <h3 className="font-semibold mb-4 text-gray-900 dark:text-white">Reviews Received</h3>
              {(() => {
                const items = (reviewsData as any)?.data ?? [];
                if (!items.length) return (
                  <div className="flex flex-col items-center justify-center py-12 text-center">
                    <Star className="w-10 h-10 text-gray-300 mb-2" />
                    <p className="text-sm text-gray-400">No reviews yet.</p>
                  </div>
                );
                return (
                  <div className="space-y-3">
                    {items.map((r: any) => (
                      <div key={r._id} className="flex gap-4 p-4 bg-gray-50 dark:bg-gray-800 rounded-xl">
                        <div className="w-10 h-10 rounded-full bg-orange-100 dark:bg-orange-900/30 flex items-center justify-center flex-shrink-0 overflow-hidden">
                          {r.rater?.profileImage
                            ? <img src={r.rater.profileImage} alt="" className="w-full h-full object-cover" />
                            : <span className="text-orange-600 font-bold text-sm">{r.rater?.fullName?.[0]?.toUpperCase() ?? '?'}</span>
                          }
                        </div>
                        <div className="flex-1 min-w-0">
                          <div className="flex items-center justify-between gap-2">
                            <p className="font-medium text-gray-800 dark:text-gray-200">{r.rater?.fullName ?? 'Unknown'}</p>
                            <div className="flex items-center gap-2">
                              <div className="flex items-center gap-1">
                                {Array.from({ length: 5 }).map((_, i) => (
                                  <Star key={i} className={`w-3.5 h-3.5 ${i < r.stars ? 'text-amber-400 fill-amber-400' : 'text-gray-300'}`} />
                                ))}
                              </div>
                              <IconBtn title="Edit" onClick={() => setReviewModal(r)}><Pencil className="w-4 h-4" /></IconBtn>
                              <IconBtn title="Delete" danger onClick={() => { if (confirm('Delete this review?')) deleteReviewMutation.mutate(r._id); }}><Trash2 className="w-4 h-4" /></IconBtn>
                            </div>
                          </div>
                          {r.review && <p className="text-sm text-gray-600 dark:text-gray-400 mt-1">{r.review}</p>}
                          <p className="text-xs text-gray-400 mt-1">{r.createdAt ? formatDate(r.createdAt) : ''}</p>
                        </div>
                      </div>
                    ))}
                  </div>
                );
              })()}
            </div>
          )}

          {/* Subscription Tab */}
          {activeTab === 'subscription' && (
            <div>
              <div className="flex items-center justify-between mb-4">
                <h3 className="font-semibold text-gray-900 dark:text-white">Subscription History</h3>
                <Button onClick={() => setAssignPlanModal(true)}>Assign Plan</Button>
              </div>
              {(() => {
                const items = (subscriptionsData as any)?.data ?? [];
                if (!items.length) return (
                  <div className="flex flex-col items-center justify-center py-12 text-center">
                    <CheckSquare className="w-10 h-10 text-gray-300 mb-2" />
                    <p className="text-sm text-gray-400">No subscriptions found.</p>
                  </div>
                );
                return (
                  <div className="space-y-3">
                    {items.map((s: any) => {
                      const tier = s.membershipType ?? s.planId?.membershipType;
                      const statusVariant = s.status === 'active' ? 'success' : s.status === 'expired' ? 'secondary' : 'destructive';
                      return (
                        <div key={s._id} className={`flex items-center justify-between p-4 rounded-xl border ${
                          s.status === 'active'
                            ? 'bg-green-50 dark:bg-green-900/10 border-green-200 dark:border-green-800'
                            : 'bg-gray-50 dark:bg-gray-800 border-gray-200 dark:border-gray-700'
                        }`}>
                          <div className="flex items-center gap-3">
                            <MembershipBadge type={tier} />
                            <div>
                              <div className="flex items-center gap-2">
                                <p className="font-medium text-gray-800 dark:text-gray-200">{s.planId?.name ?? 'Plan'}</p>
                                <Badge variant={statusVariant}>{s.status}</Badge>
                              </div>
                              <p className="text-xs text-gray-500">
                                {s.startDate ? formatDate(s.startDate) : '—'} → {s.endDate ? formatDate(s.endDate) : '—'}
                              </p>
                            </div>
                          </div>
                          <div className="flex items-center gap-3">
                            <div className="text-right">
                              <p className="font-semibold text-gray-800 dark:text-gray-200">₹{Math.round((s.amount ?? 0) / 100).toLocaleString('en-IN')}</p>
                            </div>
                            {s.status === 'active' && (
                              <div className="flex gap-1">
                                <IconBtn title="Edit End Date" onClick={() => setEditSubModal(s)}><Pencil className="w-4 h-4" /></IconBtn>
                                <IconBtn title="Cancel Plan" danger onClick={() => { if (confirm('Cancel this subscription?')) cancelSubMutation.mutate(s._id); }}><X className="w-4 h-4" /></IconBtn>
                              </div>
                            )}
                          </div>
                        </div>
                      );
                    })}
                  </div>
                );
              })()}
            </div>
          )}
        </div>
      </div>

      {modal && (
        <RequirementEditModal
          req={modal.r}
          mode={modal.mode}
          onClose={() => setModal(null)}
          onSaved={() => { queryClient.invalidateQueries({ queryKey: ['user-requests', id] }); queryClient.invalidateQueries({ queryKey: ['user', id] }); setModal(null); }}
        />
      )}

      {vehicleModal && (
        <VehicleEditModal
          vehicle={vehicleModal.v}
          mode={vehicleModal.mode}
          onClose={() => setVehicleModal(null)}
          onSaved={() => { queryClient.invalidateQueries({ queryKey: ['user-vehicles', id] }); setVehicleModal(null); }}
        />
      )}

      {reviewModal && (
        <ReviewModal
          review={reviewModal}
          onClose={() => setReviewModal(null)}
          onSaved={() => { queryClient.invalidateQueries({ queryKey: ['user-reviews', id] }); queryClient.invalidateQueries({ queryKey: ['user', id] }); setReviewModal(null); }}
        />
      )}

      {assignPlanModal && (
        <AssignPlanModal
          userId={id}
          onClose={() => setAssignPlanModal(false)}
          onSaved={() => { queryClient.invalidateQueries({ queryKey: ['user-subscriptions', id] }); queryClient.invalidateQueries({ queryKey: ['user', id] }); setAssignPlanModal(false); }}
        />
      )}

      {editSubModal && (
        <EditSubEndDateModal
          subscription={editSubModal}
          onClose={() => setEditSubModal(null)}
          onSaved={() => { queryClient.invalidateQueries({ queryKey: ['user-subscriptions', id] }); queryClient.invalidateQueries({ queryKey: ['user', id] }); setEditSubModal(null); }}
        />
      )}
    </div>
  );
}

// One side (front/back) of a KYC document, stacked with a label above the image.
function DocImage({ label, src, alt }: { label: string; src?: string; alt: string }) {
  return (
    <div>
      <p className="text-[11px] font-semibold text-gray-500 mb-1">{label}</p>
      {src ? (
        <a href={src} target="_blank" rel="noreferrer" className="block group">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src={src} alt={alt} className="w-full h-44 object-cover rounded-lg bg-gray-100 group-hover:opacity-90 transition" />
        </a>
      ) : (
        <div className="w-full h-44 flex items-center justify-center text-gray-300 text-xs bg-gray-50 dark:bg-gray-800 rounded-lg">
          No image uploaded
        </div>
      )}
    </div>
  );
}

function IconBtn({ children, onClick, title, danger }: { children: React.ReactNode; onClick: () => void; title: string; danger?: boolean }) {
  return (
    <button
      title={title}
      onClick={onClick}
      className={`p-1.5 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-800 ${danger ? 'text-red-500' : 'text-gray-500'}`}
    >
      {children}
    </button>
  );
}

function ReviewModal({ review, onClose, onSaved }: { review: any; onClose: () => void; onSaved: () => void }) {
  const [stars, setStars] = useState<number>(review.stars);
  const [text, setText] = useState<string>(review.review || '');

  const mutation = useMutation({
    mutationFn: () => adminApi.updateReview(review._id, { stars, review: text }),
    onSuccess: () => { toast.success('Review updated'); onSaved(); },
    onError: (e: any) => toast.error(e?.message || 'Update failed'),
  });

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4" onClick={onClose}>
      <div className="w-full max-w-md bg-white dark:bg-gray-900 rounded-2xl shadow-xl border border-gray-200 dark:border-gray-700" onClick={(e) => e.stopPropagation()}>
        <div className="flex items-center justify-between px-5 py-4 border-b border-gray-200 dark:border-gray-700">
          <h2 className="font-bold text-lg text-gray-900 dark:text-white">Edit Review</h2>
          <button onClick={onClose} className="text-gray-400 hover:text-gray-600"><X className="w-5 h-5" /></button>
        </div>
        <div className="p-5 space-y-4">
          <div>
            <p className="text-xs text-gray-400 mb-0.5">Reviewer</p>
            <p className="text-sm font-medium text-gray-800 dark:text-gray-100">{review.rater?.fullName ?? 'Unknown'}</p>
          </div>
          <div>
            <label className="text-xs text-gray-400 mb-1 block">Stars</label>
            <div className="flex gap-1">
              {[1, 2, 3, 4, 5].map((s) => (
                <button key={s} onClick={() => setStars(s)}>
                  <Star className={`w-6 h-6 ${s <= stars ? 'text-amber-400 fill-amber-400' : 'text-gray-300'}`} />
                </button>
              ))}
            </div>
          </div>
          <div>
            <label className="text-xs text-gray-400 mb-1 block">Review Text</label>
            <textarea
              value={text}
              onChange={(e) => setText(e.target.value)}
              rows={3}
              className="w-full border border-gray-200 dark:border-gray-700 dark:bg-gray-800 rounded-lg px-3 py-2 text-sm resize-none"
            />
          </div>
        </div>
        <div className="flex justify-end gap-2 px-5 py-4 border-t border-gray-200 dark:border-gray-700">
          <Button variant="outline" onClick={onClose}>Cancel</Button>
          <Button onClick={() => mutation.mutate()} isLoading={mutation.isPending}>Save Changes</Button>
        </div>
      </div>
    </div>
  );
}

function EditSubEndDateModal({ subscription, onClose, onSaved }: { subscription: any; onClose: () => void; onSaved: () => void }) {
  const currentEnd = subscription.endDate ? new Date(subscription.endDate).toISOString().split('T')[0] : '';
  const [endDate, setEndDate] = useState(currentEnd);

  const mutation = useMutation({
    mutationFn: () => adminApi.updateSubscriptionEndDate(subscription._id, endDate),
    onSuccess: () => { toast.success('End date updated'); onSaved(); },
    onError: (e: any) => toast.error(e?.message || 'Update failed'),
  });

  const inputCls = 'w-full border border-gray-200 dark:border-gray-700 dark:bg-gray-800 rounded-lg px-3 py-2 text-sm';

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4" onClick={onClose}>
      <div className="w-full max-w-sm bg-white dark:bg-gray-900 rounded-2xl shadow-xl border border-gray-200 dark:border-gray-700" onClick={(e) => e.stopPropagation()}>
        <div className="flex items-center justify-between px-5 py-4 border-b border-gray-200 dark:border-gray-700">
          <h2 className="font-bold text-lg text-gray-900 dark:text-white">Edit End Date</h2>
          <button onClick={onClose} className="text-gray-400 hover:text-gray-600"><X className="w-5 h-5" /></button>
        </div>
        <div className="p-5 space-y-4">
          <div>
            <p className="text-xs text-gray-400 mb-0.5">Plan</p>
            <p className="text-sm font-medium text-gray-800 dark:text-gray-100">{subscription.planId?.name ?? 'Plan'}</p>
          </div>
          <div>
            <p className="text-xs text-gray-400 mb-0.5">Start Date</p>
            <p className="text-sm font-medium text-gray-800 dark:text-gray-100">{subscription.startDate ? formatDate(subscription.startDate) : '—'}</p>
          </div>
          <div>
            <label className="text-xs text-gray-400 mb-1 block">New End Date</label>
            <input type="date" value={endDate} onChange={(e) => setEndDate(e.target.value)} className={inputCls} />
          </div>
          {endDate && subscription.startDate && (
            <p className="text-xs text-gray-500">
              Duration: {Math.ceil((new Date(endDate).getTime() - new Date(subscription.startDate).getTime()) / (1000 * 60 * 60 * 24))} days
            </p>
          )}
        </div>
        <div className="flex justify-end gap-2 px-5 py-4 border-t border-gray-200 dark:border-gray-700">
          <Button variant="outline" onClick={onClose}>Cancel</Button>
          <Button onClick={() => mutation.mutate()} isLoading={mutation.isPending} disabled={!endDate}>Save</Button>
        </div>
      </div>
    </div>
  );
}

function AssignPlanModal({ userId, onClose, onSaved }: { userId: string; onClose: () => void; onSaved: () => void }) {
  const [selectedPlanId, setSelectedPlanId] = useState('');

  const { data: plansData, isLoading: plansLoading } = useQuery({
    queryKey: ['admin-plans'],
    queryFn: () => adminApi.getPlans(),
  });

  const { data: userData } = useQuery({
    queryKey: ['user', userId],
    queryFn: () => adminApi.getUser(userId),
  });

  const { data: subsData } = useQuery({
    queryKey: ['user-subscriptions', userId],
    queryFn: () => adminApi.getUserSubscriptions(userId),
  });

  const plans: any[] = (plansData as any)?.data ?? [];
  const selectedPlan = plans.find((p) => p._id === selectedPlanId);
  const currentUser = (userData as any)?.data;
  const activeSub = ((subsData as any)?.data ?? []).find((s: any) => s.status === 'active');

  const TIER_RANK: Record<string, number> = { new: 0, active: 1, verified: 2, premium: 3, golden: 4 };
  const currentTier = TIER_RANK[currentUser?.membershipType ?? 'new'] ?? 0;
  const newTier = TIER_RANK[selectedPlan?.membershipType ?? 'new'] ?? 0;
  const days = selectedPlan?.durationDays ?? 0;
  const now = new Date();
  const activeEnd = activeSub ? new Date(activeSub.endDate) : null;
  const hasActive = activeEnd && activeEnd > now;

  let previewStart: Date | null = null;
  let previewEnd: Date | null = null;
  let previewNote = '';

  if (selectedPlan && days > 0) {
    if (hasActive) {
      if (newTier === currentTier) {
        previewStart = new Date(activeEnd!);
        previewEnd = new Date(activeEnd!);
        previewEnd.setDate(previewEnd.getDate() + days);
        previewNote = `Same tier — extends from current end date`;
      } else if (newTier > currentTier) {
        const remaining = Math.ceil((activeEnd!.getTime() - now.getTime()) / 86400000);
        previewStart = now;
        previewEnd = new Date(now);
        previewEnd.setDate(previewEnd.getDate() + days + remaining);
        previewNote = `Upgrade — ${remaining} remaining days carried over`;
      } else {
        previewStart = now;
        previewEnd = new Date(now);
        previewEnd.setDate(previewEnd.getDate() + days);
        previewNote = `Replaces current plan`;
      }
    } else {
      previewStart = now;
      previewEnd = new Date(now);
      previewEnd.setDate(previewEnd.getDate() + days);
      previewNote = `Fresh start`;
    }
  }

  const mutation = useMutation({
    mutationFn: () => adminApi.upgradeMembership(userId, selectedPlan?.membershipType, undefined, selectedPlanId),
    onSuccess: () => { toast.success('Plan assigned successfully'); onSaved(); },
    onError: (e: any) => toast.error(e?.message || 'Failed to assign plan'),
  });

  const selectCls = 'w-full border border-gray-200 dark:border-gray-700 dark:bg-gray-800 rounded-lg px-3 py-2 text-sm';

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4" onClick={onClose}>
      <div className="w-full max-w-md bg-white dark:bg-gray-900 rounded-2xl shadow-xl border border-gray-200 dark:border-gray-700" onClick={(e) => e.stopPropagation()}>
        <div className="flex items-center justify-between px-5 py-4 border-b border-gray-200 dark:border-gray-700">
          <h2 className="font-bold text-lg text-gray-900 dark:text-white">Assign Plan</h2>
          <button onClick={onClose} className="text-gray-400 hover:text-gray-600"><X className="w-5 h-5" /></button>
        </div>
        <div className="p-5 space-y-4">
          {hasActive && (
            <div className="bg-blue-50 dark:bg-blue-900/20 rounded-lg px-3 py-2 text-xs text-blue-700 dark:text-blue-300">
              Current plan active until <span className="font-semibold">{activeEnd!.toLocaleDateString('en-IN')}</span>
            </div>
          )}

          <div>
            <label className="text-xs text-gray-400 mb-1 block">Select Plan</label>
            {plansLoading ? (
              <div className="h-9 bg-gray-100 dark:bg-gray-800 rounded-lg animate-pulse" />
            ) : (
              <select value={selectedPlanId} onChange={(e) => setSelectedPlanId(e.target.value)} className={selectCls}>
                <option value="">— Choose a plan —</option>
                {plans.filter((p) => p.isActive).map((p) => {
                  const price = p.discountedPrice > 0 && p.discountedPrice < p.price ? p.discountedPrice : p.price;
                  return (
                    <option key={p._id} value={p._id}>
                      {p.name} ({p.membershipType}) — ₹{Math.round(price / 100).toLocaleString('en-IN')} / {p.durationDays}d
                    </option>
                  );
                })}
              </select>
            )}
          </div>

          {selectedPlan && previewEnd && (
            <div className="bg-orange-50 dark:bg-orange-900/20 rounded-lg px-3 py-2 text-sm space-y-1">
              <p className="font-medium text-orange-700 dark:text-orange-300 capitalize">{selectedPlan.membershipType} — {selectedPlan.name}</p>
              <p className="text-xs text-orange-600/80 dark:text-orange-400/80">
                {previewStart!.toLocaleDateString('en-IN')} → {previewEnd.toLocaleDateString('en-IN')} ({days} days)
              </p>
              <p className="text-xs text-orange-500/70 dark:text-orange-400/60">{previewNote}</p>
            </div>
          )}
        </div>
        <div className="flex justify-end gap-2 px-5 py-4 border-t border-gray-200 dark:border-gray-700">
          <Button variant="outline" onClick={onClose}>Cancel</Button>
          <Button onClick={() => mutation.mutate()} isLoading={mutation.isPending} disabled={!selectedPlanId}>
            Assign Plan
          </Button>
        </div>
      </div>
    </div>
  );
}
