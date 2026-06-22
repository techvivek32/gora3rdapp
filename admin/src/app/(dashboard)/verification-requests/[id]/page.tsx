'use client';

import { use, useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { adminApi } from '@/lib/api';
import { Badge } from '@/components/ui/Badge';
import { Button } from '@/components/ui/Button';
import { useRouter } from 'next/navigation';
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
              return (
                <div key={key} className="border border-gray-200 dark:border-gray-700 rounded-lg overflow-hidden">
                  <div className="px-4 py-2 bg-gray-50 dark:bg-gray-800">
                    <span className="font-medium text-sm">{DOC_LABELS[key] || key}</span>
                  </div>
                  {doc.image ? (
                    <a href={doc.image} target="_blank" rel="noopener noreferrer">
                      {/* eslint-disable-next-line @next/next/no-img-element */}
                      <img src={doc.image} alt={DOC_LABELS[key]} className="w-full h-44 object-cover bg-gray-100" />
                    </a>
                  ) : (
                    <div className="w-full h-44 flex items-center justify-center bg-gray-100 text-gray-400 text-sm">
                      No image
                    </div>
                  )}
                  <div className="px-4 py-3">
                    <p className="text-xs text-gray-400">Document Number</p>
                    <p className="font-mono text-sm">{doc.number || '—'}</p>
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
