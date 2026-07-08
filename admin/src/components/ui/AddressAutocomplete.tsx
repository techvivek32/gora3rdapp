'use client';

import { useEffect, useRef, useState } from 'react';
import { adminApi } from '@/lib/api';
import { MapPin } from 'lucide-react';

export interface PlaceValue {
  address: string;
  lat?: number;
  lng?: number;
  city?: string;
  state?: string;
}

interface Prediction {
  placeId: string;
  description: string;
  main: string;
  secondary: string;
}

/** Google-Places address field (proxied via the backend). Type to search Indian
 *  addresses; selecting one resolves lat/lng + clean city. */
export function AddressAutocomplete({
  value,
  onSelect,
  placeholder,
}: {
  value: string;
  onSelect: (v: PlaceValue) => void;
  placeholder?: string;
}) {
  const [query, setQuery] = useState(value);
  const [preds, setPreds] = useState<Prediction[]>([]);
  const [open, setOpen] = useState(false);
  const [loading, setLoading] = useState(false);
  const debounce = useRef<ReturnType<typeof setTimeout> | null>(null);
  const boxRef = useRef<HTMLDivElement>(null);

  useEffect(() => setQuery(value), [value]);

  // Close the dropdown when clicking outside.
  useEffect(() => {
    const h = (e: MouseEvent) => {
      if (boxRef.current && !boxRef.current.contains(e.target as Node)) setOpen(false);
    };
    document.addEventListener('mousedown', h);
    return () => document.removeEventListener('mousedown', h);
  }, []);

  const onChange = (q: string) => {
    setQuery(q);
    if (debounce.current) clearTimeout(debounce.current);
    if (q.trim().length < 2) {
      setPreds([]);
      return;
    }
    setLoading(true);
    debounce.current = setTimeout(async () => {
      try {
        const res: any = await adminApi.placesAutocomplete(q.trim());
        setPreds(res?.data?.predictions || []);
        setOpen(true);
      } catch {
        setPreds([]);
      } finally {
        setLoading(false);
      }
    }, 300);
  };

  const pick = async (p: Prediction) => {
    setQuery(p.description);
    setOpen(false);
    try {
      const res: any = await adminApi.placeDetails(p.placeId);
      const d = res?.data || {};
      onSelect({ address: d.address || p.description, lat: d.lat, lng: d.lng, city: d.city, state: d.state });
    } catch {
      onSelect({ address: p.description });
    }
  };

  return (
    <div ref={boxRef} className="relative">
      <div className="flex items-center border border-gray-200 dark:border-gray-700 dark:bg-gray-800 rounded-lg px-3">
        <MapPin className="w-4 h-4 text-gray-400 shrink-0" />
        <input
          value={query}
          onChange={(e) => onChange(e.target.value)}
          onFocus={() => preds.length && setOpen(true)}
          placeholder={placeholder || 'Search address…'}
          className="w-full bg-transparent px-2 py-2 text-sm outline-none"
        />
        {loading && <div className="w-4 h-4 border-2 border-gray-300 border-t-orange-500 rounded-full animate-spin" />}
      </div>
      {open && preds.length > 0 && (
        <div className="absolute z-20 mt-1 w-full max-h-60 overflow-y-auto bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-700 rounded-lg shadow-lg">
          {preds.map((p) => (
            <button
              key={p.placeId}
              type="button"
              onClick={() => pick(p)}
              className="w-full text-left px-3 py-2 hover:bg-gray-50 dark:hover:bg-gray-800 border-b border-gray-100 dark:border-gray-800 last:border-0"
            >
              <p className="text-sm font-medium text-gray-800 dark:text-gray-100">{p.main}</p>
              {p.secondary && <p className="text-xs text-gray-500">{p.secondary}</p>}
            </button>
          ))}
        </div>
      )}
    </div>
  );
}
