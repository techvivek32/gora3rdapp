'use client';

import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { SessionProvider, useSession, signOut } from 'next-auth/react';
import { Toaster } from 'react-hot-toast';
import { useState, useEffect } from 'react';
import { setAuthToken } from '@/lib/api';

function SessionSync() {
  const { data: session } = useSession();
  // Set synchronously during render so queries fired in this render cycle already have the token
  setAuthToken((session?.user as any)?.accessToken ?? null);
  useEffect(() => {
    setAuthToken((session?.user as any)?.accessToken ?? null);
    // Refresh token expired / invalid → session can't be renewed → auto sign out.
    if ((session as any)?.error === 'RefreshAccessTokenError') {
      signOut({ callbackUrl: '/login' });
    }
  }, [session]);
  return null;
}

export function Providers({ children }: { children: React.ReactNode }) {
  const [queryClient] = useState(
    () =>
      new QueryClient({
        defaultOptions: {
          queries: {
            staleTime: 60 * 1000,
            retry: 2,
            retryDelay: 800,
            refetchOnWindowFocus: false,
          },
        },
      }),
  );

  return (
    // Re-check the session every 4 min and on window focus so the access token is
    // refreshed before it expires (backend access token lives 15 min).
    <SessionProvider refetchInterval={4 * 60} refetchOnWindowFocus>
      <SessionSync />
      <QueryClientProvider client={queryClient}>
        {children}
        <Toaster
          position="top-right"
          toastOptions={{
            duration: 4000,
            style: { borderRadius: '10px', background: '#333', color: '#fff' },
          }}
        />
      </QueryClientProvider>
    </SessionProvider>
  );
}
