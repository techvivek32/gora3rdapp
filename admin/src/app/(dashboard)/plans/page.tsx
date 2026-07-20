'use client';

import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { adminApi } from '@/lib/api';
import { Star, X, Plus } from 'lucide-react';
import toast from 'react-hot-toast';

interface Plan {
  _id: string;
  name: string;
  description?: string;
  membershipType: string;
  duration: string;
  price: number;            // paise
  discountedPrice: number;  // paise
  durationDays: number;
  features: string[];
  isActive: boolean;
  isPopular: boolean;
  sortOrder: number;
}

type FormState = {
  _id?: string;
  name: string;
  membershipType: string;
  durationDays: number;
  price: number;            // rupees in the form
  discountedPrice: number;  // rupees in the form
  features: string;         // newline separated
  isActive: boolean;
  isPopular: boolean;
  sortOrder: number;
};

const TIER_COLORS: Record<string, string> = {
  active: 'bg-blue-100 text-blue-700',
  premium: 'bg-purple-100 text-purple-700',
  golden: 'bg-amber-100 text-amber-700',
  verified: 'bg-emerald-100 text-emerald-700',
};

// Free-form duration label stored on the plan. Day-scale plans (≤ ~4 weeks) get a
// day label; larger ones get a month label.
function durationKey(days: number) {
  if (days <= 27) return days === 1 ? '1_day' : `${days}_days`;
  const m = Math.round(days / 30);
  return `${m}_month${m > 1 ? 's' : ''}`;
}

// Human label for the plans table.
function durationLabel(days: number) {
  if (days <= 27) return days === 1 ? '1 day' : `${days} days`;
  const m = Math.round(days / 30);
  return `${m} month${m > 1 ? 's' : ''}`;
}

