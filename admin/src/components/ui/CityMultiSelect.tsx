'use client';

import { useEffect, useRef, useState } from 'react';
import { adminApi } from '@/lib/api';
import { MapPin, X } from 'lucide-react';

interface Prediction {
  placeId: string;
  main: string;       // "Rajkot"
  secondary: string;  // "Gujarat, India"
}

/**
 * City picker backed by the same Google Places proxy the app's "My Cities" page
 * uses. Typing "raj" suggests "Rajkot".
 *
 * It stores the prediction's `main` value — exactly what select_city_page.dart
 * writes into the user's `businessCities` — so admin targeting matches what users
 * actually picked in the app.
 */
export function CityMultiSelect({
  value,
  onChange,
  placeholder,
}: {
  value: string[];
  onChange: (cities: string[]) => void;
  placeholder?: string;
}) {
  const [query, setQuery] = useState('');
  const [preds, setPreds] = useState<Prediction[]>([]);
  const [open, setOpen] = useState(false);
  const [loading, setLoading] = useState(false);
  const debounce = useRef<ReturnType<typeof setTimeout> | null>(null);
  const boxRef = useRef<HTMLDivElement>(null);

  // Tolerate a legacy comma-separated string (and undefined) so a stale caller
  // can't crash the picker.
  const selected: string[] = Array.isArray(value)
    ? value
    : String(value ?? '').split(',').map((c) => c.trim()).filter(Boolean);

  // Close the dropdown when clicking outside.
  useEffect(() => {
    const h = (e: MouseEvent) => {
      if (boxRef.current && !boxRef.current.contains(e.target as Node)) setOpen(false);
    };
    document.addEventListener('mousedown', h);
    return () => document.removeEventListener('mousedown', h);
  }, []);

  const search = (q: string) => {
    setQuery(q);
    if (debounce.current) clearTimeout(debounce.current);
    if (q.trim().length < 2) {
      setPreds([]);
      setOpen(false);
      return;
    }
    setLoading(true);
    debounce.current = setTimeout(async () => {
      try {
        const res: any = await adminApi.placesAutocomplete(q.trim());
        const raw: Prediction[] = res?.data?.predictions || [];
        // Many predictions collapse to the same city ("Rajkot Airport", "Rajkot
        // Railway Station") — dedupe on the city name, like the app does.
        const seen = new Set<string>();
        setPreds(
          raw.filter((p) => {
            const key = (p.main || '').toLowerCase();
            if (!key || seen.has(key)) return false;
            seen.add(key);
            return true;
          }),
        );
        setOpen(true);
      } catch {
        setPreds([]);
      } finally {
        setLoading(false);
      }
    }, 300);
  };

  const add = (city: string) => {
    const name = city.trim();
    if (name && !selected.some((c) => c.toLowerCase() === name.toLowerCase())) {
      onChange([...selected, name]);
    }
    setQuery('');
    setPreds([]);
    setOpen(false);
  };

  const remove = (city: string) => onChange(selected.filter((c) => c !== city));

  return (
    <div ref={boxRef} className="relative">
      <div className="flex items-center border border-gray-200 dark:border-gray-700 dark:bg-gray-800 rounded-lg px-3">
        <MapPin className="w-4 h-4 text-gray-400 shrink-0" />
        <input
          value={query}
          onChange={(e) => search(e.target.value)}
          onFocus={() => preds.length && setOpen(true)}
          onKeyDown={(e) => {
            // Enter picks the top suggestion; Backspace on an empty box drops the last chip.
            if (e.key === 'Enter') {
              e.preventDefault();
              if (preds[0]) add(preds[0].main);
            } else if (e.key === 'Backspace' && !query && selected.length) {
              remove(selected[selected.length - 1]);
            }
          }}
          placeholder={placeholder || 'Type a city, e.g. Raj…'}
          className="w-full bg-transparent px-2 py-2 text-sm outline-none dark:text-white"
        />
        {loading && <div className="w-4 h-4 border-2 border-gray-300 border-t-orange-500 rounded-full animate-spin" />}
      </div>

      {open && preds.length > 0 && (
        <div className="absolute z-20 mt-1 w-full max-h-60 overflow-y-auto bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-700 rounded-lg shadow-lg">
          {preds.map((p) => (
            <button
              key={p.placeId}
              type="button"
              onClick={() => add(p.main)}
              className="w-full text-left px-3 py-2 hover:bg-gray-50 dark:hover:bg-gray-800 border-b border-gray-100 dark:border-gray-800 last:border-0"
            >
              <p className="text-sm font-medium text-gray-800 dark:text-gray-100">{p.main}</p>
              {p.secondary && <p className="text-xs text-gray-500">{p.secondary}</p>}
            </button>
          ))}
        </div>
      )}

      {selected.length > 0 && (
        <div className="flex flex-wrap gap-2 mt-2">
          {selected.map((city) => (
            <span
              key={city}
              className="inline-flex items-center gap-1 pl-3 pr-2 py-1 rounded-full text-sm bg-brand-50 text-brand-700 border border-brand-200 dark:bg-brand-500/10 dark:text-brand-300 dark:border-brand-500/30"
            >
              {city}
              <button type="button" onClick={() => remove(city)} aria-label={`Remove ${city}`} className="hover:text-brand-900 dark:hover:text-white">
                <X className="w-3.5 h-3.5" />
              </button>
            </span>
          ))}
        </div>
      )}
    </div>
  );
}
