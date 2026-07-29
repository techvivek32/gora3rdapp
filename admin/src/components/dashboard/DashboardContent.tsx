'use client';

import { Suspense, useState } from 'react';
import { StatsCards } from '@/components/dashboard/StatsCards';
import { RevenueChart } from '@/components/dashboard/RevenueChart';
import { UserGrowthChart } from '@/components/dashboard/UserGrowthChart';
import { TopCitiesCard } from '@/components/dashboard/TopCitiesCard';
import { MembershipBreakdown } from '@/components/dashboard/MembershipBreakdown';
import { Skeleton } from '@/components/ui/Skeleton';
import { PeriodFilter, type PeriodRange } from '@/components/ui/PeriodFilter';

/**
 * Client shell for the dashboard: holds the shared period filter and threads the
 * chosen date range into the stat cards + charts (each runs its own query).
 */
export function DashboardContent() {
  const [range, setRange] = useState<PeriodRange>({});

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-gray-900 dark:text-white">Dashboard</h1>
          <p className="text-gray-500 text-sm mt-1">Welcome to Gora Cabs Admin Panel</p>
        </div>
        <PeriodFilter onChange={setRange} />
      </div>

      <Suspense fallback={<StatsCardsSkeleton />}>
        <StatsCards range={range} />
      </Suspense>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <Suspense fallback={<ChartSkeleton />}>
          <RevenueChart range={range} />
        </Suspense>
        <Suspense fallback={<ChartSkeleton />}>
          <UserGrowthChart range={range} />
        </Suspense>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <Suspense fallback={<ChartSkeleton />}>
          <TopCitiesCard range={range} />
        </Suspense>
        <Suspense fallback={<ChartSkeleton />}>
          <MembershipBreakdown range={range} />
        </Suspense>
      </div>
    </div>
  );
}

function StatsCardsSkeleton() {
  return (
    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
      {[...Array(8)].map((_, i) => (
        <Skeleton key={i} className="h-28 rounded-xl" />
      ))}
    </div>
  );
}

function ChartSkeleton() {
  return <Skeleton className="h-64 rounded-xl" />;
}
