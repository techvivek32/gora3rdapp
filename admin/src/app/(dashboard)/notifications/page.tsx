'use client';

import { useState } from 'react';
import { useMutation } from '@tanstack/react-query';
import { adminApi } from '@/lib/api';
import { Button } from '@/components/ui/Button';
import { Input } from '@/components/ui/Input';
import toast from 'react-hot-toast';

const MEMBERSHIP_TYPES = ['new', 'active', 'verified', 'premium', 'golden'];

export default function NotificationsPage() {
  const [form, setForm] = useState({
    title: '',
    body: '',
    imageUrl: '',
    actionUrl: '',
    targetMemberships: [] as string[],
    targetCities: '',
    type: 'system',
  });

  const sendMutation = useMutation({
    mutationFn: () => adminApi.sendAdminNotification({
      ...form,
      targetCities: form.targetCities ? form.targetCities.split(',').map((c) => c.trim()) : undefined,
    }),
    onSuccess: () => {
      toast.success('Notification sent successfully');
      setForm({ title: '', body: '', imageUrl: '', actionUrl: '', targetMemberships: [], targetCities: '', type: 'system' });
    },
    onError: () => toast.error('Failed to send notification'),
  });

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
        <h1 className="text-2xl font-bold text-gray-900">Send Notification</h1>
        <p className="text-gray-500 mt-1">Push notifications to targeted users</p>
      </div>

      <div className="bg-white rounded-xl border border-gray-200 p-6 space-y-5 max-w-2xl">
        <div className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Title *</label>
            <Input value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value })} placeholder="Notification title" />
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Message *</label>
            <textarea
              value={form.body}
              onChange={(e) => setForm({ ...form, body: e.target.value })}
              placeholder="Notification message body"
              rows={3}
              className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-brand-500 resize-none"
            />
          </div>
          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Image URL (Optional)</label>
              <Input value={form.imageUrl} onChange={(e) => setForm({ ...form, imageUrl: e.target.value })} placeholder="https://..." />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Action URL (Optional)</label>
              <Input value={form.actionUrl} onChange={(e) => setForm({ ...form, actionUrl: e.target.value })} placeholder="/requirements" />
            </div>
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">Target Membership</label>
            <div className="flex flex-wrap gap-2">
              <button
                type="button"
                onClick={() => setForm((f) => ({ ...f, targetMemberships: [] }))}
                className={`px-3 py-1.5 rounded-lg text-sm font-medium border transition-colors ${
                  form.targetMemberships.length === 0
                    ? 'bg-gray-800 text-white border-gray-800'
                    : 'bg-white text-gray-600 border-gray-200 hover:bg-gray-50'
                }`}
              >
                All Users
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
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Target Cities (Optional)</label>
            <Input
              value={form.targetCities}
              onChange={(e) => setForm({ ...form, targetCities: e.target.value })}
              placeholder="Mumbai, Delhi, Bangalore (comma separated)"
            />
            <p className="text-xs text-gray-400 mt-1">Leave empty to send to all cities</p>
          </div>
        </div>

        <div className="bg-gray-50 rounded-lg p-4">
          <p className="text-sm font-medium text-gray-700 mb-2">Preview</p>
          <div className="bg-white rounded-lg p-3 border border-gray-200 flex gap-3">
            <div className="w-10 h-10 bg-brand-100 rounded-full flex items-center justify-center flex-shrink-0">
              <span className="text-brand-600 font-bold text-sm">G</span>
            </div>
            <div>
              <p className="font-semibold text-sm">{form.title || 'Notification Title'}</p>
              <p className="text-xs text-gray-500">{form.body || 'Notification message will appear here'}</p>
            </div>
          </div>
        </div>

        <Button
          onClick={() => sendMutation.mutate()}
          isLoading={sendMutation.isPending}
          disabled={!form.title || !form.body}
          className="w-full"
        >
          Send Notification
        </Button>
      </div>
    </div>
  );
}
