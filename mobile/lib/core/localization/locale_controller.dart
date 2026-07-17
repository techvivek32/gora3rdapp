import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds the app's current language and persists the user's choice.
///
/// A singleton (not in get_it) so the `.tr` string extension can read the active
/// language without a BuildContext. MaterialApp rebuilds when [notifyListeners]
/// fires, so switching language re-renders the whole app instantly.
class LocaleController extends ChangeNotifier {
  LocaleController._();
  static final LocaleController instance = LocaleController._();

  static const _prefsKey = 'app_locale';

  Locale _locale = const Locale('en');
  Locale get locale => _locale;
  String get lang => _locale.languageCode;

  /// Call once at startup, before runApp, to restore the saved language.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_prefsKey);
      if (code != null && code.isNotEmpty) _locale = Locale(code);
    } catch (_) {
      // Fall back to English on any storage error.
    }
  }

  Future<void> setLanguage(String code) async {
    if (code == _locale.languageCode) return;
    _locale = Locale(code);
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, code);
    } catch (_) {}
  }
}
