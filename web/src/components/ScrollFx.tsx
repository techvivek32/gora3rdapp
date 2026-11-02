'use client';

import { useEffect } from 'react';

/**
 * Two page-wide effects, from one component mounted once in the layout.
 *
 * 1. Reveal on scroll. Anything with `data-reveal` starts just below its
 *    resting place and rises into it when it first enters the viewport.
 * 2. A progress bar across the top of the header.
 *
 * One IntersectionObserver for the whole document rather than a wrapper
 * component per element: the observer is the expensive part, and a page like
 * the home screen has thirty or more of these.
 *
 * Elements are unobserved the moment they have appeared. A reveal that
 * re-triggered on the way back up would mean content fading out from under
 * someone who is simply scrolling, which is irritating rather than lively.
 */
export function ScrollFx() {
  useEffect(() => {
    // Same reasoning as CountUp: a missing API must not cost the page. And
    // without IntersectionObserver every reveal target would stay at opacity
    // 0 for ever, so that case is treated exactly like reduced motion — show
    // everything, animate nothing.
    let reduced = false;
    try {
      reduced = window.matchMedia?.('(prefers-reduced-motion: reduce)').matches ?? false;
    } catch {
      reduced = false;
    }
    if (typeof IntersectionObserver === 'undefined') reduced = true;

    // ── Reveal on scroll ────────────────────────────────────────────────
    const targets = () => [...document.querySelectorAll<HTMLElement>('[data-reveal]:not(.is-in)')];

    if (reduced) {
      // Show everything at once. Without this the page would be a column of
      // invisible blocks for anyone who turned animation off.
      targets().forEach((el) => el.classList.add('is-in'));
    }

    const io = reduced
      ? null
      : new IntersectionObserver(
          (entries) => {
            for (const e of entries) {
              if (!e.isIntersecting) continue;
              e.target.classList.add('is-in');
              io?.unobserve(e.target);
            }
          },
          // A little before the element is actually on screen, so it has
          // finished arriving by the time it is properly in view.
          { rootMargin: '0px 0px -8% 0px', threshold: 0.05 },
        );

    const observe = () => io && targets().forEach((el) => io.observe(el));
    observe();

    // Content that arrives later — the admin showcases load over the network —
    // has to be picked up too.
    const mo = new MutationObserver(() => (reduced
      ? targets().forEach((el) => el.classList.add('is-in'))
      : observe()));
    mo.observe(document.body, { childList: true, subtree: true });

    // ── Progress bar ────────────────────────────────────────────────────
    const bar = document.getElementById('gora-progress');
    let frame = 0;
    const onScroll = () => {
      if (frame) return; // one write per frame, no matter how fast the wheel
      frame = requestAnimationFrame(() => {
        frame = 0;
        if (!bar) return;
        const doc = document.documentElement;
        const max = doc.scrollHeight - doc.clientHeight;
        const pct = max > 0 ? Math.min(1, doc.scrollTop / max) : 0;
        bar.style.transform = `scaleX(${pct})`;
      });
    };
    onScroll();
    window.addEventListener('scroll', onScroll, { passive: true });
    window.addEventListener('resize', onScroll, { passive: true });

    return () => {
      io?.disconnect();
      mo.disconnect();
      window.removeEventListener('scroll', onScroll);
      window.removeEventListener('resize', onScroll);
      if (frame) cancelAnimationFrame(frame);
    };
  }, []);

  return null;
}
