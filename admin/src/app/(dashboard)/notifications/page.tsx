'use client';

import { useRef, useState } from 'react';
import { useMutation } from '@tanstack/react-query';
import { adminApi } from '@/lib/api';
import { Button } from '@/components/ui/Button';
import { Input } from '@/components/ui/Input';
import toast from 'react-hot-toast';

const MEMBERSHIP_TYPES = ['new', 'active', 'premium', 'golden'];

// Backend UserRole values. "Both" = send with no role filter.
const AUDIENCES = [
  { value: 'both', label: 'Both', roles: [] as string[] },
  { value: 'driver', label: 'Driver', roles: ['driver'] },
  { value: 'agent', label: 'Agent', roles: ['travel_agency'] },
];

const EMPTY = {
  title: '',
  body: '',
  imageUrl: '',
  actionUrl: '',
  audience: 'both',
  targetMemberships: [] as string[],
  targetCities: '',
  type: 'system',
};

const LABEL = 'block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2';

export default function NotificationsPage() {
  const [form, setForm] = useState(EMPTY);
  const [uploading, setUploading] = useState(false);
  const fileInputRef = useRef<HTMLInputElement>(null);

  const sendMutation = useMutation({
    mutationFn: () => {
      const { audience, targetCities, ...rest } = form;
      return adminApi.sendAdminNotification({
        ...rest,
        targetRoles: AUDIENCES.find((a) => a.value === audience)?.roles ?? [],
        targetCities: targetCities ? targetCities.split(',').map((c) => c.trim()).filter(Boolean) : undefined,
      });
    },
    onSuccess: (res: any) => {
      toast.success(res?.data?.message ?? res?.message ?? 'Notification sent');
      setForm(EMPTY);
    },
    onError: () => toast.error('Failed to send notification'),
  });

  const handleFileUpload = async (file: File) => {
    setUploading(true);
    try {
      const res = (await adminApi.uploadNotificationImage(file)) as any;
      // Interceptor nesting varies: { data: { url } } or { url }
      const url = res?.data?.url ?? res?.url ?? res?.data?.data?.url;
      if (!url) throw new Error('No URL returned');
      setForm((f) => ({ ...f, imageUrl: url }));
      toast.success('Image uploaded');
    } catch {
      toast.error('Upload failed');
    } finally {
      setUploading(false);
    }
  };

  const toggleMembership = (type: string) => {
    setForm((f) => ({
      ...f,
      targetMemberships: f.targetMemberships.includes(type)
        ? f.targetMemberships.filter((m) => m !== type)
        : [...f.targetMemberships, type],
    }));
  };

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-gray-900 dark:text-white">Send Notification</h1>
        <p className="text-gray-500 mt-1">Push notifications to targeted users</p>
      </div>

      {/* One full-width card — no max width, no side column. */}
      <div className="w-full bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-700 p-6 space-y-5">
        <div>
          <label className={LABEL}>Title *</label>
          <Input value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value })} placeholder="Notification title" />
        </div>

        <div>
          <label className={LABEL}>Message *</label>
          <textarea
            value={form.body}
            onChange={(e) => setForm({ ...form, body: e.target.value })}
            placeholder="Notification message body"
            rows={3}
            className="w-full border border-gray-200 dark:border-gray-700 dark:bg-gray-800 dark:text-white rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-brand-500 resize-none"
          />
        </div>

        {/* Audience + membership: the two "who gets this" controls, side by side. */}
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          <div>
            <label className={LABEL}>Send To *</label>
            <div className="flex flex-wrap gap-2">
              {AUDIENCES.map((a) => (
                <button
                  key={a.value}
                  type="button"
                  onClick={() => setForm((f) => ({ ...f, audience: a.value }))}
                  className={`px-4 py-1.5 rounded-lg text-sm font-medium border transition-colors ${
                    form.audience === a.value
                      ? 'bg-brand-600 text-white border-brand-600'
                      : 'bg-white text-gray-600 border-gray-200 hover:bg-gray-50 dark:bg-gray-800 dark:text-gray-300 dark:border-gray-700 dark:hover:bg-gray-700'
                  }`}
                >
                  {a.label}
                </button>
              ))}
            </div>
          </div>

          <div>
            <label className={LABEL}>Target Membership</label>
            <div className="flex flex-wrap gap-2">
              <button
                type="button"
                onClick={() => setForm((f) => ({ ...f, targetMemberships: [] }))}
                className={`px-3 py-1.5 rounded-lg text-sm font-medium border transition-colors ${
                  form.targetMemberships.length === 0
                    ? 'bg-gray-800 text-white border-gray-800 dark:bg-gray-200 dark:text-gray-900 dark:border-gray-200'
                    : 'bg-white text-gray-600 border-gray-200 hover:bg-gray-50 dark:bg-gray-800 dark:text-gray-300 dark:border-gray-700 dark:hover:bg-gray-700'
                }`}
              >
                All Members
              </button>
              {MEMBERSHIP_TYPES.map((type) => (
                <button
                  key={type}
                  type="button"
                  onClick={() => toggleMembership(type)}
                  className={`badge-${type} px-3 py-1.5 rounded-lg text-sm font-medium transition-opacity ${
                    form.targetMemberships.includes(type) ? 'opacity-100 ring-2 ring-offset-1' : 'opacity-60'
                  }`}
                >
                  {type.charAt(0).toUpperCase() + type.slice(1)}
                </button>
              ))}
            </div>
          </div>
        </div>

        {/* Image + action URL: the two "what it links to" controls, side by side. */}
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          <div>
            <label className={LABEL}>Image (Optional)</label>
            <input
              ref={fileInputRef}
              type="file"
              accept="image/*"
              className="hidden"
              onChange={(e) => { const f = e.target.files?.[0]; if (f) handleFileUpload(f); e.target.value = ''; }}
            />
            {form.imageUrl ? (
              <div className="relative max-w-md">
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img src={form.imageUrl} alt="Notification" className="w-full aspect-[2/1] object-cover rounded-lg border border-gray-200 dark:border-gray-700" />
                <button
                  type="button"
                  onClick={() => setForm((f) => ({ ...f, imageUrl: '' }))}
                  className="absolute top-2 right-2 w-7 h-7 rounded-full bg-black/60 text-white text-sm hover:bg-black/80"
                  aria-label="Remove image"
                >
                  ×
                </button>
              </div>
            ) : (
              <div
                onClick={() => !uploading && fileInputRef.current?.click()}
                className="w-full max-w-md aspect-[2/1] rounded-lg border-2 border-dashed border-gray-300 dark:border-gray-700 flex flex-col items-center justify-center cursor-pointer hover:border-brand-500 text-gray-400"
              >
                <span className="text-sm">{uploading ? 'Uploading…' : 'Click to upload image'}</span>
                <span className="text-xs mt-1">Recommended 1024 × 512 px</span>
              </div>
            )}
          </div>

          <div className="space-y-5">
            <div>
              <label className={LABEL}>Action URL (Optional)</label>
              <Input value={form.actionUrl} onChange={(e) => setForm({ ...form, actionUrl: e.target.value })} placeholder="https://goracabs.com/offers" />
              <p className="text-xs text-gray-400 mt-1">
                Tapping the notification opens this. Use a full https:// link for a website, or an in-app path like /subscription.
              </p>
            </div>
            <div>
              <label className={LABEL}>Target Cities (Optional)</label>
              <Input
                value={form.targetCities}
                onChange={(e) => setForm({ ...form, targetCities: e.target.value })}
                placeholder="Mumbai, Delhi, Bangalore"
              />
              <p className="text-xs text-gray-400 mt-1">Comma separated. Leave empty to send to all cities.</p>
            </div>
          </div>
        </div>

        <div className="bg-gray-50 dark:bg-gray-800 rounded-lg p-4">
          <p className="text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">Preview</p>
          <div className="bg-white dark:bg-gray-900 rounded-lg p-3 border border-gray-200 dark:border-gray-700 max-w-md">
            <div className="flex gap-3">
              <div className="w-10 h-10 bg-brand-100 rounded-full flex items-center justify-center flex-shrink-0">
                <span className="text-brand-600 font-bold text-sm">G</span>
              </div>
              <div className="min-w-0">
                <p className="font-semibold text-sm text-gray-900 dark:text-white break-words">{form.title || 'Notification Title'}</p>
                <p className="text-xs text-gray-500 whitespace-pre-line break-words">{form.body || 'Notification message will appear here'}</p>
              </div>
            </div>
            {form.imageUrl && (
              // eslint-disable-next-line @next/next/no-img-element
              <img src={form.imageUrl} alt="" className="mt-3 w-full aspect-[2/1] object-cover rounded-md" />
            )}
          </div>
          <p className="text-xs text-gray-400 mt-3">
            Sending to <span className="font-medium text-gray-600 dark:text-gray-300">{AUDIENCES.find((a) => a.value === form.audience)?.label}</span>
            {form.targetMemberships.length > 0 && ` · ${form.targetMemberships.join(', ')}`}
            {form.targetCities.trim() && ` · ${form.targetCities}`}
          </p>
        </div>

        <Button
          onClick={() => sendMutation.mutate()}
          isLoading={sendMutation.isPending}
          disabled={!form.title || !form.body || uploading}
          className="w-full"
        >
          Send Notification
        </Button>
      </div>
    </div>
  );
}
