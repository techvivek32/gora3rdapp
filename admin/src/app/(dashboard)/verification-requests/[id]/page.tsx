'use client';

import { use, useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { adminApi } from '@/lib/api';
import { Badge } from '@/components/ui/Badge';
import { Button } from '@/components/ui/Button';
import { useRouter } from 'next/navigation';
import { Check, X } from 'lucide-react';
import toast from 'react-hot-toast';

const DOC_LABELS: Record<string, string> = {
  aadhar: 'Aadhaar Card',
  pan: 'PAN Card',
  drivingLicense: 'Driving License',
  vehicleRc: 'Vehicle RC',
};

const DOC_ORDER = ['aadhar', 'pan', 'drivingLicense', 'vehicleRc'];

const STATUS_VARIANT: Record<string, 'warning' | 'success' | 'destructive' | 'secondary'> = {
  pending: 'warning',
  verified: 'success',
  rejected: 'destructive',
  none: 'secondary',
};

export default function VerificationRequestDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const router = useRouter();
  const queryClient = useQueryClient();
  const [rejectReason, setRejectReason] = useState('');
  const [showReject, setShowReject] = useState(false);

  const { data, isLoading } = useQuery({
    queryKey: ['verification-request', id],
    queryFn: () => adminApi.getVerificationRequest(id),
  });

  const invalidate = () => {
    queryClient.invalidateQueries({ queryKey: ['verification-request', id] });
    queryClient.invalidateQueries({ queryKey: ['verification-requests'] });
  };

  const approveMutation = useMutation({
    mutationFn: () => adminApi.approveVerification(id),
    onSuccess: () => { toast.success('User verified'); invalidate(); },
    onError: (e: any) => toast.error(e.message || 'Failed to approve'),
  });

  const rejectMutation = useMutation({
    mutationFn: () => adminApi.rejectVerification(id, rejectReason.trim()),
    onSuccess: () => { toast.success('Verification rejected'); setShowReject(false); invalidate(); },
    onError: (e: any) => toast.error(e.message || 'Failed to reject'),
  });

  // Per-document review. The user's overall status is recomputed on the backend:
  // all approved → verified; any rejected → rejected (only those need re-uploading).
  const reviewDoc = useMutation({
    mutationFn: ({ doc, status, reason }: { doc: string; status: 'approved' | 'rejected'; reason?: string }) =>
      adminApi.reviewDocument(id, doc, status, reason),
    onSuccess: (_res, vars) => {
      toast.success(`${DOC_LABELS[vars.doc] ?? vars.doc} ${vars.status}`);
      invalidate();
    },
    onError: (e: any) => toast.error(e.message || 'Could not update document'),
  });

  const onRejectDoc = (doc: string) => {
    const reason = window.prompt(`Why is the ${DOC_LABELS[doc] ?? doc} being rejected? (shown to the user)`);
    if (reason && reason.trim()) reviewDoc.mutate({ doc, status: 'rejected', reason: reason.trim() });
  };

  if (isLoading) return <div className="h-96 bg-gray-100 rounded-xl animate-pulse" />;

  // The detail endpoint returns the user directly under `data` (not paginated).
  const user = (data as any)?.data;
  if (!user) return <div className="text-center py-12 text-gray-500">Request not found</div>;

  const documents = user.documents || {};
  const status = user.verificationStatus || 'none';
  const submittedDocs = DOC_ORDER.filter((key) => documents[key]);

  return (
    <div className="space-y-6">
      <div className="flex items-center gap-4">
        <button onClick={() => router.back()} className="text-gray-500 hover:text-gray-700">← Back</button>
        <div className="flex-1">
          <h1 className="text-xl font-bold text-gray-900 dark:text-white">Verification Request</h1>
        </div>
        <Badge variant={STATUS_VARIANT[status] || 'secondary'} className="capitalize">{status}</Badge>
      </div>

      {/* Header: profile → name → phone → email, with actions on the right */}
      <div className="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-700 p-6">
        <div className="flex flex-col md:flex-row md:items-center gap-5">
          {/* Applicant */}
          <div className="flex items-center gap-4 flex-1 min-w-0">
            <div className="w-16 h-16 rounded-full bg-orange-100 flex items-center justify-center overflow-hidden flex-shrink-0">
              {user.profileImage ? (
                // eslint-disable-next-line @next/next/no-img-element
                <img src={user.profileImage} alt={user.fullName} className="w-full h-full object-cover" />
              ) : (
                <span className="text-2xl font-bold text-orange-600">{user.fullName?.[0]?.toUpperCase()}</span>
              )}
            </div>
            <div className="min-w-0">
              <div className="flex items-center gap-2 flex-wrap">
                <h2 className="text-lg font-bold text-gray-900 dark:text-white truncate">{user.fullName}</h2>
                {user.role && (
                  <span className="text-xs bg-gray-100 dark:bg-gray-800 px-2 py-0.5 rounded-md capitalize">
                    {String(user.role).replace('_', ' ')}
                  </span>
                )}
              </div>
              <p className="text-sm text-gray-600 dark:text-gray-300">{user.mobile || '—'}</p>
              <p className="text-sm text-gray-500 truncate">{user.email || '—'}</p>
              {user.agencyName && <p className="text-sm text-gray-500 truncate">{user.agencyName}</p>}
            </div>
          </div>

          {/* Actions */}
          <div className="flex items-center gap-3 flex-shrink-0">
            <Button
              onClick={() => approveMutation.mutate()}
              isLoading={approveMutation.isPending}
              disabled={status === 'verified'}
            >
              {status === 'verified' ? 'Already Verified' : 'Approve & Verify'}
            </Button>
            <Button
              variant="destructive"
              onClick={() => setShowReject((v) => !v)}
              disabled={status === 'rejected'}
            >
              Reject
            </Button>
          </div>
        </div>

        {/* Rejection reason input (revealed by Reject) */}
        {showReject && (
          <div className="mt-4 pt-4 border-t border-gray-200 dark:border-gray-700 space-y-2">
            <textarea
              value={rejectReason}
              onChange={(e) => setRejectReason(e.target.value)}
              placeholder="Reason for rejection (optional)"
              rows={2}
              className="w-full text-sm rounded-lg border border-gray-200 dark:border-gray-700 bg-transparent p-2 focus:outline-none focus:ring-2 focus:ring-orange-500"
            />
            <div className="flex gap-2">
              <Button variant="destructive" onClick={() => rejectMutation.mutate()} isLoading={rejectMutation.isPending}>
                Confirm Reject
              </Button>
              <Button variant="outline" onClick={() => setShowReject(false)}>Cancel</Button>
            </div>
          </div>
        )}

        {status === 'rejected' && user.verificationRejectionReason && (
          <p className="mt-4 text-sm text-red-600 bg-red-50 rounded-lg p-3">
            Rejected: {user.verificationRejectionReason}
          </p>
        )}
      </div>

      {/* Documents — one row, column count = number of documents */}
      <div className="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-700 p-6">
        <h3 className="font-semibold mb-4">Submitted Documents</h3>
        {submittedDocs.length === 0 ? (
          <p className="text-sm text-gray-500">No documents submitted.</p>
        ) : (
          <div
            className="grid gap-5"
            style={{ gridTemplateColumns: `repeat(${submittedDocs.length}, minmax(0, 1fr))` }}
          >
            {submittedDocs.map((key) => {
              const doc = documents[key] || {};
              // Legacy rows have no per-document status — treat them as pending.
              const status: string = doc.status || 'pending';
              const approved = status === 'approved';
              const rejected = status === 'rejected';

              return (
                <div key={key} className="border border-gray-200 dark:border-gray-700 rounded-lg overflow-hidden flex flex-col">
                  <div className="px-4 py-2 bg-gray-50 dark:bg-gray-800 flex items-center justify-between gap-2">
                    <span className="font-medium text-sm">{DOC_LABELS[key] || key}</span>
                    <span
                      className={`text-[10px] uppercase font-bold px-2 py-0.5 rounded-full ${
                        approved
                          ? 'bg-emerald-500/15 text-emerald-500'
                          : rejected
                            ? 'bg-red-500/15 text-red-500'
                            : 'bg-amber-500/15 text-amber-500'
                      }`}
                    >
                      {status}
                    </span>
                  </div>

                  {/* Per-document review — approve the Aadhaar, reject the PAN. */}
                  <div className="px-3 py-3 flex gap-2 border-b border-gray-200 dark:border-gray-700">
                    <button
                      onClick={() => reviewDoc.mutate({ doc: key, status: 'approved' })}
                      disabled={approved || reviewDoc.isPending}
                      className="flex-1 flex items-center justify-center gap-1 rounded-lg py-1.5 text-xs font-medium bg-green-500 hover:bg-green-600 text-white disabled:opacity-40 disabled:cursor-not-allowed"
                    >
                      <Check className="w-3.5 h-3.5" /> Approve
                    </button>
                    <button
                      onClick={() => onRejectDoc(key)}
                      disabled={rejected || reviewDoc.isPending}
                      className="flex-1 flex items-center justify-center gap-1 rounded-lg py-1.5 text-xs font-medium bg-red-500 hover:bg-red-600 text-white disabled:opacity-40 disabled:cursor-not-allowed"
                    >
                      <X className="w-3.5 h-3.5" /> Reject
                    </button>
                  </div>

                  <div className="divide-y divide-gray-200 dark:divide-gray-700">
                    <DocSide label="Front Side" src={doc.image} alt={`${DOC_LABELS[key]} front`} />
                    <DocSide label="Back Side" src={doc.backImage} alt={`${DOC_LABELS[key]} back`} />
                  </div>
                  <div className="px-4 py-3">
                    <p className="text-xs text-gray-400">Document Number</p>
                    <p className="font-mono text-sm">{doc.number || '—'}</p>
                    {rejected && doc.rejectionReason && (
                      <p className="text-xs text-red-500 mt-2">Rejected: {doc.rejectionReason}</p>
                    )}
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );
}

// One side (front/back) of a document image, with a tap-to-open link.
function DocSide({ label, src, alt }: { label: string; src?: string; alt: string }) {
  return (
    <div className="p-2">
      <p className="text-[11px] font-semibold text-gray-500 mb-1">{label}</p>
      {src ? (
        <a href={src} target="_blank" rel="noopener noreferrer">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src={src} alt={alt} className="w-full h-44 object-cover rounded-lg bg-gray-100" />
        </a>
      ) : (
        <div className="w-full h-44 flex items-center justify-center bg-gray-100 dark:bg-gray-800 text-gray-400 text-xs rounded-lg">
          No image
        </div>
      )}
    </div>
  );
}
