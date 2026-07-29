'use client';

import { useSession } from 'next-auth/react';

/**
 * Current signed-in role helpers. `isFranchise` gates admin-only actions in the
 * shared pages (wallet adjust, subscription changes, invite add/deduct) — a
 * franchise can view that data for its city but must not mutate money/invites.
 * Enforcement is server-side; these just hide the buttons for a clean UX.
 */
export function useRole() {
  const { data: session } = useSession();
  const u = session?.user as any;
  const role = u?.role as string | undefined;
  const isImpersonating = !!u?.isImpersonating;
  // The EFFECTIVE original role — while impersonating, `role` is 'franchise' but
  // the operator is really a super-admin.
  const originalRole = (u?.originalRole as string | undefined) ?? (isImpersonating ? 'super_admin' : role);
  return {
    role,
    isFranchise: role === 'franchise',
    isAdmin: role === 'admin' || role === 'super_admin',
    // True super-admin identity (works whether or not currently impersonating).
    isSuperAdmin: role === 'super_admin' || (isImpersonating && originalRole === 'super_admin'),
    isImpersonating,
    impersonatedBy: (u?.impersonatedBy as string | undefined) ?? null,
    originalRole,
    franchiseName: (u?.franchiseName as string | undefined) ?? null,
  };
}
