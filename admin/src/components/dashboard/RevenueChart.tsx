'use client';

import { useQuery } from '@tanstack/react-query';
import { adminApi } from '@/lib/api';
import { AreaChart, Area, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from 'recharts';
import { IndianRupee } from 'lucide-react';

export function RevenueChart({ range }: { range?: { dateFrom?: string; dateTo?: string } }) {
  const { data } = useQuery({
    queryKey: ['analytics', 'month', range?.dateFrom, range?.dateTo],
    queryFn: () => adminApi.getAnalytics({ period: 'month', dateFrom: range?.dateFrom, dateTo: range?.dateTo }),
  });

  const revenueData = data?.data?.revenueData || [];

  return (
    <div className="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-700 p-6">
      <div className="flex items-center justify-between mb-6">
        <div>
          <h3 className="font-semibold text-gray-900 dark:text-white">Revenue</h3>
          <p className="text-sm text-gray-500">{range?.dateFrom ? 'Selected period' : 'Last 30 days'}</p>
        </div>
        <div className="flex items-center gap-1 bg-orange-50 dark:bg-orange-900/20 text-orange-600 px-3 py-1.5 rounded-lg text-sm font-medium">
          <IndianRupee className="w-3.5 h-3.5" />
          {revenueData.reduce((acc: number, d: any) => acc + (d.revenue || 0), 0).toLocaleString()}
        </div>
      </div>
      <ResponsiveContainer width="100%" height={200}>
        <AreaChart data={revenueData} margin={{ top: 5, right: 10, left: -20, bottom: 0 }}>
          <defs>
            <linearGradient id="revenueGrad" x1="0" y1="0" x2="0" y2="1">
              <stop offset="5%" stopColor="#f97316" stopOpacity={0.3} />
              <stop offset="95%" stopColor="#f97316" stopOpacity={0} />
            </linearGradient>
          </defs>
          <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
          <XAxis dataKey="_id" tick={{ fontSize: 11 }} tickLine={false} axisLine={false} />
          <YAxis tick={{ fontSize: 11 }} tickLine={false} axisLine={false} />
          <Tooltip
            contentStyle={{ borderRadius: '8px', border: '1px solid #e5e7eb', fontSize: '12px' }}
            formatter={(val: any) => [`₹${val.toLocaleString()}`, 'Revenue']}
          />
          <Area type="monotone" dataKey="revenue" stroke="#f97316" fill="url(#revenueGrad)" strokeWidth={2} />
        </AreaChart>
      </ResponsiveContainer>
    </div>
  );
}
