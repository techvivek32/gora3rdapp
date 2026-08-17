'use client';

import { useRef, useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { adminApi } from '@/lib/api';
import { Music, Upload, Trash2, CheckCircle2, Circle } from 'lucide-react';
import toast from 'react-hot-toast';

interface Ringtone {
  _id: string;
  title: string;
  audioUrl: string;
  isActive: boolean;
  sortOrder: number;
}

export default function RingtonesPage() {
  const qc = useQueryClient();
  const fileRef = useRef<HTMLInputElement>(null);
  const [title, setTitle] = useState('');
  const [audioUrl, setAudioUrl] = useState('');
  const [uploading, setUploading] = useState(false);

  const { data: raw, isLoading } = useQuery({
    queryKey: ['ringtones'],
    queryFn: () => adminApi.getRingtones(),
  });
  const ringtones: Ringtone[] = ((raw as any)?.data ?? []) as Ringtone[];

  const invalidate = () => qc.invalidateQueries({ queryKey: ['ringtones'] });

  const create = useMutation({
    mutationFn: () => adminApi.createRingtone({ title: title.trim(), audioUrl }),
    onSuccess: () => {
      toast.success('Ringtone added');
      setTitle('');
      setAudioUrl('');
      if (fileRef.current) fileRef.current.value = '';
      invalidate();
    },
    onError: (e: any) => toast.error(e?.message || 'Could not add ringtone'),
  });

  const setActive = useMutation({
    mutationFn: (id: string) => adminApi.updateRingtone(id, { isActive: true }),
    onSuccess: () => { toast.success('Active ringtone set'); invalidate(); },
    onError: (e: any) => toast.error(e?.message || 'Could not update'),
  });

  const remove = useMutation({
    mutationFn: (id: string) => adminApi.deleteRingtone(id),
    onSuccess: () => { toast.success('Ringtone deleted'); invalidate(); },
    onError: (e: any) => toast.error(e?.message || 'Could not delete'),
  });

  const handleFile = async (file?: File | null) => {
    if (!file) return;
    if (!file.type.startsWith('audio/')) return toast.error('Please choose an audio file');
    setUploading(true);
    try {
      const res: any = await adminApi.uploadRingtone(file);
      const url = res?.data?.url ?? res?.url ?? res?.data?.data?.url;
      if (!url) throw new Error('Upload failed');
      setAudioUrl(url);
      if (!title.trim()) setTitle(file.name.replace(/\.[^.]+$/, ''));
      toast.success('Audio uploaded');
    } catch (e: any) {
      toast.error(e?.message || 'Upload failed');
    } finally {
      setUploading(false);
    }
  };

  return (
    <div className="space-y-5">
      <div className="flex items-center gap-2">
        <Music className="w-6 h-6 text-orange-500" />
        <div>
          <h1 className="text-2xl font-bold text-gray-900 dark:text-white">Ringtones</h1>
          <p className="text-sm text-gray-500">Upload alert ringtones. The active one is used by the app.</p>
        </div>
      </div>

      {/* Add form */}
      <div className="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-700 p-6 space-y-4">
        <h2 className="font-semibold text-gray-900 dark:text-white">Add Ringtone</h2>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label className="block text-xs font-medium text-gray-600 dark:text-gray-400 mb-1">Title</label>
            <input
              type="text"
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              placeholder="e.g. Loud Bell"
              className="w-full border border-gray-200 dark:border-gray-700 dark:bg-gray-800 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-orange-500"
            />
          </div>
          <div>
            <label className="block text-xs font-medium text-gray-600 dark:text-gray-400 mb-1">Audio file</label>
            <input ref={fileRef} type="file" accept="audio/*" className="hidden"
              onChange={(e) => handleFile(e.target.files?.[0])} />
            <button
              type="button"
              onClick={() => fileRef.current?.click()}
              disabled={uploading}
              className="w-full inline-flex items-center justify-center gap-2 border border-dashed border-gray-300 dark:border-gray-600 rounded-lg px-3 py-2 text-sm text-gray-600 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-800 disabled:opacity-60"
            >
              <Upload className="w-4 h-4" />
              {uploading ? 'Uploading…' : audioUrl ? 'Change file' : 'Choose audio file'}
            </button>
          </div>
        </div>
        {audioUrl && (
          <audio controls src={audioUrl} className="w-full h-10" />
        )}
        <button
          onClick={() => create.mutate()}
          disabled={create.isPending || uploading || !title.trim() || !audioUrl}
          className="px-4 py-2 rounded-lg bg-orange-500 hover:bg-orange-600 disabled:opacity-50 text-white text-sm font-semibold"
        >
          {create.isPending ? 'Saving…' : 'Add Ringtone'}
        </button>
      </div>

      {/* List */}
      <div className="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-700 p-6">
        <h2 className="font-semibold text-gray-900 dark:text-white mb-4">All Ringtones</h2>
        {isLoading ? (
          <p className="text-sm text-gray-500 py-4">Loading…</p>
        ) : ringtones.length === 0 ? (
          <p className="text-sm text-gray-500 py-4">No ringtones yet. Add one above.</p>
        ) : (
          <div className="space-y-3">
            {ringtones.map((r) => (
              <div key={r._id} className="flex items-center gap-3 flex-wrap border border-gray-100 dark:border-gray-800 rounded-lg p-3">
                <div className="flex items-center gap-2 min-w-0">
                  <Music className="w-4 h-4 text-orange-500 shrink-0" />
                  <span className="font-medium text-gray-900 dark:text-white truncate">{r.title}</span>
                  {r.isActive && (
                    <span className="inline-flex items-center gap-1 text-xs px-2 py-0.5 rounded-full font-semibold bg-green-500/15 text-green-500">
                      <CheckCircle2 className="w-3.5 h-3.5" /> Active
                    </span>
                  )}
                </div>
                <audio controls src={r.audioUrl} className="h-9 ml-auto" />
                <div className="flex items-center gap-2">
                  {!r.isActive && (
                    <button
                      onClick={() => setActive.mutate(r._id)}
                      disabled={setActive.isPending}
                      className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg border border-gray-300 dark:border-gray-600 text-sm font-medium hover:bg-gray-50 dark:hover:bg-gray-800 disabled:opacity-60"
                    >
                      <Circle className="w-4 h-4" /> Set Active
                    </button>
                  )}
                  <button
                    onClick={() => { if (confirm(`Delete "${r.title}"?`)) remove.mutate(r._id); }}
                    disabled={remove.isPending}
                    className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg border border-red-300 dark:border-red-800 text-sm font-medium text-red-600 hover:bg-red-50 dark:hover:bg-red-950 disabled:opacity-60"
                  >
                    <Trash2 className="w-4 h-4" /> Delete
                  </button>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
