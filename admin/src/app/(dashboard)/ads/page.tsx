'use client';

import { useRef, useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { adminApi } from '@/lib/api';
import { Megaphone, Upload, Trash2, CheckCircle2, Circle, ExternalLink } from 'lucide-react';
import toast from 'react-hot-toast';

type Audience = 'driver' | 'customer';

interface PopupAd {
  _id: string;
  imageUrl: string;
  linkUrl?: string;
  isActive: boolean;
  // Rows created before the driver/customer split have no value — treat as driver.
  audience?: Audience;
}

const AUDIENCES: { key: Audience; label: string; hint: string }[] = [
  { key: 'driver', label: 'Driver / Vendor', hint: 'Shown in driver & vendor mode' },
  { key: 'customer', label: 'Customer', hint: 'Shown in customer mode' },
];

export default function AdsPage() {
  const qc = useQueryClient();
  const fileRef = useRef<HTMLInputElement>(null);
  const [imageUrl, setImageUrl] = useState('');
  const [linkUrl, setLinkUrl] = useState('');
  const [uploading, setUploading] = useState(false);
  // Which side the new ad is for, and which side the list is showing.
  const [audience, setAudience] = useState<Audience>('driver');
  const [tab, setTab] = useState<Audience>('driver');

  const { data: raw, isLoading } = useQuery({
    queryKey: ['popup-ads'],
    queryFn: () => adminApi.getPopupAds(),
  });
  const allAds: PopupAd[] = ((raw as any)?.data ?? []) as PopupAd[];
  // Only the side currently selected, so the two campaigns never get confused.
  const ads = allAds.filter((a) => (a.audience ?? 'driver') === tab);
  const countFor = (k: Audience) => allAds.filter((a) => (a.audience ?? 'driver') === k).length;

  const invalidate = () => qc.invalidateQueries({ queryKey: ['popup-ads'] });

  const create = useMutation({
    mutationFn: () => adminApi.createPopupAd({ imageUrl, linkUrl: linkUrl.trim(), audience }),
    onSuccess: () => {
      toast.success(`Ad added — now live for ${audience === 'customer' ? 'customers' : 'drivers'}`);
      setTab(audience);
      setImageUrl('');
      setLinkUrl('');
      if (fileRef.current) fileRef.current.value = '';
      invalidate();
    },
    onError: (e: any) => toast.error(e?.message || 'Could not add ad'),
  });

  const setActive = useMutation({
    mutationFn: (id: string) => adminApi.updatePopupAd(id, { isActive: true }),
    onSuccess: () => { toast.success('Active ad set'); invalidate(); },
    onError: (e: any) => toast.error(e?.message || 'Could not update'),
  });

  const remove = useMutation({
    mutationFn: (id: string) => adminApi.deletePopupAd(id),
    onSuccess: () => { toast.success('Ad deleted'); invalidate(); },
    onError: (e: any) => toast.error(e?.message || 'Could not delete'),
  });

  const handleFile = async (file?: File | null) => {
    if (!file) return;
    if (!file.type.startsWith('image/')) return toast.error('Please choose an image');
    setUploading(true);
    try {
      const res: any = await adminApi.uploadAdImage(file);
      const url = res?.data?.url ?? res?.url ?? res?.data?.data?.url;
      if (!url) throw new Error('Upload failed');
      setImageUrl(url);
      toast.success('Image uploaded');
    } catch (e: any) {
      toast.error(e?.message || 'Upload failed');
    } finally {
      setUploading(false);
    }
  };

  return (
    <div className="space-y-5">
      <div className="flex items-center gap-2">
        <Megaphone className="w-6 h-6 text-orange-500" />
        <div>
          <h1 className="text-2xl font-bold text-gray-900 dark:text-white">Ads</h1>
          <p className="text-sm text-gray-500">A popup ad shown on app open. Driver and Customer mode each run their own ad.</p>
        </div>
      </div>

      {/* Add form */}
      <div className="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-700 p-6 space-y-4">
        <h2 className="font-semibold text-gray-900 dark:text-white">Add Ad</h2>

        {/* Who this ad is for — each side has its own active ad. */}
        <div>
          <label className="block text-xs font-medium text-gray-600 dark:text-gray-400 mb-1.5">Show this ad to</label>
          <div className="flex flex-wrap gap-2">
            {AUDIENCES.map((a) => (
              <button
                key={a.key}
                type="button"
                onClick={() => setAudience(a.key)}
                className={`px-3 py-2 rounded-lg border text-sm font-medium transition ${
                  audience === a.key
                    ? 'border-orange-500 bg-orange-500/10 text-orange-600 dark:text-orange-400'
                    : 'border-gray-200 dark:border-gray-700 text-gray-600 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-800'
                }`}
              >
                {a.label}
                <span className="block text-[11px] font-normal opacity-70">{a.hint}</span>
              </button>
            ))}
          </div>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <div className="flex items-center justify-between gap-2 mb-1">
              <label className="block text-xs font-medium text-gray-600 dark:text-gray-400">Ad image</label>
              <span className="text-[11px] font-medium text-orange-500 border border-orange-500/40 rounded-full px-2 py-0.5">
                Recommended: 1080 × 1350 px · 4:5 (portrait)
              </span>
            </div>
            <p className="text-[11px] text-gray-400 mb-1.5">The ratio the app popup shows. Upload at 1080×1350 (4:5) so nothing important gets cut off.</p>
            <input ref={fileRef} type="file" accept="image/*" className="hidden"
              onChange={(e) => handleFile(e.target.files?.[0])} />
            <button
              type="button"
              onClick={() => fileRef.current?.click()}
              disabled={uploading}
              className="w-full inline-flex items-center justify-center gap-2 border border-dashed border-gray-300 dark:border-gray-600 rounded-lg px-3 py-2 text-sm text-gray-600 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-800 disabled:opacity-60"
            >
              <Upload className="w-4 h-4" />
              {uploading ? 'Uploading…' : imageUrl ? 'Change image' : 'Choose image'}
            </button>
          </div>
          <div>
            <label className="block text-xs font-medium text-gray-600 dark:text-gray-400 mb-1">Redirect link (optional)</label>
            <input
              type="text"
              value={linkUrl}
              onChange={(e) => setLinkUrl(e.target.value)}
              placeholder="https://… (opens when the user taps the ad)"
              className="w-full border border-gray-200 dark:border-gray-700 dark:bg-gray-800 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-orange-500"
            />
          </div>
        </div>
        {imageUrl && (
          // eslint-disable-next-line @next/next/no-img-element
          <img src={imageUrl} alt="Ad preview" className="max-h-64 rounded-lg border border-gray-200 dark:border-gray-700" />
        )}
        <button
          onClick={() => create.mutate()}
          disabled={create.isPending || uploading || !imageUrl}
          className="px-4 py-2 rounded-lg bg-orange-500 hover:bg-orange-600 disabled:opacity-50 text-white text-sm font-semibold"
        >
          {create.isPending ? 'Saving…' : 'Save Ad'}
        </button>
      </div>

      {/* List */}
      <div className="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-700 p-6">
        <div className="flex flex-wrap items-center gap-2 mb-4">
          {AUDIENCES.map((a) => (
            <button
              key={a.key}
              type="button"
              onClick={() => setTab(a.key)}
              className={`px-3 py-1.5 rounded-lg text-sm font-semibold transition ${
                tab === a.key
                  ? 'bg-orange-500 text-white'
                  : 'text-gray-600 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-800'
              }`}
            >
              {a.label} ({countFor(a.key)})
            </button>
          ))}
        </div>
        {isLoading ? (
          <p className="text-sm text-gray-500 py-4">Loading…</p>
        ) : ads.length === 0 ? (
          <p className="text-sm text-gray-500 py-4">
            No {tab === 'customer' ? 'customer' : 'driver'} ads yet. Add one above.
          </p>
        ) : (
          <div className="space-y-3">
            {ads.map((a) => (
              <div key={a._id} className="flex items-center gap-4 border border-gray-100 dark:border-gray-800 rounded-lg p-3">
                {/* Image */}
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img src={a.imageUrl} alt="Ad" className="w-16 h-16 object-cover rounded-lg shrink-0" />

                {/* Link + Active badge (badge always on top) */}
                <div className="min-w-0 flex-1">
                  {a.isActive && (
                    <span className="inline-flex items-center gap-1 text-xs px-2 py-0.5 rounded-full font-semibold bg-green-500/15 text-green-500 mb-1">
                      <CheckCircle2 className="w-3.5 h-3.5" /> Active
                    </span>
                  )}
                  {a.linkUrl ? (
                    <a href={a.linkUrl} target="_blank" rel="noreferrer" className="text-xs text-orange-500 flex items-center gap-1 break-all">
                      <ExternalLink className="w-3.5 h-3.5 shrink-0" /> {a.linkUrl}
                    </a>
                  ) : (
                    <p className="text-xs text-gray-400">No link</p>
                  )}
                </div>

                {/* Actions — Set Active then Delete, at the end */}
                <div className="flex items-center gap-2 shrink-0">
                  {!a.isActive && (
                    <button
                      onClick={() => setActive.mutate(a._id)}
                      disabled={setActive.isPending}
                      className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg border border-gray-300 dark:border-gray-600 text-sm font-medium hover:bg-gray-50 dark:hover:bg-gray-800 disabled:opacity-60"
                    >
                      <Circle className="w-4 h-4" /> Set Active
                    </button>
                  )}
                  <button
                    onClick={() => { if (confirm('Delete this ad?')) remove.mutate(a._id); }}
                    disabled={remove.isPending}
                    className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg border border-red-300 dark:border-red-800 text-sm font-medium text-red-600 hover:bg-red-50 dark:hover:bg-red-950 disabled:opacity-60"
                  >
                    <Trash2 className="w-4 h-4" /> Delete
                  </button>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
