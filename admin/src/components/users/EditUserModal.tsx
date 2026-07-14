'use client';

import { useRef, useState } from 'react';
import { useMutation } from '@tanstack/react-query';
import { adminApi } from '@/lib/api';
import { Button } from '@/components/ui/Button';
import { Input } from '@/components/ui/Input';
import { AddressAutocomplete } from '@/components/ui/AddressAutocomplete';
import { X, Camera } from 'lucide-react';
import toast from 'react-hot-toast';

interface EditableUser {
  _id: string;
  fullName?: string;
  agencyName?: string;
  mobile?: string;
  email?: string;
  city?: string;
  state?: string;
  profileImage?: string;
}

/** Admin edit of a user's profile: name, agency, phone, email, city/state, photo. */
export function EditUserModal({
  user,
  onClose,
  onSaved,
}: {
  user: EditableUser;
  onClose: () => void;
  onSaved: () => void;
}) {
  const [form, setForm] = useState({
    fullName: user.fullName ?? '',
    agencyName: user.agencyName ?? '',
    mobile: user.mobile ?? '',
    email: user.email ?? '',
    city: user.city ?? '',
    state: user.state ?? '',
    profileImage: user.profileImage ?? '',
  });
  const [uploading, setUploading] = useState(false);
  const fileRef = useRef<HTMLInputElement>(null);

  const set = (patch: Partial<typeof form>) => setForm((f) => ({ ...f, ...patch }));

  const upload = async (file: File) => {
    if (!file.type.startsWith('image/')) return toast.error('Please select an image');
    setUploading(true);
    try {
      const res = (await adminApi.uploadProfileImage(file)) as any;
      const url = res?.data?.url ?? res?.url ?? res?.data?.data?.url ?? res?.data;
      if (!url || typeof url !== 'string') throw new Error('No URL returned');
      set({ profileImage: url });
      toast.success('Photo uploaded');
    } catch {
      toast.error('Upload failed');
    } finally {
      setUploading(false);
    }
  };

  const mutation = useMutation({
    mutationFn: () => adminApi.updateUser(user._id, form),
    onSuccess: () => { toast.success('Profile updated'); onSaved(); },
    // The backend rejects a duplicate mobile/email with a real message — show it.
    onError: (e: any) => toast.error(e?.message || 'Could not update profile'),
  });

  const validMobile = /^[6-9]\d{9}$/.test(form.mobile.replace(/\D/g, '').slice(-10));
  const canSave = form.fullName.trim().length > 0 && validMobile && !uploading;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4" onClick={onClose}>
      <div
        className="w-full max-w-lg bg-white dark:bg-gray-900 rounded-2xl shadow-xl border border-gray-200 dark:border-gray-700 max-h-[90vh] overflow-y-auto"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex items-center justify-between px-5 py-4 border-b border-gray-200 dark:border-gray-700">
          <h2 className="font-bold text-lg text-gray-900 dark:text-white">Edit Profile</h2>
          <button onClick={onClose} className="text-gray-400 hover:text-gray-600">
            <X className="w-5 h-5" />
          </button>
        </div>

        <div className="p-5 space-y-4">
          {/* Photo */}
          <div className="flex items-center gap-4">
            <div className="relative">
              <div className="w-20 h-20 rounded-full bg-gray-100 dark:bg-gray-800 overflow-hidden flex items-center justify-center border border-gray-200 dark:border-gray-700">
                {form.profileImage ? (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img src={form.profileImage} alt="" className="w-full h-full object-cover" />
                ) : (
                  <span className="text-2xl font-bold text-gray-400">
                    {(form.fullName || '?').charAt(0).toUpperCase()}
                  </span>
                )}
              </div>
              <button
                type="button"
                onClick={() => !uploading && fileRef.current?.click()}
                className="absolute -bottom-1 -right-1 w-7 h-7 rounded-full bg-orange-500 text-white flex items-center justify-center hover:bg-orange-600"
                aria-label="Change photo"
              >
                <Camera className="w-3.5 h-3.5" />
              </button>
              <input
                ref={fileRef}
                type="file"
                accept="image/*"
                className="hidden"
                onChange={(e) => { const f = e.target.files?.[0]; if (f) upload(f); e.target.value = ''; }}
              />
            </div>
            <div className="text-xs text-gray-500">
              {uploading ? 'Uploading…' : 'Tap the camera to change the profile photo.'}
              {form.profileImage && !uploading && (
                <button
                  type="button"
                  onClick={() => set({ profileImage: '' })}
                  className="block mt-1 text-red-500 hover:underline"
                >
                  Remove photo
                </button>
              )}
            </div>
          </div>

          <div>
            <label className="block text-xs font-medium text-gray-500 mb-1">Full Name *</label>
            <Input value={form.fullName} onChange={(e) => set({ fullName: e.target.value })} placeholder="Full name" />
          </div>

          <div>
            <label className="block text-xs font-medium text-gray-500 mb-1">Agency Name</label>
            <Input value={form.agencyName} onChange={(e) => set({ agencyName: e.target.value })} placeholder="Agency name" />
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label className="block text-xs font-medium text-gray-500 mb-1">Phone *</label>
              <Input
                value={form.mobile}
                onChange={(e) => set({ mobile: e.target.value })}
                placeholder="10-digit mobile"
                className="font-mono"
              />
              {form.mobile && !validMobile && (
                <p className="text-xs text-red-500 mt-1">Enter a valid 10-digit mobile number.</p>
              )}
              <p className="text-xs text-gray-400 mt-1">This is also the user&apos;s login and referral code.</p>
            </div>
            <div>
              <label className="block text-xs font-medium text-gray-500 mb-1">Email</label>
              <Input
                type="email"
                value={form.email}
                onChange={(e) => set({ email: e.target.value })}
                placeholder="name@example.com"
              />
            </div>
          </div>

          <div>
            <label className="block text-xs font-medium text-gray-500 mb-1">City</label>
            {/* Google Places, so the city matches what the app stores. */}
            <AddressAutocomplete
              value={form.city}
              placeholder="Search a city…"
              onSelect={(v) => set({ city: v.city || v.address, state: v.state || form.state })}
            />
          </div>

          <div>
            <label className="block text-xs font-medium text-gray-500 mb-1">State</label>
            <Input value={form.state} onChange={(e) => set({ state: e.target.value })} placeholder="State" />
          </div>
        </div>

        <div className="flex justify-end gap-2 px-5 py-4 border-t border-gray-200 dark:border-gray-700">
          <Button variant="outline" onClick={onClose}>Cancel</Button>
          <Button onClick={() => mutation.mutate()} isLoading={mutation.isPending} disabled={!canSave}>
            Save Changes
          </Button>
        </div>
      </div>
    </div>
  );
}
