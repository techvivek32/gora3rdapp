/**
 * Who the site belongs to.
 *
 * The brand on the logo and in the app is **Gora Taxi**; the company behind it
 * is Gora Cabs & Travels Private Limited. Both appear on the site, in the
 * places each belongs: the brand in the writing, the registered name and GSTIN
 * where a visitor is entitled to know who they are dealing with.
 *
 * These values are the same ones the backend prints on a tax invoice —
 * `backend/src/database/schemas/invoice-template.schema.ts`, the `company`
 * block of DEFAULT_TEMPLATE, which is the source of truth. There is no public
 * endpoint for them, so they are repeated here; if the operator edits the
 * invoice template, this file has to follow.
 *
 * Phone numbers, WhatsApp and the support email are NOT here. Those are
 * operator settings, read live from `/settings` and `/settings/support-contact`
 * so that changing them in the admin panel changes them on the site.
 */
export const COMPANY = {
  /** The brand. Use this in copy. */
  brand: 'Gora Taxi',
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
