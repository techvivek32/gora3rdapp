import type { Metadata } from 'next';

/** A receipt for a booking the crawler never made. Never worth indexing. */
export const metadata: Metadata = {
  title: 'Booking placed',
  robots: { index: false, follow: true },
};

export default function BookedLayout({ children }: { children: React.ReactNode }) {
  return children;
}
