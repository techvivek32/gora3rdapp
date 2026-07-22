'use client';

import { useRef, useState } from 'react';
import { adminApi } from '@/lib/api';
import { MapPin } from 'lucide-react';

interface Pred {
  city: string; // "Rajkot"
  region: string; // "Gujarat, India"
}

/**
 * City field backed by the same Google Places proxy the app's register page uses
 * (`GET /places/cities`). Typing "raj" suggests "Rajkot, Gujarat". `onChange` fires
 * on every keystroke (state = null) and again on selection (state resolved from the
 * prediction's region).
 */
export function CityAutocomplete({
  value,
  onChange,
  inputCls,
  placeholder,
}: {
  value: string;
  onChange: (city: string, state: string | null) => void;
  inputCls: string;
  placeholder?: string;
}) {
  const [results, setResults] = useState<Pred[]>([]);
  const [open, setOpen] = useState(false);
  const [loading, setLoading] = useState(false);
  const debounce = useRef<ReturnType<typeof setTimeout> | null>(null);
  const justSelected = useRef(false);

  const search = async (q: string) => {
    try {
      setLoading(true);
      const res: any = await adminApi.getCitySuggestions(q);
      const preds: any[] = res?.data?.predictions ?? [];
      const seen = new Set<string>();
      const out: Pred[] = [];
      for (const p of preds) {
        const city = String(p.main ?? p.description ?? '').trim();
        const region = String(p.secondary ?? '').trim();
        if (!city || seen.has(city)) continue;
        seen.add(city);
        out.push({ city, region });
      }
      setResults(out);
      setOpen(out.length > 0);
    } catch {
      setResults([]);
      setOpen(false);
    } finally {
      setLoading(false);
    }
  };

  const handleChange = (q: string) => {
    onChange(q, null); // free text until a suggestion is picked
    if (justSelected.current) {
      justSelected.current = false;
      return;
    }
    if (debounce.current) clearTimeout(debounce.current);
    if (q.trim().length < 2) {
      setResults([]);
      setOpen(false);
      return;
    }
    debounce.current = setTimeout(() => search(q.trim()), 300);
  };

  // "Gujarat, India" → "Gujarat"; null when only the country is present.
  const stateFrom = (region: string): string | null => {
    const parts = region.split(',').map((s) => s.trim()).filter(Boolean);
    if (!parts.length) return null;
    const first = parts[0];
    return first.toLowerCase() === 'india' ? null : first;
  };

  const select = (p: Pred) => {
    justSelected.current = true;
    onChange(p.city, stateFrom(p.region));
    setResults([]);
    setOpen(false);
  };

  return (
    <div className="relative">
      <input
        className={inputCls}
        value={value}
        placeholder={placeholder}
        autoComplete="off"
        onChange={(e) => handleChange(e.target.value)}
        onFocus={() => { if (results.length) setOpen(true); }}
        // Delay close so a suggestion click registers before blur hides the list.
        onBlur={() => setTimeout(() => setOpen(false), 150)}
      />
      {loading && (
        <div className="absolute right-3 top-1/2 -translate-y-1/2 w-3.5 h-3.5 border-2 border-orange-500 border-t-transparent rounded-full animate-spin" />
      )}
      {open && results.length > 0 && (
        <div className="absolute z-30 mt-1 w-full max-h-56 overflow-y-auto bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-lg shadow-lg">
          {results.map((r, i) => (
            <button
              key={i}
              type="button"
              // onMouseDown (not onClick) so it fires before the input's onBlur.
              onMouseDown={(e) => { e.preventDefault(); select(r); }}
              className="w-full flex items-center gap-2 px-3 py-2 text-left text-sm hover:bg-gray-50 dark:hover:bg-gray-700"
            >
              <MapPin className="w-4 h-4 text-orange-500 shrink-0" />
              <span className="font-medium text-gray-900 dark:text-white">{r.city}</span>
              {r.region && <span className="text-xs text-gray-500 truncate">· {r.region}</span>}
            </button>
          ))}
        </div>
      )}
    </div>
  );
}
