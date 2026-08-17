import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Built-in default tones (used when the user hasn't picked a custom ringtone).
/// Kept per-kind so each default matches what it was before this feature.
const _kRingAsset = 'audio/ring-2.mp4'; // popup default
String _defaultAsset(RingKind kind) =>
    kind == RingKind.notification ? 'audio/gora_ring2.mp4' : 'audio/ring-2.mp4';

/// Safety cap only: how long the background isolate will wait for the clip's
/// "complete" event before giving up (in case some device never fires it). The
/// tone itself plays once and normally finishes well before this.
const _kRingSafetyCap = Duration(seconds: 30);

// The ring played by the FCM **background isolate** lives in that isolate's own
// `_player`, which the overlay (a separate Flutter engine/isolate) cannot touch.
// So the overlay flips this shared-prefs flag on close, and the background isolate
// polls it and stops early. SharedPreferences is file-backed, so it crosses
// isolates (unlike the top-level `_player`).
const _kRingStopKey = 'gora_ring_stop_requested';

/// Whether the user has enabled booking alerts (ring + pop-up). Stored in
/// SharedPreferences so EVERY isolate — the UI, the FCM background handler and
/// the overlay engine — reads the same value. Default OFF: nothing rings until
/// the user turns it on from the home screen.
const _kAlertsEnabledKey = 'gora_alerts_enabled';

Future<bool> alertsEnabled() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload(); // pick up a toggle made in the UI isolate
    return prefs.getBool(_kAlertsEnabledKey) ?? false;
  } catch (_) {
    return false; // fail closed — silence beats an unwanted ring
  }
}

Future<void> setAlertsEnabled(bool on) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAlertsEnabledKey, on);
  } catch (_) {}
}

// ─── User-chosen ringtones (popup vs notification, stored per kind) ───────────
// Each kind stores the chosen ringtone's URL + title. Empty URL = use the bundled
// default. Stored in SharedPreferences so every isolate (UI, FCM background,
// overlay) reads the same choice.
enum RingKind { popup, notification }

String _ringUrlKey(RingKind k) => k == RingKind.popup ? 'ringtone_popup_url' : 'ringtone_notification_url';
String _ringTitleKey(RingKind k) => k == RingKind.popup ? 'ringtone_popup_title' : 'ringtone_notification_title';
String _ringPathKey(RingKind k) => k == RingKind.popup ? 'ringtone_popup_path' : 'ringtone_notification_path';

/// Local cached file path for the chosen ringtone (downloaded once). Empty if
/// none/uncached — playback then falls back to the URL, then the default tone.
Future<String> getRingtonePath(RingKind kind) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return prefs.getString(_ringPathKey(kind)) ?? '';
  } catch (_) {
    return '';
  }
}

/// Downloads [url] into the app's support dir so the tone plays from disk every
/// time (no network on each alert, works in the background). Returns the local
/// path, or null if the download failed.
Future<String?> _downloadRingtone(RingKind kind, String url) async {
  try {
    final dir = await getApplicationSupportDirectory();
    final ringDir = Directory('${dir.path}/ringtones');
    if (!ringDir.existsSync()) ringDir.createSync(recursive: true);
    final rawExt = url.split('?').first.split('.').last.toLowerCase();
    final ext = (rawExt.isNotEmpty && rawExt.length <= 4) ? rawExt : 'mp3';
    final file = File('${ringDir.path}/${kind.name}.$ext');
    await Dio().download(url, file.path);
    return file.existsSync() ? file.path : null;
  } catch (_) {
    return null;
  }
}

/// Persist a ringtone choice for [kind] AND cache the audio to disk. Pass an
/// empty [url] to reset to the built-in default. Returns true on success.
Future<bool> saveRingtoneChoice(RingKind kind, {required String url, required String title}) async {
  if (url.isEmpty) {
    await setRingtone(kind, url: '', title: '', path: '');
    return true;
  }
  final path = await _downloadRingtone(kind, url);
  // Even if the download failed, store the URL so playback can stream it.
  await setRingtone(kind, url: url, title: title, path: path ?? '');
  return path != null;
}

Future<String> getRingtoneUrl(RingKind kind) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return prefs.getString(_ringUrlKey(kind)) ?? '';
  } catch (_) {
    return '';
  }
}

Future<String> getRingtoneTitle(RingKind kind) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return prefs.getString(_ringTitleKey(kind)) ?? '';
  } catch (_) {
    return '';
  }
}

/// Save a choice for [kind]. Pass an empty [url] to reset to the default tone.
Future<void> setRingtone(RingKind kind, {required String url, required String title, String path = ''}) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    if (url.isEmpty) {
      await prefs.remove(_ringUrlKey(kind));
      await prefs.remove(_ringTitleKey(kind));
      await prefs.remove(_ringPathKey(kind));
    } else {
      await prefs.setString(_ringUrlKey(kind), url);
      await prefs.setString(_ringTitleKey(kind), title);
      if (path.isNotEmpty) {
        await prefs.setString(_ringPathKey(kind), path);
      } else {
        await prefs.remove(_ringPathKey(kind));
      }
    }
  } catch (_) {}
}

