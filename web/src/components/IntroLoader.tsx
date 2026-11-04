'use client';

import { useEffect, useState } from 'react';
import { CarSide } from './CarSide';

/**
 * The opening sequence: a car drives across and the wordmark is wiped in
 * behind it, as though the car painted the name on the road.
 *
 * This component only draws it and then tidies it away. Everything that
 * DECIDES — whether it plays, skipping on a tap, the timeout that ends it — is
 * the inline script in layout.tsx, because all of that has to work before
 * React has hydrated. See the note there.
 *
 * So the markup is always server-rendered, CSS hides it the instant
 * `data-intro="done"` appears, and this just watches for that attribute and
 * drops the node from the tree afterwards. Nothing here is load-bearing: with
 * JavaScript switched off entirely the overlay still animates and still
 * leaves, which is tested.
 *
 * It is an overlay, never a gate. The page is complete underneath from the
 * first frame — nothing waits on it, and a crawler never sees it.
 */
export function IntroLoader() {
  const [gone, setGone] = useState(false);

  useEffect(() => {
    const root = document.documentElement;
    if (root.dataset.intro === 'done') {
      setGone(true);
      return;
    }
    // The attribute is set by the script in the head, which may be a tap or a
    // timeout away. Watching it is cheaper and more exact than a second timer
    // that could disagree with the first.
    const mo = new MutationObserver(() => {
      if (root.dataset.intro === 'done') {
        setGone(true);
        mo.disconnect();
      }
    });
    mo.observe(root, { attributes: true, attributeFilter: ['data-intro'] });
    return () => mo.disconnect();
  }, []);

  if (gone) return null;

  return (
    // Decoration over a page that has already rendered, so it is hidden from
    // assistive tech rather than announced as a loading state.
    <div className="intro" aria-hidden role="presentation">
      <div className="intro-stage">
        <svg className="intro-word" viewBox="0 0 680 108" fill="none">
          <text
            x="340"
            y="78"
            textAnchor="middle"
            fontFamily="var(--font-display), system-ui, sans-serif"
            fontSize="86"
            // Bricolage stops at 800. Asking for 900 gets a synthesised
            // weight, which on a 86px wordmark is visibly smeared.
            fontWeight="800"
            letterSpacing="-2"
            fill="#ffffff"
          >
            GORA{' '}
            <tspan fill="#f97316">TAXI</tspan>
          </text>
        </svg>

        <p className="intro-tagline">India Ka Apna App</p>

        <span className="intro-road" />

        {/* Travels with the car and trails behind it. */}
        <span className="intro-streaks" aria-hidden>
          <i style={{ bottom: '4px', width: '34px', animationDelay: '0s' }} />
          <i style={{ bottom: '11px', width: '52px', animationDelay: '0.12s' }} />
          <i style={{ bottom: '18px', width: '26px', animationDelay: '0.24s' }} />
        </span>

        <span className="intro-car">
          <CarSide className="intro-car-body" />
        </span>
      </div>
    </div>
  );
}
