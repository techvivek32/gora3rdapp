import { CarSide } from '@/components/CarSide';

/**
 * The Gora Taxi app, drawn.
 *
 * The hero used to be built on whatever photograph the operator had uploaded,
 * and the one in the database is a red sports car at night in a field — all
 * of the cost of a photograph and none of the benefit. A drawing of the
 * product cannot be uploaded badly: it is the same on every install, it is a
 * few kilobytes of markup, it is sharp on any screen, and it shows the thing
 * the page is actually selling rather than a stock car.
 *
 * Deliberately not a screenshot either. A screenshot goes stale the first
 * time the app's padding changes, and at this size nobody can read one.
 *
 * Nothing in here quotes a fare. The hero must not imply a price before the
 * route is known, and a mock-up is exactly where an invented number would
 * sneak in.
 */
/*
 * Nothing in here is set under 10px.
 *
 * It is tempting to shrink type inside a device drawing — it is only a
 * picture of an app, after all — but the browser does not know that. It is
 * real text, it is read out by a screen reader, it is zoomed by anyone who
 * zooms, and at 8px it is unreadable for exactly the people who most need to
 * read it. The mock-up is sized around the type rather than the other way
 * round.
 */
export function AppMock({ className = '' }: { className?: string }) {
  return (
    /*
     * The callouts stand BESIDE the device, not on top of it.
     *
     * Floated over the screen they covered the two things the mock-up exists
     * to show — the route and the cab — so the premium trick cost the
     * content it was decorating. A screen this size has no spare room to
     * float anything over.
     */
    <div className={`relative flex items-center gap-4 xl:gap-6 ${className}`}>
      <div className="hidden w-40 shrink-0 flex-col gap-4 lg:flex xl:w-44">
        <div className="rounded-2xl bg-surface px-3.5 py-3 shadow-card ring-1 ring-hairline">
          <p className="text-[10px] font-bold uppercase tracking-[0.16em] text-brandink">Driver assigned</p>
          <p className="mt-1 text-[11px] font-bold leading-snug text-ink">
            Name, car and number sent before pickup
          </p>
        </div>
        <div className="rounded-2xl bg-midnight px-3.5 py-3 shadow-2xl ring-1 ring-white/15">
          <p className="text-[10px] font-bold uppercase tracking-[0.16em] text-brand-400">Trip code</p>
          <p className="mt-1 text-[11px] font-bold leading-snug text-white">
            Verified at pickup and at drop
          </p>
        </div>
      </div>

      {/* The device. */}
      <div className="relative w-[15.5rem] shrink-0 rounded-[2.6rem] bg-midnight p-2.5 shadow-2xl ring-1 ring-black/20 xl:w-[17rem]">
        {/* The speaker bar, which is what makes a rounded rectangle read as
            a phone rather than as a card. */}
        <span
          aria-hidden
          className="absolute left-1/2 top-[0.9rem] z-10 h-1.5 w-16 -translate-x-1/2 rounded-full bg-white/25"
        />

        <div className="overflow-hidden rounded-[2.1rem] bg-canvas">
          <div className="px-4 pb-4 pt-7">
            {/* App bar */}
            <div className="flex items-center gap-2">
              <span className="grid h-7 w-7 place-items-center rounded-lg bg-brand-500 text-[11px] font-black text-white">
                G
              </span>
              <span className="font-display text-sm font-black tracking-[-0.01em] text-ink">
                Gora Taxi
              </span>
              <span className="ml-auto h-6 w-6 rounded-full bg-sunken" />
            </div>

            {/* The trip */}
            <div className="mt-4 rounded-2xl bg-surface p-3 shadow-card ring-1 ring-hairline">
              <p className="text-[10px] font-bold uppercase tracking-[0.18em] text-muted">Your trip</p>
              <div className="mt-2.5 flex gap-2.5">
                <span className="flex flex-col items-center pt-1">
                  <span className="h-2 w-2 rounded-full bg-brand-500" />
                  <span className="lane-y my-1 h-6" />
                  <span className="h-2 w-2 rounded-full border-2 border-ink" />
                </span>
                <span className="min-w-0 flex-1 space-y-2.5">
                  <span className="block truncate text-[11px] font-bold text-ink">Rajkot</span>
                  <span className="block truncate text-[11px] font-bold text-ink">Ahmedabad</span>
                </span>
              </div>
            </div>

            {/* The cab */}
            <div className="mt-2.5 flex items-center gap-3 rounded-2xl bg-surface p-3 shadow-card ring-1 ring-hairline">
              <CarSide className="h-7 w-16 shrink-0" />
              <span className="min-w-0">
                <span className="block text-[11px] font-extrabold text-ink">Sedan</span>
                <span className="block text-[10px] leading-snug text-muted">Full fare before you confirm</span>
              </span>
            </div>

            <div className="mt-3 rounded-xl bg-brand-500 py-2.5 text-center text-[11px] font-bold text-white">
              Book now
            </div>
          </div>
        </div>
      </div>

    </div>
  );
}
