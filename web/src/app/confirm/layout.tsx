import type { Metadata } from 'next';

/**
 * A step in a transaction, not an answer to a search.
 *
 * This page renders whatever trip is held in the visitor's own browser, so to
 * a crawler — which has no trip — it is an empty shell. Indexed, it would
 * compete with the pages that can actually answer a query and offer a searcher
 * a blank screen when they clicked.
 */
export const metadata: Metadata = {
  title: 'Review & confirm',
  robots: { index: false, follow: true },
};

export default function ConfirmLayout({ children }: { children: React.ReactNode }) {
  return children;
}
