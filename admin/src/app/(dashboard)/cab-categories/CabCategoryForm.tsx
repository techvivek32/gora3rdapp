'use client';

import { useState, useRef, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { adminApi } from '@/lib/api';
import { INDIAN_STATES } from '@/lib/indian-states';
import toast from 'react-hot-toast';

export interface StatePrice { state: string; petrol?: number; diesel?: number; cng?: number }

export interface CabCategory {
  _id: string;
  name: string;
  vehicleClass?: string;
  imageUrl?: string;
  pricePerKm: number;
  pricePerKmPetrol?: number;
  pricePerKmDiesel?: number;
  pricePerKmCng?: number;
  statePricing?: StatePrice[];
  discountPercent?: number;
  dailyKmLimit?: number;
  extraKmPrice?: number;
  packageKmPerHour?: number;
  extraHourPrice?: number;
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
  discountPercent: 0,
  dailyKmLimit: 0, extraKmPrice: 0,
  packageKmPerHour: 0, extraHourPrice: 0,
  seats: 0, bags: '',
  inclusions: [] as string[], exclusions: [] as string[], facilities: [] as string[], terms: [] as string[],
  order: 0, isActive: true,
};

type Fuel = 'petrol' | 'diesel' | 'cng';
type StateMap = Record<string, { petrol?: number; diesel?: number; cng?: number }>;

type SectionKey = 'details' | 'pricing' | 'km' | 'discount' | 'info';
const SECTIONS: { key: SectionKey; label: string }[] = [
  { key: 'details', label: 'Cab Details' },
  { key: 'pricing', label: 'Pricing (₹/km)' },
  { key: 'km', label: 'KM & Rental' },
  { key: 'discount', label: 'Discount' },
  { key: 'info', label: 'Booking Info' },
];

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

const inputCls = 'w-full px-3 py-2 border border-gray-300 dark:border-gray-700 dark:bg-gray-800 dark:text-white rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-500';
const labelCls = 'block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1';

/** Full-page add / edit form for a cab category, organised into side-menu sections.
 *  `categoryId` set = edit mode. */
export default function CabCategoryForm({ categoryId }: { categoryId?: string }) {
  const router = useRouter();
  const queryClient = useQueryClient();
  const editing = !!categoryId;

  const [section, setSection] = useState<SectionKey>('details');
  const [form, setForm] = useState(EMPTY_FORM);
  // Which fuels are offered for this category (shows its price input when on).
  const [fuelActive, setFuelActive] = useState({ petrol: false, diesel: false, cng: false });
  // Explicit per-state fuel overrides. Empty for a state/fuel = uses the base rate.
  const [statePrices, setStatePrices] = useState<StateMap>({});
  const [stateFuel, setStateFuel] = useState<Fuel>('petrol'); // which fuel column is being edited
  const [applyAll, setApplyAll] = useState<string>('');       // "apply to all states" input
  const [imgError, setImgError] = useState(false);
  const [uploading, setUploading] = useState(false);
  const fileInputRef = useRef<HTMLInputElement>(null);

  // Edit mode: pull the category from the (cached) list and prefill the form.
  const { data, isLoading: loadingCat } = useQuery({
    queryKey: ['cab-categories'],
    queryFn: () => adminApi.getCabCategories(),
    enabled: editing,
  });
  const [prefilled, setPrefilled] = useState(false);
  useEffect(() => {
    if (!editing || prefilled) return;
    const list: CabCategory[] = Array.isArray((data as any)?.data) ? (data as any).data : [];
    const it = list.find((c) => c._id === categoryId);
    if (!it) return;
    setForm({
      name: it.name,
      vehicleClass: it.vehicleClass ?? '',
      imageUrl: it.imageUrl ?? '',
      pricePerKm: it.pricePerKm ?? 0,
      pricePerKmPetrol: it.pricePerKmPetrol ?? 0,
      pricePerKmDiesel: it.pricePerKmDiesel ?? 0,
      pricePerKmCng: it.pricePerKmCng ?? 0,
      discountPercent: it.discountPercent ?? 0,
      dailyKmLimit: it.dailyKmLimit ?? 0,
      extraKmPrice: it.extraKmPrice ?? 0,
      packageKmPerHour: it.packageKmPerHour ?? 0,
      extraHourPrice: it.extraHourPrice ?? 0,
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
    const sp: StateMap = {};
    for (const r of it.statePricing ?? []) {
      sp[r.state] = { petrol: r.petrol, diesel: r.diesel, cng: r.cng };
    }
    setStatePrices(sp);
    setPrefilled(true);
  }, [data, editing, categoryId, prefilled]);

  // Representative per-fuel rate, derived from the state prices (the first state
  // with a value). Used as the app's fallback + the "which fuels" (>0) signal.
  const stateBase = (fuel: Fuel): number => {
    for (const st of INDIAN_STATES) {
      const v = statePrices[st]?.[fuel];
      if (v && v > 0) return v;
    }
    return 0;
  };
  const isFuelOn = (fuel: Fuel) => fuel === 'petrol' ? fuelActive.petrol : fuel === 'diesel' ? fuelActive.diesel : fuelActive.cng;
  const base = (fuel: Fuel) => (isFuelOn(fuel) ? stateBase(fuel) : 0);

  const activeFuels: Fuel[] = [
    ...(fuelActive.petrol ? ['petrol' as const] : []),
    ...(fuelActive.diesel ? ['diesel' as const] : []),
    ...(fuelActive.cng ? ['cng' as const] : []),
  ];

  // Keep the selected state-pricing fuel tab pointed at an active fuel.
  useEffect(() => {
    const af: Fuel[] = [];
    if (fuelActive.petrol) af.push('petrol');
    if (fuelActive.diesel) af.push('diesel');
    if (fuelActive.cng) af.push('cng');
    if (af.length && !af.includes(stateFuel)) setStateFuel(af[0]);
  }, [fuelActive.petrol, fuelActive.diesel, fuelActive.cng, stateFuel]);

  const applyToAllStates = () => {
    const v = applyAll === '' ? undefined : Number(applyAll);
    setStatePrices((m) => {
      const next = { ...m };
      for (const st of INDIAN_STATES) next[st] = { ...next[st], [stateFuel]: v };
      return next;
    });
  };

  const buildPayload = () => ({
    name: form.name.trim(),
    vehicleClass: form.vehicleClass.trim(),
    imageUrl: form.imageUrl.trim(),
    // Base/fallback per-fuel rate = representative from the state prices (also the
    // "which fuels offered" signal for the app, which checks pricePerKm<Fuel> > 0).
    pricePerKm: base('petrol') || base('diesel') || base('cng') || 0,
    pricePerKmPetrol: base('petrol'),
    pricePerKmDiesel: base('diesel'),
    pricePerKmCng: base('cng'),
    // Every state gets a rate: its explicit override, else the base for that fuel.
    statePricing: INDIAN_STATES.map((st) => ({
      state: st,
      petrol: statePrices[st]?.petrol ?? base('petrol'),
      diesel: statePrices[st]?.diesel ?? base('diesel'),
      cng: statePrices[st]?.cng ?? base('cng'),
    })),
    discountPercent: Math.min(100, Math.max(0, Number(form.discountPercent) || 0)),
    dailyKmLimit: Number(form.dailyKmLimit) || 0,
    extraKmPrice: Number(form.extraKmPrice) || 0,
    packageKmPerHour: Number(form.packageKmPerHour) || 0,
    extraHourPrice: Number(form.extraHourPrice) || 0,
    seats: Number(form.seats) || 0,
    bags: form.bags.trim(),
    inclusions: form.inclusions,
    exclusions: form.exclusions,
    facilities: form.facilities,
    terms: form.terms,
    order: Number(form.order) || 0,
    isActive: form.isActive,
  });

  const finish = (msg: string) => {
    toast.success(msg);
    queryClient.invalidateQueries({ queryKey: ['cab-categories'] });
    router.push('/cab-categories');
  };

  const createMutation = useMutation({
    mutationFn: () => adminApi.createCabCategory(buildPayload()),
    onSuccess: () => finish('Category created'),
    onError: () => toast.error('Failed to create category'),
  });

  const updateMutation = useMutation({
    mutationFn: () => adminApi.updateCabCategory(categoryId!, buildPayload()),
    onSuccess: () => finish('Category updated'),
    onError: () => toast.error('Failed to update category'),
  });

  const handleFileUpload = async (file: File) => {
    if (!file.type.startsWith('image/')) return toast.error('Please select an image file');
    setUploading(true);
    try {
      const res = await adminApi.uploadCabImage(file) as any;
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
    if (!form.name.trim()) { setSection('details'); return toast.error('A name is required'); }
    const anyFuel = base('petrol') > 0 || base('diesel') > 0 || base('cng') > 0;
    if (!anyFuel) { setSection('pricing'); return toast.error('Tick a fuel and set at least one state price'); }
    if (editing) updateMutation.mutate();
    else createMutation.mutate();
  };

  const isBusy = createMutation.isPending || updateMutation.isPending || uploading;

  if (editing && loadingCat && !prefilled) {
    return <div className="h-40 bg-gray-100 dark:bg-gray-800 rounded-xl animate-pulse" />;
  }

  return (
    <div className="h-full flex flex-col gap-4">
      <div className="flex items-center justify-between shrink-0">
        <div>
          <h1 className="text-2xl font-bold text-gray-900 dark:text-white">{editing ? 'Edit Category' : 'New Category'}</h1>
          <p className="text-gray-500 mt-1">Cab category shown on the customer app&apos;s Explore Cabs results</p>
        </div>
        <button
          onClick={() => router.push('/cab-categories')}
          className="px-4 py-2 rounded-lg text-sm font-semibold border border-gray-300 dark:border-gray-700 dark:text-gray-200 hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors"
        >
          ← Back
        </button>
      </div>

      <div className="flex flex-col md:flex-row gap-6 flex-1 min-h-0">
        {/* Side menu */}
        <nav className="md:w-56 shrink-0">
          <div className="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-700 p-2 flex md:flex-col gap-1 overflow-x-auto">
            {SECTIONS.map((s, i) => (
              <button
                key={s.key}
                onClick={() => setSection(s.key)}
                className={`text-left px-4 py-2.5 rounded-lg text-sm font-semibold whitespace-nowrap transition-colors ${section === s.key ? 'bg-brand-600 text-white' : 'text-gray-700 dark:text-gray-200 hover:bg-gray-50 dark:hover:bg-gray-800'}`}
              >
                <span className="opacity-60 mr-2">{i + 1}.</span>{s.label}
              </button>
            ))}
          </div>
        </nav>

        {/* Section content — only this column scrolls; header + side menu stay fixed */}
        <div className="flex-1 min-w-0 flex flex-col min-h-0">
          <div className="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-700 p-6 space-y-5 flex-1 overflow-y-auto">

            {/* ── Cab Details ──────────────────────────────────────────── */}
            {section === 'details' && (
              <>
                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                    Image <span className="font-normal text-gray-400">— recommended 400 × 300 px (4:3), same size for all cabs</span>
                  </label>
                  <input
                    ref={fileInputRef}
                    type="file"
                    accept="image/*"
                    className="hidden"
                    onChange={(e) => { const f = e.target.files?.[0]; if (f) handleFileUpload(f); e.target.value = ''; }}
                  />
                  <div
                    onClick={() => !uploading && fileInputRef.current?.click()}
                    onDragOver={(e) => e.preventDefault()}
                    onDrop={(e) => { e.preventDefault(); const f = e.dataTransfer.files?.[0]; if (f) handleFileUpload(f); }}
                    className={`relative rounded-2xl overflow-hidden aspect-[4/3] w-full max-w-xs mx-auto cursor-pointer border-2 border-dashed transition-colors ${uploading ? 'border-brand-400 opacity-70' : 'border-gray-300 hover:border-brand-500'}`}
                  >
                    {form.imageUrl && !imgError ? (
                      <>
                        <img src={form.imageUrl} alt="Preview" className="w-full h-full object-cover" onError={() => setImgError(true)} />
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
                    className={`mt-2 ${inputCls}`}
                  />
                  {form.imageUrl && imgError && <p className="text-red-500 text-xs mt-1">Could not load image from this URL</p>}
                </div>

                <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                  <div>
                    <label className={labelCls}>Name</label>
                    <input type="text" placeholder="e.g. Wagon R or equivalent" value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} className={inputCls} />
                  </div>
                  <div>
                    <label className={labelCls}>Vehicle Class</label>
                    <input type="text" placeholder="e.g. Compact / Sedan / SUV" value={form.vehicleClass} onChange={(e) => setForm({ ...form, vehicleClass: e.target.value })} className={inputCls} />
                  </div>
                  <div>
                    <label className={labelCls}>Seats</label>
                    <input type="number" placeholder="e.g. 4" value={form.seats} onChange={(e) => setForm({ ...form, seats: Number(e.target.value) })} className={inputCls} />
                  </div>
                  <div>
                    <label className={labelCls}>Order</label>
                    <input type="number" value={form.order} onChange={(e) => setForm({ ...form, order: Number(e.target.value) })} className={inputCls} />
                  </div>
                </div>

                <label className="flex items-center gap-2 cursor-pointer">
                  <input type="checkbox" checked={form.isActive} onChange={(e) => setForm({ ...form, isActive: e.target.checked })} className="w-4 h-4 text-brand-600 rounded" />
                  <span className="text-sm font-medium text-gray-700 dark:text-gray-300">Active (visible in app)</span>
                </label>
              </>
            )}

            {/* ── Pricing (₹/km) ───────────────────────────────────────── */}
            {section === 'pricing' && (
              <div className="space-y-5">
                <div>
                  <label className={labelCls}>Fuels offered</label>
                  <p className="text-xs text-gray-500 mb-2">Tick the fuel types this cab offers. Set each fuel&apos;s per-km price state-wise below.</p>
                  <div className="flex flex-wrap gap-2">
                    {([
                      { key: 'petrol', label: 'Petrol' },
                      { key: 'diesel', label: 'Diesel' },
                      { key: 'cng', label: 'CNG' },
                    ] as const).map((f) => {
                      const active = fuelActive[f.key as keyof typeof fuelActive];
                      return (
                        <button
                          key={f.key}
                          type="button"
                          onClick={() => setFuelActive({ ...fuelActive, [f.key]: !active })}
                          className={`px-4 py-2 rounded-lg text-sm font-semibold border transition-colors ${active ? 'bg-brand-600 text-white border-brand-600' : 'border-gray-300 dark:border-gray-700 text-gray-700 dark:text-gray-200 hover:bg-gray-50 dark:hover:bg-gray-800'}`}
                        >
                          {active ? '✓ ' : ''}{f.label}
                        </button>
                      );
                    })}
                  </div>
                </div>

                {/* State-wise prices */}
                {activeFuels.length === 0 ? (
                  <p className="text-xs text-gray-400 border-t border-gray-200 dark:border-gray-700 pt-4">Tick a fuel above to set its state-wise prices.</p>
                ) : (
                  <div className="border-t border-gray-200 dark:border-gray-700 pt-4 space-y-3">
                    <div>
                      <label className={labelCls}>State-wise price/km (₹)</label>
                      <p className="text-xs text-gray-500">The app uses the pickup state&apos;s rate. Pick a fuel, then set each state (or use &quot;Apply to all&quot;).</p>
                    </div>
                    {/* Fuel sub-tabs (only active fuels) */}
                    <div className="flex flex-wrap gap-2">
                      {activeFuels.map((f) => (
                        <button key={f} type="button" onClick={() => setStateFuel(f)}
                          className={`px-4 py-1.5 rounded-lg text-sm font-semibold capitalize transition-colors ${stateFuel === f ? 'bg-brand-600 text-white' : 'border border-gray-300 dark:border-gray-700 text-gray-700 dark:text-gray-200 hover:bg-gray-50 dark:hover:bg-gray-800'}`}>
                          {f}
                        </button>
                      ))}
                    </div>
                    {/* Apply to all states */}
                    <div className="flex items-end gap-2">
                      <div className="flex-1 max-w-[220px]">
                        <label className="block text-xs font-medium text-gray-500 mb-1">Apply to all states (₹/km for {stateFuel})</label>
                        <input type="number" min={0} placeholder={`e.g. ${base(stateFuel) || 100}`} value={applyAll} onChange={(e) => setApplyAll(e.target.value)} className={inputCls} />
                      </div>
                      <button type="button" onClick={applyToAllStates}
                        className="px-4 py-2 rounded-lg text-sm font-semibold bg-brand-600 text-white hover:bg-brand-700 transition-colors">Apply to all</button>
                    </div>
                    {/* Per-state inputs */}
                    <div className="grid grid-cols-1 sm:grid-cols-2 gap-x-4 gap-y-2 max-h-80 overflow-y-auto pr-1">
                      {INDIAN_STATES.map((st) => (
                        <div key={st} className="flex items-center gap-2">
                          <span className="text-xs text-gray-600 dark:text-gray-300 flex-1 truncate" title={st}>{st}</span>
                          <input
                            type="number"
                            min={0}
                            placeholder={`${base(stateFuel)}`}
                            value={statePrices[st]?.[stateFuel] ?? ''}
                            onChange={(e) => {
                              const v = e.target.value;
                              setStatePrices((m) => ({ ...m, [st]: { ...m[st], [stateFuel]: v === '' ? undefined : Number(v) } }));
                            }}
                            className="w-24 px-2 py-1.5 border border-gray-300 dark:border-gray-700 dark:bg-gray-800 dark:text-white rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-500"
                          />
                        </div>
                      ))}
                    </div>
                  </div>
                )}
              </div>
            )}

            {/* ── Discount ─────────────────────────────────────────────── */}
            {section === 'discount' && (
              <div className="space-y-3 max-w-sm">
                <div>
                  <label className={labelCls}>Discount (%)</label>
                  <input type="number" min={0} max={100} placeholder="e.g. 10 (0 = no discount)" value={form.discountPercent} onChange={(e) => setForm({ ...form, discountPercent: Number(e.target.value) })} className={inputCls} />
                </div>
                <p className="text-xs text-gray-500">
                  Shown on the cab details screen as the original fare struck through, with the discounted fare below.
                  E.g. 10% off a ₹1,000 fare → <span className="line-through">₹1,000</span> ₹900.
                </p>
              </div>
            )}

            {/* ── KM & Rental ──────────────────────────────────────────── */}
            {section === 'km' && (
              <>
                <h3 className="text-sm font-semibold text-gray-900 dark:text-white">Round Trip</h3>
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                  <div>
                    <label className={labelCls}>Round-trip KM / day</label>
                    <input type="number" min={0} placeholder="e.g. 250 (0 = no limit)" value={form.dailyKmLimit} onChange={(e) => setForm({ ...form, dailyKmLimit: Number(e.target.value) })} className={inputCls} />
                  </div>
                  <div>
                    <label className={labelCls}>Extra KM price (₹/km)</label>
                    <input type="number" min={0} placeholder="e.g. 10" value={form.extraKmPrice} onChange={(e) => setForm({ ...form, extraKmPrice: Number(e.target.value) })} className={inputCls} />
                  </div>
                </div>
                <p className="text-xs text-gray-500 -mt-1">
                  <b>Round trip only</b>: included km = max(route distance, KM/day × days), where days are counted from the trip
                  start to the trip end date (e.g. 250 × 2 days = 500 km min; a longer route bills the actual km). The return
                  leg is counted in the route. GPS measures the driver&apos;s actual km; anything beyond is billed at the extra ₹/km.
                </p>

                <h3 className="text-sm font-semibold text-gray-900 dark:text-white pt-2">Local (hourly package)</h3>
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                  <div>
                    <label className={labelCls}>Local package KM / hour</label>
                    <input type="number" min={0} placeholder="e.g. 10 (0 = no Local packages)" value={form.packageKmPerHour} onChange={(e) => setForm({ ...form, packageKmPerHour: Number(e.target.value) })} className={inputCls} />
                  </div>
                  <div>
                    <label className={labelCls}>Extra hour price (₹/hr)</label>
                    <input type="number" min={0} placeholder="e.g. 150" value={form.extraHourPrice} onChange={(e) => setForm({ ...form, extraHourPrice: Number(e.target.value) })} className={inputCls} />
                  </div>
                </div>
                <p className="text-xs text-gray-500 -mt-1">
                  Local (in-city hourly): a 6/8/10/12-hour package includes KM/hour × hours (e.g. 10 × 8 = 80 km) at the per-km
                  rate. Time used beyond the package is billed at the extra ₹/hr; km beyond the included allowance at the extra ₹/km.
                </p>
              </>
            )}

            {/* ── Booking Info ─────────────────────────────────────────── */}
            {section === 'info' && (
              <div className="space-y-4">
                <div className="max-w-xs">
                  <label className={labelCls}>Bags</label>
                  <input type="text" placeholder="e.g. 1 Small bag" value={form.bags} onChange={(e) => setForm({ ...form, bags: e.target.value })} className={inputCls} />
                </div>
                <label className={labelCls}>Booking Info (shows as tabs in the app for this cab)</label>
                <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                  <ArrayField label="Inclusions" placeholder="e.g. Toll tax" values={form.inclusions} onChange={(v) => setForm({ ...form, inclusions: v })} />
                  <ArrayField label="Exclusions" placeholder="e.g. Parking beyond 2 hrs" values={form.exclusions} onChange={(v) => setForm({ ...form, exclusions: v })} />
                  <ArrayField label="Facilities" placeholder="e.g. AC, Music, Luggage carrier" values={form.facilities} onChange={(v) => setForm({ ...form, facilities: v })} />
                  <ArrayField label="Terms & Conditions" placeholder="e.g. Waiting charge ₹100/hr" values={form.terms} onChange={(v) => setForm({ ...form, terms: v })} />
                </div>
              </div>
            )}
          </div>

          {/* Save / Cancel — pinned below the scrolling content */}
          <div className="flex gap-3 mt-4 shrink-0">
            <button
              onClick={() => router.push('/cab-categories')}
              className="px-5 py-2.5 rounded-lg text-sm font-semibold border border-gray-300 dark:border-gray-700 dark:text-gray-200 hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors"
            >
              Cancel
            </button>
            <button
              onClick={handleSubmit}
              disabled={isBusy || !form.name.trim()}
              className="flex-1 py-2.5 bg-brand-600 hover:bg-brand-700 disabled:opacity-60 text-white font-semibold rounded-lg text-sm transition-colors flex items-center justify-center gap-2"
            >
              {isBusy ? (
                <>
                  <div className="w-4 h-4 border-2 border-white/40 border-t-white rounded-full animate-spin" />
                  Saving...
                </>
              ) : editing ? 'Update Category' : 'Create Category'}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
