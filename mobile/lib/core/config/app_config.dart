import 'package:shared_preferences/shared_preferences.dart';
import '../network/api_client.dart';

/// Small cache of app-wide platform settings the UI reads synchronously (e.g.
/// booking cards). Seeded from SharedPreferences on launch (so it has a value
/// before anything renders) and refreshed from the backend in the background.
class AppConfig {
  AppConfig._();

  /// Whether the app shows the "App Suggested Fare" line on booking cards.
  static bool appSuggestedFareEnabled = true;

  /// Whether the app shows the "N views" count on cards.
  static bool viewsEnabled = true;

  static const _kFareKey = 'cfg_app_suggested_fare';
  static const _kViewsKey = 'cfg_views_enabled';

  /// Read the last-known values from disk. Call once early in main().
  static Future<void> initFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      appSuggestedFareEnabled = prefs.getBool(_kFareKey) ?? true;
      viewsEnabled = prefs.getBool(_kViewsKey) ?? true;
    } catch (_) {}
  }

  /// Pull the latest platform settings and persist them. Best-effort.
  static Future<void> refresh(ApiClient api) async {
    try {
      final res = await api.get('/settings');
      final s = (res.data['data'] ?? res.data) as Map<String, dynamic>;
      appSuggestedFareEnabled = s['appSuggestedFareEnabled'] != false; // default true
      viewsEnabled = s['viewsEnabled'] != false; // default true
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kFareKey, appSuggestedFareEnabled);
      await prefs.setBool(_kViewsKey, viewsEnabled);
    } catch (_) {}
  }
}
