'use client';

import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { adminApi } from '@/lib/api';
import { Badge } from '@/components/ui/Badge';
import { Button } from '@/components/ui/Button';
import { MembershipBadge } from '@/components/ui/MembershipBadge';
import { useRouter } from 'next/navigation';
import toast from 'react-hot-toast';

const INFO_FIELDS = [
  { key: 'mobile', label: 'Mobile' },
  { key: 'email', label: 'Email' },
  { key: 'agencyName', label: 'Agency Name' },
  { key: 'city', label: 'City' },
  { key: 'state', label: 'State' },
  { key: 'role', label: 'Role' },
];

export default function UserDetailPage({ params }: { params: { id: string } }) {
  const router = useRouter();
  const queryClient = useQueryClient();

  const { data, isLoading } = useQuery({
    queryKey: ['user', params.id],
    queryFn: () => adminApi.getUser(params.id),
  });

  const verifyMutation = useMutation({
    mutationFn: () => adminApi.verifyUser(params.id),
    onSuccess: () => { toast.success('User verified'); queryClient.invalidateQueries({ queryKey: ['user', params.id] }); },
  });

  const blockMutation = useMutation({
    mutationFn: (block: boolean) => adminApi[block ? 'blockUser' : 'unblockUser'](params.id),
    onSuccess: (_, block) => { toast.success(block ? 'User blocked' : 'User unblocked'); queryClient.invalidateQueries({ queryKey: ['user', params.id] }); },
  });

  const upgradeMutation = useMutation({
    mutationFn: (type: string) => adminApi.upgradeMembership(params.id, type),
    onSuccess: () => { toast.success('Membership upgraded'); queryClient.invalidateQueries({ queryKey: ['user', params.id] }); },
  });

  if (isLoading) return <div className="h-96 bg-gray-100 rounded-xl animate-pulse" />;

  const user = data?.data?.data;
  if (!user) return <div className="text-center py-12 text-gray-500">User not found</div>;

  return (
    <div className="space-y-6 max-w-4xl">
      <div className="flex items-center gap-4">
        <button onClick={() => router.back()} className="text-gray-500 hover:text-gray-700">← Back</button>
        <div>
          <h1 className="text-2xl font-bold text-gray-900">{user.fullName}</h1>
          <p className="text-gray-500">User ID: {user._id}</p>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <div className="lg:col-span-2 space-y-6">
          <div className="bg-white rounded-xl border border-gray-200 p-6">
            <div className="flex items-start gap-5">
              <div className="w-20 h-20 rounded-full bg-gray-100 flex items-center justify-center overflow-hidden flex-shrink-0">
                {user.profileImage ? (
                  <img src={user.profileImage} alt={user.fullName} className="w-full h-full object-cover" />
                ) : (
                  <span className="text-3xl font-bold text-gray-400">{user.fullName[0]}</span>
                )}
              </div>
              <div className="flex-1">
                <div className="flex items-center gap-3 flex-wrap">
                  <h2 className="text-xl font-bold">{user.fullName}</h2>
                  <MembershipBadge type={user.membershipType} />
                  {user.isVerified && <Badge variant="success">Verified</Badge>}
                  {user.isBlocked && <Badge variant="destructive">Blocked</Badge>}
                </div>
                <div className="mt-4 grid grid-cols-2 gap-3">
                  {INFO_FIELDS.map(({ key, label }) => user[key] && (
                    <div key={key}>
                      <p className="text-xs text-gray-400">{label}</p>
                      <p className="font-medium text-sm capitalize">{user[key]}</p>
                    </div>
                  ))}
                </div>
              </div>
            </div>
          </div>

          <div className="bg-white rounded-xl border border-gray-200 p-6">
            <h3 className="font-semibold mb-4">Activity Stats</h3>
            <div className="grid grid-cols-3 gap-4">
              {[
                { label: 'Requirements', value: user.requirementsPosted },
                { label: 'Vehicles Listed', value: user.vehiclesPosted },
                { label: 'Rating', value: user.rating?.toFixed(1) || '—' },
              ].map(({ label, value }) => (
                <div key={label} className="bg-gray-50 rounded-lg p-4 text-center">
                  <p className="text-2xl font-bold">{value}</p>
                  <p className="text-xs text-gray-500 mt-1">{label}</p>
                </div>
              ))}
            </div>
          </div>

          {user.businessCities?.length > 0 && (
            <div className="bg-white rounded-xl border border-gray-200 p-6">
              <h3 className="font-semibold mb-3">Business Cities</h3>
              <div className="flex flex-wrap gap-2">
                {user.businessCities.map((city: string) => (
                  <span key={city} className="bg-blue-50 text-blue-700 px-3 py-1 rounded-full text-sm font-medium">{city}</span>
                ))}
              </div>
            </div>
          )}
        </div>

        <div className="space-y-4">
          <div className="bg-white rounded-xl border border-gray-200 p-5">
            <h3 className="font-semibold mb-4">Actions</h3>
            <div className="space-y-3">
              {!user.isVerified && (
                <Button className="w-full" onClick={() => verifyMutation.mutate()} isLoading={verifyMutation.isPending}>
                  Verify User
                </Button>
              )}
              <Button
                className="w-full"
                variant={user.isBlocked ? 'default' : 'destructive'}
                onClick={() => blockMutation.mutate(!user.isBlocked)}
                isLoading={blockMutation.isPending}
              >
                {user.isBlocked ? 'Unblock User' : 'Block User'}
              </Button>
            </div>
          </div>

          <div className="bg-white rounded-xl border border-gray-200 p-5">
            <h3 className="font-semibold mb-4">Upgrade Membership</h3>
            <div className="space-y-2">
              {['active', 'verified', 'premium', 'golden'].map((type) => (
                <button
                  key={type}
                  onClick={() => upgradeMutation.mutate(type)}
                  disabled={user.membershipType === type}
                  className={`w-full text-left px-3 py-2 rounded-lg text-sm font-medium border transition-colors
                    ${user.membershipType === type
                      ? 'bg-gray-50 text-gray-400 border-gray-100 cursor-not-allowed'
                      : `badge-${type} hover:opacity-90 cursor-pointer`
                    }`}
                >
                  {type.charAt(0).toUpperCase() + type.slice(1)}
                  {user.membershipType === type && ' (current)'}
                </button>
              ))}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
