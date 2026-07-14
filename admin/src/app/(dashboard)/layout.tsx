import { redirect } from 'next/navigation';
import { getServerSession } from 'next-auth';
import { authOptions } from '@/lib/auth';
import DashboardShell from '@/components/layout/DashboardShell';

export default async function DashboardLayout({ children }: { children: React.ReactNode }) {
  const session = await getServerSession(authOptions);
  if (!session) redirect('/login');

  // The chrome (sidebar + header) is rendered by DashboardShell, which owns the
  // fullscreen toggle — this component stays a server component for the session check.
  return <DashboardShell>{children}</DashboardShell>;
}
