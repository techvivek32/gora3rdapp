'use client';

import { useQuery } from '@tanstack/react-query';
import { adminApi } from '@/lib/api';
import { FileText, ArrowRight } from 'lucide-react';
import Link from 'next/link';
import { MembershipBadge } from '../ui/MembershipBadge';
import { formatDate } from '@/lib/utils';

export function RecentRequirements() {
  const { data } = useQuery({
    queryKey: ['admin-requirements', 1, '', '', ''],
    queryFn: () => adminApi.getRequirements({ page: 1, limit: 8, sortBy: 'createdAt', sortOrder: 'desc' }),
  });

  const requirements = data?.data || [];

  const tripTypeColor: Record<string, string> = {
    one_way: 'bg-blue-100 text-blue-700',
    round_trip: 'bg-green-100 text-green-700',
    airport_transfer: 'bg-purple-100 text-purple-700',
    local: 'bg-yellow-100 text-yellow-700',
    outstation: 'bg-orange-100 text-orange-700',
  };

  return (
    <div className="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-700">
      <div className="px-6 py-4 flex items-center justify-between border-b border-gray-200 dark:border-gray-700">
        <div className="flex items-center gap-2">
          <FileText className="w-4 h-4 text-orange-500" />
          <h3 className="font-semibold text-gray-900 dark:text-white">Recent Requirements</h3>
        </div>
        <Link href="/requirements" className="text-xs text-orange-500 hover:text-orange-600 flex items-center gap-1">
          View all <ArrowRight className="w-3 h-3" />
        </Link>
      </div>

      <div className="divide-y divide-gray-100 dark:divide-gray-800">
        {requirements.map((req: any) => (
          <div key={req._id} className="px-6 py-3.5 flex items-center gap-4 hover:bg-gray-50 dark:hover:bg-gray-800/50">
            <div className="flex-1 min-w-0">
              <div className="flex items-center gap-2 mb-1">
                <span className="text-xs font-mono text-gray-500">#{req.bookingId}</span>
                <span className={`text-xs px-2 py-0.5 rounded-full font-medium capitalize ${tripTypeColor[req.tripType] || 'bg-gray-100 text-gray-700'}`}>
                  {req.tripType?.replace('_', ' ')}
                </span>
              </div>
              <p className="text-sm font-medium text-gray-900 dark:text-white truncate">
                {req.pickupCity} → {req.dropCity}
              </p>
              <p className="text-xs text-gray-500">
                {req.vehicleType?.replace('_', ' ')} • {new Date(req.travelDate).toDateString()}
              </p>
            </div>
            <div className="text-right">
              {req.postedBy && <MembershipBadge type={req.postedBy.membershipType} size="xs" />}
              <p className="text-xs text-gray-400 mt-1">{formatDate(req.createdAt)}</p>
            </div>
          </div>
        ))}

        {requirements.length === 0 && (
          <div className="px-6 py-8 text-center text-sm text-gray-500">No requirements yet</div>
        )}
      </div>
    </div>
  );
}
