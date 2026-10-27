'use client';

import { useEffect, useRef, useState } from 'react';
import { Loader2, MapPin, X } from 'lucide-react';
import { apiGet } from '@/lib/api';
import type { Geo } from '@/lib/types';

interface Prediction {
  placeId: string;
  description: string;
  main: string;
  secondary: string;
}

/**
 * Google Places picker, same contract the app uses: `/places/autocomplete` for
 * suggestions, then `/places/details` to turn the chosen prediction into
 * address + lat/lng + city.
 *
 * The coordinates matter more than the text: the whole fare depends on the road
 * distance from `/places/route`, which needs lat/lng. So a typed string that was
 * never resolved is NOT treated as a valid place — the caller checks for `lat`.
 */
export function PlaceInput({
  label,
  value,
  onChange,
  placeholder = 'Search a city or address',
  cityOnly = false,
  required = false,
}: {
  label: string;
  value?: Geo;
  onChange: (geo: Geo | undefined) => void;
  placeholder?: string;
  /** Restrict to city-level predictions (used for Car Pool from/to). */
  cityOnly?: boolean;
  required?: boolean;
}) {
  const [text, setText] = useState(value?.address ?? '');
  const [items, setItems] = useState<Prediction[]>([]);
  const [open, setOpen] = useState(false);
  const [busy, setBusy] = useState(false);
  const boxRef = useRef<HTMLDivElement>(null);

  // Keep the field in step when the parent replaces the value (e.g. swap, reset).
  useEffect(() => {
    setText(value?.address ?? '');
  }, [value?.address]);

  // Close on an outside click so the list never sits over the next field.
  useEffect(() => {
    const onDoc = (e: MouseEvent) => {
      if (boxRef.current && !boxRef.current.contains(e.target as Node)) setOpen(false);
    };
    document.addEventListener('mousedown', onDoc);
    return () => document.removeEventListener('mousedown', onDoc);
  }, []);

  // Debounced lookup — Google bills per call, so don't fire on every keystroke.
  useEffect(() => {
    const q = text.trim();
    if (q.length < 3 || q === value?.address) {
      setItems([]);
      return;
    }
    let cancelled = false;
    const t = setTimeout(async () => {
      setBusy(true);
      try {
        const data = await apiGet<{ predictions: Prediction[] }>(
          cityOnly ? '/places/cities' : '/places/autocomplete',
          { input: q },
        );
        if (!cancelled) {
          setItems(data?.predictions ?? []);
          setOpen(true);
        }
      } catch {
        if (!cancelled) setItems([]);
      } finally {
        if (!cancelled) setBusy(false);
      }
    }, 350);
    return () => {
      cancelled = true;
      clearTimeout(t);
    };
  }, [text, cityOnly, value?.address]);

  const pick = async (p: Prediction) => {
    setOpen(false);
    setText(p.description);
    setBusy(true);
    try {
      const d = await apiGet<{ address: string; lat: number; lng: number; city: string }>('/places/details', {
        placeId: p.placeId,
      });
      onChange({ address: d.address || p.description, lat: d.lat, lng: d.lng, city: d.city });
    } catch {
      // Details failed — keep the text so the customer sees their choice, but
      // without coordinates the caller will still ask them to pick again.
      onChange({ address: p.description });
    } finally {
      setBusy(false);
    }
  };

  const clear = () => {
    setText('');
    setItems([]);
    onChange(undefined);
  };

  return (
    <div ref={boxRef} className="relative">
      <label className="label">
        {label} {required && <span className="text-brand-600">*</span>}
      </label>
      <div className="relative">
        <MapPin className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted" />
        <input
          className="field pl-9 pr-9"
          value={text}
          placeholder={placeholder}
          onChange={(e) => {
            setText(e.target.value);
            // Typing invalidates a previously resolved place — its coordinates
            // no longer describe what's in the box.
            if (value) onChange(undefined);
          }}
          onFocus={() => items.length > 0 && setOpen(true)}
          autoComplete="off"
        />
        {busy ? (
          <Loader2 className="absolute right-3 top-1/2 h-4 w-4 -translate-y-1/2 animate-spin text-brand-500" />
        ) : text ? (
          <button
            type="button"
            onClick={clear}
            className="absolute right-2.5 top-1/2 -translate-y-1/2 rounded-full p-1 text-muted hover:bg-gray-100"
            aria-label={`Clear ${label}`}
          >
            <X className="h-4 w-4" />
          </button>
        ) : null}
      </div>

      {open && items.length > 0 && (
        <ul className="absolute z-30 mt-1 max-h-72 w-full overflow-auto rounded-xl border border-hairline bg-white py-1 shadow-card">
          {items.map((p) => (
            <li key={p.placeId}>
              <button
                type="button"
                onClick={() => pick(p)}
                className="flex w-full items-start gap-2.5 px-3 py-2.5 text-left hover:bg-brand-50"
              >
                <MapPin className="mt-0.5 h-4 w-4 shrink-0 text-brand-500" />
                <span className="min-w-0">
                  <span className="block truncate text-sm font-semibold text-ink">{p.main}</span>
                  {p.secondary && <span className="block truncate text-xs text-muted">{p.secondary}</span>}
                </span>
              </button>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
