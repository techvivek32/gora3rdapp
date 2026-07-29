'use client';

import { useQuery } from '@tanstack/react-query';
import { adminApi } from '@/lib/api';
import { PeriodFilter, type PeriodRange } from '@/components/ui/PeriodFilter';
import {
  AreaChart, Area, BarChart, Bar, XAxis, YAxis, CartesianGrid,
  Tooltip, ResponsiveContainer, PieChart, Pie, Cell, Legend,
} from 'recharts';
import { useEffect, useState } from 'react';

const MEMBERSHIP_COLORS: Record<string, string> = {
  new: '#6B7280',
  active: '#3B82F6',
  verified: '#10B981',
  premium: '#F59E0B',
  golden: '#EF4444',
};

function useDark() {
  const [dark, setDark] = useState(false);
  useEffect(() => {
    const check = () => setDark(document.documentElement.classList.contains('dark'));
    check();
    const obs = new MutationObserver(check);
    obs.observe(document.documentElement, { attributes: true, attributeFilter: ['class'] });
    return () => obs.disconnect();
  }, []);
  return dark;
}

const cardCls = 'bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-700 p-6';
const titleCls = 'font-semibold text-gray-900 dark:text-white mb-4';

export default function AnalyticsPage() {
  const dark = useDark();
  const [range, setRange] = useState<PeriodRange>({});
  const { data, isLoading } = useQuery({
    queryKey: ['analytics', range.dateFrom, range.dateTo],
    queryFn: () => adminApi.getAnalytics({ dateFrom: range.dateFrom, dateTo: range.dateTo }),
  });

  const analytics = data?.data;

  const grid = dark ? '#374151' : '#F3F4F6';
  const tick = dark ? '#9CA3AF' : '#6B7280';
  const tooltipStyle = {
    contentStyle: {
      backgroundColor: dark ? '#1F2937' : '#ffffff',
      border: `1px solid ${dark ? '#374151' : '#E5E7EB'}`,
      borderRadius: 8,
      color: dark ? '#F9FAFB' : '#111827',
      fontSize: 12,
    },
  };

  if (isLoading) {
    return (
      <div className="space-y-6">
        <h1 className="text-2xl font-bold text-gray-900 dark:text-white">Analytics</h1>
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          {Array.from({ length: 4 }).map((_, i) => (
            <div key={i} className="h-72 bg-gray-100 dark:bg-gray-800 rounded-xl animate-pulse" />
          ))}
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-8">
      <div className="flex items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-gray-900 dark:text-white">Analytics</h1>
          <p className="text-gray-500 dark:text-gray-400 mt-1">
            {range.dateFrom ? 'Platform performance for the selected period' : 'Platform performance over the last 30 days'}
          </p>
        </div>
        <PeriodFilter onChange={setRange} />
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* User Growth */}
        <div className={cardCls}>
          <h2 className={titleCls}>User Growth</h2>
          <ResponsiveContainer width="100%" height={240}>
            <AreaChart data={analytics?.userGrowth || []}>
              <defs>
                <linearGradient id="userGrad" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor="#F97316" stopOpacity={0.3} />
                  <stop offset="95%" stopColor="#F97316" stopOpacity={0} />
                </linearGradient>
              </defs>
              <CartesianGrid strokeDasharray="3 3" stroke={grid} />
              <XAxis dataKey="_id" tick={{ fontSize: 11, fill: tick }} />
              <YAxis tick={{ fontSize: 11, fill: tick }} />
              <Tooltip {...tooltipStyle} />
              <Area type="monotone" dataKey="count" stroke="#F97316" fill="url(#userGrad)" strokeWidth={2} />
            </AreaChart>
          </ResponsiveContainer>
        </div>

        {/* Requirements Posted */}
        <div className={cardCls}>
          <h2 className={titleCls}>Requirements Posted</h2>
          <ResponsiveContainer width="100%" height={240}>
            <BarChart data={analytics?.requirementGrowth || []}>
              <CartesianGrid strokeDasharray="3 3" stroke={grid} />
              <XAxis dataKey="_id" tick={{ fontSize: 11, fill: tick }} />
              <YAxis tick={{ fontSize: 11, fill: tick }} />
              <Tooltip {...tooltipStyle} />
              <Bar dataKey="count" fill="#3B82F6" radius={[4, 4, 0, 0]} />
            </BarChart>
          </ResponsiveContainer>
        </div>

        {/* Revenue Trend */}
        <div className={cardCls}>
          <h2 className={titleCls}>Revenue Trend</h2>
          <ResponsiveContainer width="100%" height={240}>
            <AreaChart data={analytics?.revenueData || []}>
              <defs>
                <linearGradient id="revGrad" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor="#10B981" stopOpacity={0.3} />
                  <stop offset="95%" stopColor="#10B981" stopOpacity={0} />
                </linearGradient>
              </defs>
              <CartesianGrid strokeDasharray="3 3" stroke={grid} />
              <XAxis dataKey="_id" tick={{ fontSize: 11, fill: tick }} />
              <YAxis tick={{ fontSize: 11, fill: tick }} tickFormatter={(v) => `₹${Number(v).toLocaleString('en-IN')}`} />
              <Tooltip {...tooltipStyle} formatter={(value: number) => [`₹${Number(value).toLocaleString('en-IN')}`, 'Revenue']} />
              <Area type="monotone" dataKey="revenue" stroke="#10B981" fill="url(#revGrad)" strokeWidth={2} />
            </AreaChart>
          </ResponsiveContainer>
        </div>

        {/* Membership Breakdown */}
        <div className={cardCls}>
          <h2 className={titleCls}>Membership Breakdown</h2>
          <ResponsiveContainer width="100%" height={240}>
            <PieChart>
              <Pie
                data={analytics?.membershipBreakdown || []}
                cx="50%"
                cy="50%"
                innerRadius={60}
                outerRadius={90}
                paddingAngle={3}
                dataKey="count"
                nameKey="_id"
              >
                {(analytics?.membershipBreakdown || []).map((entry: { _id: string }) => (
                  <Cell key={entry._id} fill={MEMBERSHIP_COLORS[entry._id] || '#6B7280'} />
                ))}
              </Pie>
              <Tooltip {...tooltipStyle} />
              <Legend
                formatter={(value) => (
                  <span style={{ color: tick, fontSize: 12 }}>
                    {value.charAt(0).toUpperCase() + value.slice(1)}
                  </span>
                )}
              />
            </PieChart>
          </ResponsiveContainer>
        </div>
      </div>

      {/* Top Cities */}
      <div className={cardCls}>
        <h2 className={titleCls}>Top Cities</h2>
        <div className="space-y-3">
          {(analytics?.topCities || []).map((city: { _id: string; count: number }, i: number) => {
            const max = analytics.topCities[0]?.count || 1;
            const pct = Math.round((city.count / max) * 100);
            return (
              <div key={city._id} className="flex items-center gap-4">
                <span className="w-6 text-sm font-bold text-gray-400">{i + 1}</span>
                <span className="w-32 text-sm font-medium text-gray-800 dark:text-gray-200 truncate">{city._id}</span>
                <div className="flex-1 bg-gray-100 dark:bg-gray-700 rounded-full h-2">
                  <div className="bg-brand-500 h-2 rounded-full transition-all" style={{ width: `${pct}%` }} />
                </div>
                <span className="text-sm text-gray-500 dark:text-gray-400 w-12 text-right">{city.count}</span>
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
}
