'use client';

import { use } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { adminApi } from '@/lib/api';
import { Badge } from '@/components/ui/Badge';
import { Button } from '@/components/ui/Button';
import { MembershipBadge } from '@/components/ui/MembershipBadge';
import { formatDate } from '@/lib/utils';
import { useRouter } from 'next/navigation';
import toast from 'react-hot-toast';
import {
  ArrowLeft, Phone, Mail, Building2, MapPin, Briefcase, ShieldCheck,
  FileText, ClipboardList, Car, Star, Wallet, BadgeCheck, Ban, CheckCircle2,
} from 'lucide-react';

const INFO_FIELDS = [
  { key: 'mobile', label: 'Mobile', icon: Phone },
  { key: 'email', label: 'Email', icon: Mail },
  { key: 'agencyName', label: 'Agency', icon: Building2 },
  { key: 'city', label: 'City', icon: MapPin },
  { key: 'state', label: 'State', icon: MapPin },
  { key: 'role', label: 'Role', icon: Briefcase },
];

const DOCS = [
  { key: 'aadhar', label: 'Aadhaar Card' },
  { key: 'pan', label: 'PAN Card' },
  { key: 'drivingLicense', label: 'Driving License' },
  { key: 'vehicleRc', label: 'Vehicle RC' },
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

  const { data, isLoading } = useQuery({
    queryKey: ['user', id],
    queryFn: () => adminApi.getUser(id),
  });

  const verifyMutation = useMutation({
    mutationFn: () => adminApi.verifyUser(id),
    onSuccess: () => { toast.success('User verified'); queryClient.invalidateQueries({ queryKey: ['user', id] }); },
  });

  const blockMutation = useMutation({
    mutationFn: (block: boolean) => adminApi[block ? 'blockUser' : 'unblockUser'](id),
    onSuccess: (_, block) => { toast.success(block ? 'User blocked' : 'User unblocked'); queryClient.invalidateQueries({ queryKey: ['user', id] }); },
  });

  const upgradeMutation = useMutation({
    mutationFn: (type: string) => adminApi.upgradeMembership(id, type),
    onSuccess: () => { toast.success('Membership upgraded'); queryClient.invalidateQueries({ queryKey: ['user', id] }); },
  });

  if (isLoading) return <div className="h-96 bg-gray-100 dark:bg-gray-800 rounded-xl animate-pulse" />;

  // API client unwraps res.data; backend returns { data: user } → data.data is the user.
  const user = (data as any)?.data;
  if (!user) return <div className="text-center py-12 text-gray-500">User not found</div>;

  const providedDocs = DOCS
    .map((d) => ({ ...d, doc: user.documents?.[d.key] }))
    .filter((d) => d.doc && (d.doc.number || d.doc.image));

  const cardCls = 'bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-700';

  return (
    <div className="space-y-6">
      {/* Header */}
      <button
        onClick={() => router.back()}
        className="inline-flex items-center gap-1.5 text-sm font-medium text-gray-500 hover:text-gray-800 dark:hover:text-gray-200"
      >
        <ArrowLeft className="w-4 h-4" /> Back to Users
      </button>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* ─── Main column ─────────────────────────────────────────── */}
        <div className="lg:col-span-2 space-y-6">
          {/* Profile */}
          <div className={`${cardCls} overflow-hidden`}>
            <div className="h-20 bg-gradient-to-r from-orange-500 to-orange-400" />
            <div className="px-6 pb-6 -mt-10">
              <div className="flex items-end gap-4">
                <div className="w-20 h-20 rounded-2xl bg-white dark:bg-gray-800 ring-4 ring-white dark:ring-gray-900 flex items-center justify-center overflow-hidden shadow-sm">
                  {user.profileImage ? (
                    // eslint-disable-next-line @next/next/no-img-element
                    <img src={user.profileImage} alt={user.fullName} className="w-full h-full object-cover" />
                  ) : (
                    <span className="text-3xl font-bold text-orange-500">{user.fullName?.[0]?.toUpperCase()}</span>
                  )}
                </div>
                <div className="flex flex-wrap items-center gap-2 pb-1">
                  <MembershipBadge type={user.membershipType} />
                  {user.isVerified && <Badge variant="success">Verified</Badge>}
                  {user.isBlocked && <Badge variant="destructive">Blocked</Badge>}
                  {!user.isBlocked && user.isActive && <Badge variant="secondary">Active</Badge>}
                </div>
              </div>

              <h2 className="mt-4 text-xl font-bold text-gray-900 dark:text-white">{user.fullName}</h2>

              <div className="mt-4 grid grid-cols-1 sm:grid-cols-2 gap-4">
                {INFO_FIELDS.map(({ key, label, icon: Icon }) => user[key] && (
                  <div key={key} className="flex items-start gap-3">
                    <div className="w-9 h-9 rounded-lg bg-gray-100 dark:bg-gray-800 flex items-center justify-center flex-shrink-0">
                      <Icon className="w-4 h-4 text-gray-500" />
                    </div>
                    <div className="min-w-0">
                      <p className="text-xs text-gray-400">{label}</p>
                      <p className="font-medium text-sm text-gray-800 dark:text-gray-100 truncate capitalize">
                        {String(user[key]).replace(/_/g, ' ')}
                      </p>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          </div>

          {/* KYC Documents */}
          <div className={`${cardCls} p-6`}>
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
                        {/* eslint-disable-next-line @next/next/no-img-element */}
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
              <div className="flex flex-col items-center justify-center py-8 text-center">
                <ClipboardList className="w-10 h-10 text-gray-300 mb-2" />
                <p className="text-sm text-gray-400">This user hasn&apos;t submitted any KYC documents yet.</p>
              </div>
            )}
          </div>

          {/* Activity Stats */}
          <div className={`${cardCls} p-6`}>
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

          {/* Business Cities */}
          {user.businessCities?.length > 0 && (
            <div className={`${cardCls} p-6`}>
              <h3 className="font-semibold mb-3 text-gray-900 dark:text-white">Business Cities</h3>
              <div className="flex flex-wrap gap-2">
                {user.businessCities.map((city: string) => (
                  <span key={city} className="bg-orange-50 dark:bg-orange-900/20 text-orange-700 dark:text-orange-300 px-3 py-1 rounded-full text-sm font-medium">{city}</span>
                ))}
              </div>
            </div>
          )}
        </div>

        {/* ─── Sidebar ─────────────────────────────────────────────── */}
        <div className="space-y-6">
          <div className={`${cardCls} p-5`}>
            <h3 className="font-semibold mb-4 text-gray-900 dark:text-white">Actions</h3>
            <div className="space-y-3">
              {!user.isVerified && (
                <Button className="w-full" onClick={() => verifyMutation.mutate()} isLoading={verifyMutation.isPending}>
                  <BadgeCheck className="w-4 h-4 mr-2" /> Verify User
                </Button>
              )}
              <Button
                className="w-full"
                variant={user.isBlocked ? 'default' : 'destructive'}
                onClick={() => blockMutation.mutate(!user.isBlocked)}
                isLoading={blockMutation.isPending}
              >
                {user.isBlocked ? <CheckCircle2 className="w-4 h-4 mr-2" /> : <Ban className="w-4 h-4 mr-2" />}
                {user.isBlocked ? 'Unblock User' : 'Block User'}
              </Button>
            </div>
          </div>

          <div className={`${cardCls} p-5`}>
            <h3 className="font-semibold mb-4 text-gray-900 dark:text-white">Upgrade Membership</h3>
            <div className="space-y-2">
              {['active', 'verified', 'premium', 'golden'].map((type) => (
                <button
                  key={type}
                  onClick={() => upgradeMutation.mutate(type)}
                  disabled={user.membershipType === type || upgradeMutation.isPending}
                  className={`w-full flex items-center justify-between px-3 py-2.5 rounded-lg text-sm font-medium border transition-colors
                    ${user.membershipType === type
                      ? 'bg-gray-50 dark:bg-gray-800 text-gray-400 border-gray-100 dark:border-gray-700 cursor-not-allowed'
                      : 'border-gray-200 dark:border-gray-700 hover:bg-gray-50 dark:hover:bg-gray-800 cursor-pointer text-gray-700 dark:text-gray-200'
                    }`}
                >
                  <span className="capitalize">{type}</span>
                  {user.membershipType === type
                    ? <span className="text-xs">Current</span>
                    : <MembershipBadge type={type} />}
                </button>
              ))}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
