'use client';

import { useQuery } from '@tanstack/react-query';
import { adminApi } from '@/lib/api';
import { PieChart, Pie, Cell, Tooltip, ResponsiveContainer, Legend } from 'recharts';

const MEMBERSHIP_COLORS: Record<string, string> = {
  new: '#6b7280',
  active: '#3b82f6',
  verified: '#10b981',
  premium: '#8b5cf6',
  golden: '#f59e0b',
};

export function MembershipBreakdown() {
  const { data } = useQuery({
    queryKey: ['analytics', 'month'],
    queryFn: () => adminApi.getAnalytics('month'),
  });

  const breakdown = data?.data?.membershipBreakdown || [];

  return (
    <div className="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-700 p-6">
      <h3 className="font-semibold text-gray-900 dark:text-white mb-4">Membership Split</h3>
      <ResponsiveContainer width="100%" height={180}>
        <PieChart>
          <Pie data={breakdown} dataKey="count" nameKey="_id" cx="50%" cy="50%" outerRadius={70} paddingAngle={3}>
            {breakdown.map((entry: any, index: number) => (
              <Cell key={index} fill={MEMBERSHIP_COLORS[entry._id] || '#94a3b8'} />
            ))}
          </Pie>
          <Tooltip
            contentStyle={{ borderRadius: '8px', border: '1px solid #e5e7eb', fontSize: '12px' }}
            formatter={(val: any, name: string) => [val, name.charAt(0).toUpperCase() + name.slice(1)]}
          />
          <Legend iconType="circle" iconSize={8} wrapperStyle={{ fontSize: '12px' }} />
        </PieChart>
      </ResponsiveContainer>
    </div>
  );
}
