'use client';

import type { SelectedCab, TripDraft } from './types';

/**
 * The in-progress booking, carried across the search -> results -> confirm
 * pages.
 *
 * The mobile app passes this map through GoRouter's `extra`, which dies on a
 * reload. A browser tab can be refreshed (or the Razorpay redirect can bounce
 * the customer back) halfway through, so the website parks it in sessionStorage
 * instead: it survives a reload, is scoped to the tab, and is gone when the tab
 * closes so a stale trip never resurfaces days later.
 */
const TRIP_KEY = 'gora_trip_draft';
const CAB_KEY = 'gora_selected_cab';

function read<T>(key: string): T | null {
  if (typeof window === 'undefined') return null;
  try {
    const raw = window.sessionStorage.getItem(key);
    return raw ? (JSON.parse(raw) as T) : null;
  } catch {
    return null;
  }
}

function write(key: string, value: unknown) {
  if (typeof window === 'undefined') return;
  try {
    window.sessionStorage.setItem(key, JSON.stringify(value));
  } catch {
    /* storage blocked — the flow still works within one page load */
  }
}

export const tripDraft = {
  get: () => read<TripDraft>(TRIP_KEY),
  set: (t: TripDraft) => write(TRIP_KEY, t),
  clear: () => {
    try {
      window.sessionStorage.removeItem(TRIP_KEY);
      window.sessionStorage.removeItem(CAB_KEY);
    } catch {
      /* ignore */
    }
  },
};

export const selectedCab = {
  get: () => read<SelectedCab>(CAB_KEY),
  set: (c: SelectedCab) => write(CAB_KEY, c),
};