export default function PlansPage() {
  const qc = useQueryClient();
  const [form, setForm] = useState<FormState | null>(null);

  const { data: raw, isLoading } = useQuery({
    queryKey: ['admin-plans'],
    queryFn: () => adminApi.getPlans(),
  });
  const plans: Plan[] = (raw as any)?.data || [];

  const invalidate = () => qc.invalidateQueries({ queryKey: ['admin-plans'] });

  const saveMutation = useMutation({
    mutationFn: (f: FormState) => {
      const payload = {
        name: f.name,
        membershipType: f.membershipType,
        durationDays: Number(f.durationDays),
        duration: durationKey(Number(f.durationDays)),
        price: Math.round(Number(f.price) * 100),            // rupees → paise
        discountedPrice: Math.round(Number(f.discountedPrice) * 100),
        features: f.features.split('\n').map((s) => s.trim()).filter(Boolean),
        isActive: f.isActive,
        isPopular: f.isPopular,
        sortOrder: Number(f.sortOrder),
      };
      return f._id ? adminApi.updatePlan(f._id, payload) : adminApi.createPlan(payload);
    },
    onSuccess: () => { toast.success('Plan saved'); setForm(null); invalidate(); },
    onError: (e: any) => toast.error(e?.message || 'Could not save plan'),
  });

  const openCreate = () => setForm({
    name: '',
    membershipType: 'active',
    durationDays: 30,
    price: 0,
    discountedPrice: 0,
    features: '',
    isActive: true,
    isPopular: false,
    sortOrder: 0,
  });

  const openEdit = (p: Plan) => setForm({
    _id: p._id,
    name: p.name,
    membershipType: p.membershipType,
    durationDays: p.durationDays,
    price: (p.price ?? 0) / 100,
    discountedPrice: (p.discountedPrice ?? 0) / 100,
    features: (p.features || []).join('\n'),
    isActive: p.isActive,
    isPopular: p.isPopular,
    sortOrder: p.sortOrder ?? 0,
  });

  const rupees = (paise: number) => `₹${((paise ?? 0) / 100).toLocaleString('en-IN')}`;

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <Star className="w-6 h-6 text-orange-500" />
          <div>
            <h1 className="text-2xl font-bold text-gray-900 dark:text-white">Plan Management</h1>
            <p className="text-sm text-gray-500">Add &amp; edit membership plans — name, duration, price and more.</p>
          </div>
        </div>

        <button
          onClick={openCreate}
          className="inline-flex items-center gap-1.5 px-4 py-2 rounded-lg bg-orange-500 hover:bg-orange-600 text-white text-sm font-semibold transition-colors"
        >
          <Plus className="w-4 h-4" /> Add Plan
        </button>
      </div>

      {isLoading ? (
        <p className="text-sm text-gray-400 p-6 text-center">Loading…</p>
      ) : (
        <div className="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-700 overflow-x-auto">
          <table className="w-full text-sm">
            <thead className="bg-gray-50 dark:bg-gray-800 text-gray-500 text-left">
              <tr>
                <th className="px-4 py-3 font-medium">Plan</th>
                <th className="px-4 py-3 font-medium">Tier</th>
                <th className="px-4 py-3 font-medium">Duration</th>
                <th className="px-4 py-3 font-medium">Price</th>
                <th className="px-4 py-3 font-medium">Status</th>
                <th className="px-4 py-3 font-medium text-right">Actions</th>
              </tr>
            </thead>
            <tbody>
              {plans.map((p) => (
                <tr key={p._id} className="border-t border-gray-100 dark:border-gray-800">
                  <td className="px-4 py-3">
                    <div className="font-medium text-gray-900 dark:text-white">{p.name}</div>
                    {p.isPopular && <span className="text-[10px] text-purple-600 font-semibold">Most Popular</span>}
                  </td>
                  <td className="px-4 py-3">
                    <span className={`text-xs font-semibold px-2 py-1 rounded-full capitalize ${TIER_COLORS[p.membershipType] || 'bg-gray-100 text-gray-600'}`}>{p.membershipType}</span>
                  </td>
                  <td className="px-4 py-3 text-gray-700 dark:text-gray-300">{durationLabel(p.durationDays)} <span className="text-gray-400">({p.durationDays}d)</span></td>
                  <td className="px-4 py-3 font-semibold text-gray-900 dark:text-white">{rupees(p.price)}</td>
                  <td className="px-4 py-3">
                    <span className={`text-xs px-2 py-1 rounded-full ${p.isActive ? 'bg-green-100 text-green-700' : 'bg-gray-100 text-gray-500'}`}>{p.isActive ? 'Active' : 'Hidden'}</span>
                  </td>
                  <td className="px-4 py-3 text-right whitespace-nowrap">
                    <button onClick={() => openEdit(p)} className="text-orange-600 hover:underline font-medium">Edit</button>
                  </td>
                </tr>
              ))}
              {plans.length === 0 && (
                <tr><td colSpan={6} className="px-4 py-8 text-center text-gray-400">No plans yet.</td></tr>
              )}
            </tbody>
          </table>
        </div>
      )}

      {/* Edit / Create drawer */}
      {form && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4" onClick={() => setForm(null)}>
          <div
            className="bg-white dark:bg-gray-900 rounded-2xl w-full max-w-lg max-h-[90vh] overflow-y-auto p-6 space-y-4"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="flex items-center justify-between">
              <h2 className="text-lg font-bold text-gray-900 dark:text-white">{form._id ? 'Edit Plan' : 'New Plan'}</h2>
              <button onClick={() => setForm(null)}><X className="w-5 h-5 text-gray-400" /></button>
            </div>

            <Field label="Plan Name">
              <input className={inputCls} value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} placeholder="e.g. Premium 3 Months" />
            </Field>

            <div className="grid grid-cols-2 gap-3">
              <Field label="Tier">
                <select className={inputCls} value={form.membershipType} onChange={(e) => setForm({ ...form, membershipType: e.target.value })}>
                  <option value="active">Active</option>
                  <option value="premium">Premium</option>
                  <option value="golden">Golden</option>
                </select>
              </Field>
              <Field label="Duration (days)">
                <input type="number" min={1} className={inputCls} value={form.durationDays} onChange={(e) => setForm({ ...form, durationDays: +e.target.value })} placeholder="1 / 30 / 90 / 180 / 365" />
                <div className="flex flex-wrap gap-1.5 mt-1.5">
                  {[{ d: 1, l: '1 Day' }, { d: 30, l: '1 Month' }, { d: 90, l: '3 Months' }, { d: 180, l: '6 Months' }, { d: 365, l: '1 Year' }].map((o) => (
                    <button
                      key={o.d}
                      type="button"
                      onClick={() => setForm({ ...form, durationDays: o.d })}
                      className={`px-2 py-0.5 rounded-md text-xs font-medium border transition-colors ${
                        form.durationDays === o.d
                          ? 'bg-orange-500 border-orange-500 text-white'
                          : 'border-gray-300 dark:border-gray-600 text-gray-600 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-800'
                      }`}
                    >
                      {o.l}
                    </button>
                  ))}
                </div>
                <p className="text-xs text-gray-400 mt-1">1 day = a 24-hour plan.</p>
              </Field>
            </div>

            <Field label="Price (₹)">
              <input type="number" className={inputCls} value={form.price} onChange={(e) => setForm({ ...form, price: +e.target.value })} />
            </Field>

            <div className="flex items-center gap-4 pb-2">
              <label className="flex items-center gap-2 text-sm">
                <input type="checkbox" checked={form.isActive} onChange={(e) => setForm({ ...form, isActive: e.target.checked })} /> Active
              </label>
              <label className="flex items-center gap-2 text-sm">
                <input type="checkbox" checked={form.isPopular} onChange={(e) => setForm({ ...form, isPopular: e.target.checked })} /> Popular
              </label>
            </div>

            <button
              onClick={() => {
                if (!form.name.trim()) return toast.error('Enter a plan name');
                saveMutation.mutate(form);
              }}
              disabled={saveMutation.isPending}
              className="w-full py-2.5 bg-orange-500 hover:bg-orange-600 disabled:opacity-60 text-white font-semibold rounded-lg text-sm"
            >
              {saveMutation.isPending ? 'Saving…' : 'Save Plan'}
            </button>
          </div>
        </div>
      )}
    </div>
  );
}

const inputCls = 'w-full border border-gray-200 dark:border-gray-700 dark:bg-gray-800 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-orange-500';

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div>
      <label className="block text-xs font-medium text-gray-600 dark:text-gray-400 mb-1">{label}</label>
      {children}
    </div>
  );
}
