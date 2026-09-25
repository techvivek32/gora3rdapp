'use client';

import { useState, useRef, useEffect } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { adminApi } from '@/lib/api';
import { Badge } from '@/components/ui/Badge';
import toast from 'react-hot-toast';

interface CabCategory {
  _id: string;
  name: string;
  vehicleClass?: string;
  imageUrl?: string;
  pricePerKm: number;
  pricePerKmPetrol?: number;
  pricePerKmDiesel?: number;
  pricePerKmCng?: number;
  seats?: number;
  bags?: string;
  inclusions?: string[];
  exclusions?: string[];
  facilities?: string[];
  terms?: string[];
  order: number;
  isActive: boolean;
  createdAt?: string;
}

const EMPTY_FORM = {
  name: '', vehicleClass: '', imageUrl: '',
  pricePerKm: 0, pricePerKmPetrol: 0, pricePerKmDiesel: 0, pricePerKmCng: 0,
  seats: 0, bags: '',
  inclusions: [] as string[], exclusions: [] as string[], facilities: [] as string[], terms: [] as string[],
  order: 0, isActive: true,
};

// A simple add/remove editor for a per-cab string list, held in the form state.
function ArrayField({ label, placeholder, values, onChange }: { label: string; placeholder: string; values: string[]; onChange: (v: string[]) => void }) {
  const [val, setVal] = useState('');
  const add = () => { const t = val.trim(); if (t) { onChange([...values, t]); setVal(''); } };
  return (
    <div className="border border-gray-200 dark:border-gray-700 rounded-lg p-3">
      <h3 className="text-sm font-semibold text-gray-900 dark:text-white mb-2">{label}</h3>
      <div className="flex gap-2 mb-2">
        <input
          type="text"
          placeholder={placeholder}
          value={val}
          onChange={(e) => setVal(e.target.value)}
          onKeyDown={(e) => { if (e.key === 'Enter') { e.preventDefault(); add(); } }}
          className="flex-1 px-3 py-2 border border-gray-300 dark:border-gray-700 dark:bg-gray-800 dark:text-white rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-500"
        />
        <button type="button" onClick={add} disabled={!val.trim()}
          className="px-3 py-2 rounded-lg text-sm font-semibold bg-brand-600 text-white hover:bg-brand-700 disabled:opacity-50">Add</button>
      </div>
      <div className="flex flex-wrap gap-2">
        {values.length === 0 && <span className="text-xs text-gray-400">No items yet.</span>}
        {values.map((v, i) => (
          <span key={i} className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-medium bg-gray-100 text-gray-700 border border-gray-200 dark:bg-gray-800 dark:text-gray-300">
            {v}
            <button type="button" onClick={() => onChange(values.filter((_, j) => j !== i))} className="text-gray-500 hover:text-red-600 font-bold leading-none">×</button>
          </span>
        ))}
      </div>
    </div>
  );
}

