'use client';

import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { adminApi } from '@/lib/api';
import { Building2, Plus, X, Trash2, Upload } from 'lucide-react';
import toast from 'react-hot-toast';

interface DocEntry { number?: string; frontImage?: string; backImage?: string }
interface Payout {
  type: 'bank' | 'upi';
  label?: string;
  upiId?: string;
  accountHolderName?: string;
  bankName?: string;
  accountNumber?: string;
  ifsc?: string;
}
interface Franchise {
  _id: string;
  name: string;
  dob?: string;
  city?: string;
  state?: string;
  email?: string;
  phone: string;
  agencyName?: string;
  commissionPercent?: number;
  documents?: Record<string, DocEntry>;
  payoutAccounts?: Payout[];
  isActive: boolean;
}

interface FormState {
  _id?: string;
  name: string; dob: string; city: string; state: string; email: string;
  phone: string; agencyName: string; password: string;
  commissionPercent: number;
  documents: Record<string, DocEntry>;
  payoutAccounts: Payout[];
  isActive: boolean;
}

const DOCS = [
  { key: 'aadhar', label: 'Aadhaar' },
  { key: 'pan', label: 'PAN' },
  { key: 'drivingLicense', label: 'Driving License' },
];

const inputCls =
  'w-full border border-gray-200 dark:border-gray-700 dark:bg-gray-800 dark:text-white rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-orange-500';
const labelCls = 'block text-xs font-medium text-gray-600 dark:text-gray-400 mb-1';

const blankForm = (): FormState => ({
  name: '', dob: '', city: '', state: '', email: '', phone: '', agencyName: '', password: '',
  commissionPercent: 0, documents: {}, payoutAccounts: [], isActive: true,
});

