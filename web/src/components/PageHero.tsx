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
 * It now opens the way the home page's sections do — a coloured pill over a
 * heavy heading on a pale wash — because that is the one shape repeated down
 * the whole site, and a page that opens differently from every section on the
 * landing page is a page that looks like it came from somewhere else.
 *
 * Left-aligned rather than centred, and that is deliberate: these pages carry
 * a form or a list directly underneath, and a centred heading over a
 * left-aligned form puts two axes on one screen.
 */
export function PageHero({
  eyebrow,
  title,
  lead,
  aside,
  children,
  width = '6xl',
  tone = 'blue',
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
  /** Which pill colour opens the page. */
  tone?: 'blue' | 'accent';
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
    <div className="relative overflow-hidden border-b border-hairline bg-bandcool">
      <div
        aria-hidden
        className="pointer-events-none absolute inset-0"
        style={{
          background:
            'radial-gradient(46% 60% at 6% 0%, rgba(249,115,22,0.09) 0%, transparent 62%),'
            + 'radial-gradient(50% 64% at 97% 10%, rgba(0,134,214,0.11) 0%, transparent 62%)',
        }}
      />

      <div className={`relative mx-auto ${MAX} px-4 pb-12 pt-10 sm:pt-12`}>
        <div className="flex flex-wrap items-end justify-between gap-x-6 gap-y-4">
          <div className="min-w-0 flex-1">
            {eyebrow && (
              <span
                className={`${tone === 'accent' ? 'eyebrow-accent' : 'eyebrow-blue'} reveal`}
                style={{ '--d': '40ms' } as React.CSSProperties}
              >
                {eyebrow}
              </span>
            )}
            <h1 className="display-section reveal mt-4" style={{ '--d': '110ms' } as React.CSSProperties}>
              {title}
            </h1>
            {lead && (
              <p
                className="reveal mt-4 max-w-xl text-[16px] leading-relaxed text-muted"
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
    </div>
  );
}
