import 'package:shared_preferences/shared_preferences.dart';

/// Membership tiers that unlock contacting a poster (call / WhatsApp).
const _paidTiers = ['active', 'verified', 'premium', 'golden'];

/// Single source of truth for "can this user contact a poster?".
/// Mirrors the check the requirement card uses, so the card, the in-app alert and
/// the floating overlay all agree.
bool canContactPosters(Map<String, dynamic>? user) {
  if (user == null) return false;
  if (user['isPremium'] == true || user['isGolden'] == true) return true;
  return _paidTiers.contains((user['membershipType'] ?? '').toString());
}

/// The overlay runs in a **separate Flutter engine** with no access to the app's
/// blocs or DI, so the answer is mirrored into SharedPreferences for it to read.
const kOverlayCanContactKey = 'gora_overlay_can_contact';

Future<void> saveOverlayContactFlag(Map<String, dynamic>? user) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kOverlayCanContactKey, canContactPosters(user));
  } catch (_) {
    // Never let a prefs failure break auth.
  }
}

Future<void> clearOverlayContactFlag() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(kOverlayCanContactKey);
  } catch (_) {}
}
