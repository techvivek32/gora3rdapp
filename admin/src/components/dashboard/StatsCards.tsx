'use client';

import { useQuery } from '@tanstack/react-query';
import { adminApi } from '@/lib/api';
import { Users, Car, FileText, TrendingUp, Crown, Shield, Star, IndianRupee } from 'lucide-react';
import { cn } from '@/lib/utils';

interface StatCard {
  title: string;
  value: string | number;
  change?: string;
  icon: React.ReactNode;
  color: string;
  bgColor: string;
}

export function StatsCards() {
  const { data } = useQuery({
    queryKey: ['dashboard-stats'],
    queryFn: adminApi.getDashboardStats,
  });

  const stats = data?.data;

  const cards: StatCard[] = [
    {
      title: 'Total Users',
      value: stats?.users?.total?.toLocaleString() || '0',
      change: `+${stats?.today?.registrations || 0} today`,
      icon: <Users className="w-5 h-5" />,
      color: 'text-blue-600',
      bgColor: 'bg-blue-100 dark:bg-blue-900/30',
    },
    {
      title: 'Active Users',
      value: stats?.users?.active?.toLocaleString() || '0',
      change: '7 day active',
      icon: <TrendingUp className="w-5 h-5" />,
      color: 'text-emerald-600',
      bgColor: 'bg-emerald-100 dark:bg-emerald-900/30',
    },
    {
      title: 'Verified Users',
      value: stats?.users?.verified?.toLocaleString() || '0',
      icon: <Shield className="w-5 h-5" />,
      color: 'text-indigo-600',
      bgColor: 'bg-indigo-100 dark:bg-indigo-900/30',
    },
    {
      title: 'Premium Members',
      value: stats?.users?.premium?.toLocaleString() || '0',
      icon: <Star className="w-5 h-5" />,
      color: 'text-purple-600',
      bgColor: 'bg-purple-100 dark:bg-purple-900/30',
    },
    {
      title: 'Golden Members',
      value: stats?.users?.golden?.toLocaleString() || '0',
      icon: <Crown className="w-5 h-5" />,
      color: 'text-amber-600',
      bgColor: 'bg-amber-100 dark:bg-amber-900/30',
    },
    {
      title: 'Requirements',
      value: stats?.requirements?.active?.toLocaleString() || '0',
      change: `+${stats?.today?.requirements || 0} today`,
      icon: <FileText className="w-5 h-5" />,
      color: 'text-orange-600',
      bgColor: 'bg-orange-100 dark:bg-orange-900/30',
    },
    {
      title: 'Active Vehicles',
      value: stats?.vehicles?.active?.toLocaleString() || '0',
      icon: <Car className="w-5 h-5" />,
      color: 'text-cyan-600',
      bgColor: 'bg-cyan-100 dark:bg-cyan-900/30',
    },
    {
      title: 'Total Revenue',
      value: `₹${(stats?.revenue?.total || 0).toLocaleString()}`,
      change: `₹${(stats?.revenue?.monthly || 0).toLocaleString()} this month`,
      icon: <IndianRupee className="w-5 h-5" />,
      color: 'text-rose-600',
      bgColor: 'bg-rose-100 dark:bg-rose-900/30',
    },
  ];

  return (
    <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
      {cards.map((card) => (
        <div key={card.title} className="stat-card">
          <div className="flex items-start justify-between">
            <div>
              <p className="text-sm text-gray-500 dark:text-gray-400">{card.title}</p>
              <p className="text-2xl font-bold text-gray-900 dark:text-white mt-1">{card.value}</p>
              {card.change && (
                <p className="text-xs text-gray-400 mt-1">{card.change}</p>
              )}
            </div>
            <div className={cn('p-2.5 rounded-lg', card.bgColor)}>
              <span className={card.color}>{card.icon}</span>
            </div>
          </div>
        </div>
      ))}
    </div>
  );
}
