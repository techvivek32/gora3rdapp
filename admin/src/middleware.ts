import { NextResponse } from 'next/server';
import type { NextRequest } from 'next/server';
import { getToken } from 'next-auth/jwt';

// The only routes a franchise may open. Everything else (managing franchises,
// plans, banners, notifications, pricing, settings, withdrawals…) is admin-only.
// Kept in sync with the franchise sidebar in components/layout/Sidebar.tsx.
const FRANCHISE_ALLOWED = [
  '/dashboard',
  '/analytics',
  '/users',
  '/support-chats',
  '/referrals',
  '/verification-requests',
  '/deletion-requests',
  '/requirements',
  '/vehicles',
  '/reports',
  '/subscriptions',
  '/payments',
  '/wallets',
  '/cities',
  '/profile',
];

function isFranchiseAllowed(pathname: string): boolean {
  return FRANCHISE_ALLOWED.some((p) => pathname === p || pathname.startsWith(`${p}/`));
}

// A franchise can otherwise reach admin-only pages by typing the URL directly
// (the sidebar just hides the links). This redirects them back to their dashboard.
// Admins/super-admins are never restricted; unauthenticated access is still handled
// by the dashboard layout's getServerSession check.
export async function middleware(req: NextRequest) {
  const token = await getToken({ req, secret: process.env.NEXTAUTH_SECRET });
  if (token?.role === 'franchise' && !isFranchiseAllowed(req.nextUrl.pathname)) {
    return NextResponse.redirect(new URL('/dashboard', req.url));
  }
  return NextResponse.next();
}

export const config = {
  // Run on every page except API routes, Next internals, the login page, and files
  // with an extension (static assets).
  matcher: ['/((?!api|_next/static|_next/image|favicon.ico|login|.*\\.).*)'],
};
