'use client';

import { useQuery } from '@tanstack/react-query';
import { apiGet } from './api';
import { COMPANY } from './company';

/**
 * Website copy the operator edits in the admin panel.
 *
 * The defaults below are the same list the backend carries
 * (modules/site-content/site-text.keys.ts). Repeated here on purpose: a page
 * must render correctly on the first paint, before the request returns, and
 * must keep rendering if the request fails. A hook that can hand back an
 * empty string is a hook that can ship a blank heading.
 *
 * Adding an editable string is one entry here and one in the backend's list.
 */
export const SITE_TEXT: Record<string, string> = {
  // Who the site belongs to. The values live in company.ts so the website has
  // one place to read them from; the backend carries the same defaults for the
  // admin form.
  'company.brand': COMPANY.brand,
  'company.tagline': COMPANY.tagline,
  'company.legalName': COMPANY.legalName,
  'company.address': COMPANY.address,
  'company.city': COMPANY.city,
  'company.gstin': COMPANY.gstin,
  'company.appName': COMPANY.appName,
  'company.playStoreUrl': COMPANY.playStoreUrl,

  'contact.eyebrow': 'Talk to us',
  'contact.title': `Contact ${COMPANY.brand}`,
  'contact.subtitle':
    'Someone is on the phone 24\u00d77. Call before you book if you want a quote checked, or after you book if anything about the trip changes.',
  'contact.callNote': '24\u00d77, every day',
  'contact.whatsappLine': 'Message the team',
  'contact.whatsappNote': 'Send a trip and get it booked',
  'contact.emailNote': 'For bills and documents',
  'contact.appNote': 'Track the trip and keep your history',
  'contact.officeTitle': 'Registered office',
  'contact.bookedTitle': 'Already booked?',
  'contact.bookedBody': 'Keep the booking reference handy when you call.',

  'footer.blurb':
    'Outstation cabs, local packages, drivers for your own car, and shared rides across India.',

  'support.title': 'Help & Support',
  'support.subtitle': 'We are here 24×7. Reach us whichever way suits you.',
  'support.bookingTitle': 'About a booking you made here',
  'support.bookingBody':
    'Keep your booking reference handy when you call. To see the trip, track the driver or raise a complaint, open the Gora Taxi app with the same mobile number you booked with — the booking is already there.',
  'support.caution':
    'Caution: never make advance payments to an unknown person without a reference. Pay only through this website or the Gora Taxi app.',
  'support.cta': 'Book a cab',
  'footer.caution':
    'Caution: never make advance payments to an unknown person without a reference.',
  'footer.appNote':
    'Booked here? Open the Gora Taxi app with the same mobile number and your trip is already waiting for you.',
};

/**
 * `t('support.title')` — the operator's text if they set one, otherwise the
 * default above.
 *
 * An operator who clears a field means it: an empty caution banner hides the
 * banner. So the fallback applies to a key the server did not send, not to
 * one it sent as empty.
 */
export function useSiteText() {
  const { data } = useQuery({
    queryKey: ['site-text'],
    queryFn: () => apiGet<Record<string, string>>('/site-content'),
    staleTime: 5 * 60 * 1000,
    retry: 0,
  });

  return (key: string): string => {
    const v = data?.[key];
    return typeof v === 'string' ? v : (SITE_TEXT[key] ?? '');
  };
}
