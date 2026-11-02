'use client';

/**
 * Wraps every page. Next re-renders a `template` on each navigation (unlike a
 * layout, which persists), so this is the cheapest place to put a transition:
 * one CSS class, no router events to subscribe to and nothing to clean up.
 *
 * Deliberately short — 280ms. A page transition is a cost paid on every click,
 * and a long one on a site whose job is to take a booking is just a delay with
 * a flourish on it.
 */
export default function Template({ children }: { children: React.ReactNode }) {
  return <div className="page-in">{children}</div>;
}
