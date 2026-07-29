'use client';

import { useSession } from 'next-auth/react';
import { Moon, Sun, Maximize2 } from 'lucide-react';
import { useEffect, useState } from 'react';
import NotificationBell from './NotificationBell';
import { useFullscreen } from './FullscreenContext';

export default function Header() {
  const { data: session } = useSession();
  const { toggleFullscreen } = useFullscreen();
  const [isDark, setIsDark] = useState(true);

  // Show the real role — a franchise session must not read "Super Admin".
  const role = (session?.user as any)?.role as string | undefined;
  const franchiseCity = (session?.user as any)?.franchiseCity as string | undefined;
  const roleLabel =
    role === 'franchise'
      ? `Franchise${franchiseCity ? ` · ${franchiseCity}` : ''}`
      : role === 'admin'
        ? 'Admin'
        : 'Super Admin';

  // Sync with the theme applied by the pre-paint init script (defaults to dark).
  useEffect(() => {
    setIsDark(document.documentElement.classList.contains('dark'));
  }, []);

  const toggleTheme = () => {
    const next = !document.documentElement.classList.contains('dark');
    document.documentElement.classList.toggle('dark', next);
    localStorage.setItem('theme', next ? 'dark' : 'light');
    setIsDark(next);
  };

  return (
    <header className="h-16 bg-white dark:bg-gray-900 border-b border-gray-200 dark:border-gray-700 flex items-center justify-between px-6 flex-shrink-0">
      {/* Left */}
      <div className="flex items-center gap-4">
        
      </div>

      {/* Right */}
      <div className="flex items-center gap-3">
        {/* Fullscreen Toggle — available on every page */}
        <button
          onClick={toggleFullscreen}
          title="Fullscreen"
          className="p-2 rounded-lg text-gray-500 hover:text-gray-700 hover:bg-gray-100 dark:hover:bg-gray-800 transition-colors"
        >
          <Maximize2 className="w-5 h-5" />
        </button>

        {/* Theme Toggle */}
        <button
          onClick={toggleTheme}
          className="p-2 rounded-lg text-gray-500 hover:text-gray-700 hover:bg-gray-100 dark:hover:bg-gray-800 transition-colors"
        >
          {isDark ? <Sun className="w-5 h-5" /> : <Moon className="w-5 h-5" />}
        </button>

        {/* Notifications */}
        <NotificationBell />

        {/* User Avatar */}
        <div className="flex items-center gap-2 pl-3 border-l border-gray-200 dark:border-gray-700">
          <div className="w-8 h-8 rounded-full bg-orange-500 flex items-center justify-center">
            <span className="text-white text-sm font-semibold">
              {session?.user?.name?.[0]?.toUpperCase() || 'A'}
            </span>
          </div>
          <div className="hidden md:block">
            <p className="text-sm font-medium text-gray-900 dark:text-white">
              {session?.user?.name || 'Admin'}
            </p>
            <p className="text-xs text-gray-500">{roleLabel}</p>
          </div>
        </div>
      </div>
    </header>
  );
}
