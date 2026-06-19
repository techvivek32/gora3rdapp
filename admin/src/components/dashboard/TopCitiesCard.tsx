'use client';

import { useQuery } from '@tanstack/react-query';
import { adminApi } from '@/lib/api';
import { MapPin } from 'lucide-react';

export function TopCitiesCard() {
  const { data } = useQuery({
    queryKey: ['analytics', 'month'],
    queryFn: () => adminApi.getAnalytics({ period: 'month' }),
  });

  const topCities = data?.data?.topCities || [];
  const maxCount = topCities[0]?.count || 1;

  return (
    <div className="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-700 p-6">
      <div className="flex items-center gap-2 mb-4">
        <MapPin className="w-4 h-4 text-orange-500" />
        <h3 className="font-semibold text-gray-900 dark:text-white">Top Cities</h3>
      </div>
      <div className="space-y-3">
        {topCities.slice(0, 6).map((city: any, idx: number) => (
          <div key={city._id} className="flex items-center gap-3">
            <span className="text-xs text-gray-400 w-5">{idx + 1}</span>
            <div className="flex-1">
              <div className="flex justify-between text-sm mb-1">
                <span className="font-medium text-gray-700 dark:text-gray-300">{city._id}</span>
                <span className="text-gray-500">{city.count}</span>
              </div>
              <div className="h-1.5 bg-gray-100 dark:bg-gray-800 rounded-full overflow-hidden">
                <div
                  className="h-full bg-orange-500 rounded-full"
                  style={{ width: `${(city.count / maxCount) * 100}%` }}
                />
              </div>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
