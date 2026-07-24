'use client';

import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { adminApi } from '@/lib/api';
import { IndianRupee, Percent, Wallet, CheckCircle2, Clock, Plus, X } from 'lucide-react';
import toast from 'react-hot-toast';

interface Settlement { _id: string; amount: number; note?: string; createdAt?: string; paidBy?: { fullName?: string } }
interface MonthRow { month: string; revenue: number; commission: number }
interface Earnings {
  commissionPercent: number;
  totalRevenue: number;
  totalCommission: number;
  totalSettled: number;
  pending: number;
  months: MonthRow[];
  settlements: Settlement[];
}

const inr = (n: number) => `₹${(n ?? 0).toLocaleString('en-IN')}`;
const monthLabel = (m: string) => {
  const [y, mo] = m.split('-');
  const names = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return `${names[Number(mo)] ?? mo} ${y}`;
};

/**
 * Commission earnings for a franchise: plan revenue × commission %, minus what the
 * admin has already settled. `self` uses the logged-in franchise's own data;
 * `canSettle` shows the admin "Record Settlement" control.
 */
export function FranchiseEarnings({ franchiseId, self, canSettle }: { franchiseId?: string; self?: boolean; canSettle?: boolean }) {
  const qc = useQueryClient();
  const key = ['franchise-earnings', self ? 'me' : franchiseId];
  const { data: raw, isLoading } = useQuery({
    queryKey: key,
    queryFn: () => (self ? adminApi.getMyFranchiseEarnings() : adminApi.getFranchiseEarnings(franchiseId!)),
    enabled: self || !!franchiseId,
  });
  const e: Earnings | undefined = (raw as any)?.data;

  const [settleOpen, setSettleOpen] = useState(false);
  const [amount, setAmount] = useState('');
  const [note, setNote] = useState('');

  const settle = useMutation({
    mutationFn: () => adminApi.settleFranchise(franchiseId!, { amount: Number(amount), note: note.trim() || undefined }),
    onSuccess: () => {
      toast.success('Settlement recorded');
      qc.invalidateQueries({ queryKey: key });
      setSettleOpen(false); setAmount(''); setNote('');
    },
    onError: (err: any) => toast.error(err?.message || 'Could not record settlement'),
  });

  const submitSettle = (ev: React.FormEvent) => {
    ev.preventDefault();
    const amt = Number(amount);
    if (!amt || amt <= 0) return toast.error('Enter a valid amount');
    settle.mutate();
  };

  if (isLoading) return <div className="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-700 p-6 text-sm text-gray-500">Loading earnings…</div>;
  if (!e) return null;

  return (
    <div className="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-700 p-6 space-y-5">
      <div className="flex items-center justify-between gap-3">
        <div className="flex items-center gap-2">
          <IndianRupee className="w-5 h-5 text-orange-500" />
          <h2 className="font-semibold text-gray-900 dark:text-white">Earnings &amp; Commission</h2>
        </div>
        {canSettle && (
          <button
            onClick={() => setSettleOpen(true)}
            className="inline-flex items-center gap-1.5 px-3 py-2 rounded-lg bg-orange-500 hover:bg-orange-600 text-white text-sm font-semibold"
          >
            <Plus className="w-4 h-4" /> Record Settlement
          </button>
        )}
      </div>

      {/* KPI cards */}
      <div className="grid grid-cols-2 lg:grid-cols-5 gap-3">
        <Kpi icon={<Wallet className="w-4 h-4" />} label="Plan Revenue" value={inr(e.totalRevenue)} color="text-blue-600 bg-blue-50 dark:bg-blue-900/20" />
        <Kpi icon={<Percent className="w-4 h-4" />} label="Commission" value={`${e.commissionPercent}%`} color="text-indigo-600 bg-indigo-50 dark:bg-indigo-900/20" />
        <Kpi icon={<IndianRupee className="w-4 h-4" />} label="Earned" value={inr(e.totalCommission)} color="text-orange-600 bg-orange-50 dark:bg-orange-900/20" />
        <Kpi icon={<CheckCircle2 className="w-4 h-4" />} label="Settled" value={inr(e.totalSettled)} color="text-emerald-600 bg-emerald-50 dark:bg-emerald-900/20" />
        <Kpi icon={<Clock className="w-4 h-4" />} label="Pending" value={inr(e.pending)} color="text-red-600 bg-red-50 dark:bg-red-900/20" />
      </div>

      {/* Monthly breakdown */}
      <div>
        <h3 className="text-sm font-semibold text-gray-700 dark:text-gray-300 mb-2">Monthly Plan Revenue &amp; Commission</h3>
        {e.months.length === 0 ? (
          <p className="text-sm text-gray-400">No plan revenue yet.</p>
        ) : (
          <div className="border border-gray-200 dark:border-gray-700 rounded-lg overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="text-left text-xs uppercase tracking-wide text-gray-500 border-b border-gray-200 dark:border-gray-700">
                  <th className="px-4 py-2 font-medium">Month</th>
                  <th className="px-4 py-2 font-medium text-right">Plan Revenue</th>
                  <th className="px-4 py-2 font-medium text-right">Commission ({e.commissionPercent}%)</th>
                </tr>
              </thead>
              <tbody>
                {e.months.map((m) => (
                  <tr key={m.month} className="border-b border-gray-100 dark:border-gray-800 last:border-0">
                    <td className="px-4 py-2 text-gray-900 dark:text-white">{monthLabel(m.month)}</td>
                    <td className="px-4 py-2 text-right text-gray-700 dark:text-gray-300">{inr(m.revenue)}</td>
                    <td className="px-4 py-2 text-right font-semibold text-orange-500">{inr(m.commission)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* Settlements */}
      <div>
        <h3 className="text-sm font-semibold text-gray-700 dark:text-gray-300 mb-2">Settlement History</h3>
        {e.settlements.length === 0 ? (
          <p className="text-sm text-gray-400">No settlements yet.</p>
        ) : (
          <div className="space-y-2">
            {e.settlements.map((s) => (
              <div key={s._id} className="flex items-center justify-between border border-gray-200 dark:border-gray-700 rounded-lg px-4 py-2">
                <div>
                  <div className="text-sm font-medium text-gray-900 dark:text-white">{inr(s.amount)}</div>
                  <div className="text-xs text-gray-500">
                    {s.createdAt ? new Date(s.createdAt).toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric' }) : ''}
                    {s.paidBy?.fullName ? ` · by ${s.paidBy.fullName}` : ''}
                    {s.note ? ` · ${s.note}` : ''}
                  </div>
                </div>
                <CheckCircle2 className="w-4 h-4 text-emerald-500" />
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Settle modal */}
      {canSettle && settleOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
          <div className="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-700 w-full max-w-sm p-5">
            <div className="flex items-center justify-between mb-4">
              <h3 className="font-semibold text-gray-900 dark:text-white">Record Settlement</h3>
              <button onClick={() => setSettleOpen(false)} className="text-gray-400 hover:text-gray-600"><X className="w-5 h-5" /></button>
            </div>
            <p className="text-xs text-gray-500 mb-3">Pending: <span className="font-semibold text-red-500">{inr(e.pending)}</span></p>
            <form onSubmit={submitSettle} className="space-y-3">
              <div>
                <label className="block text-xs text-gray-500 mb-1">Amount paid (₹)</label>
                <input
                  type="number" min={1} value={amount} onChange={(ev) => setAmount(ev.target.value)} autoFocus
                  className="w-full border border-gray-200 dark:border-gray-700 dark:bg-gray-800 dark:text-white rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-orange-500"
                />
              </div>
              <div>
                <label className="block text-xs text-gray-500 mb-1">Note (optional)</label>
                <input
                  value={note} onChange={(ev) => setNote(ev.target.value)} placeholder="e.g. UPI ref / month"
                  className="w-full border border-gray-200 dark:border-gray-700 dark:bg-gray-800 dark:text-white rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-orange-500"
                />
              </div>
              <div className="flex justify-end gap-2 pt-1">
                <button type="button" onClick={() => setSettleOpen(false)} className="px-3 py-2 rounded-lg border border-gray-300 dark:border-gray-600 text-sm">Cancel</button>
                <button type="submit" disabled={settle.isPending} className="px-4 py-2 rounded-lg bg-orange-500 hover:bg-orange-600 disabled:opacity-60 text-white text-sm font-semibold">
                  {settle.isPending ? 'Saving…' : 'Record'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}

function Kpi({ icon, label, value, color }: { icon: React.ReactNode; label: string; value: string; color: string }) {
  return (
    <div className="border border-gray-200 dark:border-gray-700 rounded-lg p-3">
      <div className={`w-8 h-8 rounded-lg flex items-center justify-center mb-2 ${color}`}>{icon}</div>
      <div className="text-lg font-bold text-gray-900 dark:text-white leading-tight">{value}</div>
      <div className="text-xs text-gray-500">{label}</div>
    </div>
  );
}
