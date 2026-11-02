'use client';

import { useEffect, useRef, useState } from 'react';

/**
 * Counts a number up to its value when it first scrolls into view.
 *
 * Used for fares, which is why it is careful about two things. It always lands
 * EXACTLY on the target — an eased counter that stops at 13,598 because the
 * last frame never ran would be showing the customer a wrong price. And it
 * only ever animates upward to a settled figure; if the value changes (the
 * Best Price toggle, a different cab), it jumps rather than rolling, because
 * rolling between two real prices reads as the price changing by itself.
 */
export function CountUp({
  value,
  duration = 700,
  format = (n: number) => n.toLocaleString('en-IN'),
  className = '',
}: {
  value: number;
  duration?: number;
  format?: (n: number) => string;
  className?: string;
}) {
  const ref = useRef<HTMLSpanElement>(null);
  const [shown, setShown] = useState(value);
  const done = useRef(false);

  useEffect(() => {
    // Second and later values: no roll. See above.
    if (done.current) {
      setShown(value);
      return;
    }
    const el = ref.current;
    if (!el) return;

    // Guarded, not assumed. A throw inside this effect happens during
    // commit, which takes the entire page down with it — and this one renders
    // on /cabs, where the booking is made. An old browser or a stripped-down
    // webview should lose the count-up, nothing else.
    const stillPreferred = (() => {
      try {
        return window.matchMedia?.('(prefers-reduced-motion: reduce)').matches ?? false;
      } catch {
        return false;
      }
    })();
    if (stillPreferred || typeof IntersectionObserver === 'undefined') {
      done.current = true;
      setShown(value);
      return;
    }

    const run = () => {
      done.current = true;
      const from = 0;
      const start = performance.now();
      let raf = 0;
      const tick = (now: number) => {
        const t = Math.min(1, (now - start) / duration);
        // easeOutCubic
        const eased = 1 - Math.pow(1 - t, 3);
        setShown(Math.round(from + (value - from) * eased));
        if (t < 1) raf = requestAnimationFrame(tick);
        else setShown(value); // land on the real figure, never near it
      };
      raf = requestAnimationFrame(tick);
      return () => cancelAnimationFrame(raf);
    };

    const io = new IntersectionObserver(
      (entries) => {
        if (entries.some((e) => e.isIntersecting)) {
          io.disconnect();
          run();
        }
      },
      { threshold: 0.2 },
    );
    io.observe(el);
    return () => io.disconnect();
  }, [value, duration]);

  return (
    <span ref={ref} className={className}>
      {format(shown)}
    </span>
  );
}
