'use client';

import { useMemo, useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { adminApi } from '@/lib/api';
import { Input } from '@/components/ui/Input';
import { Loader2, Pencil, Star, Trash2, X } from 'lucide-react';
import toast from 'react-hot-toast';

/**
 * The cities the network is set up in.
 *
 * Not the same thing as City Insights next door: that counts the demand and
 * supply the platform HAS, from requirements and drivers. This is the list
 * the operator DECLARES — it feeds the website's "Where we run" strip and
 * the app's city pickers, and until now it could only be changed by editing
 * the database.
 *
 * Switched-off cities are listed here but hidden from the public endpoint,
 * so a city can be taken off the website without losing its row.
 */
interface City {
  _id: string;
  name: string;
  state: string;
  slug?: string;
  isActive?: boolean;
  isFeatured?: boolean;
  sortOrder?: number;
  color?: string;
}

/**
 * The chip colours on the website's coverage strip.
 *
 * A fixed set rather than a colour picker: each solid carries white text and
 * is known to clear 4.5:1 against it, which an arbitrary hex cannot promise —
 * the first pale yellow anyone picked would make that chip unreadable and
 * nothing here would stop them.
 *
 * `auto` is what the strip did before this existed: featured cities take the
 * next colour in a rotation, the rest are soft. The swatches below are the
 * real website values, so what you see here is what the site draws.
 *
 * Mirrored in web/src/lib/city-colour.ts. Add a value there too.
 */
const COLOURS: { value: string; label: string; swatch: string; ring?: boolean }[] = [
  { value: 'auto', label: 'Auto', swatch: 'linear-gradient(135deg,#0f766e 0 25%,#a16207 25% 50%,#c2410c 50% 75%,#ea580c 75%)' },
  { value: 'soft', label: 'Soft', swatch: '#ffedd5', ring: true },
  { value: 'orange', label: 'Orange', swatch: '#c2410c' },
  { value: 'teal', label: 'Teal', swatch: '#0f766e' },
  { value: 'gold', label: 'Gold', swatch: '#a16207' },
  { value: 'slate', label: 'Slate', swatch: '#64748b' },
];

const EMPTY = {
  name: '', state: '', isActive: true, isFeatured: false, sortOrder: 0, color: 'auto',
};

export function ServiceCities() {
  const queryClient = useQueryClient();
  const [search, setSearch] = useState('');
  const [editing, setEditing] = useState<City | null>(null);
  const [form, setForm] = useState(EMPTY);
  const [open, setOpen] = useState(false);

  const { data, isLoading } = useQuery({
    queryKey: ['admin-cities'],
    queryFn: () => adminApi.getAdminCities(),
  });
  // `/admin/cities` is paginated, so the rows are a level deeper than the
  // envelope's `data`: { data: { data: [...], meta } }.
  const cities: City[] = data?.data?.data?.data ?? data?.data?.data ?? [];

  const shown = useMemo(() => {
    const q = search.trim().toLowerCase();
    if (!q) return cities;
    return cities.filter(
      (c) => c.name.toLowerCase().includes(q) || (c.state || '').toLowerCase().includes(q),
    );
  }, [cities, search]);

  const done = (msg: string) => {
    queryClient.invalidateQueries({ queryKey: ['admin-cities'] });
    toast.success(msg);
  };
  // The server has the real rules — a duplicate name, a name with nothing in
  // it. Showing its sentence beats inventing one here that says less.
  const failed = (e: any, fallback: string) =>
    toast.error(e?.response?.data?.message ?? fallback);

  const create = useMutation({
    mutationFn: (body: typeof EMPTY) => adminApi.createCity(body),
    onSuccess: () => { done('City added'); close(); },
    onError: (e) => failed(e, 'Could not add that city'),
  });
  const update = useMutation({
    mutationFn: ({ id, body }: { id: string; body: any }) => adminApi.updateCity(id, body),
    onSuccess: () => { done('City updated'); close(); },
    onError: (e) => failed(e, 'Could not update that city'),
  });
  const remove = useMutation({
    mutationFn: (id: string) => adminApi.deleteCity(id),
    onSuccess: () => done('City removed'),
    onError: (e) => failed(e, 'Could not remove that city'),
  });

  function close() {
    setOpen(false);
    setEditing(null);
    setForm(EMPTY);
  }
  function openCreate() {
    setEditing(null);
    setForm(EMPTY);
    setOpen(true);
  }
  function openEdit(c: City) {
    setEditing(c);
    setForm({
      name: c.name ?? '',
      state: c.state ?? '',
      isActive: c.isActive ?? true,
      isFeatured: c.isFeatured ?? false,
      sortOrder: c.sortOrder ?? 0,
      color: c.color || 'auto',
    });
    setOpen(true);
  }
  function submit(e: React.FormEvent) {
    e.preventDefault();
    if (!form.name.trim() || !form.state.trim()) return toast.error('Name and state are both needed');
    if (editing) update.mutate({ id: editing._id, body: form });
    else create.mutate(form);
  }

  const busy = create.isPending || update.isPending;
  const liveCount = cities.filter((c) => c.isActive !== false).length;

  return (
    <div className="space-y-5">
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <p className="text-sm text-gray-500">
            {liveCount} of {cities.length} showing on the website and in the app.
          </p>
        </div>
        <div className="flex items-center gap-3">
          <Input
            placeholder="Search city or state…"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="max-w-xs"
          />
          <button
            onClick={openCreate}
            className="shrink-0 rounded-lg bg-brand-600 px-4 py-2 text-sm font-semibold text-white transition-colors hover:bg-brand-700"
          >
            + Add city
          </button>
        </div>
      </div>

      {open && (
        <form
          onSubmit={submit}
          className="space-y-4 rounded-xl border border-gray-200 bg-white p-6 dark:border-gray-700 dark:bg-gray-900"
        >
          <div className="flex items-center justify-between">
            <h3 className="font-semibold text-gray-900 dark:text-white">
              {editing ? `Edit ${editing.name}` : 'New city'}
            </h3>
            <button type="button" onClick={close} className="text-gray-400 hover:text-gray-600">
              <X className="h-4 w-4" />
            </button>
          </div>

          <div className="grid gap-4 sm:grid-cols-2">
            <div>
              <label className="mb-1 block text-sm font-medium text-gray-700 dark:text-gray-300">City</label>
              <Input value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} placeholder="Udaipur" />
            </div>
            <div>
              <label className="mb-1 block text-sm font-medium text-gray-700 dark:text-gray-300">State</label>
              <Input value={form.state} onChange={(e) => setForm({ ...form, state: e.target.value })} placeholder="Rajasthan" />
            </div>
            <div>
              <label className="mb-1 block text-sm font-medium text-gray-700 dark:text-gray-300">Order</label>
              <Input
                type="number"
                min={0}
                value={form.sortOrder}
                onChange={(e) => setForm({ ...form, sortOrder: Number(e.target.value) || 0 })}
              />
              <p className="mt-1 text-xs text-gray-400">Lower numbers come first.</p>
            </div>
            <div className="sm:col-span-2">
              <label className="mb-2 block text-sm font-medium text-gray-700 dark:text-gray-300">
                Chip colour on the website
              </label>
              <div className="flex flex-wrap gap-2">
                {COLOURS.map((c) => (
                  <button
                    key={c.value}
                    type="button"
                    onClick={() => setForm({ ...form, color: c.value })}
                    aria-pressed={form.color === c.value}
                    className={`flex items-center gap-2 rounded-lg border px-3 py-2 text-sm font-medium transition-colors ${
                      form.color === c.value
                        ? 'border-brand-500 bg-brand-50 text-brand-700 dark:bg-brand-900/20 dark:text-brand-300'
                        : 'border-gray-200 text-gray-600 hover:bg-gray-50 dark:border-gray-700 dark:text-gray-300 dark:hover:bg-gray-800'
                    }`}
                  >
                    <span
                      className={`h-4 w-4 rounded-full ${c.ring ? 'ring-1 ring-gray-300 dark:ring-gray-600' : ''}`}
                      style={{ background: c.swatch }}
                    />
                    {c.label}
                  </button>
                ))}
              </div>
              <p className="mt-1.5 text-xs text-gray-400">
                Auto: featured cities get a colour from the rotation, the rest stay soft.
              </p>
            </div>

            <div className="flex items-end gap-5 pb-1">
              <label className="flex items-center gap-2 text-sm text-gray-700 dark:text-gray-300">
                <input
                  type="checkbox"
                  checked={form.isActive}
                  onChange={(e) => setForm({ ...form, isActive: e.target.checked })}
                  className="h-4 w-4 rounded border-gray-300 text-brand-600"
                />
                Showing
              </label>
              <label className="flex items-center gap-2 text-sm text-gray-700 dark:text-gray-300">
                <input
                  type="checkbox"
                  checked={form.isFeatured}
                  onChange={(e) => setForm({ ...form, isFeatured: e.target.checked })}
                  className="h-4 w-4 rounded border-gray-300 text-brand-600"
                />
                Featured
              </label>
            </div>
          </div>

          <div className="flex gap-2">
            <button
              type="submit"
              disabled={busy}
              className="inline-flex items-center gap-2 rounded-lg bg-brand-600 px-5 py-2 text-sm font-semibold text-white transition-colors hover:bg-brand-700 disabled:opacity-50"
            >
              {busy && <Loader2 className="h-4 w-4 animate-spin" />}
              {editing ? 'Save' : 'Add city'}
            </button>
            <button
              type="button"
              onClick={close}
              className="rounded-lg px-4 py-2 text-sm font-semibold text-gray-600 hover:bg-gray-100 dark:text-gray-300 dark:hover:bg-gray-800"
            >
              Cancel
            </button>
          </div>
        </form>
      )}

      {isLoading ? (
        <div className="grid h-40 place-items-center">
          <Loader2 className="h-6 w-6 animate-spin text-gray-400" />
        </div>
      ) : shown.length === 0 ? (
        <div className="rounded-xl border border-gray-200 p-10 text-center text-sm text-gray-500 dark:border-gray-700">
          {cities.length === 0 ? 'No cities yet. Add the first one.' : 'No city matches that search.'}
        </div>
      ) : (
        <div className="overflow-hidden rounded-xl border border-gray-200 dark:border-gray-700">
          {shown.map((c, i) => (
            <div
              key={c._id}
              className={`flex items-center gap-4 bg-white px-4 py-3 dark:bg-gray-900 ${
                i > 0 ? 'border-t border-gray-100 dark:border-gray-800' : ''
              }`}
            >
              {/* The colour, on the row — otherwise you have to open each
                  city to find out what the strip looks like. */}
              <span
                aria-hidden
                title={COLOURS.find((x) => x.value === (c.color || 'auto'))?.label}
                className={`h-6 w-6 shrink-0 rounded-full ${
                  (c.color || 'auto') === 'soft' ? 'ring-1 ring-gray-300 dark:ring-gray-600' : ''
                }`}
                style={{ background: COLOURS.find((x) => x.value === (c.color || 'auto'))?.swatch }}
              />
              <div className="min-w-0 flex-1">
                <p className="flex items-center gap-2 font-semibold text-gray-900 dark:text-white">
                  {c.name}
                  {c.isFeatured && <Star className="h-3.5 w-3.5 fill-amber-400 text-amber-400" />}
                </p>
                <p className="text-xs text-gray-500">{c.state}</p>
              </div>

              {/* One click, not a form: whether a city is showing is the thing
                  an operator changes most. */}
              <button
                onClick={() => update.mutate({ id: c._id, body: { isActive: !(c.isActive !== false) } })}
                className={`shrink-0 rounded-full px-3 py-1 text-xs font-semibold transition-colors ${
                  c.isActive !== false
                    ? 'bg-emerald-50 text-emerald-700 hover:bg-emerald-100 dark:bg-emerald-900/20 dark:text-emerald-400'
                    : 'bg-gray-100 text-gray-500 hover:bg-gray-200 dark:bg-gray-800'
                }`}
              >
                {c.isActive !== false ? 'Showing' : 'Hidden'}
              </button>

              <button
                onClick={() => openEdit(c)}
                className="shrink-0 rounded-lg p-2 text-gray-400 transition-colors hover:bg-gray-100 hover:text-gray-700 dark:hover:bg-gray-800"
                aria-label={`Edit ${c.name}`}
              >
                <Pencil className="h-4 w-4" />
              </button>
              <button
                onClick={() => {
                  if (confirm(`Remove ${c.name} from the list?`)) remove.mutate(c._id);
                }}
                className="shrink-0 rounded-lg p-2 text-gray-400 transition-colors hover:bg-red-50 hover:text-red-600 dark:hover:bg-red-900/20"
                aria-label={`Remove ${c.name}`}
              >
                <Trash2 className="h-4 w-4" />
              </button>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
