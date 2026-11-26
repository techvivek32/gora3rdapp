'use client';

import { X } from 'lucide-react';

/**
 * The ✕ that empties a text field in one tap.
 *
 * Positioned absolutely inside a `relative` wrapper, so the field it sits in
 * needs right padding (`pr-9`) to keep the text from running underneath it.
 * Shared so every field clears the same way — `PlaceInput` has had one for a
 * while and the rest of the form did not, which made the others feel broken by
 * comparison.
 */
export function ClearButton({
  onClick,
  label,
  className = '',
}: {
  onClick: () => void;
  /** Named for screen readers, e.g. "Clear your name". */
  label: string;
  className?: string;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      aria-label={label}
      title={label}
      className={`absolute right-2.5 top-1/2 -translate-y-1/2 rounded-full p-1 text-muted transition hover:bg-sunken hover:text-ink ${className}`}
    >
      <X className="h-4 w-4" />
    </button>
  );
}
