'use client';

import { useQuery } from '@tanstack/react-query';
import { adminApi } from '@/lib/api';
import { Building2, CreditCard, Landmark, MapPin } from 'lucide-react';
import { FRANCHISE_DOCS, type Franchise } from '@/components/franchises/FranchiseFormModal';

// Read-only profile of the logged-in franchise. Editing is done by the admin
// from the admin panel — a franchise cannot change its own commission/documents.
export default function FranchiseProfilePage() {
  const { data: raw, isLoading } = useQuery({
    queryKey: ['franchise-me'],
    queryFn: () => adminApi.getFranchiseMe(),
  });
  const f: Franchise | undefined = (raw as any)?.data;

  if (isLoading) return <p className="p-6 text-sm text-gray-500">Loading…</p>;
  if (!f) return <p className="p-6 text-sm text-gray-500">Profile not available.</p>;

  const dob = f.dob ? new Date(f.dob).toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric' }) : '—';

  return (
    <div className="space-y-5 max-w-4xl">
      <div className="flex items-center gap-2">
        <Building2 className="w-6 h-6 text-orange-500" />
        <div>
          <h1 className="text-2xl font-bold text-gray-900 dark:text-white">My Profile</h1>
          <p className="text-sm text-gray-500">Your franchise account details.</p>
        </div>
      </div>

      {/* Summary */}
      <div className="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-700 p-6">
        <div className="flex items-center gap-4">
          <div className="w-14 h-14 rounded-full bg-orange-500/10 flex items-center justify-center shrink-0">
            <Building2 className="w-7 h-7 text-orange-500" />
          </div>
          <div>
            <h2 className="text-xl font-bold text-gray-900 dark:text-white">{f.name}</h2>
            <p className="text-sm text-gray-500">{f.agencyName || '—'}</p>
          </div>
          {f.city && (
            <span className="ml-auto inline-flex items-center gap-1 text-xs px-2.5 py-1 rounded-full font-medium bg-orange-500/15 text-orange-500">
              <MapPin className="w-3.5 h-3.5" /> {f.city}
            </span>
          )}
        </div>

        <div className="grid grid-cols-2 md:grid-cols-3 gap-4 mt-6">
          <Info label="Phone" value={f.phone} mono />
          <Info label="Email" value={f.email || '—'} />
          <Info label="Date of Birth" value={dob} />
          <Info label="City" value={f.city || '—'} />
          <Info label="State" value={f.state || '—'} />
          <Info label="Commission" value={`${f.commissionPercent ?? 0}%`} />
        </div>
      </div>

      {/* Documents */}
      <div className="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-700 p-6">
        <h2 className="font-semibold text-gray-900 dark:text-white mb-4">Documents</h2>
        {(() => {
          const docs = f.documents ?? {};
          const has = FRANCHISE_DOCS.some((d) => docs[d.key]?.number || docs[d.key]?.frontImage || docs[d.key]?.backImage);
          if (!has) return <p className="text-sm text-gray-400">No documents on file.</p>;
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
