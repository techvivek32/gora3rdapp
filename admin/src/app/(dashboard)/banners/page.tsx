'use client';

import { useState, useRef } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { adminApi } from '@/lib/api';
import { Badge } from '@/components/ui/Badge';
import toast from 'react-hot-toast';

interface Banner {
  _id: string;
  title: string;
  subtitle?: string;
  imageUrl?: string;
  phone?: string;
  whatsapp?: string;
  actionUrl?: string;
  startDate?: string;
  endDate?: string;
  isActive: boolean;
  sortOrder: number;
  clickCount: number;
  viewCount: number;
}

const EMPTY_FORM = {
  title: '', subtitle: '', imageUrl: '', phone: '', whatsapp: '', sameWhatsapp: true,
  actionUrl: '', startDate: '', endDate: '', isActive: true,
};

export default function BannersPage() {
  const [showForm, setShowForm] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [form, setForm] = useState(EMPTY_FORM);
  const [imgError, setImgError] = useState(false);
  const [uploading, setUploading] = useState(false);
  const fileInputRef = useRef<HTMLInputElement>(null);
  const queryClient = useQueryClient();

  const { data, isLoading } = useQuery({
    queryKey: ['banners'],
    queryFn: () => adminApi.getBanners(),
  });

  // Fix: interceptor extracts data?.data, so response.data = bannersArray
  const banners: Banner[] = Array.isArray((data as any)?.data) ? (data as any).data : [];

  // Payload sent to the API — WhatsApp mirrors the phone when "same" is ticked.
  const buildPayload = () => ({
    title: form.title.trim(),
    subtitle: form.subtitle.trim(),
    imageUrl: form.imageUrl.trim(),
    phone: form.phone.trim(),
    whatsapp: (form.sameWhatsapp ? form.phone : form.whatsapp).trim(),
    actionUrl: form.actionUrl.trim(),
    // Empty means "no bound" — the backend treats a missing date as always-on.
    startDate: form.startDate || null,
    endDate: form.endDate || null,
    isActive: form.isActive,
  });

  const createMutation = useMutation({
    mutationFn: () => adminApi.createBanner(buildPayload()),
    onSuccess: () => {
      toast.success('Banner created');
      setForm(EMPTY_FORM);
      setShowForm(false);
      queryClient.invalidateQueries({ queryKey: ['banners'] });
    },
    onError: () => toast.error('Failed to create banner'),
  });

  const updateMutation = useMutation({
    mutationFn: () => adminApi.updateBanner(editingId!, buildPayload()),
    onSuccess: () => {
      toast.success('Banner updated');
      setEditingId(null);
      setForm(EMPTY_FORM);
      setShowForm(false);
      queryClient.invalidateQueries({ queryKey: ['banners'] });
    },
    onError: () => toast.error('Failed to update banner'),
  });

  const toggleMutation = useMutation({
    mutationFn: ({ id, isActive }: { id: string; isActive: boolean }) =>
      adminApi.updateBanner(id, { isActive }),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['banners'] }),
  });

  const deleteMutation = useMutation({
    mutationFn: (id: string) => adminApi.deleteBanner(id),
    onSuccess: () => {
      toast.success('Banner deleted');
      queryClient.invalidateQueries({ queryKey: ['banners'] });
    },
    onError: () => toast.error('Failed to delete banner'),
  });

  const openCreate = () => {
    setEditingId(null);
    setForm(EMPTY_FORM);
    setImgError(false);
    setShowForm(true);
  };

  const openEdit = (b: Banner) => {
    setEditingId(b._id);
    const phone = b.phone ?? '';
    const whatsapp = b.whatsapp ?? '';
    // "Same" when there's no separate WhatsApp number, or it matches the phone.
    const sameWhatsapp = !whatsapp || whatsapp === phone;
    setForm({
      title: b.title,
      subtitle: b.subtitle ?? '',
      imageUrl: b.imageUrl ?? '',
      phone,
      whatsapp,
      sameWhatsapp,
      actionUrl: b.actionUrl ?? '',
      // <input type="date"> needs yyyy-mm-dd.
      startDate: b.startDate ? String(b.startDate).slice(0, 10) : '',
      endDate: b.endDate ? String(b.endDate).slice(0, 10) : '',
      isActive: b.isActive,
    });
    setImgError(false);
    setShowForm(true);
  };

  const handleFileUpload = async (file: File) => {
    if (!file.type.startsWith('image/')) return toast.error('Please select an image file');
    setUploading(true);
    try {
      const res = await adminApi.uploadBannerImage(file) as any;
      // Interceptor: { data: { url } } or { url } depending on nesting
      const url = res?.data?.url ?? res?.url ?? res?.data?.data?.url;
      if (!url) throw new Error('No URL returned');
      setForm((f) => ({ ...f, imageUrl: url }));
      setImgError(false);
      toast.success('Image uploaded');
    } catch {
      toast.error('Upload failed — check storage config or paste a URL instead');
    } finally {
      setUploading(false);
    }
  };

  const handleSubmit = () => {
    if (!form.imageUrl.trim()) return toast.error('A banner image is required');
    if (editingId) updateMutation.mutate();
    else createMutation.mutate();
  };

  const isBusy = createMutation.isPending || updateMutation.isPending || uploading;

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900 dark:text-white">Banners</h1>
          <p className="text-gray-500 mt-1">Manage promotional banners shown at the top of the app</p>
        </div>
        <button
          onClick={showForm ? () => { setShowForm(false); setEditingId(null); } : openCreate}
          className="px-4 py-2 rounded-lg text-sm font-semibold bg-brand-600 text-white hover:bg-brand-700 transition-colors"
        >
          {showForm ? 'Cancel' : '+ Add Banner'}
        </button>
      </div>

      {/* Form */}
      {showForm && (
        <div className="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-700 p-6 space-y-5">
          <h2 className="font-semibold text-lg text-gray-900 dark:text-white">{editingId ? 'Edit Banner' : 'New Banner'}</h2>

          {/* Image upload + URL */}
          <div>
            <div className="flex items-center justify-between mb-2 flex-wrap gap-2">
              <label className="block text-sm font-medium text-gray-700 dark:text-gray-300">Banner Image</label>
              <span className="inline-flex items-center gap-1.5 text-xs font-medium text-brand-700 bg-brand-50 border border-brand-200 rounded-full px-2.5 py-1">
                <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 5a1 1 0 011-1h14a1 1 0 011 1v14a1 1 0 01-1 1H5a1 1 0 01-1-1V5z" /></svg>
                Recommended: 1080 × 528 px · 2.05:1 (landscape)
              </span>
            </div>
            <p className="text-xs text-gray-400 mb-2">
              This is the exact ratio the app shows banners at (home & requirement list). Any image is auto-cropped to fit — upload at 1080×528 so nothing important gets cut off.
            </p>

            {/* Hidden file input */}
            <input
              ref={fileInputRef}
              type="file"
              accept="image/*"
              className="hidden"
              onChange={(e) => { const f = e.target.files?.[0]; if (f) handleFileUpload(f); e.target.value = ''; }}
            />

            {/* Preview / upload area — sized like the app (minimal, phone-width) */}
            <div
              onClick={() => !uploading && fileInputRef.current?.click()}
              onDragOver={(e) => e.preventDefault()}
              onDrop={(e) => { e.preventDefault(); const f = e.dataTransfer.files?.[0]; if (f) handleFileUpload(f); }}
              className={`relative rounded-2xl overflow-hidden aspect-[358/175] w-full max-w-sm mx-auto cursor-pointer border-2 border-dashed transition-colors ${uploading ? 'border-brand-400 opacity-70' : 'border-gray-300 hover:border-brand-500'}`}
            >
              {form.imageUrl && !imgError ? (
                <>
                  <img
                    src={form.imageUrl}
                    alt="Preview"
                    className="w-full h-full object-cover"
                    onError={() => setImgError(true)}
                  />
                  {/* Mobile-style title/subtitle gradient — matches the app */}
                  {(form.title || form.subtitle) && (
                    <div className="absolute inset-x-0 bottom-0 p-3 bg-gradient-to-t from-black/65 to-transparent pointer-events-none">
                      {form.title && <p className="text-white font-bold text-sm leading-tight line-clamp-1">{form.title}</p>}
                      {form.subtitle && <p className="text-white/80 text-[11px] leading-tight line-clamp-1">{form.subtitle}</p>}
                    </div>
                  )}
                  {/* Overlay on hover */}
                  <div className="absolute inset-0 bg-black/40 opacity-0 hover:opacity-100 transition-opacity flex flex-col items-center justify-center gap-1">
                    <svg className="w-8 h-8 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-8l-4-4m0 0L8 8m4-4v12" /></svg>
                    <span className="text-white text-sm font-medium">Click to change</span>
                  </div>
                </>
              ) : (
                <div className="w-full h-full bg-gradient-to-br from-orange-100 to-orange-200 flex flex-col items-center justify-center gap-2">
                  {uploading ? (
                    <>
                      <div className="w-8 h-8 border-4 border-brand-600 border-t-transparent rounded-full animate-spin" />
                      <span className="text-brand-700 text-sm font-medium">Uploading...</span>
                    </>
                  ) : (
                    <>
                      <svg className="w-10 h-10 text-orange-400" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-8l-4-4m0 0L8 8m4-4v12" /></svg>
                      <span className="text-gray-600 dark:text-gray-400 text-sm font-medium">Click or drag to upload image</span>
                      <span className="text-gray-400 text-xs">PNG, JPG, WebP — best at 1080 × 528 px (2.05:1)</span>
                    </>
                  )}
                </div>
              )}
            </div>

            {/* Or paste URL */}
            <div className="mt-2 flex items-center gap-2">
              <div className="flex-1 h-px bg-gray-200 dark:bg-gray-700" />
              <span className="text-xs text-gray-400 whitespace-nowrap">or paste URL</span>
              <div className="flex-1 h-px bg-gray-200 dark:bg-gray-700" />
            </div>
            <input
              type="url"
              placeholder="https://example.com/banner.jpg"
              value={form.imageUrl}
              onChange={(e) => { setForm({ ...form, imageUrl: e.target.value }); setImgError(false); }}
              className="mt-2 w-full px-3 py-2 border border-gray-300 dark:border-gray-700 dark:bg-gray-800 dark:text-white rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-500"
            />
            {form.imageUrl && imgError && (
              <p className="text-red-500 text-xs mt-1">Could not load image from this URL</p>
            )}
            {form.imageUrl && !imgError && (
              <p className="text-[11px] text-gray-400 text-center mt-2">This is how it appears in the app · 2.05:1</p>
            )}
          </div>

          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Title</label>
              <input
                type="text"
                placeholder="e.g. Special Offer"
                value={form.title}
                onChange={(e) => setForm({ ...form, title: e.target.value })}
                className="w-full px-3 py-2 border border-gray-300 dark:border-gray-700 dark:bg-gray-800 dark:text-white rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-500"
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Subtitle</label>
              <input
                type="text"
                placeholder="e.g. Book now and save 20%"
                value={form.subtitle}
                onChange={(e) => setForm({ ...form, subtitle: e.target.value })}
                className="w-full px-3 py-2 border border-gray-300 dark:border-gray-700 dark:bg-gray-800 dark:text-white rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-500"
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Phone Number</label>
              <input
                type="tel"
                placeholder="e.g. 9876543210"
                value={form.phone}
                onChange={(e) => setForm({ ...form, phone: e.target.value })}
                className="w-full px-3 py-2 border border-gray-300 dark:border-gray-700 dark:bg-gray-800 dark:text-white rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-500"
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">WhatsApp Number</label>
              <input
                type="tel"
                placeholder="e.g. 9876543210"
                value={form.sameWhatsapp ? form.phone : form.whatsapp}
                disabled={form.sameWhatsapp}
                onChange={(e) => setForm({ ...form, whatsapp: e.target.value })}
                className="w-full px-3 py-2 border border-gray-300 dark:border-gray-700 dark:bg-gray-800 dark:text-white rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-500 disabled:bg-gray-100 disabled:text-gray-400"
              />
              <label className="flex items-center gap-2 cursor-pointer mt-2">
                <input
                  type="checkbox"
                  checked={form.sameWhatsapp}
                  onChange={(e) => setForm({ ...form, sameWhatsapp: e.target.checked })}
                  className="w-4 h-4 text-brand-600 rounded"
                />
                <span className="text-xs text-gray-600 dark:text-gray-400">WhatsApp same as phone</span>
              </label>
            </div>
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Action URL (Optional)</label>
            <input
              type="text"
              value={form.actionUrl}
              onChange={(e) => setForm({ ...form, actionUrl: e.target.value })}
              placeholder="https://goracabs.com/offers  or  /subscription"
              className="w-full px-3 py-2 border border-gray-300 dark:border-gray-700 dark:bg-gray-800 dark:text-white rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-500"
            />
            <p className="text-xs text-gray-400 mt-1">
              Shown as an &quot;Open&quot; button in the app&apos;s banner popup. Full https:// link, or an in-app path like /subscription.
            </p>
          </div>

          {/* Schedule: the app only shows the banner inside this window. */}
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Start Date (Optional)</label>
              <input
                type="date"
                value={form.startDate}
                onChange={(e) => setForm({ ...form, startDate: e.target.value })}
                className="w-full px-3 py-2 border border-gray-300 dark:border-gray-700 dark:bg-gray-800 dark:text-white rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-500"
              />
              <p className="text-xs text-gray-400 mt-1">Leave empty to start immediately.</p>
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">End Date (Optional)</label>
              <input
                type="date"
                value={form.endDate}
                min={form.startDate || undefined}
                onChange={(e) => setForm({ ...form, endDate: e.target.value })}
                className="w-full px-3 py-2 border border-gray-300 dark:border-gray-700 dark:bg-gray-800 dark:text-white rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-500"
              />
              <p className="text-xs text-gray-400 mt-1">Leave empty to run forever. Outside this window the banner is hidden.</p>
            </div>
          </div>

          <label className="flex items-center gap-2 cursor-pointer">
            <input
              type="checkbox"
              checked={form.isActive}
              onChange={(e) => setForm({ ...form, isActive: e.target.checked })}
              className="w-4 h-4 text-brand-600 rounded"
            />
            <span className="text-sm font-medium text-gray-700 dark:text-gray-300">Active (visible in app)</span>
          </label>

          <button
            onClick={handleSubmit}
            disabled={isBusy || !form.imageUrl.trim()}
            className="w-full py-2.5 bg-brand-600 hover:bg-brand-700 disabled:opacity-60 text-white font-semibold rounded-lg text-sm transition-colors flex items-center justify-center gap-2"
          >
            {isBusy ? (
              <>
                <div className="w-4 h-4 border-2 border-white/40 border-t-white rounded-full animate-spin" />
                Saving...
              </>
            ) : editingId ? 'Update Banner' : 'Create Banner'}
          </button>
        </div>
      )}

      {/* List */}
      {isLoading ? (
        <div className="space-y-4">
          {Array.from({ length: 3 }).map((_, i) => (
            <div key={i} className="h-24 bg-gray-100 rounded-xl animate-pulse" />
          ))}
        </div>
      ) : banners.length === 0 ? (
        <div className="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-700 p-12 text-center">
          <div className="text-4xl mb-3">🖼️</div>
          <p className="text-gray-500 font-medium">No banners yet</p>
          <p className="text-gray-400 text-sm mt-1">Create your first banner to show it in the app</p>
        </div>
      ) : (
        <div className="space-y-4">
          {banners.map((banner) => (
            <div key={banner._id} className="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-700 p-5 flex items-center gap-4">
              {/* Thumbnail — same ratio & style the app shows it at */}
              <div className="w-44 flex-shrink-0">
                <MobileBannerPreview imageUrl={banner.imageUrl} title={banner.title} subtitle={banner.subtitle} />
              </div>

              <div className="flex-1 min-w-0">
                <div className="flex items-center gap-2 flex-wrap">
                  <h3 className="font-semibold text-gray-900 dark:text-white">{banner.title}</h3>
                  <Badge variant={banner.isActive ? 'success' : 'secondary'}>
                    {banner.isActive ? 'Active' : 'Inactive'}
                  </Badge>
                  <span className="text-xs text-gray-400">Order: {banner.sortOrder}</span>
                </div>
                {banner.subtitle && <p className="text-gray-500 text-sm mt-0.5">{banner.subtitle}</p>}
                <div className="flex gap-4 mt-1.5 text-xs text-gray-400">
                  <span>{banner.viewCount} views</span>
                  <span>{banner.clickCount} clicks</span>
                  {banner.phone && <span>📞 {banner.phone}</span>}
                  {banner.whatsapp && banner.whatsapp !== banner.phone && <span>💬 {banner.whatsapp}</span>}
                </div>
              </div>

              <div className="flex gap-2 flex-shrink-0">
                <button
                  onClick={() => openEdit(banner)}
                  className="px-3 py-1.5 text-xs font-semibold border border-gray-300 dark:border-gray-700 dark:text-gray-200 rounded-lg hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors"
                >
                  Edit
                </button>
                <button
                  onClick={() => toggleMutation.mutate({ id: banner._id, isActive: !banner.isActive })}
                  className={`px-3 py-1.5 text-xs font-semibold rounded-lg transition-colors ${banner.isActive ? 'border border-yellow-400 text-yellow-700 hover:bg-yellow-50' : 'border border-green-400 text-green-700 hover:bg-green-50'}`}
                >
                  {banner.isActive ? 'Deactivate' : 'Activate'}
                </button>
                <button
                  onClick={() => { if (confirm('Delete this banner?')) deleteMutation.mutate(banner._id); }}
                  className="px-3 py-1.5 text-xs font-semibold border border-red-300 text-red-600 rounded-lg hover:bg-red-50 transition-colors"
                >
                  Delete
                </button>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

/** Renders a banner exactly the way the mobile app does — 2.05:1 box (358×175pt),
 *  16px rounded corners, image cover-fit, and a bottom dark gradient with the
 *  title/subtitle — so the admin sees the real in-app appearance. */
function MobileBannerPreview({ imageUrl, title, subtitle }: { imageUrl?: string; title?: string; subtitle?: string }) {
  return (
    <div className="relative w-full aspect-[358/175] rounded-2xl overflow-hidden bg-gradient-to-br from-orange-400 to-orange-600 shadow-sm">
      {imageUrl && (
        <img
          src={imageUrl}
          alt={title || 'Banner'}
          className="absolute inset-0 w-full h-full object-cover"
          onError={(e) => { (e.target as HTMLImageElement).style.display = 'none'; }}
        />
      )}
      {(title || subtitle) && (
        <div className="absolute inset-x-0 bottom-0 p-3 bg-gradient-to-t from-black/65 to-transparent">
          {title && <p className="text-white font-bold text-sm leading-tight line-clamp-1">{title}</p>}
          {subtitle && <p className="text-white/80 text-[11px] leading-tight line-clamp-1">{subtitle}</p>}
        </div>
      )}
    </div>
  );
}
