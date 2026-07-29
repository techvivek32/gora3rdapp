'use client';

import { use, useState } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { adminApi } from '@/lib/api';
import { ArrowLeft, Pencil, Trash2, Building2, CreditCard, Landmark } from 'lucide-react';
import toast from 'react-hot-toast';
import { FranchiseFormModal, FRANCHISE_DOCS, type Franchise } from '@/components/franchises/FranchiseFormModal';
import { FranchiseEarnings } from '@/components/franchises/FranchiseEarnings';
import { LoginAsButton } from '@/components/impersonation/LoginAsButton';

export default function FranchiseDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const router = useRouter();
  const qc = useQueryClient();
  const [editing, setEditing] = useState(false);

  const { data: raw, isLoading } = useQuery({
    queryKey: ['franchise', id],
    queryFn: () => adminApi.getFranchise(id),
  });
  const f: Franchise | undefined = (raw as any)?.data;

  const del = useMutation({
    mutationFn: () => adminApi.deleteFranchise(id),
    onSuccess: () => {
      toast.success('Franchise removed');
      qc.invalidateQueries({ queryKey: ['franchises'] });
      router.push('/franchises');
    },
    onError: (e: any) => toast.error(e?.message || 'Could not delete'),
  });

  if (isLoading) return <p className="p-6 text-sm text-gray-500">Loading…</p>;
  if (!f) return <p className="p-6 text-sm text-gray-500">Franchise not found.</p>;

  const dob = f.dob ? new Date(f.dob).toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric' }) : '—';

  return (
    <div className="space-y-5">
      {/* Header */}
      <div className="flex items-center justify-between flex-wrap gap-3">
        <Link href="/franchises" className="inline-flex items-center gap-1.5 text-sm text-gray-500 hover:text-gray-700 dark:hover:text-gray-300">
          <ArrowLeft className="w-4 h-4" /> Back to Franchises
        </Link>
        <div className="flex items-center gap-2">
          <button onClick={() => setEditing(true)} className="inline-flex items-center gap-1.5 px-3 py-2 rounded-lg border border-gray-300 dark:border-gray-600 text-sm font-medium hover:bg-gray-50 dark:hover:bg-gray-800">
            <Pencil className="w-4 h-4" /> Edit
          </button>
          <button onClick={() => { if (confirm(`Delete "${f.name}"? This cannot be undone.`)) del.mutate(); }} className="inline-flex items-center gap-1.5 px-3 py-2 rounded-lg bg-red-500 hover:bg-red-600 text-white text-sm font-medium">
            <Trash2 className="w-4 h-4" /> Delete
          </button>
          <LoginAsButton franchiseId={id} />
        </div>
      </div>

      {/* Summary card */}
      <div className="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-700 p-6">
        <div className="flex items-center gap-4">
          <div className="w-14 h-14 rounded-full bg-orange-500/10 flex items-center justify-center shrink-0">
            <Building2 className="w-7 h-7 text-orange-500" />
          </div>
          <div>
            <h1 className="text-xl font-bold text-gray-900 dark:text-white">{f.name}</h1>
            <p className="text-sm text-gray-500">{f.agencyName || '—'}</p>
          </div>
          <span className={`ml-auto text-xs px-2.5 py-1 rounded-full font-medium ${f.isActive ? 'bg-emerald-500/15 text-emerald-500' : 'bg-gray-400/15 text-gray-500'}`}>
            {f.isActive ? 'Active' : 'Inactive'}
          </span>
        </div>

        <div className="grid grid-cols-2 md:grid-cols-3 gap-4 mt-6">
          <Info label="Phone" value={f.phone} mono />
          <Info label="WhatsApp" value={f.whatsappNumber || '—'} mono />
          <Info label="Email" value={f.email || '—'} />
          <Info label="Date of Birth" value={dob} />
          <Info label="Cities" value={((f as any).cities?.length ? (f as any).cities : (f.city ? [f.city] : [])).join(', ') || '—'} />
          <Info label="Whole States" value={((f as any).states?.length ? (f as any).states : (f.state ? [f.state] : [])).join(', ') || '—'} />
          <Info label="Commission" value={`${f.commissionPercent ?? 0}%`} />
        </div>
      </div>

      {/* Documents */}
      <div className="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-700 p-6">
        <h2 className="font-semibold text-gray-900 dark:text-white mb-4">Documents</h2>
        {(() => {
          const docs = f.documents ?? {};
          const has = FRANCHISE_DOCS.some((d) => docs[d.key]?.number || docs[d.key]?.frontImage || docs[d.key]?.backImage);
          if (!has) return <p className="text-sm text-gray-400">No documents uploaded.</p>;
          return (
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
              {FRANCHISE_DOCS.map(({ key, label }) => {
                const d = docs[key];
                if (!d || (!d.number && !d.frontImage && !d.backImage)) return null;
                return (
                  <div key={key} className="border border-gray-200 dark:border-gray-700 rounded-lg overflow-hidden">
                    <div className="px-3 py-2 bg-gray-50 dark:bg-gray-800 flex items-center justify-between">
                      <span className="text-sm font-medium">{label}</span>
                      {d.number && <span className="font-mono text-xs text-gray-500">{d.number}</span>}
                    </div>
                    <div className="p-2 space-y-2">
                      <DocSide label="Front" src={d.frontImage} />
                      <DocSide label="Back" src={d.backImage} />
                    </div>
                  </div>
                );
              })}
            </div>
          );
        })()}
      </div>

      {/* Payout accounts */}
      <div className="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-700 p-6">
        <h2 className="font-semibold text-gray-900 dark:text-white mb-4">Payout Accounts</h2>
        {(f.payoutAccounts?.length ?? 0) === 0 ? (
          <p className="text-sm text-gray-400">No payout accounts.</p>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
            {f.payoutAccounts!.map((p, i) => (
              <div key={i} className="border border-gray-200 dark:border-gray-700 rounded-lg p-4">
                <div className="flex items-center gap-2 mb-2">
                  {p.type === 'upi' ? <CreditCard className="w-4 h-4 text-orange-500" /> : <Landmark className="w-4 h-4 text-blue-500" />}
                  <span className="text-xs font-bold uppercase text-gray-500">{p.type}</span>
                  {p.label && <span className="text-sm font-medium text-gray-900 dark:text-white">· {p.label}</span>}
                </div>
                {p.type === 'upi' ? (
                  <div className="text-sm space-y-1">
                    <Row label="UPI ID" value={p.upiId} mono />
                    <Row label="Holder" value={p.accountHolderName} />
                  </div>
                ) : (
                  <div className="text-sm space-y-1">
                    <Row label="Bank" value={p.bankName} />
                    <Row label="Holder" value={p.accountHolderName} />
                    <Row label="Account" value={p.accountNumber} mono />
                    <Row label="IFSC" value={p.ifsc} mono />
                  </div>
                )}
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Commission earnings + settlements (admin can record payouts) */}
      <FranchiseEarnings franchiseId={id} canSettle />

      {editing && (
        <FranchiseFormModal
          franchise={f}
          onClose={() => setEditing(false)}
          onSaved={() => { setEditing(false); qc.invalidateQueries({ queryKey: ['franchise', id] }); }}
        />
      )}
    </div>
  );
}

function Info({ label, value, mono }: { label: string; value: string; mono?: boolean }) {
  return (
    <div>
      <p className="text-xs text-gray-400">{label}</p>
      <p className={`text-sm text-gray-900 dark:text-white ${mono ? 'font-mono' : ''}`}>{value}</p>
    </div>
  );
}

function Row({ label, value, mono }: { label: string; value?: string; mono?: boolean }) {
  return (
    <div className="flex justify-between gap-2">
      <span className="text-gray-400">{label}</span>
      <span className={`text-gray-900 dark:text-white text-right ${mono ? 'font-mono' : ''}`}>{value || '—'}</span>
    </div>
  );
}

function DocSide({ label, src }: { label: string; src?: string }) {
  return (
    <div>
      <p className="text-xs text-gray-400 mb-1">{label}</p>
      {src ? (
        // eslint-disable-next-line @next/next/no-img-element
        <img src={src} alt={label} className="w-full h-28 object-cover rounded border border-gray-200 dark:border-gray-700" />
      ) : (
        <div className="w-full h-28 rounded border border-dashed border-gray-300 dark:border-gray-700 flex items-center justify-center text-xs text-gray-400">No image</div>
      )}
    </div>
  );
}
