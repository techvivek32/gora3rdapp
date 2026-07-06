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
  actionUrl?: string;
  isActive: boolean;
  sortOrder: number;
  clickCount: number;
  viewCount: number;
}

const EMPTY_FORM = { title: '', subtitle: '', imageUrl: '', actionUrl: '', sortOrder: 0, isActive: true };

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

  const createMutation = useMutation({
    mutationFn: () => adminApi.createBanner({ ...form, sortOrder: Number(form.sortOrder) }),
    onSuccess: () => {
      toast.success('Banner created');
      setForm(EMPTY_FORM);
      setShowForm(false);
      queryClient.invalidateQueries({ queryKey: ['banners'] });
    },
    onError: () => toast.error('Failed to create banner'),
  });

  const updateMutation = useMutation({
    mutationFn: (data: Partial<typeof EMPTY_FORM>) => adminApi.updateBanner(editingId!, data),
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
    setForm({ title: b.title, subtitle: b.subtitle ?? '', imageUrl: b.imageUrl ?? '', actionUrl: b.actionUrl ?? '', sortOrder: b.sortOrder, isActive: b.isActive });
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
    if (editingId) updateMutation.mutate(form);
    else createMutation.mutate();
  };

  const isBusy = createMutation.isPending || updateMutation.isPending || uploading;

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Banners</h1>
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
        <div className="bg-white rounded-xl border border-gray-200 p-6 space-y-5">
          <h2 className="font-semibold text-lg">{editingId ? 'Edit Banner' : 'New Banner'}</h2>

          {/* Image upload + URL */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">Banner Image</label>

            {/* Hidden file input */}
            <input
              ref={fileInputRef}
              type="file"
              accept="image/*"
              className="hidden"
              onChange={(e) => { const f = e.target.files?.[0]; if (f) handleFileUpload(f); e.target.value = ''; }}
            />

            {/* Preview / upload area */}
            <div
              onClick={() => !uploading && fileInputRef.current?.click()}
              onDragOver={(e) => e.preventDefault()}
              onDrop={(e) => { e.preventDefault(); const f = e.dataTransfer.files?.[0]; if (f) handleFileUpload(f); }}
              className={`relative rounded-xl overflow-hidden h-44 cursor-pointer border-2 border-dashed transition-colors ${uploading ? 'border-brand-400 opacity-70' : 'border-gray-300 hover:border-brand-500'}`}
            >
              {form.imageUrl && !imgError ? (
                <>
                  <img
                    src={form.imageUrl}
                    alt="Preview"
                    className="w-full h-full object-cover"
                    onError={() => setImgError(true)}
                  />
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
                      <span className="text-gray-600 text-sm font-medium">Click or drag to upload image</span>
                      <span className="text-gray-400 text-xs">PNG, JPG, WebP — auto resized to 1200×400</span>
                    </>
                  )}
                </div>
              )}
            </div>

            {/* Or paste URL */}
            <div className="mt-2 flex items-center gap-2">
              <div className="flex-1 h-px bg-gray-200" />
              <span className="text-xs text-gray-400 whitespace-nowrap">or paste URL</span>
              <div className="flex-1 h-px bg-gray-200" />
            </div>
            <input
              type="url"
              placeholder="https://example.com/banner.jpg"
              value={form.imageUrl}
              onChange={(e) => { setForm({ ...form, imageUrl: e.target.value }); setImgError(false); }}
              className="mt-2 w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-500"
            />
            {form.imageUrl && imgError && (
              <p className="text-red-500 text-xs mt-1">Could not load image from this URL</p>
            )}
          </div>

          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Title</label>
              <input
                type="text"
                placeholder="e.g. Special Offer"
                value={form.title}
                onChange={(e) => setForm({ ...form, title: e.target.value })}
                className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-500"
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Subtitle</label>
              <input
                type="text"
                placeholder="e.g. Book now and save 20%"
                value={form.subtitle}
                onChange={(e) => setForm({ ...form, subtitle: e.target.value })}
                className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-500"
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Action URL</label>
              <input
                type="text"
                placeholder="e.g. /requirements or https://..."
                value={form.actionUrl}
                onChange={(e) => setForm({ ...form, actionUrl: e.target.value })}
                className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-500"
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Sort Order</label>
              <input
                type="number"
                min={0}
                value={form.sortOrder}
                onChange={(e) => setForm({ ...form, sortOrder: Number(e.target.value) })}
                className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-500"
              />
              <p className="text-xs text-gray-400 mt-1">Lower = shown first</p>
            </div>
          </div>

          <label className="flex items-center gap-2 cursor-pointer">
            <input
              type="checkbox"
              checked={form.isActive}
              onChange={(e) => setForm({ ...form, isActive: e.target.checked })}
              className="w-4 h-4 text-brand-600 rounded"
            />
            <span className="text-sm font-medium text-gray-700">Active (visible in app)</span>
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
        <div className="bg-white rounded-xl border border-gray-200 p-12 text-center">
          <div className="text-4xl mb-3">🖼️</div>
          <p className="text-gray-500 font-medium">No banners yet</p>
          <p className="text-gray-400 text-sm mt-1">Create your first banner to show it in the app</p>
        </div>
      ) : (
        <div className="space-y-4">
          {banners.map((banner) => (
            <div key={banner._id} className="bg-white rounded-xl border border-gray-200 p-5 flex items-center gap-4">
              {/* Thumbnail */}
              <div className="w-32 h-20 rounded-lg overflow-hidden flex-shrink-0 bg-gradient-to-br from-orange-400 to-orange-600">
                {banner.imageUrl && (
                  <img
                    src={banner.imageUrl}
                    alt={banner.title}
                    className="w-full h-full object-cover"
                    onError={(e) => { (e.target as HTMLImageElement).style.display = 'none'; }}
                  />
                )}
              </div>

              <div className="flex-1 min-w-0">
                <div className="flex items-center gap-2 flex-wrap">
                  <h3 className="font-semibold">{banner.title}</h3>
                  <Badge variant={banner.isActive ? 'success' : 'secondary'}>
                    {banner.isActive ? 'Active' : 'Inactive'}
                  </Badge>
                  <span className="text-xs text-gray-400">Order: {banner.sortOrder}</span>
                </div>
                {banner.subtitle && <p className="text-gray-500 text-sm mt-0.5">{banner.subtitle}</p>}
                <div className="flex gap-4 mt-1.5 text-xs text-gray-400">
                  <span>{banner.viewCount} views</span>
                  <span>{banner.clickCount} clicks</span>
                  {banner.actionUrl && <span className="truncate max-w-[160px]">→ {banner.actionUrl}</span>}
                </div>
              </div>

              <div className="flex gap-2 flex-shrink-0">
                <button
                  onClick={() => openEdit(banner)}
                  className="px-3 py-1.5 text-xs font-semibold border border-gray-300 rounded-lg hover:bg-gray-50 transition-colors"
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
