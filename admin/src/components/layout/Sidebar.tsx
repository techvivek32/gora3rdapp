'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { cn } from '@/lib/utils';
import {
  LayoutDashboard, Users, Car, MapPin, Bell, CreditCard,
  BarChart3, Flag, Image, Settings, ChevronDown, LogOut, Shield,
  FileText, Megaphone, Star, Map, BadgeCheck, Wallet
} from 'lucide-react';
import { signOut } from 'next-auth/react';

const navigation = [
  {
    label: 'Overview',
    items: [
      { href: '/dashboard', label: 'Dashboard', icon: LayoutDashboard },
      { href: '/analytics', label: 'Analytics', icon: BarChart3 },
    ],
  },
  {
    label: 'Users & Platform',
    items: [
      { href: '/users', label: 'Users', icon: Users },
      { href: '/verification-requests', label: 'Verification Requests', icon: BadgeCheck },
      { href: '/requirements', label: 'Requirements', icon: FileText },
      { href: '/vehicles', label: 'Available Vehicles', icon: Car },
      { href: '/reports', label: 'Reports', icon: Flag },
    ],
  },
  {
    label: 'Monetization',
    items: [
      { href: '/subscriptions', label: 'Memberships', icon: Star },
      { href: '/payments', label: 'Payments', icon: CreditCard },
      { href: '/wallets', label: 'Wallet Management', icon: Wallet },
    ],
  },
  {
    label: 'Content & Config',
    items: [
      { href: '/cities', label: 'Cities', icon: Map },
      { href: '/banners', label: 'Banners', icon: Image },
      { href: '/notifications', label: 'Notifications', icon: Bell },
      { href: '/settings', label: 'Settings', icon: Settings },
    ],
  },
];

export default function Sidebar() {
  const pathname = usePathname();

  return (
    <aside className="w-64 h-screen bg-white dark:bg-gray-900 border-r border-gray-200 dark:border-gray-700 flex flex-col">
      {/* Logo */}
      <div className="flex items-center gap-3 px-6 py-5 border-b border-gray-200 dark:border-gray-700">
        <div className="w-9 h-9 bg-orange-500 rounded-lg flex items-center justify-center">
          <Car className="w-5 h-5 text-white" />
        </div>
        <div>
          <span className="font-bold text-gray-900 dark:text-white">Gora Cabs</span>
          <div className="flex items-center gap-1">
            <Shield className="w-3 h-3 text-orange-500" />
            <span className="text-xs text-gray-500">Admin Panel</span>
          </div>
        </div>
      </div>

      {/* Navigation */}
      <nav className="flex-1 overflow-y-auto px-3 py-4 space-y-6">
        {navigation.map((group) => (
          <div key={group.label}>
            <p className="px-3 mb-2 text-xs font-semibold text-gray-400 uppercase tracking-wider">
              {group.label}
            </p>
            <ul className="space-y-0.5">
              {group.items.map((item) => {
                const isActive = pathname === item.href || pathname.startsWith(item.href + '/');
                return (
                  <li key={item.href}>
                    <Link
                      href={item.href}
                      className={cn(
                        'sidebar-link',
                        isActive && 'active',
                      )}
                    >
                      <item.icon className="w-4 h-4 flex-shrink-0" />
                      {item.label}
                    </Link>
                  </li>
                );
              })}
            </ul>
          </div>
        ))}
      </nav>

      {/* Logout */}
      <div className="px-3 py-4 border-t border-gray-200 dark:border-gray-700">
        <button
          onClick={() => signOut({ callbackUrl: '/login' })}
          className="sidebar-link w-full text-red-500 hover:text-red-600 hover:bg-red-50 dark:hover:bg-red-900/20"
        >
          <LogOut className="w-4 h-4" />
          Sign Out
        </button>
      </div>
    </aside>
  );
}
