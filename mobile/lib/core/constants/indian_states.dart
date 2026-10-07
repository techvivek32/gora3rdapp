// All Indian states + union territories, used to resolve the pickup state for
// state-wise cab fuel pricing. Kept in sync with the admin panel's list.
const List<String> kIndianStates = [
  'Andhra Pradesh', 'Arunachal Pradesh', 'Assam', 'Bihar', 'Chhattisgarh',
  'Goa', 'Gujarat', 'Haryana', 'Himachal Pradesh', 'Jharkhand', 'Karnataka',
  'Kerala', 'Madhya Pradesh', 'Maharashtra', 'Manipur', 'Meghalaya', 'Mizoram',
  'Nagaland', 'Odisha', 'Punjab', 'Rajasthan', 'Sikkim', 'Tamil Nadu',
  'Telangana', 'Tripura', 'Uttar Pradesh', 'Uttarakhand', 'West Bengal',
  'Andaman and Nicobar Islands', 'Chandigarh',
  'Dadra and Nagar Haveli and Daman and Diu',
  'Delhi', 'Jammu and Kashmir', 'Ladakh', 'Lakshadweep', 'Puducherry',
];

/// Finds the Indian state mentioned in a pickup address/city string, or '' if
/// none match. Matches on the longest name first so "Andhra Pradesh" wins over
/// a stray substring.
String stateFromText(String text) {
  final hay = text.toLowerCase();
  final sorted = [...kIndianStates]..sort((a, b) => b.length.compareTo(a.length));
  for (final s in sorted) {
    if (hay.contains(s.toLowerCase())) return s;
  }
  return '';
}
