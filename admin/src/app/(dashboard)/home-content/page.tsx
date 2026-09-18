'use client';

import { useState, useRef } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { adminApi } from '@/lib/api';
import { Badge } from '@/components/ui/Badge';
import toast from 'react-hot-toast';

type Section = 'travel' | 'offers' | 'explore';

interface ShowcaseItem {
  _id: string;
  section: Section;
  title: string;
  subtitle?: string;
  imageUrl?: string;
  actionUrl?: string;
  category?: string;
  city?: string;
  order: number;
  isActive: boolean;
  createdAt?: string;
}

interface CityImage {
  _id: string;
  city: string;
  imageUrl?: string;
  isActive: boolean;
}

const SECTION_LABELS: Record<Section, string> = {
  travel: 'Travel Made Better',
  offers: 'Special Offers',
  explore: 'Explore (category chips)',
};

const EMPTY_FORM = {
  section: 'travel' as Section,
  title: '', subtitle: '', category: '', city: '',
  imageUrl: '', actionUrl: '', order: 0, isActive: true,
};

const EMPTY_CITY_FORM = { city: '', imageUrl: '', isActive: true };

export default function HomeContentPage() {
  const queryClient = useQueryClient();

  // ─── Showcase items ────────────────────────────────────────────────────────
  const [filter, setFilter] = useState<'all' | Section>('all');
  const [showForm, setShowForm] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [form, setForm] = useState(EMPTY_FORM);
  const [imgError, setImgError] = useState(false);
  const [uploading, setUploading] = useState(false);
  const fileInputRef = useRef<HTMLInputElement>(null);

  const { data, isLoading } = useQuery({
    queryKey: ['home-showcase', filter],
    queryFn: () => adminApi.getHomeShowcase(filter === 'all' ? undefined : filter),
  });

  // Interceptor extracts data?.data, so response.data = itemsArray
  const items: ShowcaseItem[] = Array.isArray((data as any)?.data) ? (data as any).data : [];

  const buildPayload = () => ({
    section: form.section,
    title: form.title.trim(),
    subtitle: form.subtitle.trim(),
    category: form.category.trim(),
    city: form.city.trim(),
    imageUrl: form.imageUrl.trim(),
    actionUrl: form.actionUrl.trim(),
    order: Number(form.order) || 0,
    isActive: form.isActive,
  });

  const createMutation = useMutation({
    mutationFn: () => adminApi.createHomeShowcase(buildPayload()),
    onSuccess: () => {
      toast.success('Item created');
      setForm(EMPTY_FORM);
      setShowForm(false);
      queryClient.invalidateQueries({ queryKey: ['home-showcase'] });
    },
    onError: () => toast.error('Failed to create item'),
  });

  const updateMutation = useMutation({
    mutationFn: () => adminApi.updateHomeShowcase(editingId!, buildPayload()),
    onSuccess: () => {
      toast.success('Item updated');
      setEditingId(null);
      setForm(EMPTY_FORM);
      setShowForm(false);
      queryClient.invalidateQueries({ queryKey: ['home-showcase'] });
    },
    onError: () => toast.error('Failed to update item'),
  });

  const toggleMutation = useMutation({
    mutationFn: ({ id, isActive }: { id: string; isActive: boolean }) =>
      adminApi.updateHomeShowcase(id, { isActive }),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['home-showcase'] }),
  });

  const deleteMutation = useMutation({
    mutationFn: (id: string) => adminApi.deleteHomeShowcase(id),
    onSuccess: () => {
      toast.success('Item deleted');
      queryClient.invalidateQueries({ queryKey: ['home-showcase'] });
    },
    onError: () => toast.error('Failed to delete item'),
  });

  const openCreate = () => {
    setEditingId(null);
    setForm(EMPTY_FORM);
    setImgError(false);
    setShowForm(true);
  };

  const openEdit = (it: ShowcaseItem) => {
    setEditingId(it._id);
    setForm({
      section: it.section,
      title: it.title,
      subtitle: it.subtitle ?? '',
      category: it.category ?? '',
      city: it.city ?? '',
      imageUrl: it.imageUrl ?? '',
      actionUrl: it.actionUrl ?? '',
      order: it.order ?? 0,
      isActive: it.isActive,
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
    if (!form.title.trim()) return toast.error('A title is required');
    if (editingId) updateMutation.mutate();
    else createMutation.mutate();
  };

  const isBusy = createMutation.isPending || updateMutation.isPending || uploading;

  // ─── City hero images ────────────────────────────────────────────────────────
  const [cityForm, setCityForm] = useState(EMPTY_CITY_FORM);
  const [cityImgError, setCityImgError] = useState(false);
  const [cityUploading, setCityUploading] = useState(false);
  const cityFileInputRef = useRef<HTMLInputElement>(null);

  const { data: cityData, isLoading: cityLoading } = useQuery({
    queryKey: ['home-city-images'],
    queryFn: () => adminApi.getCityImages(),
  });
  const cityImages: CityImage[] = Array.isArray((cityData as any)?.data) ? (cityData as any).data : [];

  const upsertCityMutation = useMutation({
    mutationFn: () => adminApi.upsertCityImage({
      city: cityForm.city.trim(),
      imageUrl: cityForm.imageUrl.trim(),
      isActive: cityForm.isActive,
    }),
    onSuccess: () => {
      toast.success('City image saved');
      setCityForm(EMPTY_CITY_FORM);
      setCityImgError(false);
      queryClient.invalidateQueries({ queryKey: ['home-city-images'] });
    },
    onError: () => toast.error('Failed to save city image'),
  });

  const deleteCityMutation = useMutation({
    mutationFn: (id: string) => adminApi.deleteCityImage(id),
    onSuccess: () => {
      toast.success('City image deleted');
      queryClient.invalidateQueries({ queryKey: ['home-city-images'] });
    },
    onError: () => toast.error('Failed to delete city image'),
  });

  const handleCityFileUpload = async (file: File) => {
    if (!file.type.startsWith('image/')) return toast.error('Please select an image file');
    setCityUploading(true);
    try {
      const res = await adminApi.uploadBannerImage(file) as any;
      const url = res?.data?.url ?? res?.url ?? res?.data?.data?.url;
      if (!url) throw new Error('No URL returned');
      setCityForm((f) => ({ ...f, imageUrl: url }));
      setCityImgError(false);
      toast.success('Image uploaded');
    } catch {
      toast.error('Upload failed — check storage config or paste a URL instead');
    } finally {
      setCityUploading(false);
    }
  };

  const handleCitySubmit = () => {
    if (!cityForm.city.trim()) return toast.error('A city name is required');
    upsertCityMutation.mutate();
  };

  const cityBusy = upsertCityMutation.isPending || cityUploading;

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900 dark:text-white">Home Content</h1>
          <p className="text-gray-500 mt-1">Manage the showcase sections & city hero images on the customer app home page</p>
        </div>
        <button
          onClick={showForm ? () => { setShowForm(false); setEditingId(null); } : openCreate}
          className="px-4 py-2 rounded-lg text-sm font-semibold bg-brand-600 text-white hover:bg-brand-700 transition-colors"
        >
          {showForm ? 'Cancel' : '+ Add Item'}
        </button>
      </div>

      {/* Form */}
      {showForm && (
        <div className="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-700 p-6 space-y-5">
          <h2 className="font-semibold text-lg text-gray-900 dark:text-white">{editingId ? 'Edit Item' : 'New Item'}</h2>

          {/* Image upload + URL */}
          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">Image</label>

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
              className={`relative rounded-2xl overflow-hidden aspect-[4/3] w-full max-w-xs mx-auto cursor-pointer border-2 border-dashed transition-colors ${uploading ? 'border-brand-400 opacity-70' : 'border-gray-300 hover:border-brand-500'}`}
            >
              {form.imageUrl && !imgError ? (
                <>
                  <img
                    src={form.imageUrl}
                    alt="Preview"
                    className="w-full h-full object-cover"
                    onError={() => setImgError(true)}
                  />
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
                      <span className="text-gray-400 text-xs">PNG, JPG, WebP</span>
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
              placeholder="https://example.com/image.jpg"
              value={form.imageUrl}
              onChange={(e) => { setForm({ ...form, imageUrl: e.target.value }); setImgError(false); }}
              className="mt-2 w-full px-3 py-2 border border-gray-300 dark:border-gray-700 dark:bg-gray-800 dark:text-white rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-500"
            />
            {form.imageUrl && imgError && (
              <p className="text-red-500 text-xs mt-1">Could not load image from this URL</p>
            )}
          </div>

          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Section</label>
              <select
                value={form.section}
                onChange={(e) => setForm({ ...form, section: e.target.value as Section })}
                className="w-full px-3 py-2 border border-gray-300 dark:border-gray-700 dark:bg-gray-800 dark:text-white rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-500"
              >
                <option value="travel">Travel Made Better</option>
                <option value="offers">Special Offers</option>
                <option value="explore">Explore (chips)</option>
              </select>
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Order</label>
              <input
                type="number"
                value={form.order}
                onChange={(e) => setForm({ ...form, order: Number(e.target.value) })}
                className="w-full px-3 py-2 border border-gray-300 dark:border-gray-700 dark:bg-gray-800 dark:text-white rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-500"
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Title</label>
              <input
                type="text"
                placeholder="e.g. Hotels"
                value={form.title}
                onChange={(e) => setForm({ ...form, title: e.target.value })}
                className="w-full px-3 py-2 border border-gray-300 dark:border-gray-700 dark:bg-gray-800 dark:text-white rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-500"
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Subtitle</label>
              <input
                type="text"
                placeholder="e.g. Book the best stays"
                value={form.subtitle}
                onChange={(e) => setForm({ ...form, subtitle: e.target.value })}
                className="w-full px-3 py-2 border border-gray-300 dark:border-gray-700 dark:bg-gray-800 dark:text-white rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-500"
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Category</label>
              <input
                type="text"
                placeholder="e.g. Business"
                value={form.category}
                onChange={(e) => setForm({ ...form, category: e.target.value })}
                className="w-full px-3 py-2 border border-gray-300 dark:border-gray-700 dark:bg-gray-800 dark:text-white rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-500"
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">City</label>
              <input
                type="text"
                placeholder="Blank = show in all cities"
                value={form.city}
                onChange={(e) => setForm({ ...form, city: e.target.value })}
                className="w-full px-3 py-2 border border-gray-300 dark:border-gray-700 dark:bg-gray-800 dark:text-white rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-500"
              />
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
            disabled={isBusy || !form.title.trim()}
            className="w-full py-2.5 bg-brand-600 hover:bg-brand-700 disabled:opacity-60 text-white font-semibold rounded-lg text-sm transition-colors flex items-center justify-center gap-2"
          >
            {isBusy ? (
              <>
                <div className="w-4 h-4 border-2 border-white/40 border-t-white rounded-full animate-spin" />
                Saving...
              </>
            ) : editingId ? 'Update Item' : 'Create Item'}
          </button>
        </div>
      )}

      {/* Section filter */}
      <div className="flex gap-2 flex-wrap">
        {([['all', 'All'], ['travel', 'Travel'], ['offers', 'Offers'], ['explore', 'Explore']] as const).map(([key, label]) => (
          <button
            key={key}
            onClick={() => setFilter(key as 'all' | Section)}
            className={`px-3 py-1.5 text-sm font-semibold rounded-lg transition-colors ${filter === key ? 'bg-brand-600 text-white' : 'border border-gray-300 dark:border-gray-700 dark:text-gray-200 hover:bg-gray-50 dark:hover:bg-gray-800'}`}
          >
            {label}
          </button>
        ))}
      </div>

      {/* Showcase table */}
      {isLoading ? (
        <div className="space-y-4">
          {Array.from({ length: 3 }).map((_, i) => (
            <div key={i} className="h-16 bg-gray-100 rounded-xl animate-pulse" />
          ))}
        </div>
      ) : items.length === 0 ? (
        <div className="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-700 p-12 text-center">
          <div className="text-4xl mb-3">🏠</div>
          <p className="text-gray-500 font-medium">No items yet</p>
          <p className="text-gray-400 text-sm mt-1">Add your first showcase item to display it in the app</p>
        </div>
      ) : (
        <div className="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-700 overflow-hidden">
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-gray-200 dark:border-gray-700 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">
                  <th className="px-4 py-3">Image</th>
                  <th className="px-4 py-3">Section</th>
                  <th className="px-4 py-3">Title</th>
                  <th className="px-4 py-3">Category</th>
                  <th className="px-4 py-3">City</th>
                  <th className="px-4 py-3">Order</th>
                  <th className="px-4 py-3">Active</th>
                  <th className="px-4 py-3 text-right">Actions</th>
                </tr>
              </thead>
              <tbody>
                {items.map((it) => (
                  <tr key={it._id} className="border-b border-gray-100 dark:border-gray-800 last:border-0">
                    <td className="px-4 py-3">
                      <div className="w-16 h-12 rounded-lg overflow-hidden bg-gray-100 dark:bg-gray-800 flex-shrink-0">
                        {it.imageUrl && (
                          // eslint-disable-next-line @next/next/no-img-element
                          <img
                            src={it.imageUrl}
                            alt={it.title}
                            className="w-full h-full object-cover"
                            onError={(e) => { (e.target as HTMLImageElement).style.display = 'none'; }}
                          />
                        )}
                      </div>
                    </td>
                    <td className="px-4 py-3">
                      <span className="text-xs font-medium text-gray-600 dark:text-gray-300">{SECTION_LABELS[it.section] ?? it.section}</span>
                    </td>
                    <td className="px-4 py-3">
                      <div className="font-semibold text-gray-900 dark:text-white">{it.title}</div>
                      {it.subtitle && <div className="text-xs text-gray-400">{it.subtitle}</div>}
                    </td>
                    <td className="px-4 py-3 text-gray-600 dark:text-gray-300">{it.category || '—'}</td>
                    <td className="px-4 py-3 text-gray-600 dark:text-gray-300">{it.city ? it.city : <span className="text-gray-400">All</span>}</td>
                    <td className="px-4 py-3 text-gray-600 dark:text-gray-300">{it.order}</td>
                    <td className="px-4 py-3">
                      <button onClick={() => toggleMutation.mutate({ id: it._id, isActive: !it.isActive })}>
                        <Badge variant={it.isActive ? 'success' : 'secondary'}>
                          {it.isActive ? 'Active' : 'Inactive'}
                        </Badge>
                      </button>
                    </td>
                    <td className="px-4 py-3">
                      <div className="flex gap-2 justify-end">
                        <button
                          onClick={() => openEdit(it)}
                          className="px-3 py-1.5 text-xs font-semibold border border-gray-300 dark:border-gray-700 dark:text-gray-200 rounded-lg hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors"
                        >
                          Edit
                        </button>
                        <button
                          onClick={() => { if (confirm('Delete this item?')) deleteMutation.mutate(it._id); }}
                          className="px-3 py-1.5 text-xs font-semibold border border-red-300 text-red-600 rounded-lg hover:bg-red-50 transition-colors"
                        >
                          Delete
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* ─── City Hero Images ──────────────────────────────────────────────── */}
      <div className="pt-4 border-t border-gray-200 dark:border-gray-700">
        <h2 className="text-xl font-bold text-gray-900 dark:text-white">City Hero Images</h2>
        <p className="text-gray-500 mt-1">The hero background shown for each city on the customer home page (upsert by city)</p>
      </div>

      {/* Add/Update city image form */}
      <div className="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-700 p-6 space-y-5">
        <h3 className="font-semibold text-gray-900 dark:text-white">Add / Update City Image</h3>

        {/* Hidden file input */}
        <input
          ref={cityFileInputRef}
          type="file"
          accept="image/*"
          className="hidden"
          onChange={(e) => { const f = e.target.files?.[0]; if (f) handleCityFileUpload(f); e.target.value = ''; }}
        />

        <div className="grid grid-cols-1 md:grid-cols-2 gap-4 items-start">
          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">City</label>
            <input
              type="text"
              placeholder="e.g. Jaipur"
              value={cityForm.city}
              onChange={(e) => setCityForm({ ...cityForm, city: e.target.value })}
              className="w-full px-3 py-2 border border-gray-300 dark:border-gray-700 dark:bg-gray-800 dark:text-white rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-500"
            />
            <label className="flex items-center gap-2 cursor-pointer mt-3">
              <input
                type="checkbox"
                checked={cityForm.isActive}
                onChange={(e) => setCityForm({ ...cityForm, isActive: e.target.checked })}
                className="w-4 h-4 text-brand-600 rounded"
              />
              <span className="text-sm font-medium text-gray-700 dark:text-gray-300">Active (visible in app)</span>
            </label>
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Image</label>
            <div
              onClick={() => !cityUploading && cityFileInputRef.current?.click()}
              onDragOver={(e) => e.preventDefault()}
              onDrop={(e) => { e.preventDefault(); const f = e.dataTransfer.files?.[0]; if (f) handleCityFileUpload(f); }}
              className={`relative rounded-2xl overflow-hidden aspect-[16/9] w-full cursor-pointer border-2 border-dashed transition-colors ${cityUploading ? 'border-brand-400 opacity-70' : 'border-gray-300 hover:border-brand-500'}`}
            >
              {cityForm.imageUrl && !cityImgError ? (
                <>
                  <img
                    src={cityForm.imageUrl}
                    alt="Preview"
                    className="w-full h-full object-cover"
                    onError={() => setCityImgError(true)}
                  />
                  <div className="absolute inset-0 bg-black/40 opacity-0 hover:opacity-100 transition-opacity flex flex-col items-center justify-center gap-1">
                    <svg className="w-8 h-8 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-8l-4-4m0 0L8 8m4-4v12" /></svg>
                    <span className="text-white text-sm font-medium">Click to change</span>
                  </div>
                </>
              ) : (
                <div className="w-full h-full bg-gradient-to-br from-orange-100 to-orange-200 flex flex-col items-center justify-center gap-2">
                  {cityUploading ? (
                    <>
                      <div className="w-8 h-8 border-4 border-brand-600 border-t-transparent rounded-full animate-spin" />
                      <span className="text-brand-700 text-sm font-medium">Uploading...</span>
                    </>
                  ) : (
                    <>
                      <svg className="w-10 h-10 text-orange-400" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-8l-4-4m0 0L8 8m4-4v12" /></svg>
                      <span className="text-gray-600 dark:text-gray-400 text-sm font-medium">Click or drag to upload image</span>
                    </>
                  )}
                </div>
              )}
            </div>
            <input
              type="url"
              placeholder="or paste URL — https://example.com/city.jpg"
              value={cityForm.imageUrl}
              onChange={(e) => { setCityForm({ ...cityForm, imageUrl: e.target.value }); setCityImgError(false); }}
              className="mt-2 w-full px-3 py-2 border border-gray-300 dark:border-gray-700 dark:bg-gray-800 dark:text-white rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-500"
            />
          </div>
        </div>

        <button
          onClick={handleCitySubmit}
          disabled={cityBusy || !cityForm.city.trim()}
          className="px-4 py-2.5 bg-brand-600 hover:bg-brand-700 disabled:opacity-60 text-white font-semibold rounded-lg text-sm transition-colors flex items-center justify-center gap-2"
        >
          {cityBusy ? (
            <>
              <div className="w-4 h-4 border-2 border-white/40 border-t-white rounded-full animate-spin" />
              Saving...
            </>
          ) : 'Save City Image'}
        </button>
      </div>

      {/* City images table */}
      {cityLoading ? (
        <div className="space-y-4">
          {Array.from({ length: 2 }).map((_, i) => (
            <div key={i} className="h-16 bg-gray-100 rounded-xl animate-pulse" />
          ))}
        </div>
      ) : cityImages.length === 0 ? (
        <div className="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-700 p-12 text-center">
          <div className="text-4xl mb-3">🌆</div>
          <p className="text-gray-500 font-medium">No city images yet</p>
          <p className="text-gray-400 text-sm mt-1">Add a city hero image above</p>
        </div>
      ) : (
        <div className="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-700 overflow-hidden">
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-gray-200 dark:border-gray-700 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">
                  <th className="px-4 py-3">Image</th>
                  <th className="px-4 py-3">City</th>
                  <th className="px-4 py-3">Active</th>
                  <th className="px-4 py-3 text-right">Actions</th>
                </tr>
              </thead>
              <tbody>
                {cityImages.map((ci) => (
                  <tr key={ci._id} className="border-b border-gray-100 dark:border-gray-800 last:border-0">
                    <td className="px-4 py-3">
                      <div className="w-20 h-12 rounded-lg overflow-hidden bg-gray-100 dark:bg-gray-800 flex-shrink-0">
                        {ci.imageUrl && (
                          // eslint-disable-next-line @next/next/no-img-element
                          <img
                            src={ci.imageUrl}
                            alt={ci.city}
                            className="w-full h-full object-cover"
                            onError={(e) => { (e.target as HTMLImageElement).style.display = 'none'; }}
                          />
                        )}
                      </div>
                    </td>
                    <td className="px-4 py-3 font-semibold text-gray-900 dark:text-white">{ci.city}</td>
                    <td className="px-4 py-3">
                      <Badge variant={ci.isActive ? 'success' : 'secondary'}>
                        {ci.isActive ? 'Active' : 'Inactive'}
                      </Badge>
                    </td>
                    <td className="px-4 py-3">
                      <div className="flex gap-2 justify-end">
                        <button
                          onClick={() => { if (confirm('Delete this city image?')) deleteCityMutation.mutate(ci._id); }}
                          className="px-3 py-1.5 text-xs font-semibold border border-red-300 text-red-600 rounded-lg hover:bg-red-50 transition-colors"
                        >
                          Delete
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </div>
  );
}
