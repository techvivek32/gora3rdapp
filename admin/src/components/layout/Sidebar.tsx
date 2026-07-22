'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { cn } from '@/lib/utils';
import {
  LayoutDashboard, Users, Car, Bell, CreditCard,
  BarChart3, Flag, Image, Settings, LogOut, PlayCircle, Building2,
  FileText, Star, Map, BadgeCheck, Wallet, Trophy, MessageSquare, Banknote, DollarSign, UserX, UserCircle
} from 'lucide-react';
import { signOut, useSession } from 'next-auth/react';

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
      { href: '/support-chats', label: 'Support Chats', icon: MessageSquare },
      { href: '/referrals', label: 'Invite Leaderboard', icon: Trophy },
      { href: '/verification-requests', label: 'Verification Requests', icon: BadgeCheck },
      { href: '/deletion-requests', label: 'Deletion Requests', icon: UserX },
      { href: '/requirements', label: 'Requirements', icon: FileText },
      { href: '/vehicles', label: 'Available Vehicles', icon: Car },
      { href: '/reports', label: 'Reports', icon: Flag },
    ],
  },
  {
    label: 'Franchises',
    items: [
      { href: '/franchises', label: 'Franchises', icon: Building2 },
      { href: '/franchise-leaderboard', label: 'Franchise Leaderboard', icon: Trophy },
    ],
  },
  {
    label: 'Monetization',
    items: [
      { href: '/subscriptions', label: 'Memberships', icon: Star },
      { href: '/plans', label: 'Plan Management', icon: BadgeCheck },
      { href: '/payments', label: 'Payments', icon: CreditCard },
      { href: '/wallets', label: 'Wallet Management', icon: Wallet },
      { href: '/withdrawals', label: 'Withdrawals', icon: Banknote },
    ],
  },
  {
    label: 'Content & Config',
    items: [
      { href: '/cities', label: 'Cities', icon: Map },
      { href: '/banners', label: 'Banners', icon: Image },
      { href: '/training-videos', label: 'Training Videos', icon: PlayCircle },
      { href: '/notifications', label: 'Notifications', icon: Bell },
      { href: '/pricing', label: 'Pricing Config', icon: DollarSign },
      { href: '/settings', label: 'Settings', icon: Settings },
      { href: '/profile', label: 'Profile', icon: UserCircle },
    ],
  },
];

// Franchise panel is a city-scoped subset of the admin panel. Same routes,
// but a franchise only ever sees data for their own city (enforced server-side).
const franchiseNavigation = [
  {
    label: 'Overview',
    items: [
      { href: '/dashboard', label: 'Dashboard', icon: LayoutDashboard },
      { href: '/analytics', label: 'Analytics', icon: BarChart3 },
    ],
  },
  {
    label: 'Operations',
    items: [
      { href: '/users', label: 'Users', icon: Users },
      { href: '/support-chats', label: 'Support Chat', icon: MessageSquare },
      { href: '/referrals', label: 'Invite Leaderboard', icon: Trophy },
      { href: '/verification-requests', label: 'Verification Requests', icon: BadgeCheck },
      { href: '/deletion-requests', label: 'Delete Requests', icon: UserX },
      { href: '/requirements', label: 'Requirements', icon: FileText },
      { href: '/vehicles', label: 'Available', icon: Car },
      { href: '/reports', label: 'Reports', icon: Flag },
    ],
  },
  {
    label: 'Monetization',
    items: [
      { href: '/subscriptions', label: 'Membership', icon: Star },
      { href: '/payments', label: 'Payment', icon: CreditCard },
      { href: '/wallets', label: 'Wallet Management', icon: Wallet },
    ],
  },
  {
    label: 'Account',
    items: [
      { href: '/cities', label: 'Cities', icon: Map },
      { href: '/profile', label: 'Profile', icon: UserCircle },
    ],
  },
];

export default function Sidebar() {
  const pathname = usePathname();
  const { data: session } = useSession();
  const isFranchise = (session?.user as any)?.role === 'franchise';
  const franchiseCity = (session?.user as any)?.franchiseCity as string | undefined;
  const nav = isFranchise ? franchiseNavigation : navigation;

  return (
    <aside className="w-64 h-screen bg-white dark:bg-gray-900 border-r border-gray-200 dark:border-gray-700 flex flex-col">
      {/* Logo */}
      <div className="flex items-center gap-3 px-6 py-4 border-b border-gray-200 dark:border-gray-700">
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img
          src="/Gora_Taxi_Partner.png"
          alt="Gora Taxi Partner"
          className="h-10 w-10 flex-shrink-0 object-contain rounded-xl"
        />
        <div>
          <span className="font-bold text-gray-900 dark:text-white">Gora Taxi</span>
          <div className="flex items-center gap-1">
            <span className="text-xs text-gray-500">
              {isFranchise ? `Franchise${franchiseCity ? ` · ${franchiseCity}` : ''}` : 'Partner'}
            </span>
          </div>
        </div>
      </div>

      {/* Navigation */}
      <nav className="flex-1 overflow-y-auto px-3 py-4 space-y-6">
        {nav.map((group) => (
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
      <div className="px-3 py-1 border-t border-gray-200 dark:border-gray-700">
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
