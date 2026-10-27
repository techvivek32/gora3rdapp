/** All Indian states + union territories, used to resolve the pickup state for
 *  state-wise cab fuel pricing. Ported from the mobile app's
 *  `core/constants/indian_states.dart` and kept in sync with the admin list. */
export const INDIAN_STATES = [
  'Andhra Pradesh', 'Arunachal Pradesh', 'Assam', 'Bihar', 'Chhattisgarh',
  'Goa', 'Gujarat', 'Haryana', 'Himachal Pradesh', 'Jharkhand', 'Karnataka',
  'Kerala', 'Madhya Pradesh', 'Maharashtra', 'Manipur', 'Meghalaya', 'Mizoram',
  'Nagaland', 'Odisha', 'Punjab', 'Rajasthan', 'Sikkim', 'Tamil Nadu',
  'Telangana', 'Tripura', 'Uttar Pradesh', 'Uttarakhand', 'West Bengal',
  'Andaman and Nicobar Islands', 'Chandigarh',
  'Dadra and Nagar Haveli and Daman and Diu',
  'Delhi', 'Jammu and Kashmir', 'Ladakh', 'Lakshadweep', 'Puducherry',
];

/** Longest name first, so "Andhra Pradesh" wins over a stray "Andhra". */
const SORTED = [...INDIAN_STATES].sort((a, b) => b.length - a.length);

/** The Indian state mentioned in an address/city string, or '' if none match. */
export function stateFromText(text: string): string {
  const hay = (text || '').toLowerCase();
  for (const s of SORTED) {
    if (hay.includes(s.toLowerCase())) return s;
  }
  return '';
}
