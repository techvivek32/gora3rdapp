/**
 * Who the site belongs to.
 *
 * The brand on the logo and in the app is **Gora Taxi**; the company behind it
 * is Gora Cabs & Travels Private Limited. Both appear on the site, in the
 * places each belongs: the brand in the writing, the registered name and GSTIN
 * where a visitor is entitled to know who they are dealing with.
 *
 * These are DEFAULTS, not the live values. Every one of them is editable in
 * the admin panel (Website Text → Company details) and the pages read them
 * through `useSiteText()`; this file is what the site shows on the first
 * paint, before that request returns, and if it fails. Nothing here needs
 * editing when the operator changes an address.
 *
 * Phone numbers, WhatsApp and the support email are not here either. Those
 * are operator settings, read live from `/settings` and
 * `/settings/support-contact`.
 */
export const COMPANY = {
  /** The brand. Use this in copy. */
  brand: 'Gora Taxi',
  /** The small line under the logo, header and footer. */
  tagline: 'India Ka Apna App',
  /** The registered company. Use this where the law or plain honesty wants it. */
  legalName: 'Gora Cabs & Travels Private Limited',
  address:
    '132, Nayak Bhawan, Haripura Vyas Colony, Tempo Stand Airforce, Jodhpur, Rajasthan 342011',
  city: 'Jodhpur, Rajasthan',
  gstin: '08AAMCG5008P1Z3',
  /**
   * One app serves drivers, vendors and customers, and it is listed under the
   * name the partners know it by. Linking to it is better than telling someone
   * to go and search the store, but the listing title is what they will see.
   */
  appName: 'Gora Taxi Partner',
  playStoreUrl: 'https://play.google.com/store/apps/details?id=com.taxi.call_taxi_partner',
} as const;
