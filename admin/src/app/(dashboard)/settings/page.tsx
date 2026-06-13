'use client';

import { useSession } from 'next-auth/react';
import { Badge } from '@/components/ui/Badge';

export default function SettingsPage() {
  const { data: session } = useSession();

  return (
    <div className="space-y-6 max-w-2xl">
      <div>
        <h1 className="text-2xl font-bold text-gray-900">Settings</h1>
        <p className="text-gray-500 mt-1">Account and platform configuration</p>
      </div>

      <div className="bg-white rounded-xl border border-gray-200 p-6">
        <h2 className="font-semibold text-gray-900 mb-4">Admin Profile</h2>
        <div className="flex items-center gap-4">
          <div className="w-16 h-16 bg-brand-100 rounded-full flex items-center justify-center">
            <span className="text-brand-600 font-bold text-2xl">
              {session?.user?.name?.[0]?.toUpperCase() || 'A'}
            </span>
          </div>
          <div>
            <p className="font-semibold text-lg">{session?.user?.name || 'Admin'}</p>
            <p className="text-gray-500">{session?.user?.email}</p>
            <Badge variant="warning" className="mt-1">
              {(session?.user as any)?.role || 'admin'}
            </Badge>
          </div>
        </div>
      </div>

      <div className="bg-white rounded-xl border border-gray-200 p-6">
        <h2 className="font-semibold text-gray-900 mb-4">Platform Info</h2>
        <dl className="space-y-3">
          {[
            { label: 'Platform Name', value: 'Gora Cabs Admin' },
            { label: 'API Version', value: 'v1' },
            { label: 'Build', value: 'Production' },
          ].map(({ label, value }) => (
            <div key={label} className="flex justify-between py-2 border-b border-gray-100 last:border-0">
              <dt className="text-gray-500 text-sm">{label}</dt>
              <dd className="font-medium text-sm">{value}</dd>
            </div>
          ))}
        </dl>
      </div>

      <div className="bg-amber-50 border border-amber-200 rounded-xl p-5">
        <h3 className="font-semibold text-amber-800">Environment Variables Required</h3>
        <p className="text-amber-700 text-sm mt-1">
          Configure <code className="bg-amber-100 px-1 rounded">.env.local</code> with{' '}
          <code className="bg-amber-100 px-1 rounded">NEXTAUTH_SECRET</code>,{' '}
          <code className="bg-amber-100 px-1 rounded">NEXT_PUBLIC_API_URL</code>, and{' '}
          <code className="bg-amber-100 px-1 rounded">NEXTAUTH_URL</code> before deploying.
        </p>
      </div>
    </div>
  );
}
