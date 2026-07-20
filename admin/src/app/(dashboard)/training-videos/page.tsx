'use client';

import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { adminApi } from '@/lib/api';
import { PlayCircle, Plus, X, ExternalLink } from 'lucide-react';
import toast from 'react-hot-toast';

interface Video {
  _id: string;
  title: string;
  url: string;
  isActive: boolean;
  sortOrder: number;
}

interface FormState {
  _id?: string;
  title: string;
  url: string;
  isActive: boolean;
  sortOrder: number;
}

const inputCls =
  'w-full border border-gray-200 dark:border-gray-700 dark:bg-gray-800 dark:text-white rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-orange-500';

export default function TrainingVideosPage() {
  const qc = useQueryClient();
  const [form, setForm] = useState<FormState | null>(null);

  const { data: raw, isLoading } = useQuery({
    queryKey: ['training-videos'],
    queryFn: () => adminApi.getTrainingVideos(),
  });
  const videos: Video[] = Array.isArray((raw as any)?.data) ? (raw as any).data : [];

  const save = useMutation({
    mutationFn: () => {
      const payload = { title: form!.title.trim(), url: form!.url.trim(), isActive: form!.isActive, sortOrder: form!.sortOrder };
      return form!._id ? adminApi.updateTrainingVideo(form!._id, payload) : adminApi.createTrainingVideo(payload);
    },
    onSuccess: () => {
      toast.success(form!._id ? 'Video updated' : 'Video added');
      setForm(null);
      qc.invalidateQueries({ queryKey: ['training-videos'] });
    },
    onError: (e: any) => toast.error(e?.message || 'Could not save'),
  });

  const del = useMutation({
    mutationFn: (id: string) => adminApi.deleteTrainingVideo(id),
    onSuccess: () => {
      toast.success('Video removed');
      qc.invalidateQueries({ queryKey: ['training-videos'] });
    },
    onError: (e: any) => toast.error(e?.message || 'Could not delete'),
  });

  const openCreate = () => setForm({ title: '', url: '', isActive: true, sortOrder: 0 });
  const openEdit = (v: Video) => setForm({ _id: v._id, title: v.title, url: v.url, isActive: v.isActive, sortOrder: v.sortOrder ?? 0 });

  const validUrl = (u: string) => /^https?:\/\/.+/i.test(u.trim());

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <PlayCircle className="w-6 h-6 text-orange-500" />
          <div>
            <h1 className="text-2xl font-bold text-gray-900 dark:text-white">Training Videos</h1>
            <p className="text-sm text-gray-500">Add a title and a link — shown in the app under Settings.</p>
          </div>
        </div>
        <button
          onClick={openCreate}
          className="inline-flex items-center gap-1.5 px-4 py-2 rounded-lg bg-orange-500 hover:bg-orange-600 text-white text-sm font-semibold transition-colors"
        >
          <Plus className="w-4 h-4" /> Add Video
        </button>
      </div>

      <div className="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-700 overflow-hidden">
        {isLoading ? (
          <p className="p-6 text-sm text-gray-500">Loading…</p>
        ) : videos.length === 0 ? (
          <p className="p-6 text-sm text-gray-500">No training videos yet.</p>
        ) : (
          <table className="w-full text-sm">
            <thead>
              <tr className="text-left text-xs uppercase tracking-wide text-gray-500 border-b border-gray-200 dark:border-gray-700">
                <th className="px-4 py-3 font-medium">Order</th>
                <th className="px-4 py-3 font-medium">Title</th>
                <th className="px-4 py-3 font-medium">Link</th>
                <th className="px-4 py-3 font-medium">Status</th>
                <th className="px-4 py-3 font-medium text-right">Actions</th>
              </tr>
            </thead>
            <tbody>
              {videos.map((v) => (
                <tr key={v._id} className="border-b border-gray-100 dark:border-gray-800 last:border-0">
                  <td className="px-4 py-3 text-gray-500">{v.sortOrder}</td>
                  <td className="px-4 py-3 font-medium text-gray-900 dark:text-white">{v.title}</td>
                  <td className="px-4 py-3 max-w-xs">
                    <a href={v.url} target="_blank" rel="noreferrer" className="inline-flex items-center gap-1 text-orange-600 dark:text-orange-400 truncate hover:underline">
                      <ExternalLink className="w-3.5 h-3.5 shrink-0" />
                      <span className="truncate">{v.url}</span>
                    </a>
                  </td>
                  <td className="px-4 py-3">
                    <span className={`text-xs px-2 py-0.5 rounded-full font-medium ${v.isActive ? 'bg-emerald-500/15 text-emerald-500' : 'bg-gray-400/15 text-gray-500'}`}>
                      {v.isActive ? 'Active' : 'Hidden'}
                    </span>
                  </td>
                  <td className="px-4 py-3 text-right whitespace-nowrap">
                    <button onClick={() => openEdit(v)} className="text-orange-600 hover:underline font-medium">Edit</button>
                    <button
                      onClick={() => { if (confirm(`Delete "${v.title}"?`)) del.mutate(v._id); }}
                      className="ml-4 text-red-600 hover:underline font-medium"
                    >
                      Delete
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>

      {/* Create / Edit drawer */}
      {form && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4" onClick={() => setForm(null)}>
          <div className="w-full max-w-md bg-white dark:bg-gray-900 rounded-2xl shadow-xl border border-gray-200 dark:border-gray-700" onClick={(e) => e.stopPropagation()}>
            <div className="flex items-center justify-between px-5 py-4 border-b border-gray-200 dark:border-gray-700">
              <h2 className="text-lg font-bold text-gray-900 dark:text-white">{form._id ? 'Edit Video' : 'Add Video'}</h2>
              <button onClick={() => setForm(null)}><X className="w-5 h-5 text-gray-400" /></button>
            </div>
            <div className="p-5 space-y-4">
              <div>
                <label className="block text-xs font-medium text-gray-600 dark:text-gray-400 mb-1">Title *</label>
                <input className={inputCls} value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value })} placeholder="e.g. How to post a requirement" />
              </div>
              <div>
                <label className="block text-xs font-medium text-gray-600 dark:text-gray-400 mb-1">Video Link *</label>
                <input className={inputCls} value={form.url} onChange={(e) => setForm({ ...form, url: e.target.value })} placeholder="https://youtu.be/..." />
                <p className="text-xs text-gray-400 mt-1">Any https link (YouTube, Drive, etc.). Opens in the app when tapped.</p>
              </div>
              <div>
                <label className="block text-xs font-medium text-gray-600 dark:text-gray-400 mb-1">Sort Order</label>
                <input type="number" className={inputCls} value={form.sortOrder} onChange={(e) => setForm({ ...form, sortOrder: +e.target.value })} />
              </div>
              <label className="flex items-center gap-2 text-sm text-gray-700 dark:text-gray-300">
                <input type="checkbox" checked={form.isActive} onChange={(e) => setForm({ ...form, isActive: e.target.checked })} className="w-4 h-4" />
                Active (visible in app)
              </label>
            </div>
            <div className="flex justify-end gap-2 px-5 py-4 border-t border-gray-200 dark:border-gray-700">
              <button onClick={() => setForm(null)} className="px-4 py-2 rounded-lg border border-gray-300 dark:border-gray-600 text-sm font-medium">Cancel</button>
              <button
                onClick={() => save.mutate()}
                disabled={!form.title.trim() || !validUrl(form.url) || save.isPending}
                className="px-4 py-2 rounded-lg bg-orange-500 hover:bg-orange-600 disabled:opacity-50 text-white text-sm font-semibold"
              >
                {save.isPending ? 'Saving…' : form._id ? 'Save Changes' : 'Add Video'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
