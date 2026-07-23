import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How long the ring keeps sounding when a new requirement arrives.
const _kRingDuration = Duration(seconds: 10);

// The ring played by the FCM **background isolate** lives in that isolate's own
// `_player`, which the overlay (a separate Flutter engine/isolate) cannot touch.
// So the overlay flips this shared-prefs flag on close, and the background isolate
// polls it and stops early. SharedPreferences is file-backed, so it crosses
// isolates (unlike the top-level `_player`).
const _kRingStopKey = 'gora_ring_stop_requested';

AudioPlayer? _player;
Timer? _stopTimer;

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

/// Plays the ring tone bundled at assets/audio/ring.mpeg when a new requirement
/// arrives, for [duration] (looping if the clip is shorter). Best-effort —
/// silently ignores failures (no audio focus / codec, etc).
///
/// Calling it again restarts the ring rather than layering a second one.
///
/// Set [awaitEnd] when calling from the FCM background isolate: that isolate is
/// torn down once the handler returns, taking the stop timer (and the player)
/// with it. Awaiting the full duration keeps it alive so the ring actually lasts
/// [duration] and then stops cleanly.
Future<void> playRequirementRing({
  Duration duration = _kRingDuration,
  bool awaitEnd = false,
}) async {
  await stopRequirementRing();
  await _clearStopFlag(); // fresh start — forget any earlier dismiss request
  try {
    final player = AudioPlayer();
    _player = player;
    // Loop so a short clip still fills the full window; we end it below.
    await player.setReleaseMode(ReleaseMode.loop);
    await player.play(AssetSource('audio/ring.mpeg'));

    if (awaitEnd) {
      // Background isolate: poll the shared stop flag so the overlay (a different
      // isolate) can cut the ring short the moment the user dismisses the popup.
      final end = DateTime.now().add(duration);
      while (DateTime.now().isBefore(end)) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        if (await _stopRequested()) break;
      }
      await stopRequirementRing();
      await _clearStopFlag();
    } else {
      // Foreground: the popup lives in this same isolate, so its close handler's
      // stopRequirementRing stops this player directly. The 10s timer is the cap.
      _stopTimer = Timer(duration, stopRequirementRing);
    }
  } catch (e) {
    debugPrint('Ring play error: $e');
    await stopRequirementRing();
  }
}

/// Stops the ring immediately (used by the 10s timer, and when the user dismisses
/// the popup so the tone doesn't keep playing over them).
Future<void> stopRequirementRing() async {
  _stopTimer?.cancel();
  _stopTimer = null;

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
