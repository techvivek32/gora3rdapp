import { Suspense } from 'react';
import { StatsCards } from '@/components/dashboard/StatsCards';
import { RevenueChart } from '@/components/dashboard/RevenueChart';
import { UserGrowthChart } from '@/components/dashboard/UserGrowthChart';
import { TopCitiesCard } from '@/components/dashboard/TopCitiesCard';
import { RecentRequirements } from '@/components/dashboard/RecentRequirements';
import { MembershipBreakdown } from '@/components/dashboard/MembershipBreakdown';
import { Skeleton } from '@/components/ui/Skeleton';

export const metadata = { title: 'Dashboard' };

export default function DashboardPage() {
  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-gray-900 dark:text-white">Dashboard</h1>
        <p className="text-gray-500 text-sm mt-1">Welcome to Gora Cabs Admin Panel</p>
      </div>

      <Suspense fallback={<StatsCardsSkeleton />}>
        <StatsCards />
      </Suspense>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <Suspense fallback={<ChartSkeleton />}>
          <RevenueChart />
        </Suspense>
        <Suspense fallback={<ChartSkeleton />}>
          <UserGrowthChart />
        </Suspense>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <div className="lg:col-span-2">
          <Suspense fallback={<ChartSkeleton />}>
            <RecentRequirements />
          </Suspense>
        </div>
        <div className="space-y-6">
          <Suspense fallback={<ChartSkeleton />}>
            <MembershipBreakdown />
          </Suspense>
          <Suspense fallback={<ChartSkeleton />}>
            <TopCitiesCard />
          </Suspense>
        </div>
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
