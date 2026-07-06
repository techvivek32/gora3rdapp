import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Plays the ring tone bundled at assets/audio/ring.mpeg when a new requirement
/// arrives. Best-effort — silently ignores failures (no audio focus / codec, etc).
Future<void> playRequirementRing() async {
  try {
    final player = AudioPlayer();
    await player.setReleaseMode(ReleaseMode.release);
    await player.play(AssetSource('audio/ring.mpeg'));
  } catch (e) {
    debugPrint('Ring play error: $e');
  }
}
