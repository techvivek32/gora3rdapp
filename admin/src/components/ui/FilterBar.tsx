'use client';

import { Search, X } from 'lucide-react';

interface FilterBarProps {
  // Search (omit onSearch to hide the search box)
  search?: string;
  onSearch?: (v: string) => void;
  searchPlaceholder?: string;
  // Extra filter controls (e.g. status selects/tabs) rendered inline
  children?: React.ReactNode;
  onClear?: () => void;
}

const inputCls =
  'px-3 py-2 rounded-lg border border-gray-200 dark:border-gray-700 dark:bg-gray-800 dark:text-white text-sm focus:outline-none focus:ring-2 focus:ring-orange-500';

/** Shared admin filter bar: text search plus any extra controls. */
export function FilterBar({
  search = '',
  onSearch,
  searchPlaceholder = 'Search…',
  children,
  onClear,
}: FilterBarProps) {
  return (
    <div className="flex flex-wrap items-center gap-3">
      {onSearch && (
        <div className="relative flex-1 min-w-[200px] max-w-xs">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
          <input
            value={search}
            onChange={(e) => onSearch(e.target.value)}
            placeholder={searchPlaceholder}
            className={`${inputCls} w-full pl-9`}
          />
        </div>
      )}

      {children}

      {search && onClear && (
        <button
          onClick={onClear}
          className="flex items-center gap-1 px-3 py-2 rounded-lg text-sm text-gray-500 dark:text-gray-400 border border-gray-200 dark:border-gray-700 hover:bg-gray-50 dark:hover:bg-gray-800"
        >
          <X className="w-4 h-4" /> Clear
        </button>
      )}
    </div>
  );
}
