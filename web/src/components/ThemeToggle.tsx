'use client';

import { useEffect, useState } from 'react';
import { Moon, Sun } from 'lucide-react';

export const THEME_KEY = 'gora-theme';

/**
 * Light / dark switch.
 *
 * The attribute on `<html>` is always an explicit `light` or `dark` — the
 * script in layout.tsx resolves the system preference to one of the two before
 * the first paint. That matters twice over: the page never flashes the wrong
 * theme, and because the attribute is never absent, Tailwind's `dark:` variant
 * is reliable enough to swap the two icons in pure CSS.
 *
 * Which is why the icons are NOT chosen in JavaScript. The server has no idea
 * what the visitor's OS prefers, so rendering the right one here would either
 * mismatch on hydration or need a blank first paint. CSS knows, immediately.
 */
export function ThemeToggle({ className = '' }: { className?: string }) {
  // Only to stop a click before hydration doing nothing silently; the rendered
  // output is identical either way, so there is nothing to mismatch.
  const [ready, setReady] = useState(false);
  useEffect(() => setReady(true), []);

  // Someone who has never chosen follows their OS, including when they change
  // it with the tab open. Once they choose, their choice sticks.
  useEffect(() => {
    const mq = window.matchMedia('(prefers-color-scheme: dark)');
    const onSystem = () => {
      try {
        if (localStorage.getItem(THEME_KEY)) return;
      } catch {
        // Private mode can throw on read — fall through and follow the OS.
      }
      document.documentElement.dataset.theme = mq.matches ? 'dark' : 'light';
    };
    mq.addEventListener('change', onSystem);
    return () => mq.removeEventListener('change', onSystem);
  }, []);

  const toggle = () => {
    const root = document.documentElement;
    const next = root.dataset.theme === 'dark' ? 'light' : 'dark';
    root.dataset.theme = next;
    try {
      localStorage.setItem(THEME_KEY, next);
    } catch {
      // Storage blocked — the switch still works for this page view.
    }
  };

  return (
    <button
      type="button"
      onClick={ready ? toggle : undefined}
      aria-label="Switch between light and dark"
      title="Switch between light and dark"
      className={`group relative grid h-10 w-10 shrink-0 place-items-center overflow-hidden rounded-xl
                  border border-hairline bg-surface text-muted transition
                  hover:border-brand-400 hover:text-brand-500 ${className}`}
    >
      {/* A wash that blooms out of the corner on hover. */}
      <span
        aria-hidden
        className="absolute inset-0 scale-0 rounded-xl bg-brand-500/10 transition-transform duration-300 group-hover:scale-100"
      />
      {/* Both icons are always in the DOM; CSS shows one. They cross-fade and
          rotate past each other, so the switch reads as one object turning. */}
      <Sun
        className="absolute h-[18px] w-[18px] rotate-0 scale-100 opacity-100 transition-all duration-300
                   dark:-rotate-90 dark:scale-0 dark:opacity-0"
      />
      <Moon
        className="absolute h-[18px] w-[18px] rotate-90 scale-0 opacity-0 transition-all duration-300
                   dark:rotate-0 dark:scale-100 dark:opacity-100"
      />
    </button>
  );
}
