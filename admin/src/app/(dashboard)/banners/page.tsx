'use client';

import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { adminApi } from '@/lib/api';
import { Button } from '@/components/ui/Button';
import { Input } from '@/components/ui/Input';
import { Badge } from '@/components/ui/Badge';
import toast from 'react-hot-toast';

interface Banner {
  _id: string;
  title: string;
  subtitle?: string;
  imageUrl?: string;
  actionUrl?: string;
  isActive: boolean;
  sortOrder: number;
  clickCount: number;
  viewCount: number;
  startDate?: string;
  endDate?: string;
}

export default function BannersPage() {
  const [showForm, setShowForm] = useState(false);
  const [form, setForm] = useState({ title: '', subtitle: '', imageUrl: '', actionUrl: '', sortOrder: 0 });
  const queryClient = useQueryClient();

  const { data, isLoading } = useQuery({
    queryKey: ['banners'],
    queryFn: () => adminApi.getBanners(),
  });

  const createMutation = useMutation({
    mutationFn: () => adminApi.createBanner(form),
    onSuccess: () => {
      toast.success('Banner created');
      setForm({ title: '', subtitle: '', imageUrl: '', actionUrl: '', sortOrder: 0 });
      setShowForm(false);
      queryClient.invalidateQueries({ queryKey: ['banners'] });
    },
    onError: () => toast.error('Failed to create banner'),
  });

  const toggleMutation = useMutation({
    mutationFn: ({ id, isActive }: { id: string; isActive: boolean }) => adminApi.updateBanner(id, { isActive }),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['banners'] }),
  });

  const deleteMutation = useMutation({
    mutationFn: (id: string) => adminApi.deleteBanner(id),
    onSuccess: () => { toast.success('Banner deleted'); queryClient.invalidateQueries({ queryKey: ['banners'] }); },
  });

  const banners: Banner[] = data?.data?.data || [];

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Banners</h1>
          <p className="text-gray-500 mt-1">Manage promotional banners in the app</p>
        </div>
        <Button onClick={() => setShowForm(!showForm)}>
          {showForm ? 'Cancel' : '+ Add Banner'}
        </Button>
      </div>

      {showForm && (
        <div className="bg-white rounded-xl border border-gray-200 p-6 space-y-4">
          <h2 className="font-semibold text-lg">New Banner</h2>
          <div className="grid grid-cols-2 gap-4">
            <Input placeholder="Title *" value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value })} />
            <Input placeholder="Subtitle" value={form.subtitle} onChange={(e) => setForm({ ...form, subtitle: e.target.value })} />
            <Input placeholder="Image URL" value={form.imageUrl} onChange={(e) => setForm({ ...form, imageUrl: e.target.value })} />
            <Input placeholder="Action URL" value={form.actionUrl} onChange={(e) => setForm({ ...form, actionUrl: e.target.value })} />
          </div>
          <Button onClick={() => createMutation.mutate()} isLoading={createMutation.isPending} disabled={!form.title}>
            Create Banner
          </Button>
        </div>
      )}

      {isLoading ? (
        <div className="space-y-4">{Array.from({ length: 3 }).map((_, i) => <div key={i} className="h-24 bg-gray-100 rounded-xl animate-pulse" />)}</div>
      ) : (
        <div className="space-y-4">
          {banners.map((banner) => (
            <div key={banner._id} className="bg-white rounded-xl border border-gray-200 p-5 flex items-center gap-4">
              {banner.imageUrl && (
                <img src={banner.imageUrl} alt={banner.title} className="w-32 h-20 object-cover rounded-lg flex-shrink-0" />
              )}
              <div className="flex-1 min-w-0">
                <div className="flex items-center gap-2">
                  <h3 className="font-semibold">{banner.title}</h3>
                  <Badge variant={banner.isActive ? 'success' : 'secondary'}>
                    {banner.isActive ? 'Active' : 'Inactive'}
                  </Badge>
                </div>
                {banner.subtitle && <p className="text-gray-500 text-sm mt-1">{banner.subtitle}</p>}
                <div className="flex gap-4 mt-2 text-xs text-gray-400">
                  <span>{banner.viewCount} views</span>
                  <span>{banner.clickCount} clicks</span>
                </div>
              </div>
              <div className="flex gap-2 flex-shrink-0">
                <Button
                  size="sm"
                  variant={banner.isActive ? 'outline' : 'default'}
                  onClick={() => toggleMutation.mutate({ id: banner._id, isActive: !banner.isActive })}
                >
                  {banner.isActive ? 'Deactivate' : 'Activate'}
                </Button>
                <Button size="sm" variant="destructive" onClick={() => deleteMutation.mutate(banner._id)}>
                  Delete
                </Button>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
