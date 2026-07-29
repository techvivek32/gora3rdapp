'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { useSession } from 'next-auth/react';
import { useQueryClient } from '@tanstack/react-query';
import { AlertTriangle, LogOut } from 'lucide-react';
import toast from 'react-hot-toast';
import { adminApi } from '@/lib/api';
import { useRole } from '@/hooks/useRole';

/**
 * Permanent banner shown on every dashboard page while a "Login As" session is
 * active. Exiting restores the original admin token (backend re-issues it + closes
 * the audit row), clears cache, and returns to the admin dashboard.
 */
export function ImpersonationBanner() {
  const { isImpersonating, franchiseName } = useRole();
  const { update } = useSession();
  const router = useRouter();
  const qc = useQueryClient();
  const [loading, setLoading] = useState(false);

  if (!isImpersonating) return null;

  const exit = async () => {
    setLoading(true);
    try {
      const res: any = await adminApi.exitLoginAs();
      const { accessToken, user } = res.data;
      await update({ exitImpersonation: { accessToken, user } });
      qc.clear();
      toast.success('Exited Login As');
      router.push('/dashboard');
    } catch (e: any) {
      toast.error(e?.message || 'Could not exit Login As');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="flex-shrink-0 flex flex-wrap items-center gap-x-4 gap-y-1 bg-orange-500 text-white px-4 py-2 text-sm">
      <span className="inline-flex items-center gap-1.5 font-semibold">
        <AlertTriangle className="w-4 h-4" /> Login As Active
      </span>
      <span className="opacity-95">
        Currently logged in as <strong>{franchiseName || 'Franchise'}</strong>
      </span>
      <span className="opacity-80">Original user: Super Admin</span>
      <button
        onClick={exit}
        disabled={loading}
        className="ml-auto inline-flex items-center gap-1.5 rounded-md bg-white/20 hover:bg-white/30 disabled:opacity-50 px-3 py-1 font-medium transition-colors"
      >
        <LogOut className="w-4 h-4" /> {loading ? 'Exiting…' : 'Exit Login As'}
      </button>
    </div>
  );
}
