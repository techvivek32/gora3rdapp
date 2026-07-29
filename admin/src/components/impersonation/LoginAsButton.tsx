'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { useSession } from 'next-auth/react';
import { useQueryClient } from '@tanstack/react-query';
import { LogIn } from 'lucide-react';
import toast from 'react-hot-toast';
import { adminApi } from '@/lib/api';
import { useRole } from '@/hooks/useRole';

/**
 * "Login As" primary action on the franchise detail page. Visible only to a real
 * Super Admin who is not already impersonating. Starts a secure impersonation
 * session (backend mints a franchise-scoped JWT), swaps the NextAuth session to
 * that token, clears cached admin data, and lands on the franchise dashboard.
 */
export function LoginAsButton({ franchiseId }: { franchiseId: string }) {
  const { isSuperAdmin, isImpersonating } = useRole();
  const { update } = useSession();
  const router = useRouter();
  const qc = useQueryClient();
  const [loading, setLoading] = useState(false);

  if (!isSuperAdmin || isImpersonating) return null;

  const go = async () => {
    setLoading(true);
    try {
      const res: any = await adminApi.loginAsFranchise(franchiseId);
      const { accessToken, franchise } = res.data;
      await update({ impersonate: { accessToken, franchise } });
      qc.clear(); // drop admin-scoped cache so everything refetches as the franchise
      toast.success(`Now logged in as ${franchise.name}`);
      router.push('/dashboard');
    } catch (e: any) {
      toast.error(e?.message || 'Could not start Login As');
    } finally {
      setLoading(false);
    }
  };

  return (
    <button
      onClick={go}
      disabled={loading}
      className="inline-flex items-center gap-1.5 px-3 py-2 rounded-lg bg-orange-500 hover:bg-orange-600 disabled:opacity-50 text-white text-sm font-medium"
    >
      <LogIn className="w-4 h-4" /> {loading ? 'Starting…' : 'Login As'}
    </button>
  );
}
