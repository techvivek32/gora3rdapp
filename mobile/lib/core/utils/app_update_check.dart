import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';

// Only check once per app launch.
bool _updateChecked = false;

/// Google Play **In-App Update**. Auto-detects whether a newer version has been
/// published on the Play Store (no backend or version number needed) and shows
/// Google's native update flow. Just publish a new AAB with a higher version
/// code — Play detects it and the popup appears for users on older builds.
///
/// Uses an immediate (mandatory) update when Play allows it, otherwise a
/// flexible (background) update. Best-effort and Android/Play-only — silently
/// no-ops on web, iOS, sideloaded builds, or if Play returns no update.
Future<void> checkForAppUpdate() async {
  if (_updateChecked || kIsWeb) return;
  _updateChecked = true;
  try {
    final info = await InAppUpdate.checkForUpdate();
    if (info.updateAvailability != UpdateAvailability.updateAvailable) return;

    if (info.immediateUpdateAllowed) {
      // Full-screen "Update" flow — blocks until the user updates.
      await InAppUpdate.performImmediateUpdate();
    } else if (info.flexibleUpdateAllowed) {
      // Downloads in the background, then applies on completion.
      await InAppUpdate.startFlexibleUpdate();
      await InAppUpdate.completeFlexibleUpdate();
    }
  } catch (_) {
    // No Play Store context / no update / error — never block the app.
  }
}
