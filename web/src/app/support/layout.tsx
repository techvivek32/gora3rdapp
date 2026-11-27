import type { Metadata } from 'next';
import { abs, clampDescription } from '@/lib/seo';

export const metadata: Metadata = {
  title: 'Help & Support — Contact Gora Taxi',
  description: clampDescription(
    'Reach Gora Taxi about a booking, a fare or a driver. Phone, WhatsApp and email support, with answers to the questions we are asked most.',
  ),
  alternates: { canonical: abs('/support') },
  openGraph: {
    type: 'website',
    url: abs('/support'),
    title: 'Help & Support — Contact Gora Taxi',
    description: 'Reach Gora Taxi about a booking, a fare or a driver.',
  },
};

export default function SupportLayout({ children }: { children: React.ReactNode }) {
  return children;
}
