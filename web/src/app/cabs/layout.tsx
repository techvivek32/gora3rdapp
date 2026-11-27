import type { Metadata } from 'next';

/**
 * Applies to `/cabs` AND to `/cabs/[route]` — Next inherits metadata down the
 * segment — so the `noindex` here is overridden explicitly in the route page.
 *
 * `/cabs` itself is the fare-results screen. It prices whatever trip is held
 * in the visitor's browser, so a crawler arriving cold sees an empty result
 * with no route and no price. The pages that answer an intercity search are
 * the `/cabs/<from>-to-<to>` ones below it, and those set `index: true`.
 */
export const metadata: Metadata = {
  // A bare string here would REPLACE the root template for this segment and
  // everything under it, and the route pages below would lose the brand from
  // their titles. Re-declaring the template keeps "… | Gora Taxi" on them
  // while this page still gets its own plain title.
  title: { default: 'Choose your cab', template: '%s | Gora Taxi' },
  robots: { index: false, follow: true },
};

export default function CabsLayout({ children }: { children: React.ReactNode }) {
  return children;
}
