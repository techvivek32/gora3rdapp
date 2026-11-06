import type { ReactNode } from 'react';

/**
 * The band every page that is not the home page opens with.
 *
 * Before this each one started differently: the booking page had a warm wash
 * and a trust row, Car Pool and Help had no band at all — a heading sitting
 * straight on the canvas, two sizes smaller than anything on the landing
 * page. Three pages, three openings, which is what makes a site read as a
 * template with the pages filled in separately.
 *
 * The vocabulary is the landing page's: the same backdrop, the same grain,
 * the same chapter label over a heavy heading, and the dashed lane closing
 * the band off. One component, so it stays that way.
 */
export function PageHero({
  eyebrow,
  title,
  lead,
  aside,
  children,
  width = '6xl',
}: {
  eyebrow?: ReactNode;
  title: ReactNode;
  lead?: ReactNode;
  /** Pinned to the right of the heading on a wide screen — a link, a button. */
  aside?: ReactNode;
  /** Under the lead, full width: a trust row, a set of chips. */
  children?: ReactNode;
  /** Match the page's own container, or the band's content sits off its axis. */
  width?: '2xl' | '3xl' | '4xl' | '6xl';
}) {
  // Spelled out rather than built from a template string: Tailwind only
  // emits a class it has seen, and `max-w-${width}` is not one it can see.
  const MAX = {
    '2xl': 'max-w-2xl',
    '3xl': 'max-w-3xl',
    '4xl': 'max-w-4xl',
    '6xl': 'max-w-6xl',
  }[width];

  return (
    <div className="hero-band relative overflow-hidden border-b border-hairline">
      <div aria-hidden className="noise pointer-events-none absolute inset-0" />

      <div className={`relative mx-auto ${MAX} px-4 pb-12 pt-12 sm:pt-14`}>
        <div className="flex flex-wrap items-end justify-between gap-x-6 gap-y-4">
          <div className="min-w-0 flex-1">
            {eyebrow && (
              <p className="eyebrow reveal text-brandink" style={{ '--d': '40ms' } as React.CSSProperties}>
                {eyebrow}
              </p>
            )}
            <h1 className="display-section reveal mt-3" style={{ '--d': '110ms' } as React.CSSProperties}>
              {title}
            </h1>
            {lead && (
              <p
                className="reveal mt-4 max-w-xl text-[15px] leading-relaxed text-muted"
                style={{ '--d': '180ms' } as React.CSSProperties}
              >
                {lead}
              </p>
            )}
          </div>
          {aside && (
            <div className="reveal shrink-0" style={{ '--d': '240ms' } as React.CSSProperties}>
              {aside}
            </div>
          )}
        </div>
        {children && (
          <div className="reveal mt-7" style={{ '--d': '250ms' } as React.CSSProperties}>
            {children}
          </div>
        )}
      </div>

      <span aria-hidden className="lane-x absolute inset-x-0 bottom-0 block" />
    </div>
  );
}
