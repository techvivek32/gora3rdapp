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
  // ── Who the site belongs to ───────────────────────────────────────────
  // These used to be hardcoded in the website (web/src/lib/company.ts) with a
  // note saying "if the operator edits the invoice template, this file has to
  // follow" — which meant an address change was a code change. They are the
  // same details the tax invoice prints, so they belong to the operator.
  {
    key: 'company.brand',
    group: 'Company details',
    label: 'Brand name',
    hint: 'The name used in the writing across the site.',
    fallback: 'Gora Taxi',
    maxLength: 60,
  },
  {
    key: 'company.tagline',
    group: 'Company details',
    label: 'Tagline',
    hint: 'The small line under the logo, in the header and the footer.',
    fallback: 'India Ka Apna App',
    maxLength: 60,
  },
  {
    key: 'company.legalName',
    group: 'Company details',
    label: 'Registered company name',
    hint: 'Shown where a visitor is entitled to know who they are dealing with.',
    fallback: 'Gora Cabs & Travels Private Limited',
    maxLength: 120,
  },
  {
    key: 'company.address',
    group: 'Company details',
    label: 'Registered office address',
    fallback:
      '132, Nayak Bhawan, Haripura Vyas Colony, Tempo Stand Airforce, Jodhpur, Rajasthan 342011',
    multiline: true,
    maxLength: 300,
  },
  {
    key: 'company.city',
    group: 'Company details',
    label: 'City and state',
    hint: 'Used in a sentence — "run by … from Jodhpur, Rajasthan".',
    fallback: 'Jodhpur, Rajasthan',
    maxLength: 80,
  },
  {
    key: 'company.gstin',
    group: 'Company details',
    label: 'GSTIN',
    hint: 'Leave blank to take it off the site.',
    fallback: '08AAMCG5008P1Z3',
    maxLength: 20,
  },
  {
    key: 'company.appName',
    group: 'Company details',
    label: 'App name on the store',
    hint: 'The title someone sees when the Get the app card takes them there.',
    fallback: 'Gora Taxi Partner',
    maxLength: 60,
  },
  {
    key: 'company.playStoreUrl',
    group: 'Company details',
    label: 'Play Store link',
    fallback: 'https://play.google.com/store/apps/details?id=com.taxi.call_taxi_partner',
    maxLength: 300,
  },

  // ── Contact section on the home page ──────────────────────────────────
  // The phone, WhatsApp and email themselves are operator settings already
  // (Settings → Support contact); this is the wording around them.
  {
    key: 'contact.eyebrow',
    group: 'Contact section (home page)',
    label: 'Small label above the heading',
    fallback: 'Talk to us',
    maxLength: 40,
  },
  {
    key: 'contact.title',
    group: 'Contact section (home page)',
    label: 'Heading',
    fallback: 'Contact Gora Taxi',
    maxLength: 80,
  },
  {
    key: 'contact.subtitle',
    group: 'Contact section (home page)',
    label: 'Line under the heading',
    fallback:
      'Someone is on the phone 24×7. Call before you book if you want a quote checked, or after you book if anything about the trip changes.',
    multiline: true,
    maxLength: 300,
  },
  {
    key: 'contact.callNote',
    group: 'Contact section (home page)',
    label: 'Call card — note',
    fallback: '24×7, every day',
    maxLength: 80,
  },
  {
    key: 'contact.whatsappLine',
    group: 'Contact section (home page)',
    label: 'WhatsApp card — main line',
    fallback: 'Message the team',
    maxLength: 80,
  },
  {
    key: 'contact.whatsappNote',
    group: 'Contact section (home page)',
    label: 'WhatsApp card — note',
    fallback: 'Send a trip and get it booked',
    maxLength: 80,
  },
  {
    key: 'contact.emailNote',
    group: 'Contact section (home page)',
    label: 'Email card — note',
    fallback: 'For bills and documents',
    maxLength: 80,
  },
  {
    key: 'contact.appNote',
    group: 'Contact section (home page)',
    label: 'Get the app card — note',
    fallback: 'Track the trip and keep your history',
    maxLength: 80,
  },
  {
    key: 'contact.officeTitle',
    group: 'Contact section (home page)',
    label: 'Address card — heading',
    fallback: 'Registered office',
    maxLength: 60,
  },
  {
    key: 'contact.bookedTitle',
    group: 'Contact section (home page)',
    label: 'Already-booked card — heading',
    fallback: 'Already booked?',
    maxLength: 60,
  },
  {
    key: 'contact.bookedBody',
    group: 'Contact section (home page)',
    label: 'Already-booked card — text',
    hint: 'The second phone number is added after this automatically when one is set.',
    fallback: 'Keep the booking reference handy when you call.',
    multiline: true,
    maxLength: 300,
  },

  // ── Footer ────────────────────────────────────────────────────────────
  {
    key: 'footer.blurb',
    group: 'Footer (every page)',
    label: 'Short description under the logo',
    fallback:
      'Outstation cabs, local packages, drivers for your own car, and shared rides across India.',
    multiline: true,
    maxLength: 300,
  },
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
