import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The ring tone asset — played ONCE when a new requirement arrives.
const _kRingAsset = 'audio/ring-1.mp4';

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

AudioPlayer? _player;
StreamSubscription<void>? _completeSub;

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
Future<void> playRequirementRing({bool awaitEnd = false}) async {
  await stopRequirementRing();
  await _clearStopFlag(); // fresh start — forget any earlier dismiss request
  try {
    final player = AudioPlayer();
    _player = player;
    // Play ONCE — release (not loop) so the tone ends by itself after one play.
    await player.setReleaseMode(ReleaseMode.release);
    await player.play(AssetSource(_kRingAsset));

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
