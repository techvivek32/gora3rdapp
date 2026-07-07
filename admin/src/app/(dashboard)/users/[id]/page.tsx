'use client';

import { use, useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { adminApi } from '@/lib/api';
import { Badge } from '@/components/ui/Badge';
import { Button } from '@/components/ui/Button';
import { MembershipBadge } from '@/components/ui/MembershipBadge';
import { formatDate } from '@/lib/utils';
import { useRouter } from 'next/navigation';
import toast from 'react-hot-toast';
import {
  ArrowLeft, Phone, Mail, Building2, MapPin, ShieldCheck,
  FileText, ClipboardList, Car, Star, Wallet, Ban, CheckCircle2,
  Calendar, User, CreditCard, ArrowUpRight, FileCheck, CheckSquare,
} from 'lucide-react';

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

  const { data, isLoading } = useQuery({
    queryKey: ['user', id],
    queryFn: () => adminApi.getUser(id),
  });

  const { data: requestsData } = useQuery({
    queryKey: ['user-requests', id],
    queryFn: () => adminApi.getUserRequirements(id),
    enabled: activeTab === 'requests',
  });

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
    .filter((d) => d.doc && (d.doc.number || d.doc.image));

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
                      {doc.image ? (
                        <a href={doc.image} target="_blank" rel="noreferrer" className="block group">
                          <img src={doc.image} alt={label} className="w-full h-44 object-cover group-hover:opacity-90 transition" />
                        </a>
                      ) : (
                        <div className="w-full h-44 flex items-center justify-center text-gray-300 text-xs bg-gray-50 dark:bg-gray-800">
                          No image uploaded
                        </div>
                      )}
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
              <h3 className="font-semibold mb-4 text-gray-900 dark:text-white">Requirements Posted</h3>
              {(() => {
                const items = (requestsData as any)?.data ?? [];
                if (!items.length) return (
                  <div className="flex flex-col items-center justify-center py-12 text-center">
                    <ClipboardList className="w-10 h-10 text-gray-300 mb-2" />
                    <p className="text-sm text-gray-400">No requirements posted yet.</p>
                  </div>
                );
                return (
                  <div className="overflow-x-auto">
                    <table className="w-full text-sm">
                      <thead>
                        <tr className="border-b border-gray-200 dark:border-gray-700 text-left">
                          <th className="pb-3 pr-4 font-medium text-gray-500">Booking ID</th>
                          <th className="pb-3 pr-4 font-medium text-gray-500">Route</th>
                          <th className="pb-3 pr-4 font-medium text-gray-500">Vehicle</th>
                          <th className="pb-3 pr-4 font-medium text-gray-500">Travel Date</th>
                          <th className="pb-3 pr-4 font-medium text-gray-500">Fare</th>
                          <th className="pb-3 font-medium text-gray-500">Status</th>
                        </tr>
                      </thead>
                      <tbody className="divide-y divide-gray-100 dark:divide-gray-800">
                        {items.map((r: any) => (
                          <tr key={r._id} className="hover:bg-gray-50 dark:hover:bg-gray-800/50">
                            <td className="py-3 pr-4 font-mono text-xs text-gray-600 dark:text-gray-400">{r.bookingId}</td>
                            <td className="py-3 pr-4">
                              <span className="font-medium text-gray-800 dark:text-gray-200">{r.pickupCity}</span>
                              <span className="text-gray-400 mx-1">→</span>
                              <span className="font-medium text-gray-800 dark:text-gray-200">{r.dropCity}</span>
                            </td>
                            <td className="py-3 pr-4 capitalize text-gray-600 dark:text-gray-400">{r.vehicleType?.replace(/_/g, ' ')}</td>
                            <td className="py-3 pr-4 text-gray-600 dark:text-gray-400">{r.travelDate ? formatDate(r.travelDate) : '—'}</td>
                            <td className="py-3 pr-4 text-gray-800 dark:text-gray-200">₹{r.fare ?? 0}</td>
                            <td className="py-3">
                              <Badge variant={r.status === 'active' ? 'success' : r.status === 'cancelled' ? 'destructive' : 'secondary'}>
                                {r.status}
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
                            <div className="flex items-center gap-1">
                              {Array.from({ length: 5 }).map((_, i) => (
                                <Star key={i} className={`w-3.5 h-3.5 ${i < r.stars ? 'text-amber-400 fill-amber-400' : 'text-gray-300'}`} />
                              ))}
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
              <h3 className="font-semibold mb-4 text-gray-900 dark:text-white">Subscription History</h3>
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
                    {items.map((s: any) => (
                      <div key={s._id} className="flex items-center justify-between p-4 bg-gray-50 dark:bg-gray-800 rounded-xl">
                        <div className="flex items-center gap-3">
                          <MembershipBadge type={s.membershipType ?? s.planId?.membershipType} />
                          <div>
                            <p className="font-medium text-gray-800 dark:text-gray-200">{s.planId?.name ?? 'Plan'}</p>
                            <p className="text-xs text-gray-500">
                              {s.startDate ? formatDate(s.startDate) : '—'} → {s.endDate ? formatDate(s.endDate) : '—'}
                            </p>
                          </div>
                        </div>
                        <div className="text-right">
                          <p className="font-semibold text-gray-800 dark:text-gray-200">₹{s.amount}</p>
                          <Badge variant={s.status === 'active' ? 'success' : s.status === 'expired' ? 'secondary' : 'warning'}>
                            {s.status}
                          </Badge>
                        </div>
                      </div>
                    ))}
                  </div>
                );
              })()}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
