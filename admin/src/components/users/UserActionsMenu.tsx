'use client';

import { useState } from 'react';
import { MoreVertical, Shield, Ban, UserCheck, Crown, Star, Eye } from 'lucide-react';
import Link from 'next/link';

interface Props {
  user: any;
  onVerify: () => void;
  onBlock: () => void;
}

export function UserActionsMenu({ user, onVerify, onBlock }: Props) {
  const [open, setOpen] = useState(false);

  return (
    <div className="relative">
      <button
        onClick={() => setOpen(!open)}
        className="p-1.5 rounded-md hover:bg-gray-100 dark:hover:bg-gray-800 text-gray-500"
      >
        <MoreVertical className="w-4 h-4" />
      </button>

      {open && (
        <>
          <div className="fixed inset-0 z-10" onClick={() => setOpen(false)} />
          <div className="absolute right-0 top-8 z-20 w-48 bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-700 rounded-xl shadow-xl py-1">
            <Link
              href={`/users/${user._id}`}
              className="flex items-center gap-2.5 px-4 py-2 text-sm hover:bg-gray-50 dark:hover:bg-gray-800 text-gray-700 dark:text-gray-300"
              onClick={() => setOpen(false)}
            >
              <Eye className="w-4 h-4" /> View Profile
            </Link>

            {!user.isVerified && (
              <button
                onClick={() => { onVerify(); setOpen(false); }}
                className="flex items-center gap-2.5 px-4 py-2 text-sm hover:bg-gray-50 dark:hover:bg-gray-800 text-emerald-600 w-full"
              >
                <Shield className="w-4 h-4" /> Verify User
              </button>
            )}

            <button
              className="flex items-center gap-2.5 px-4 py-2 text-sm hover:bg-gray-50 dark:hover:bg-gray-800 text-purple-600 w-full"
              onClick={() => setOpen(false)}
            >
              <Star className="w-4 h-4" /> Upgrade to Premium
            </button>

            <button
              className="flex items-center gap-2.5 px-4 py-2 text-sm hover:bg-gray-50 dark:hover:bg-gray-800 text-amber-600 w-full"
              onClick={() => setOpen(false)}
            >
              <Crown className="w-4 h-4" /> Upgrade to Golden
            </button>

            <div className="border-t border-gray-100 dark:border-gray-800 my-1" />

            {!user.isBlocked ? (
              <button
                onClick={() => { onBlock(); setOpen(false); }}
                className="flex items-center gap-2.5 px-4 py-2 text-sm hover:bg-gray-50 dark:hover:bg-gray-800 text-red-600 w-full"
              >
                <Ban className="w-4 h-4" /> Block User
              </button>
            ) : (
              <button
                onClick={() => setOpen(false)}
                className="flex items-center gap-2.5 px-4 py-2 text-sm hover:bg-gray-50 dark:hover:bg-gray-800 text-green-600 w-full"
              >
                <UserCheck className="w-4 h-4" /> Unblock User
              </button>
            )}
          </div>
        </>
      )}
    </div>
  );
}
