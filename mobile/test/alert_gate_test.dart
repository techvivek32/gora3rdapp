// The gate protects ONE thing — the single native overlay window. It must not
// also silence the tone, which is what these tests pin down.
//
// The bug being guarded against: a second booking arriving while the first was
// still on screen was refused outright, and because the tray channel the server
// posts on is silent by design, that booking reached the driver with no sound
// at all. The window is scarce; the audio player is not.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gora_cabs/core/utils/alert_gate.dart';

/// A booking id no other test (or earlier run) can collide with — the gate
/// keeps its state in real files under the system temp directory.
String freshKey([String tag = '']) =>
    'bk_${tag}_${DateTime.now().microsecondsSinceEpoch}_${Object().hashCode}';

void main() {
  // The window lock is a single shared file, so hand it back after every test
  // or the next one starts with it held.
  tearDown(() async => AlertGate.release());

  group('the same booking twice', () {
    test('is let through once, then reported as a duplicate', () async {
      final key = freshKey('dup');
      expect(await AlertGate.isDuplicate(key), isFalse, reason: 'first copy must alert');
      expect(await AlertGate.isDuplicate(key), isTrue, reason: 'second copy is a repeat');
    });

    test('two different bookings are not duplicates of each other', () async {
      expect(await AlertGate.isDuplicate(freshKey('a')), isFalse);
      expect(await AlertGate.isDuplicate(freshKey('b')), isFalse);
    });

    test('a push with no booking id is never treated as a repeat', () async {
      // Nothing to compare it against — silencing it would lose a real alert.
      expect(await AlertGate.isDuplicate(''), isFalse);
      expect(await AlertGate.isDuplicate(''), isFalse);
    });
  });

  group('the overlay window', () {
    test('is given to one alert at a time', () async {
      expect(await AlertGate.takeWindow(), isTrue);
      expect(await AlertGate.takeWindow(), isFalse, reason: 'one window, one card');
    });

    test('is free again as soon as the holder releases it', () async {
      expect(await AlertGate.takeWindow(), isTrue);
      await AlertGate.release();
      expect(await AlertGate.takeWindow(), isTrue);
    });

    test('is stolen back from a holder that died without releasing', () async {
      expect(await AlertGate.takeWindow(), isTrue);
      // Backdate the lock past its lease, the way an isolate Android killed
      // mid-alert would leave it.
      final lock = File('${Directory.systemTemp.path}/gora_alert.lock');
      lock.setLastModifiedSync(DateTime.now().subtract(const Duration(minutes: 5)));
      expect(await AlertGate.takeWindow(), isTrue, reason: 'a dead holder must not mute the app');
    });
  });

  group('a second booking while one is already showing', () {
    test('loses the window but is NOT a duplicate — so it still rings', () async {
      final first = freshKey('first');
      final second = freshKey('second');

      // First booking: alerts, and takes the window for its card.
      expect(await AlertGate.isDuplicate(first), isFalse);
      expect(await AlertGate.takeWindow(), isTrue);

      // Second booking arrives while that card is still up.
      expect(await AlertGate.isDuplicate(second), isFalse,
          reason: 'a different booking is not a repeat; silencing it loses the job');
      expect(await AlertGate.takeWindow(), isFalse,
          reason: 'it must not fight for the one overlay window');

      // The caller reads those two answers as: play the tone, skip the card.
    });
  });
}
