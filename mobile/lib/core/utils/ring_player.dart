import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// How long the ring keeps sounding when a new requirement arrives.
const _kRingDuration = Duration(seconds: 10);

AudioPlayer? _player;
Timer? _stopTimer;

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
  try {
    final player = AudioPlayer();
    _player = player;
    // Loop so a short clip still fills the full window; we end it below.
    await player.setReleaseMode(ReleaseMode.loop);
    await player.play(AssetSource('audio/ring.mpeg'));

    if (awaitEnd) {
      await Future<void>.delayed(duration);
      await stopRequirementRing();
    } else {
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
