'use client';

import { useEffect, useMemo, useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { adminApi } from '@/lib/api';
import { Loader2, RotateCcw } from 'lucide-react';
import toast from 'react-hot-toast';

/**
 * The words on the public website.
 *
 * The fields are not listed here — the server sends them, with their labels,
 * hints, limits and defaults (backend site-text.keys.ts). That is deliberate:
 * adding an editable string should be one entry in one file, not an entry
 * here as well that someone forgets to keep in step.
 */
interface Field {
  key: string;
  group: string;
  label: string;
  hint?: string;
  fallback: string;
  multiline?: boolean;
  maxLength: number;
  value: string;
  isOverridden: boolean;
}

export default function WebsiteTextPage() {
  const queryClient = useQueryClient();
  const [draft, setDraft] = useState<Record<string, string>>({});

  const { data, isLoading } = useQuery({
    queryKey: ['site-text-admin'],
    queryFn: () => adminApi.getSiteText(),
  });
  const fields: Field[] = useMemo(
    () => data?.data?.data ?? data?.data ?? [],
    [data],
  );

  // Seed the form from the server, and re-seed after a save so "changed"
  // goes back to clean rather than staying lit for ever.
  useEffect(() => {
    if (fields.length) {
      setDraft(Object.fromEntries(fields.map((f) => [f.key, f.value])));
    }
  }, [fields]);

  const save = useMutation({
    mutationFn: (items: { key: string; value: string }[]) => adminApi.saveSiteText(items),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['site-text-admin'] });
      toast.success('Saved. The website shows it right away.');
    },
    onError: (e: any) =>
      toast.error(e?.response?.data?.message ?? 'Could not save the text'),
  });

  const reset = useMutation({
    mutationFn: (key: string) => adminApi.resetSiteText(key),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['site-text-admin'] });
      toast.success('Back to the default wording');
    },
    onError: () => toast.error('Could not reset that field'),
  });

  const changed = fields.filter((f) => (draft[f.key] ?? f.value) !== f.value);

  const groups = useMemo(() => {
    const by = new Map<string, Field[]>();
    for (const f of fields) {
      if (!by.has(f.group)) by.set(f.group, []);
      by.get(f.group)!.push(f);
    }
    return [...by.entries()];
  }, [fields]);

  if (isLoading) {
    return (
      <div className="grid h-64 place-items-center">
        <Loader2 className="h-6 w-6 animate-spin text-gray-400" />
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex items-start justify-between gap-3">
        <div>
          <h1 className="text-2xl font-bold text-gray-900 dark:text-white">Website Text</h1>
          <p className="mt-1 text-gray-500">
            The wording on the public website. Clear a field to hide that block; use Reset to go
            back to the original wording.
          </p>
        </div>
        <button
          onClick={() =>
            save.mutate(changed.map((f) => ({ key: f.key, value: draft[f.key] ?? f.value })))
          }
          disabled={changed.length === 0 || save.isPending}
          className="inline-flex shrink-0 items-center gap-2 rounded-lg bg-brand-600 px-5 py-2.5 text-sm font-semibold text-white transition-colors hover:bg-brand-700 disabled:opacity-40"
        >
          {save.isPending && <Loader2 className="h-4 w-4 animate-spin" />}
          {changed.length === 0 ? 'Saved' : `Save ${changed.length} change${changed.length > 1 ? 's' : ''}`}
        </button>
      </div>

      {groups.map(([group, items]) => (
        <div
          key={group}
          className="rounded-xl border border-gray-200 bg-white p-6 dark:border-gray-700 dark:bg-gray-900"
        >
          <h2 className="mb-5 font-semibold text-gray-900 dark:text-white">{group}</h2>
          <div className="space-y-5">
            {items.map((f) => {
              const value = draft[f.key] ?? f.value;
              const dirty = value !== f.value;
              return (
                <div key={f.key}>
                  <div className="mb-1 flex items-center justify-between gap-3">
                    <label className="text-sm font-medium text-gray-700 dark:text-gray-300">
                      {f.label}
                      {dirty && <span className="ml-2 text-xs font-normal text-brand-600">changed</span>}
                    </label>
                    {f.isOverridden && (
                      <button
                        onClick={() => reset.mutate(f.key)}
                        className="inline-flex items-center gap-1 text-xs font-semibold text-gray-400 transition-colors hover:text-gray-700 dark:hover:text-gray-200"
                        title="Back to the wording the site ships with"
                      >
                        <RotateCcw className="h-3 w-3" />
                        Reset
                      </button>
                    )}
                  </div>
                  {f.multiline ? (
                    <textarea
                      rows={3}
                      maxLength={f.maxLength}
                      value={value}
                      onChange={(e) => setDraft({ ...draft, [f.key]: e.target.value })}
                      className="w-full rounded-lg border border-gray-200 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-brand-500 dark:border-gray-700 dark:bg-gray-800 dark:text-white"
                    />
                  ) : (
                    <input
                      type="text"
                      maxLength={f.maxLength}
                      value={value}
                      onChange={(e) => setDraft({ ...draft, [f.key]: e.target.value })}
                      className="w-full rounded-lg border border-gray-200 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-brand-500 dark:border-gray-700 dark:bg-gray-800 dark:text-white"
                    />
                  )}
                  <div className="mt-1 flex items-start justify-between gap-3">
                    <p className="text-xs text-gray-400">
                      {f.hint ?? (value.trim() ? '' : 'Empty — this block is hidden on the website.')}
                    </p>
                    <span className="shrink-0 text-xs tabular-nums text-gray-400">
                      {value.length}/{f.maxLength}
                    </span>
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      ))}
    </div>
  );
}
