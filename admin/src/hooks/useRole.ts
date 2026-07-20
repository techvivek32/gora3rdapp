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
  const role = (session?.user as any)?.role as string | undefined;
  return {
    role,
    isFranchise: role === 'franchise',
    isAdmin: role === 'admin' || role === 'super_admin',
  };
}
