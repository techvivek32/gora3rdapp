/**
 * A photograph, or a drawn panel standing in for one.
 *
 * The site is built around the operator's own pictures, and the operator may
 * have uploaded none. A missing `src` used to mean a grey box with a word in
 * it, which looks like a bug; here it means a generated poster — a wash in a
 * colour derived from the title, the lane pattern over it, and a vignette.
 * Two destinations never come out the same colour, and the same destination
 * is the same colour on every visit, because the hue is a hash of the name
 * rather than a random number or a position in a list.
 *
 * A broken URL ends in the same place: `onError` drops the image and the
 * poster that was already underneath it shows through. Nothing on this page
 * can render as an empty frame.
 */
'use client';

import { useState } from 'react';

/**
 * A stable hue from a string.
 *
 * Picked from a short list rather than anywhere on the wheel. A free hash
 * over 360 degrees put half the panels in grass green and lime next to an
 * orange brand and a near-black page; these six are the warm and deep ends of
 * the same family, so a grid of them reads as one set whatever the titles
 * happen to be.
 */
const TONES = [20, 34, 350, 6, 318, 268];

function hueOf(seed: string): number {
  let h = 0;
  for (let i = 0; i < seed.length; i++) h = (h * 31 + seed.charCodeAt(i)) % 9973;
  return TONES[h % TONES.length];
}

export function Poster({
  src,
  alt = '',
  seed,
  hue,
  className = '',
  imgClassName = '',
  children,
}: {
  src?: string;
  alt?: string;
  /** What the hue is derived from — the title, usually. */
  seed: string;
  /** Overrides the hash, for the one or two places that must land on brand. */
  hue?: number;
  /**
   * The frame: give it the height and the rounding.
   *
   * Size it, do not position it. `.poster` sets `position: relative` for its
   * own stand-in texture and that wins over an `absolute` utility passed in
   * here, which collapses the panel to nothing. To float one, wrap it in a
   * positioned element and pass `h-full w-full`.
   */
  className?: string;
  imgClassName?: string;
  /** Laid over the picture. Put the scrim in here, above this element. */
  children?: React.ReactNode;
}) {
  const [broken, setBroken] = useState(false);
  const show = src && !broken;

  return (
    <div
      className={`poster relative overflow-hidden ${show ? 'has-photo' : ''} ${className}`}
      style={{ ['--h' as string]: String(hue ?? hueOf(seed || 'gora')) }}
    >
      {show && (
        /* eslint-disable-next-line @next/next/no-img-element */
        <img
          src={src}
          alt={alt}
          loading="lazy"
          onError={() => setBroken(true)}
          className={`absolute inset-0 h-full w-full object-cover ${imgClassName}`}
        />
      )}
      {children}
    </div>
  );
}
