'use client';

import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { adminApi } from '@/lib/api';
import { Button } from '@/components/ui/Button';
import { Input } from '@/components/ui/Input';
import { Badge } from '@/components/ui/Badge';
import toast from 'react-hot-toast';

interface City {
  _id: string;
  name: string;
  state: string;
  slug: string;
  isActive: boolean;
  isFeatured: boolean;
  requirementCount: number;
  vehicleCount: number;
  userCount: number;
}

export default function CitiesPage() {
  const [showForm, setShowForm] = useState(false);
  const [name, setName] = useState('');
  const [state, setState] = useState('');
  const queryClient = useQueryClient();

  const { data, isLoading } = useQuery({
    queryKey: ['cities'],
    queryFn: () => adminApi.getCities(),
  });

  const createMutation = useMutation({
    mutationFn: () => adminApi.createCity({ name: name.trim(), state: state.trim() }),
    onSuccess: () => {
      toast.success('City created');
      setName(''); setState(''); setShowForm(false);
      queryClient.invalidateQueries({ queryKey: ['cities'] });
    },
    onError: () => toast.error('Failed to create city'),
  });

  const deleteMutation = useMutation({
    mutationFn: (id: string) => adminApi.deleteCity(id),
    onSuccess: () => { toast.success('City deleted'); queryClient.invalidateQueries({ queryKey: ['cities'] }); },
  });

  const cities: City[] = data?.data?.data || [];

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Cities</h1>
          <p className="text-gray-500 mt-1">Manage platform cities</p>
        </div>
        <Button onClick={() => setShowForm(!showForm)}>
          {showForm ? 'Cancel' : '+ Add City'}
        </Button>
      </div>

      {showForm && (
        <div className="bg-white rounded-xl border border-gray-200 p-6">
          <h2 className="font-semibold text-lg mb-4">Add New City</h2>
          <div className="grid grid-cols-2 gap-4">
            <Input placeholder="City Name" value={name} onChange={(e) => setName(e.target.value)} />
            <Input placeholder="State" value={state} onChange={(e) => setState(e.target.value)} />
          </div>
          <Button
            className="mt-4"
            onClick={() => createMutation.mutate()}
            isLoading={createMutation.isPending}
            disabled={!name || !state}
          >
            Create City
          </Button>
        </div>
      )}

      {isLoading ? (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {Array.from({ length: 9 }).map((_, i) => (
            <div key={i} className="h-32 bg-gray-100 rounded-xl animate-pulse" />
          ))}
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {cities.map((city) => (
            <div key={city._id} className="bg-white rounded-xl border border-gray-200 p-5 hover:shadow-card-hover transition-shadow">
              <div className="flex items-start justify-between">
                <div>
                  <h3 className="font-semibold text-lg">{city.name}</h3>
                  <p className="text-gray-500 text-sm">{city.state}</p>
                </div>
                <div className="flex gap-2">
                  <Badge variant={city.isActive ? 'success' : 'secondary'}>
                    {city.isActive ? 'Active' : 'Inactive'}
                  </Badge>
                  {city.isFeatured && <Badge variant="warning">Featured</Badge>}
                </div>
              </div>
              <div className="mt-4 grid grid-cols-3 gap-2 text-center">
                {[
                  { label: 'Users', value: city.userCount },
                  { label: 'Requirements', value: city.requirementCount },
                  { label: 'Vehicles', value: city.vehicleCount },
                ].map(({ label, value }) => (
                  <div key={label} className="bg-gray-50 rounded-lg p-2">
                    <p className="text-lg font-bold">{value}</p>
                    <p className="text-xs text-gray-500">{label}</p>
                  </div>
                ))}
              </div>
              <button
                onClick={() => deleteMutation.mutate(city._id)}
                className="mt-3 text-xs text-red-500 hover:underline"
              >
                Delete
              </button>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