export default function FranchisesPage() {
  const qc = useQueryClient();
  const [form, setForm] = useState<FormState | null>(null);
  const [search, setSearch] = useState('');

  const { data: raw, isLoading } = useQuery({
    queryKey: ['franchises', search],
    queryFn: () => adminApi.getFranchises({ search: search || undefined }),
  });
  const franchises: Franchise[] = Array.isArray((raw as any)?.data) ? (raw as any).data : [];

  const save = useMutation({
    mutationFn: () => {
      const { _id, ...rest } = form!;
      const payload: any = { ...rest };
      if (!payload.password) delete payload.password; // don't overwrite on edit
      if (!payload.dob) delete payload.dob;
      return _id ? adminApi.updateFranchise(_id, payload) : adminApi.createFranchise(payload);
    },
    onSuccess: () => {
      toast.success(form!._id ? 'Franchise updated' : 'Franchise created');
      setForm(null);
      qc.invalidateQueries({ queryKey: ['franchises'] });
    },
    onError: (e: any) => toast.error(e?.message || 'Could not save'),
  });

  const del = useMutation({
    mutationFn: (id: string) => adminApi.deleteFranchise(id),
    onSuccess: () => { toast.success('Franchise removed'); qc.invalidateQueries({ queryKey: ['franchises'] }); },
    onError: (e: any) => toast.error(e?.message || 'Could not delete'),
  });

  const openEdit = (f: Franchise) => setForm({
    _id: f._id,
    name: f.name, dob: f.dob ? String(f.dob).slice(0, 10) : '', city: f.city ?? '', state: f.state ?? '',
    email: f.email ?? '', phone: f.phone, agencyName: f.agencyName ?? '', password: '',
    commissionPercent: f.commissionPercent ?? 0,
    documents: f.documents ?? {}, payoutAccounts: f.payoutAccounts ?? [], isActive: f.isActive,
  });

  const setDoc = (key: string, patch: Partial<DocEntry>) =>
    setForm((f) => f && ({ ...f, documents: { ...f.documents, [key]: { ...(f.documents[key] ?? {}), ...patch } } }));

  const addPayout = (type: 'bank' | 'upi') =>
    setForm((f) => f && ({ ...f, payoutAccounts: [...f.payoutAccounts, { type }] }));
  const setPayout = (i: number, patch: Partial<Payout>) =>
    setForm((f) => f && ({ ...f, payoutAccounts: f.payoutAccounts.map((p, idx) => idx === i ? { ...p, ...patch } : p) }));
  const removePayout = (i: number) =>
    setForm((f) => f && ({ ...f, payoutAccounts: f.payoutAccounts.filter((_, idx) => idx !== i) }));

  const canSave = !!form && form.name.trim() && form.phone.trim() && (!!form._id || form.password.trim());

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <Building2 className="w-6 h-6 text-orange-500" />
          <div>
            <h1 className="text-2xl font-bold text-gray-900 dark:text-white">Franchises</h1>
            <p className="text-sm text-gray-500">Create &amp; manage franchise accounts, commission and payout details.</p>
          </div>
        </div>
        <button onClick={() => setForm(blankForm())} className="inline-flex items-center gap-1.5 px-4 py-2 rounded-lg bg-orange-500 hover:bg-orange-600 text-white text-sm font-semibold">
          <Plus className="w-4 h-4" /> Add Franchise
        </button>
      </div>

      <input className={`${inputCls} max-w-sm`} placeholder="Search name / phone / email / city…" value={search} onChange={(e) => setSearch(e.target.value)} />

      <div className="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-700 overflow-x-auto">
        {isLoading ? (
          <p className="p-6 text-sm text-gray-500">Loading…</p>
        ) : franchises.length === 0 ? (
          <p className="p-6 text-sm text-gray-500">No franchises yet.</p>
        ) : (
          <table className="w-full text-sm">
            <thead>
              <tr className="text-left text-xs uppercase tracking-wide text-gray-500 border-b border-gray-200 dark:border-gray-700">
                <th className="px-4 py-3 font-medium">Name</th>
                <th className="px-4 py-3 font-medium">Phone</th>
                <th className="px-4 py-3 font-medium">City</th>
                <th className="px-4 py-3 font-medium">Agency</th>
                <th className="px-4 py-3 font-medium text-right">Commission</th>
                <th className="px-4 py-3 font-medium">Payouts</th>
                <th className="px-4 py-3 font-medium">Status</th>
                <th className="px-4 py-3 font-medium text-right">Actions</th>
              </tr>
            </thead>
            <tbody>
              {franchises.map((f) => (
                <tr key={f._id} className="border-b border-gray-100 dark:border-gray-800 last:border-0">
                  <td className="px-4 py-3 font-medium text-gray-900 dark:text-white">{f.name}</td>
                  <td className="px-4 py-3 font-mono text-xs text-gray-600 dark:text-gray-400">{f.phone}</td>
                  <td className="px-4 py-3 text-gray-600 dark:text-gray-400">{f.city || '—'}</td>
                  <td className="px-4 py-3 text-gray-600 dark:text-gray-400">{f.agencyName || '—'}</td>
                  <td className="px-4 py-3 text-right text-gray-900 dark:text-white">{f.commissionPercent ?? 0}%</td>
                  <td className="px-4 py-3 text-gray-500">{f.payoutAccounts?.length ?? 0}</td>
                  <td className="px-4 py-3">
                    <span className={`text-xs px-2 py-0.5 rounded-full font-medium ${f.isActive ? 'bg-emerald-500/15 text-emerald-500' : 'bg-gray-400/15 text-gray-500'}`}>
                      {f.isActive ? 'Active' : 'Inactive'}
                    </span>
                  </td>
                  <td className="px-4 py-3 text-right whitespace-nowrap">
                    <button onClick={() => openEdit(f)} className="text-orange-600 hover:underline font-medium">Edit</button>
                    <button onClick={() => { if (confirm(`Delete "${f.name}"?`)) del.mutate(f._id); }} className="ml-4 text-red-600 hover:underline font-medium">Delete</button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>

      {form && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4" onClick={() => setForm(null)}>
          <div className="w-full max-w-2xl max-h-[92vh] overflow-y-auto bg-white dark:bg-gray-900 rounded-2xl shadow-xl border border-gray-200 dark:border-gray-700" onClick={(e) => e.stopPropagation()}>
            <div className="sticky top-0 z-10 flex items-center justify-between px-5 py-4 border-b border-gray-200 dark:border-gray-700 bg-white dark:bg-gray-900">
              <h2 className="text-lg font-bold text-gray-900 dark:text-white">{form._id ? 'Edit Franchise' : 'Add Franchise'}</h2>
              <button onClick={() => setForm(null)}><X className="w-5 h-5 text-gray-400" /></button>
            </div>

            <div className="p-5 space-y-5">
              {/* Basic */}
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div><label className={labelCls}>Name *</label><input className={inputCls} value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} /></div>
                <div><label className={labelCls}>Date of Birth</label><input type="date" className={inputCls} value={form.dob} onChange={(e) => setForm({ ...form, dob: e.target.value })} /></div>
                <div><label className={labelCls}>Phone *</label><input className={inputCls} value={form.phone} onChange={(e) => setForm({ ...form, phone: e.target.value })} /></div>
                <div><label className={labelCls}>Email</label><input type="email" className={inputCls} value={form.email} onChange={(e) => setForm({ ...form, email: e.target.value })} /></div>
                <div><label className={labelCls}>City</label><input className={inputCls} value={form.city} onChange={(e) => setForm({ ...form, city: e.target.value })} /></div>
                <div><label className={labelCls}>State</label><input className={inputCls} value={form.state} onChange={(e) => setForm({ ...form, state: e.target.value })} /></div>
                <div><label className={labelCls}>Agency Name</label><input className={inputCls} value={form.agencyName} onChange={(e) => setForm({ ...form, agencyName: e.target.value })} /></div>
                <div>
                  <label className={labelCls}>{form._id ? 'New Password (leave blank to keep)' : 'Password *'}</label>
                  <input type="password" className={inputCls} value={form.password} onChange={(e) => setForm({ ...form, password: e.target.value })} placeholder={form._id ? '••••••' : ''} />
                </div>
                <div>
                  <label className={labelCls}>Commission (%)</label>
                  <input type="number" min={0} max={100} className={inputCls} value={form.commissionPercent} onChange={(e) => setForm({ ...form, commissionPercent: +e.target.value })} />
                </div>
              </div>

              {/* Documents */}
              <div>
                <p className="text-sm font-semibold text-gray-900 dark:text-white mb-2">Documents <span className="text-gray-400 font-normal">(optional)</span></p>
                <div className="space-y-3">
                  {DOCS.map(({ key, label }) => (
                    <div key={key} className="border border-gray-200 dark:border-gray-700 rounded-lg p-3">
                      <div className="flex items-center gap-3 mb-2">
                        <span className="text-sm font-medium w-32 shrink-0">{label}</span>
                        <input className={inputCls} placeholder={`${label} number`} value={form.documents[key]?.number ?? ''} onChange={(e) => setDoc(key, { number: e.target.value })} />
                      </div>
                      <div className="grid grid-cols-2 gap-3">
                        <DocImage label="Front" url={form.documents[key]?.frontImage} onChange={(u) => setDoc(key, { frontImage: u })} />
                        <DocImage label="Back" url={form.documents[key]?.backImage} onChange={(u) => setDoc(key, { backImage: u })} />
                      </div>
                    </div>
                  ))}
                </div>
              </div>

              {/* Payout accounts */}
              <div>
                <div className="flex items-center justify-between mb-2">
                  <p className="text-sm font-semibold text-gray-900 dark:text-white">Payout Accounts <span className="text-gray-400 font-normal">(multiple allowed)</span></p>
                  <div className="flex gap-2">
                    <button type="button" onClick={() => addPayout('bank')} className="text-xs px-2.5 py-1 rounded-md border border-gray-300 dark:border-gray-600 hover:bg-gray-50 dark:hover:bg-gray-800">+ Bank</button>
                    <button type="button" onClick={() => addPayout('upi')} className="text-xs px-2.5 py-1 rounded-md border border-gray-300 dark:border-gray-600 hover:bg-gray-50 dark:hover:bg-gray-800">+ UPI</button>
                  </div>
                </div>
                {form.payoutAccounts.length === 0 && <p className="text-xs text-gray-400">No payout accounts added.</p>}
                <div className="space-y-3">
                  {form.payoutAccounts.map((p, i) => (
                    <div key={i} className="border border-gray-200 dark:border-gray-700 rounded-lg p-3 relative">
                      <button type="button" onClick={() => removePayout(i)} className="absolute top-2 right-2 text-gray-400 hover:text-red-500"><Trash2 className="w-4 h-4" /></button>
                      <span className="text-xs font-semibold uppercase text-orange-500">{p.type}</span>
                      <input className={`${inputCls} mt-2`} placeholder="Label (e.g. HDFC personal)" value={p.label ?? ''} onChange={(e) => setPayout(i, { label: e.target.value })} />
                      {p.type === 'upi' ? (
                        <div className="grid grid-cols-2 gap-2 mt-2">
                          <input className={inputCls} placeholder="UPI ID" value={p.upiId ?? ''} onChange={(e) => setPayout(i, { upiId: e.target.value })} />
                          <input className={inputCls} placeholder="Account holder name" value={p.accountHolderName ?? ''} onChange={(e) => setPayout(i, { accountHolderName: e.target.value })} />
                        </div>
                      ) : (
                        <div className="grid grid-cols-2 gap-2 mt-2">
                          <input className={inputCls} placeholder="Bank name" value={p.bankName ?? ''} onChange={(e) => setPayout(i, { bankName: e.target.value })} />
                          <input className={inputCls} placeholder="Account holder name" value={p.accountHolderName ?? ''} onChange={(e) => setPayout(i, { accountHolderName: e.target.value })} />
                          <input className={inputCls} placeholder="Account number" value={p.accountNumber ?? ''} onChange={(e) => setPayout(i, { accountNumber: e.target.value })} />
                          <input className={inputCls} placeholder="IFSC" value={p.ifsc ?? ''} onChange={(e) => setPayout(i, { ifsc: e.target.value })} />
                        </div>
                      )}
                    </div>
                  ))}
                </div>
              </div>

              <label className="flex items-center gap-2 text-sm text-gray-700 dark:text-gray-300">
                <input type="checkbox" checked={form.isActive} onChange={(e) => setForm({ ...form, isActive: e.target.checked })} className="w-4 h-4" />
                Active
              </label>
            </div>

            <div className="sticky bottom-0 flex justify-end gap-2 px-5 py-4 border-t border-gray-200 dark:border-gray-700 bg-white dark:bg-gray-900">
              <button onClick={() => setForm(null)} className="px-4 py-2 rounded-lg border border-gray-300 dark:border-gray-600 text-sm font-medium">Cancel</button>
              <button onClick={() => save.mutate()} disabled={!canSave || save.isPending} className="px-4 py-2 rounded-lg bg-orange-500 hover:bg-orange-600 disabled:opacity-50 text-white text-sm font-semibold">
                {save.isPending ? 'Saving…' : form._id ? 'Save Changes' : 'Create Franchise'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

function DocImage({ label, url, onChange }: { label: string; url?: string; onChange: (url: string) => void }) {
  const [busy, setBusy] = useState(false);
  const upload = async (file: File) => {
    if (!file.type.startsWith('image/')) return toast.error('Select an image');
    setBusy(true);
    try {
      const res = (await adminApi.uploadDocumentImage(file)) as any;
      const u = typeof res?.data === 'string' ? res.data : (res?.data?.url ?? res?.url);
      if (!u) throw new Error('No URL');
      onChange(u);
    } catch {
      toast.error('Upload failed');
    } finally {
      setBusy(false);
    }
  };
  return (
    <div>
      <p className="text-xs text-gray-500 mb-1">{label}</p>
      {url ? (
        <div className="relative">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src={url} alt={label} className="w-full h-24 object-cover rounded-lg border border-gray-200 dark:border-gray-700" />
          <button type="button" onClick={() => onChange('')} className="absolute top-1 right-1 w-6 h-6 rounded-full bg-black/60 text-white text-xs hover:bg-black/80">×</button>
        </div>
      ) : (
        <label className="h-24 flex flex-col items-center justify-center gap-1 rounded-lg border-2 border-dashed border-gray-300 dark:border-gray-700 text-gray-400 cursor-pointer hover:border-orange-500">
          <Upload className="w-4 h-4" />
          <span className="text-xs">{busy ? 'Uploading…' : 'Upload'}</span>
          <input type="file" accept="image/*" className="hidden" onChange={(e) => { const f = e.target.files?.[0]; if (f) upload(f); e.target.value = ''; }} />
        </label>
      )}
    </div>
  );
}
