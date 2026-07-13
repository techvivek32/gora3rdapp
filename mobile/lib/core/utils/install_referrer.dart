import 'dart:io';

import 'package:android_play_install_referrer/android_play_install_referrer.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kPendingReferralKey = 'gora_pending_referral';
const _kReferrerCheckedKey = 'gora_referrer_checked';

/// Captures the referral code that travelled with a Play Store install.
///
/// When someone taps an invite link containing `&referrer=ref%3D<CODE>`, Google
/// Play holds that string through the install and hands it to the app on first
/// launch. That's the only way a fresh install can know who invited it — nothing
/// is shared with the app before it exists.
///
/// Runs once and remembers it did: the Play referrer never changes for a given
/// install, so re-reading it on every launch would just re-fill a code the user
/// may have deliberately cleared.
Future<void> captureInstallReferrer() async {
  if (!Platform.isAndroid) return;

  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(_kReferrerCheckedKey) == true) return;

  try {
    final details = await AndroidPlayInstallReferrer.installReferrer;
    final raw = details.installReferrer ?? '';
    final code = _extractCode(raw);
    if (code != null && code.isNotEmpty) {
      await prefs.setString(_kPendingReferralKey, code);
      debugPrint('Install referral captured: $code');
    }
  } catch (e) {
    // No Play Store (sideloaded APK / emulator) — nothing to capture.
    debugPrint('Install referrer unavailable: $e');
  } finally {
    await prefs.setBool(_kReferrerCheckedKey, true);
  }
}

/// `utm_source=invite&ref=9876543210` → `9876543210`.
/// An organic Play install sends `utm_source=google-play&utm_medium=organic`,
/// which has no `ref` and correctly yields null.
String? _extractCode(String referrer) {
  if (referrer.isEmpty) return null;
  for (final part in referrer.split('&')) {
    final i = part.indexOf('=');
    if (i <= 0) continue;
    if (part.substring(0, i) == 'ref') {
      return Uri.decodeComponent(part.substring(i + 1)).trim();
    }
  }
  return null;
}

/// The captured code, for pre-filling the register form. Null if this install
/// didn't come from an invite link.
Future<String?> pendingReferralCode() async {
  final prefs = await SharedPreferences.getInstance();
  final code = prefs.getString(_kPendingReferralKey);
  return (code == null || code.isEmpty) ? null : code;
}

/// Called after a successful registration — the code has done its job.
Future<void> clearPendingReferralCode() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_kPendingReferralKey);
}
