'use client';

import { useId, useState } from 'react';
import { useMutation } from '@tanstack/react-query';
import { adminApi } from '@/lib/api';
import { Button } from '@/components/ui/Button';
import { Input } from '@/components/ui/Input';
import { X, Upload } from 'lucide-react';
import toast from 'react-hot-toast';

const DOCS = [
  { key: 'aadhar', label: 'Aadhaar Card' },
  { key: 'pan', label: 'PAN Card' },
  { key: 'drivingLicense', label: 'Driving License' },
  { key: 'vehicleRc', label: 'Vehicle RC' },
];

interface DocState {
  number: string;
  image: string; // front URL
  backImage: string; // back URL
}

const EMPTY: DocState = { number: '', image: '', backImage: '' };

/**
 * Upload KYC documents on a user's behalf, for users who can't manage it in the
 * app. Submitting puts the account into "pending" for the normal review flow.
 */
export function UploadDocumentsModal({
  userId,
  onClose,
  onSaved,
}: {
  userId: string;
  onClose: () => void;
  onSaved: () => void;
}) {
  const [docs, setDocs] = useState<Record<string, DocState>>(
    Object.fromEntries(DOCS.map((d) => [d.key, { ...EMPTY }])),
  );
  const [uploading, setUploading] = useState<string | null>(null);

  const setDoc = (key: string, patch: Partial<DocState>) =>
    setDocs((d) => ({ ...d, [key]: { ...d[key], ...patch } }));

  const upload = async (key: string, side: 'image' | 'backImage', file: File) => {
    if (!file.type.startsWith('image/')) return toast.error('Please select an image');
    setUploading(`${key}_${side}`);
    try {
      const res = (await adminApi.uploadDocumentImage(file)) as any;
      // /storage/upload returns the URL as a bare string inside the envelope.
      const url = typeof res?.data === 'string' ? res.data : (res?.data?.url ?? res?.url);
      if (!url) throw new Error('No URL returned');
      setDoc(key, { [side]: url } as Partial<DocState>);
      toast.success('Image uploaded');
    } catch {
      toast.error('Upload failed');
    } finally {
      setUploading(null);
    }
  };

  // Only send documents that actually have something in them.
  const payload = () =>
    Object.fromEntries(
      Object.entries(docs)
        .filter(([, d]) => d.number.trim() || d.image || d.backImage)
        .map(([k, d]) => [
          k,
          {
            ...(d.number.trim() ? { number: d.number.trim() } : {}),
            ...(d.image ? { image: d.image } : {}),
            ...(d.backImage ? { backImage: d.backImage } : {}),
          },
        ]),
    );

  const hasAny = Object.keys(payload()).length > 0;

  const mutation = useMutation({
    mutationFn: () => adminApi.submitDocumentsFor(userId, payload()),
    onSuccess: () => { toast.success('Documents submitted for verification'); onSaved(); },
    onError: (e: any) => toast.error(e?.message || 'Could not submit documents'),
  });

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4" onClick={onClose}>
      <div
        className="w-full max-w-2xl bg-white dark:bg-gray-900 rounded-2xl shadow-xl border border-gray-200 dark:border-gray-700 max-h-[90vh] overflow-y-auto"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex items-center justify-between px-5 py-4 border-b border-gray-200 dark:border-gray-700">
          <div>
            <h2 className="font-bold text-lg text-gray-900 dark:text-white">Upload KYC Documents</h2>
            <p className="text-xs text-gray-500">Submitting sends the account for verification.</p>
          </div>
          <button onClick={onClose} className="text-gray-400 hover:text-gray-600">
            <X className="w-5 h-5" />
          </button>
        </div>

        <div className="p-5 space-y-5">
          {DOCS.map(({ key, label }) => (
            <div key={key} className="border border-gray-200 dark:border-gray-700 rounded-lg p-4 space-y-3">
              <p className="font-medium text-sm text-gray-900 dark:text-white">{label}</p>

              <Input
                value={docs[key].number}
                onChange={(e) => setDoc(key, { number: e.target.value })}
                placeholder={`${label} number`}
                className="font-mono"
              />

              <div className="grid grid-cols-2 gap-3">
                <SidePicker
                  label="Front Side"
                  url={docs[key].image}
                  busy={uploading === `${key}_image`}
                  onPick={(f) => upload(key, 'image', f)}
                  onClear={() => setDoc(key, { image: '' })}
                />
                <SidePicker
                  label="Back Side"
                  url={docs[key].backImage}
                  busy={uploading === `${key}_backImage`}
                  onPick={(f) => upload(key, 'backImage', f)}
                  onClear={() => setDoc(key, { backImage: '' })}
                />
              </div>
            </div>
          ))}
        </div>

        <div className="flex justify-end gap-2 px-5 py-4 border-t border-gray-200 dark:border-gray-700">
          <Button variant="outline" onClick={onClose}>Cancel</Button>
          <Button
            onClick={() => mutation.mutate()}
            isLoading={mutation.isPending}
            disabled={!hasAny || !!uploading}
          >
            Submit for Verification
          </Button>
        </div>
      </div>
    </div>
  );
}

function SidePicker({
  label,
  url,
  busy,
  onPick,
  onClear,
}: {
  label: string;
  url: string;
  busy: boolean;
  onPick: (file: File) => void;
  onClear: () => void;
}) {
  const inputId = useId(); // stable across renders, unlike a random string
  return (
    <div>
      <p className="text-xs text-gray-500 mb-1">{label}</p>
      {url ? (
        <div className="relative">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src={url} alt={label} className="w-full h-28 object-cover rounded-lg border border-gray-200 dark:border-gray-700" />
          <button
            type="button"
            onClick={onClear}
            className="absolute top-1 right-1 w-6 h-6 rounded-full bg-black/60 text-white text-xs hover:bg-black/80"
            aria-label={`Remove ${label}`}
          >
            ×
          </button>
        </div>
      ) : (
        <label
          htmlFor={inputId}
          className="h-28 flex flex-col items-center justify-center gap-1 rounded-lg border-2 border-dashed border-gray-300 dark:border-gray-700 text-gray-400 cursor-pointer hover:border-orange-500"
        >
          <Upload className="w-4 h-4" />
          <span className="text-xs">{busy ? 'Uploading…' : 'Upload'}</span>
        </label>
      )}
      <input
        id={inputId}
        type="file"
        accept="image/*"
        className="hidden"
        onChange={(e) => { const f = e.target.files?.[0]; if (f) onPick(f); e.target.value = ''; }}
      />
    </div>
  );
}
