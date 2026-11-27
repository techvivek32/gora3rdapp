import type { Metadata } from 'next';

/**
 * The booking form. `follow: true` so the links out of it still pass on, but
 * the form itself is a step in a transaction and has nothing to rank for that
 * the route and city pages do not say better.
 */
export const metadata: Metadata = {
  title: 'Book a cab',
  robots: { index: false, follow: true },
};

export default function BookLayout({ children }: { children: React.ReactNode }) {
  return children;
}