export default function CabCategoriesPage() {
  const queryClient = useQueryClient();

  const [showForm, setShowForm] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [form, setForm] = useState(EMPTY_FORM);
  // Which fuels are offered for this category (shows its price input when on).
  const [fuelActive, setFuelActive] = useState({ petrol: false, diesel: false, cng: false });
  const [imgError, setImgError] = useState(false);
  const [uploading, setUploading] = useState(false);
  const fileInputRef = useRef<HTMLInputElement>(null);

  const { data, isLoading } = useQuery({
    queryKey: ['cab-categories'],
    queryFn: () => adminApi.getCabCategories(),
  });

  // Interceptor extracts data?.data, so response.data = categoriesArray
  const items: CabCategory[] = Array.isArray((data as any)?.data) ? (data as any).data : [];

  // ── Global minimum bill KM (applies to ALL cabs) ──────────────────────────────
  const [minBillKm, setMinBillKm] = useState<number>(0);
  const { data: settingsData } = useQuery({
    queryKey: ['admin-settings-minbillkm'],
    queryFn: () => adminApi.getAdminSettings(),
  });
  useEffect(() => {
    const v = (settingsData as any)?.data?.minBillKm;
    if (typeof v === 'number') setMinBillKm(v);
  }, [settingsData]);
  const saveMinKmMutation = useMutation({
    mutationFn: () => adminApi.updateSettings({ minBillKm: Number(minBillKm) || 0 }),
    onSuccess: () => {
      toast.success('Minimum bill KM saved');
      queryClient.invalidateQueries({ queryKey: ['admin-settings-minbillkm'] });
    },
    onError: () => toast.error('Failed to save minimum bill KM'),
  });

  const buildPayload = () => ({
    name: form.name.trim(),
    vehicleClass: form.vehicleClass.trim(),
    imageUrl: form.imageUrl.trim(),
    // Base rate = the first active fuel's price (kept as a safe fallback).
    pricePerKm:
      (fuelActive.petrol && Number(form.pricePerKmPetrol)) ||
      (fuelActive.diesel && Number(form.pricePerKmDiesel)) ||
      (fuelActive.cng && Number(form.pricePerKmCng)) || 0,
    pricePerKmPetrol: fuelActive.petrol ? (Number(form.pricePerKmPetrol) || 0) : 0,
    pricePerKmDiesel: fuelActive.diesel ? (Number(form.pricePerKmDiesel) || 0) : 0,
    pricePerKmCng: fuelActive.cng ? (Number(form.pricePerKmCng) || 0) : 0,
    seats: Number(form.seats) || 0,
    bags: form.bags.trim(),
    inclusions: form.inclusions,
    exclusions: form.exclusions,
    facilities: form.facilities,
    terms: form.terms,
    order: Number(form.order) || 0,
    isActive: form.isActive,
  });

  const createMutation = useMutation({
    mutationFn: () => adminApi.createCabCategory(buildPayload()),
    onSuccess: () => {
      toast.success('Category created');
      setForm(EMPTY_FORM);
      setShowForm(false);
      queryClient.invalidateQueries({ queryKey: ['cab-categories'] });
    },
    onError: () => toast.error('Failed to create category'),
  });

  const updateMutation = useMutation({
    mutationFn: () => adminApi.updateCabCategory(editingId!, buildPayload()),
    onSuccess: () => {
      toast.success('Category updated');
      setEditingId(null);
      setForm(EMPTY_FORM);
      setShowForm(false);
      queryClient.invalidateQueries({ queryKey: ['cab-categories'] });
    },
    onError: () => toast.error('Failed to update category'),
  });

  const toggleMutation = useMutation({
    mutationFn: ({ id, isActive }: { id: string; isActive: boolean }) =>
      adminApi.updateCabCategory(id, { isActive }),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['cab-categories'] }),
  });

  const deleteMutation = useMutation({
    mutationFn: (id: string) => adminApi.deleteCabCategory(id),
    onSuccess: () => {
      toast.success('Category deleted');
      queryClient.invalidateQueries({ queryKey: ['cab-categories'] });
    },
    onError: () => toast.error('Failed to delete category'),
  });

  const openCreate = () => {
    setEditingId(null);
    setForm(EMPTY_FORM);
    setFuelActive({ petrol: false, diesel: false, cng: false });
    setImgError(false);
    setShowForm(true);
  };

  const openEdit = (it: CabCategory) => {
    setEditingId(it._id);
    setForm({
      name: it.name,
      vehicleClass: it.vehicleClass ?? '',
      imageUrl: it.imageUrl ?? '',
      pricePerKm: it.pricePerKm ?? 0,
      pricePerKmPetrol: it.pricePerKmPetrol ?? 0,
      pricePerKmDiesel: it.pricePerKmDiesel ?? 0,
      pricePerKmCng: it.pricePerKmCng ?? 0,
      seats: it.seats ?? 0,
      bags: it.bags ?? '',
      inclusions: it.inclusions ?? [],
      exclusions: it.exclusions ?? [],
      facilities: it.facilities ?? [],
      terms: it.terms ?? [],
      order: it.order ?? 0,
      isActive: it.isActive,
    });
    setFuelActive({
      petrol: (it.pricePerKmPetrol ?? 0) > 0,
      diesel: (it.pricePerKmDiesel ?? 0) > 0,
      cng: (it.pricePerKmCng ?? 0) > 0,
    });
    setImgError(false);
    setShowForm(true);
  };

  const handleFileUpload = async (file: File) => {
    if (!file.type.startsWith('image/')) return toast.error('Please select an image file');
    setUploading(true);
    try {
      const res = await adminApi.uploadCabImage(file) as any;
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
    if (!form.name.trim()) return toast.error('A name is required');
    const anyFuel =
      (fuelActive.petrol && Number(form.pricePerKmPetrol) > 0) ||
      (fuelActive.diesel && Number(form.pricePerKmDiesel) > 0) ||
      (fuelActive.cng && Number(form.pricePerKmCng) > 0);
    if (!anyFuel) return toast.error('Add at least one fuel with a price per km');
    if (editingId) updateMutation.mutate();
    else createMutation.mutate();
  };

  const isBusy = createMutation.isPending || updateMutation.isPending || uploading;

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900 dark:text-white">Cab Categories</h1>
          <p className="text-gray-500 mt-1">Manage the vehicle classes shown on the customer app&apos;s Explore Cabs results</p>
        </div>
        <button
          onClick={showForm ? () => { setShowForm(false); setEditingId(null); } : openCreate}
          className="px-4 py-2 rounded-lg text-sm font-semibold bg-brand-600 text-white hover:bg-brand-700 transition-colors"
        >
          {showForm ? 'Cancel' : '+ Add Category'}
        </button>
      </div>

      {/* Global minimum bill KM — applies to every cab */}
      <div className="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-700 p-4 flex items-end gap-3 flex-wrap">
        <div className="flex-1 min-w-[240px]">
          <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Minimum Bill KM (all cabs)</label>
          <input
            type="number"
            min={0}
            placeholder="e.g. 200 (0 = no minimum)"
            value={minBillKm}
            onChange={(e) => setMinBillKm(Number(e.target.value))}
            className="w-full max-w-xs px-3 py-2 border border-gray-300 dark:border-gray-700 dark:bg-gray-800 dark:text-white rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-500"
          />
          <p className="text-xs text-gray-500 mt-1">
            Applies to every cab. Shorter trips are billed for at least this many km — e.g. min 200 → a 69 km ride is charged as 200 km.
          </p>
        </div>
        <button
          onClick={() => saveMinKmMutation.mutate()}
          disabled={saveMinKmMutation.isPending}
          className="px-4 py-2 rounded-lg text-sm font-semibold bg-brand-600 text-white hover:bg-brand-700 disabled:opacity-60 transition-colors"
        >
          {saveMinKmMutation.isPending ? 'Saving…' : 'Save'}
        </button>
      </div>

      {/* Form */}
      {showForm && (
        <div className="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-700 p-6 space-y-5">
          <h2 className="font-semibold text-lg text-gray-900 dark:text-white">{editingId ? 'Edit Category' : 'New Category'}</h2>

          {/* Image upload + URL */}
          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
              Image <span className="font-normal text-gray-400">— recommended 400 × 300 px (4:3), same size for all cabs</span>
            </label>

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
                      <span className="text-gray-400 text-xs">PNG, JPG, WebP · Recommended 400 × 300 px (4:3)</span>
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
              <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Name</label>
              <input
                type="text"
                placeholder="e.g. Wagon R or equivalent"
                value={form.name}
                onChange={(e) => setForm({ ...form, name: e.target.value })}
                className="w-full px-3 py-2 border border-gray-300 dark:border-gray-700 dark:bg-gray-800 dark:text-white rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-500"
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Vehicle Class</label>
              <input
                type="text"
                placeholder="e.g. Compact / Sedan / SUV"
                value={form.vehicleClass}
                onChange={(e) => setForm({ ...form, vehicleClass: e.target.value })}
                className="w-full px-3 py-2 border border-gray-300 dark:border-gray-700 dark:bg-gray-800 dark:text-white rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-500"
              />
            </div>
            <div className="sm:col-span-2">
              <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Available fuels &amp; price/km (₹)</label>
              <p className="text-xs text-gray-500 mb-2">Tick a fuel to offer it, then set its per-km rate. Only ticked fuels show in the app.</p>
              <div className="space-y-2">
                {([
                  { key: 'petrol', label: 'Petrol', field: 'pricePerKmPetrol' as const },
                  { key: 'diesel', label: 'Diesel', field: 'pricePerKmDiesel' as const },
                  { key: 'cng', label: 'CNG', field: 'pricePerKmCng' as const },
                ] as const).map((f) => {
                  const active = fuelActive[f.key as keyof typeof fuelActive];
                  return (
                    <div key={f.key} className="flex items-center gap-3">
                      <label className="flex items-center gap-2 w-28 shrink-0 cursor-pointer">
                        <input
                          type="checkbox"
                          checked={active}
                          onChange={(e) => setFuelActive({ ...fuelActive, [f.key]: e.target.checked })}
                          className="w-4 h-4 accent-brand-600"
                        />
                        <span className="text-sm text-gray-700 dark:text-gray-300">{f.label}</span>
                      </label>
                      <input
                        type="number"
                        placeholder={`₹/km for ${f.label}`}
                        disabled={!active}
                        value={form[f.field]}
                        onChange={(e) => setForm({ ...form, [f.field]: Number(e.target.value) })}
                        className="flex-1 px-3 py-2 border border-gray-300 dark:border-gray-700 dark:bg-gray-800 dark:text-white rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-500 disabled:opacity-40 disabled:cursor-not-allowed"
                      />
                    </div>
                  );
                })}
              </div>
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Seats</label>
              <input
                type="number"
                placeholder="e.g. 4"
                value={form.seats}
                onChange={(e) => setForm({ ...form, seats: Number(e.target.value) })}
                className="w-full px-3 py-2 border border-gray-300 dark:border-gray-700 dark:bg-gray-800 dark:text-white rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-500"
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Bags</label>
              <input
                type="text"
                placeholder="e.g. 1 Small bag"
                value={form.bags}
                onChange={(e) => setForm({ ...form, bags: e.target.value })}
                className="w-full px-3 py-2 border border-gray-300 dark:border-gray-700 dark:bg-gray-800 dark:text-white rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-500"
              />
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
          </div>

          {/* Per-cab info tabs — shown on the customer Confirm Booking screen */}
          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Booking Info (shows as tabs in the app for this cab)</label>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
              <ArrayField label="Inclusions" placeholder="e.g. Toll tax" values={form.inclusions} onChange={(v) => setForm({ ...form, inclusions: v })} />
              <ArrayField label="Exclusions" placeholder="e.g. Parking beyond 2 hrs" values={form.exclusions} onChange={(v) => setForm({ ...form, exclusions: v })} />
              <ArrayField label="Facilities" placeholder="e.g. AC, Music, Luggage carrier" values={form.facilities} onChange={(v) => setForm({ ...form, facilities: v })} />
              <ArrayField label="Terms & Conditions" placeholder="e.g. Waiting charge ₹100/hr" values={form.terms} onChange={(v) => setForm({ ...form, terms: v })} />
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
            disabled={isBusy || !form.name.trim()}
            className="w-full py-2.5 bg-brand-600 hover:bg-brand-700 disabled:opacity-60 text-white font-semibold rounded-lg text-sm transition-colors flex items-center justify-center gap-2"
          >
            {isBusy ? (
              <>
                <div className="w-4 h-4 border-2 border-white/40 border-t-white rounded-full animate-spin" />
                Saving...
              </>
            ) : editingId ? 'Update Category' : 'Create Category'}
          </button>
        </div>
      )}

      {/* Categories table */}
      {isLoading ? (
        <div className="space-y-4">
          {Array.from({ length: 3 }).map((_, i) => (
            <div key={i} className="h-16 bg-gray-100 rounded-xl animate-pulse" />
          ))}
        </div>
      ) : items.length === 0 ? (
        <div className="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-700 p-12 text-center">
          <div className="text-4xl mb-3">🚕</div>
          <p className="text-gray-500 font-medium">No categories yet</p>
          <p className="text-gray-400 text-sm mt-1">Add your first cab category to show it in the app</p>
        </div>
      ) : (
        <div className="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-700 overflow-hidden">
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-gray-200 dark:border-gray-700 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">
                  <th className="px-4 py-3">Image</th>
                  <th className="px-4 py-3">Name</th>
                  <th className="px-4 py-3">Class</th>
                  <th className="px-4 py-3">₹ / km</th>
                  <th className="px-4 py-3">Seats</th>
                  <th className="px-4 py-3">Bags</th>
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
                            alt={it.name}
                            className="w-full h-full object-cover"
                            onError={(e) => { (e.target as HTMLImageElement).style.display = 'none'; }}
                          />
                        )}
                      </div>
                    </td>
                    <td className="px-4 py-3">
                      <div className="font-semibold text-gray-900 dark:text-white">{it.name}</div>
                    </td>
                    <td className="px-4 py-3 text-gray-600 dark:text-gray-300">{it.vehicleClass || '—'}</td>
                    <td className="px-4 py-3 text-gray-600 dark:text-gray-300">₹{it.pricePerKm}</td>
                    <td className="px-4 py-3 text-gray-600 dark:text-gray-300">{it.seats ? it.seats : '—'}</td>
                    <td className="px-4 py-3 text-gray-600 dark:text-gray-300">{it.bags || '—'}</td>
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
                          onClick={() => { if (confirm('Delete this category?')) deleteMutation.mutate(it._id); }}
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
