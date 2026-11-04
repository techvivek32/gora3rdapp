/**
 * The pieces of website copy an operator can edit.
 *
 * A FIXED list, not an open key/value store. Two reasons: the admin panel can
 * render a labelled form instead of asking someone to type a key correctly,
 * and a typo in a key cannot silently create a row that nothing ever reads.
 * Adding a new editable string is one entry here plus one call site.
 *
 * `fallback` is the copy the site ships with. It is the single source of that
 * default — the website carries the same list (web/src/lib/site-text.ts) so a
 * page still reads correctly before this request returns, or if it fails.
 */
export interface SiteTextKey {
  key: string;
  /** Which screen it belongs to, for grouping in the admin form. */
  group: string;
  label: string;
  /** What it is for, shown under the field. */
  hint?: string;
  fallback: string;
  multiline?: boolean;
  maxLength: number;
}

export const SITE_TEXT_KEYS: SiteTextKey[] = [
  {
    key: 'support.title',
    group: 'Help & Support page',
    label: 'Heading',
    fallback: 'Help & Support',
    maxLength: 80,
  },
  {
    key: 'support.subtitle',
    group: 'Help & Support page',
    label: 'Line under the heading',
    fallback: 'We are here 24×7. Reach us whichever way suits you.',
    maxLength: 200,
  },
  {
    key: 'support.bookingTitle',
    group: 'Help & Support page',
    label: 'Booking note — heading',
    fallback: 'About a booking you made here',
    maxLength: 80,
  },
  {
    key: 'support.bookingBody',
    group: 'Help & Support page',
    label: 'Booking note — text',
    hint: 'Shown to someone who booked on the website and needs help with that trip.',
    fallback:
      'Keep your booking reference handy when you call. To see the trip, track the driver or raise a complaint, open the Gora Taxi app with the same mobile number you booked with — the booking is already there.',
    multiline: true,
    maxLength: 500,
  },
  {
    key: 'support.caution',
    group: 'Help & Support page',
    label: 'Caution banner',
    hint: 'The red warning at the foot of the page. Leave blank to hide it.',
    fallback:
      'Caution: never make advance payments to an unknown person without a reference. Pay only through this website or the Gora Taxi app.',
    multiline: true,
    maxLength: 400,
  },
  {
    key: 'support.cta',
    group: 'Help & Support page',
    label: 'Button at the bottom',
    fallback: 'Book a cab',
    maxLength: 40,
  },
  {
    key: 'footer.caution',
    group: 'Footer (every page)',
    label: 'Caution note',
    hint: 'The red warning in the footer. Leave blank to hide it.',
    fallback: 'Caution: never make advance payments to an unknown person without a reference.',
    multiline: true,
    maxLength: 300,
  },
  {
    key: 'footer.appNote',
    group: 'Footer (every page)',
    label: 'Track your trip note',
    hint: 'Shown under "Reach us", pointing someone at the app for a booking they already made.',
    fallback:
      'Booked here? Open the Gora Taxi app with the same mobile number and your trip is already waiting for you.',
    multiline: true,
    maxLength: 300,
  },
];

export const SITE_TEXT_DEFAULTS: Record<string, string> = Object.fromEntries(
  SITE_TEXT_KEYS.map((k) => [k.key, k.fallback]),
);

export const isSiteTextKey = (key: string): boolean =>
  SITE_TEXT_KEYS.some((k) => k.key === key);

export const siteTextKey = (key: string): SiteTextKey | undefined =>
  SITE_TEXT_KEYS.find((k) => k.key === key);