AudioPlayer? _player;
StreamSubscription<void>? _completeSub;
AudioPlayer? _previewPlayer;

/// Preview a ringtone in the settings screen. Empty [url] previews the default.
Future<void> playPreview({String url = ''}) async {
  await stopPreview();
  try {
    final player = AudioPlayer();
    _previewPlayer = player;
    await player.setReleaseMode(ReleaseMode.release);
    if (url.isNotEmpty) {
      try {
        await player.play(UrlSource(url));
      } catch (_) {
        await player.play(AssetSource(_kRingAsset));
      }
    } else {
      await player.play(AssetSource(_kRingAsset));
    }
  } catch (_) {}
}

Future<void> stopPreview() async {
  final p = _previewPlayer;
  _previewPlayer = null;
  if (p == null) return;
  try {
    await p.stop();
    await p.dispose();
  } catch (_) {}
}

/// Ask whichever isolate is currently ringing to stop — sets the shared flag AND
/// stops any player in the CURRENT isolate. Call this from every "dismiss" path
/// (overlay close, alert close) so the ring can never outlive the popup.
Future<void> requestStopRing() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kRingStopKey, true);
  } catch (_) {}
  await stopRequirementRing();
}

Future<bool> _stopRequested() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload(); // pick up a write made by the overlay isolate
    return prefs.getBool(_kRingStopKey) ?? false;
  } catch (_) {
    return false;
  }
}

Future<void> _clearStopFlag() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kRingStopKey, false);
  } catch (_) {}
}

/// Plays the ring tone bundled at assets/[_kRingAsset] ONCE when a new requirement
/// arrives (no looping — it stops on its own when the clip ends). Best-effort:
/// silently ignores failures (no audio focus / codec, etc).
///
/// Calling it again restarts the ring rather than layering a second one.
///
/// Set [awaitEnd] when calling from the FCM background isolate: that isolate is
/// torn down once the handler returns, taking the player with it. Awaiting the
/// clip's completion keeps it alive so the tone actually plays through once (and
/// stops early if the user dismisses the popup).
Future<void> playRequirementRing({bool awaitEnd = false, RingKind kind = RingKind.popup}) async {
  await stopRequirementRing();
  await _clearStopFlag(); // fresh start — forget any earlier dismiss request
  try {
    final player = AudioPlayer();
    _player = player;
    // Play ONCE — release (not loop) so the tone ends by itself after one play.
    await player.setReleaseMode(ReleaseMode.release);
    // The user's chosen tone for this kind (popup vs notification); empty → the
    // bundled default. Fall back to the default if the URL can't be played.
    final cachedPath = await getRingtonePath(kind);
    final url = await getRingtoneUrl(kind);
    try {
      if (cachedPath.isNotEmpty && File(cachedPath).existsSync()) {
        await player.play(DeviceFileSource(cachedPath)); // from disk — no network
      } else if (url.isNotEmpty) {
        await player.play(UrlSource(url));
      } else {
        await player.play(AssetSource(_defaultAsset(kind)));
      }
    } catch (_) {
      await player.play(AssetSource(_defaultAsset(kind)));
    }

    if (awaitEnd) {
      // Background isolate: keep it alive until the clip finishes OR the user
      // dismisses the popup (shared stop flag). The cap is only a hang-guard.
      final completer = Completer<void>();
      final sub = player.onPlayerComplete.listen((_) {
        if (!completer.isCompleted) completer.complete();
      });
      final end = DateTime.now().add(_kRingSafetyCap);
      while (!completer.isCompleted && DateTime.now().isBefore(end)) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        if (await _stopRequested()) break;
      }
      await sub.cancel();
      await stopRequirementRing();
      await _clearStopFlag();
    } else {
      // Foreground: the tone plays once; clean up the player when it completes.
      // The popup's close handler also calls stopRequirementRing directly.
      _completeSub = player.onPlayerComplete.listen((_) => stopRequirementRing());
    }
  } catch (e) {
    debugPrint('Ring play error: $e');
    await stopRequirementRing();
  }
}

/// Stops the ring immediately (when the clip completes, or when the user dismisses
/// the popup so the tone doesn't keep playing over them).
Future<void> stopRequirementRing() async {
  await _completeSub?.cancel();
  _completeSub = null;

  final player = _player;
  _player = null;
  if (player == null) return;
  try {
    await player.stop();
    await player.dispose();
  } catch (e) {
    debugPrint('Ring stop error: $e');
  }
}
