import type { Metadata } from 'next';
import { abs, clampDescription } from '@/lib/seo';

export const metadata: Metadata = {
  title: 'Car Pool — Share a Ride and Split the Fare',
  description: clampDescription(
    'Find a shared ride on your route and split the cost, or post seats in your own car. Verified members, seat-wise pricing, pay the driver directly.',
  ),
  alternates: { canonical: abs('/pool') },
  openGraph: {
    type: 'website',
    url: abs('/pool'),
    title: 'Car Pool — Share a Ride and Split the Fare',
    description: 'Find a shared ride on your route and split the cost, or post seats in your own car.',
  },
};

export default function PoolLayout({ children }: { children: React.ReactNode }) {
  return children;
}
