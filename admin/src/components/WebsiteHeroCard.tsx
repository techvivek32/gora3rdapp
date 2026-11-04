'use client';

import { useRef, useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { adminApi } from '@/lib/api';
import toast from 'react-hot-toast';

/**
 * The picture beside the headline on the public website's first screen.
 *
 * It lives in the same collection as the per-city hero images, under a
 * reserved key, because it is the same kind of thing: a hero image, chosen
 * rather than resolved. The per-city ones are fetched from Google Places and
 * refreshed monthly; this one is never touched by that, which is the whole
 * point of setting it by hand.
 *
 * With nothing set, the website shows the top cab class from the fleet
 * instead — so leaving this empty is a real choice, not a broken page.
 */
const WEBSITE_HERO_KEY = '__website__';

interface CityImage {
  _id: string;
  city: string;
  imageUrl?: string;
  isManual?: boolean;
  isActive?: boolean;
}

export function WebsiteHeroCard() {
  const queryClient = useQueryClient();
  const fileRef = useRef<HTMLInputElement>(null);
  const [uploading, setUploading] = useState(false);

  const { data, isLoading } = useQuery({
    queryKey: ['city-images'],
    queryFn: () => adminApi.getCityImages(),
  });

  const rows: CityImage[] = data?.data?.data ?? data?.data ?? [];
  const hero = rows.find((r) => r.city === WEBSITE_HERO_KEY);
  const imageUrl = hero?.imageUrl ?? '';

  const save = useMutation({
    mutationFn: (url: string) =>
      adminApi.upsertCityImage({ city: WEBSITE_HERO_KEY, imageUrl: url, isActive: true }),
    onSuccess: (_r, url) => {
      queryClient.invalidateQueries({ queryKey: ['city-images'] });
      toast.success(url ? 'Hero image saved' : 'Hero image removed');
    },
    onError: () => toast.error('Could not save the hero image'),
  });

  const upload = async (file: File) => {
    // Guard before the request so the operator gets a sentence rather than a
    // 413 from the proxy.
    if (!file.type.startsWith('image/')) return toast.error('That is not an image');
    if (file.size > 8 * 1024 * 1024) return toast.error('Keep it under 8 MB');
    setUploading(true);
    try {
      const res = await adminApi.uploadShowcaseImage(file);
      const url = res?.data?.data?.url ?? res?.data?.url;
      if (!url) throw new Error('no url');
      await save.mutateAsync(url);
    } catch {
      toast.error('Upload failed');
    } finally {
      setUploading(false);
    }
  };

  return (
    <div className="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-700 p-6">
      <div className="flex items-start justify-between gap-4">
        <div>
          <h2 className="font-semibold text-lg text-gray-900 dark:text-white">Website hero image</h2>
          <p className="text-sm text-gray-500 mt-1">
            Shown beside the headline on the first screen of goracabs.com. Landscape, 4:3 or
            wider — 1200&nbsp;×&nbsp;900&nbsp;px is plenty.
          </p>
        </div>
        {imageUrl && (
          <button
            onClick={() => save.mutate('')}
            disabled={save.isPending}
            className="shrink-0 px-3 py-1.5 rounded-lg text-sm font-semibold text-red-600 hover:bg-red-50 dark:hover:bg-red-900/20 transition-colors disabled:opacity-50"
          >
            Remove
          </button>
        )}
      </div>

      <input
        ref={fileRef}
        // The page has a second file input further down, in the showcase
        // form. This names the one that sets the website's hero so a test
        // does not have to guess by DOM order.
        data-hero-upload
        type="file"
        accept="image/*"
        className="hidden"
        onChange={(e) => {
          const f = e.target.files?.[0];
          if (f) upload(f);
          e.target.value = '';
        }}
      />

      <div className="mt-4">
        {isLoading ? (
          <div className="h-48 rounded-lg bg-gray-100 dark:bg-gray-800 animate-pulse" />
        ) : imageUrl ? (
          <button
            type="button"
            onClick={() => fileRef.current?.click()}
            disabled={uploading}
            className="group relative block w-full overflow-hidden rounded-lg border border-gray-200 dark:border-gray-700"
          >
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img src={imageUrl} alt="Website hero" className="h-56 w-full object-cover" />
            <span className="absolute inset-0 grid place-items-center bg-black/0 text-sm font-semibold text-transparent transition-colors group-hover:bg-black/50 group-hover:text-white">
              {uploading ? 'Uploading…' : 'Replace image'}
            </span>
          </button>
        ) : (
          <button
            type="button"
            onClick={() => fileRef.current?.click()}
            disabled={uploading}
            className="grid h-56 w-full place-items-center rounded-lg border-2 border-dashed border-gray-300 dark:border-gray-600 text-sm text-gray-500 transition-colors hover:border-brand-500 hover:text-brand-600 disabled:opacity-50"
          >
            {uploading ? 'Uploading…' : (
              <span className="text-center">
                <span className="block font-semibold">Upload a hero image</span>
                <span className="mt-1 block text-xs">
                  With none set, the website shows your top cab class instead.
                </span>
              </span>
            )}
          </button>
        )}
      </div>
    </div>
  );
}
