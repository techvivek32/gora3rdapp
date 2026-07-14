'use client';

import { useEffect, useRef, useState } from 'react';
import { useRouter } from 'next/navigation';
import { useSession } from 'next-auth/react';
import { useQuery } from '@tanstack/react-query';
import { Bell, CreditCard, Banknote, Star } from 'lucide-react';
import { adminApi } from '@/lib/api';

interface Activity {
  id: string;
  type: 'plan' | 'payment' | 'withdrawal';
  title: string;
  message: string;
  status?: string;
  href: string;
  createdAt: string;
}

// "Seen up to" marker. The feed is derived from payments/withdrawals rather than
// stored notification rows, so there's no per-row read flag to persist — anything
// newer than this timestamp counts as unread.
const SEEN_KEY = 'admin_activity_seen_at';

const ICONS = {
  plan: Star,
  payment: CreditCard,
  withdrawal: Banknote,
} as const;

const TONE = {
  plan: 'text-amber-500 bg-amber-500/10',
  payment: 'text-emerald-500 bg-emerald-500/10',
  withdrawal: 'text-blue-500 bg-blue-500/10',
} as const;

function timeAgo(iso: string) {
  const mins = Math.floor((Date.now() - new Date(iso).getTime()) / 60000);
  if (mins < 1) return 'just now';
  if (mins < 60) return `${mins}m ago`;
  if (mins < 1440) return `${Math.floor(mins / 60)}h ago`;
  return `${Math.floor(mins / 1440)}d ago`;
}

export default function NotificationBell() {
  const router = useRouter();
  const { status } = useSession();
  const [open, setOpen] = useState(false);
  const [seenAt, setSeenAt] = useState(0);
  const boxRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    setSeenAt(Number(localStorage.getItem(SEEN_KEY) ?? 0));
  }, []);

  // Close on outside click.
  useEffect(() => {
    const h = (e: MouseEvent) => {
      if (boxRef.current && !boxRef.current.contains(e.target as Node)) setOpen(false);
    };
    document.addEventListener('mousedown', h);
    return () => document.removeEventListener('mousedown', h);
  }, []);

  const { data } = useQuery({
    queryKey: ['admin-activity'],
    // The axios client gets its token from useSession; firing before that lands
    // would 401.
    enabled: status === 'authenticated',
    refetchInterval: 60_000,
    queryFn: async () => {
      const res: any = await adminApi.getAdminActivity(20);
      const d = res?.data ?? res;
      return {
        items: (d?.items ?? []) as Activity[],
        pendingWithdrawals: (d?.pendingWithdrawals ?? 0) as number,
      };
    },
  });

  const items = data?.items ?? [];
  const unread = items.filter((i) => new Date(i.createdAt).getTime() > seenAt).length;

  const toggle = () => {
    const next = !open;
    setOpen(next);
    if (next && items.length) {
      // Opening the panel is what marks it seen.
      const newest = new Date(items[0].createdAt).getTime();
      localStorage.setItem(SEEN_KEY, String(newest));
      setSeenAt(newest);
    }
  };

  return (
    <div ref={boxRef} className="relative">
      <button
        onClick={toggle}
        className="relative p-2 rounded-lg text-gray-500 hover:text-gray-700 hover:bg-gray-100 dark:hover:bg-gray-800 transition-colors"
        aria-label="Notifications"
      >
        <Bell className="w-5 h-5" />
        {unread > 0 && (
          <span className="absolute -top-0.5 -right-0.5 min-w-[18px] h-[18px] px-1 flex items-center justify-center rounded-full bg-red-500 text-white text-[10px] font-bold">
            {unread > 9 ? '9+' : unread}
          </span>
        )}
      </button>

      {open && (
        <div className="absolute right-0 mt-2 w-96 max-w-[calc(100vw-2rem)] bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-700 rounded-xl shadow-xl z-50 overflow-hidden">
          <div className="flex items-center justify-between px-4 py-3 border-b border-gray-200 dark:border-gray-700">
            <p className="text-sm font-semibold text-gray-900 dark:text-white">Notifications</p>
            {(data?.pendingWithdrawals ?? 0) > 0 && (
              <span className="text-xs px-2 py-0.5 rounded-full bg-blue-500/10 text-blue-500 font-medium">
                {data!.pendingWithdrawals} pending withdrawal{data!.pendingWithdrawals > 1 ? 's' : ''}
              </span>
            )}
          </div>

          <div className="max-h-96 overflow-y-auto">
            {items.length === 0 ? (
              <p className="px-4 py-8 text-sm text-gray-500 text-center">Nothing yet.</p>
            ) : (
              items.map((n) => {
                const Icon = ICONS[n.type] ?? Bell;
                const isNew = new Date(n.createdAt).getTime() > seenAt;
                return (
                  <button
                    key={n.id}
                    onClick={() => { setOpen(false); router.push(n.href); }}
                    className={`w-full text-left flex gap-3 px-4 py-3 border-b border-gray-100 dark:border-gray-800 last:border-0 hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors ${
                      isNew ? 'bg-orange-500/5' : ''
                    }`}
                  >
                    <span className={`w-8 h-8 rounded-full flex items-center justify-center shrink-0 ${TONE[n.type] ?? 'text-gray-500 bg-gray-500/10'}`}>
                      <Icon className="w-4 h-4" />
                    </span>
                    <span className="min-w-0 flex-1">
                      <span className="flex items-center justify-between gap-2">
                        <span className="text-sm font-medium text-gray-900 dark:text-white">{n.title}</span>
                        <span className="text-xs text-gray-400 shrink-0">{timeAgo(n.createdAt)}</span>
                      </span>
                      <span className="block text-xs text-gray-500 mt-0.5 line-clamp-2">{n.message}</span>
                    </span>
                  </button>
                );
              })
            )}
          </div>
        </div>
      )}
    </div>
  );
}
