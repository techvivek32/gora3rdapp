import 'dart:io';

/// Lets exactly one booking alert put a card on screen at a time, and only once
/// per booking.
///
/// Every FCM alert wakes its OWN background isolate, and each one calls
/// `showRequirementOverlay`, which drives a single native overlay window
/// through `isActive → close → show`. Fire four of those together — which is
/// what happens when the same booking arrives more than once — and they race:
/// measured on an emulator, only two of four ever returned, one of them after
/// 34 seconds, and the other two never did. A background isolate that never
/// finishes is one Android eventually kills, and a user who sees that enough
/// times is told the app "keeps stopping".
///
/// The lock has to be atomic, not merely shared. A read-then-write over
/// SharedPreferences is not: the first attempt at this gate used one, all four
/// alerts read the free slot before any of them wrote it, and every one of them
/// sailed through. `File.create(exclusive: true)` fails if the file already
/// exists, and that check-and-create is a single operation in the OS — which is
/// the guarantee this needs.
///
/// Two separate guards, because they answer different questions:
///   * the same booking twice  → the second is a duplicate, drop it outright;
///   * a different booking while one is still showing → let the tray
///     notification carry it rather than fighting for the overlay window.
class AlertGate {
  /// How long a claim is held if nobody releases it. The overlay call takes
  /// about four seconds normally; this only has to outlast that, and be short
  /// enough that an isolate killed mid-alert does not mute the next one for
  /// long.
  static const _lease = Duration(seconds: 15);

  /// A booking that already rang within this window is treated as a repeat.
  static const _dedupWindow = Duration(minutes: 1);

  static Directory get _dir => Directory.systemTemp;
  static File get _lock => File('${_dir.path}/gora_alert.lock');
  static File _seen(String key) =>
      File('${_dir.path}/gora_alert_${key.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')}.seen');

  /// True if this alert may show its card. Call [release] once it has.
  static Future<bool> claim(String bookingKey) async {
    try {
      if (bookingKey.isNotEmpty && _isRepeat(bookingKey)) return false;
      if (!_takeLock()) return false;
      return true;
    } catch (_) {
      // Storage unavailable: let the alert through rather than silencing it.
      return true;
    }
  }

  /// Hand the slot back as soon as the card is up, so a genuinely new booking
  /// does not have to wait out the whole lease.
  static Future<void> release() async {
    try {
      if (_lock.existsSync()) _lock.deleteSync();
    } catch (_) {/* the stale-lease check frees it anyway */}
  }

  /// Marks this booking as alerted, and reports whether it already was.
  static bool _isRepeat(String key) {
    final f = _seen(key);
    try {
      f.createSync(exclusive: true); // atomic: throws if another alert got here
      return false;
    } on FileSystemException {
      try {
        final age = DateTime.now().difference(f.lastModifiedSync());
        if (age < _dedupWindow) return true;
        f.setLastModifiedSync(DateTime.now()); // old enough to ring again
        return false;
      } catch (_) {
        return false;
      }
    }
  }

  /// Atomically takes the single alert slot, stealing it only if abandoned.
  static bool _takeLock() {
    try {
      _lock.createSync(exclusive: true);
      return true;
    } on FileSystemException {
      try {
        final age = DateTime.now().difference(_lock.lastModifiedSync());
        if (age < _lease) return false; // someone is genuinely mid-alert
        // The holder died without releasing — take it over.
        _lock.setLastModifiedSync(DateTime.now());
        return true;
      } catch (_) {
        return false;
      }
    }
  }
}
