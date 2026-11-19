import 'dart:async';
import 'dart:isolate';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Crash and error reporting.
///
/// Why this exists: Play Console reported a user-perceived crash rate of 2.27%
/// against a 1.09% bad-behaviour threshold, and there was no way to find out
/// why. Play's own crash traces are of limited use for a Flutter app — the Dart
/// stack lives inside libapp.so, so what Play shows is a native frame in the
/// engine, the same frame for every unrelated Dart failure. Crashlytics records
/// the Dart stack, so a crash names the function that threw.
///
/// It installs two global handlers, and the difference between them matters:
///
///  * [FlutterError.onError] catches a throw inside the widget tree — build,
///    layout, paint, a gesture callback. Flutter already survives these (it
///    paints an error box); we only want them reported.
///
///  * `platformDispatcher.onError` catches an async error with no handler —
///    a Future that rejects with nobody awaiting it, a stream with no
///    onError. **This one is a process killer.** Left alone it propagates out
///    of the root zone and Android records a crash. Returning true here marks
///    it handled, so the app reports the error and stays alive. A dropped API
///    response should not close the app on a driver mid-trip.
///
/// Everything is best-effort. If Firebase failed to initialise — no Play
/// services, a device with the Google stack stripped out — every call here is a
/// silent no-op rather than a second crash on top of the first.
class CrashReporter {
  static bool _enabled = false;

  /// Turn reporting on and install the global handlers. Safe to call when
  /// Firebase did not initialise; reporting just stays off.
  static Future<void> init() async {
    try {
      final crashlytics = FirebaseCrashlytics.instance;
      // Off in debug: a developer's own stack traces would otherwise drown the
      // real ones, and the dashboard is what the crash rate is read from.
      await crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode);
      _enabled = !kDebugMode;
    } catch (e) {
      debugPrint('Crashlytics unavailable: $e');
      _enabled = false;
    }

    // Framework errors: let Flutter print it as usual, then report it.
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      previous?.call(details);
      if (_enabled) {
        FirebaseCrashlytics.instance.recordFlutterError(details);
      }
    };

    // Unhandled async errors. Returning true is the point of this handler —
    // see the class comment.
    PlatformDispatcher.instance.onError = (error, stack) {
      debugPrint('Uncaught async error: $error');
      record(error, stack, reason: 'uncaught-async');
      return true;
    };

    // Errors thrown on a background isolate never reach either handler above.
    // The FCM background handler and the overlay entry point both run on one.
    try {
      Isolate.current.addErrorListener(
        RawReceivePort((dynamic pair) {
          final list = pair as List<dynamic>;
          record(
            list.first ?? 'isolate error',
            list.last == null ? null : StackTrace.fromString('${list.last}'),
            reason: 'isolate',
            fatal: true,
          );
        }).sendPort,
      );
    } catch (_) {
      // Not supported on every platform; nothing else depends on it.
    }
  }

  /// Report one error. [reason] is what shows up as the crash's subtitle in the
  /// console, so it should say where it came from ('startup/push', 'overlay').
  static Future<void> record(
    Object error,
    StackTrace? stack, {
    String? reason,
    bool fatal = false,
  }) async {
    if (!_enabled) return;
    try {
      await FirebaseCrashlytics.instance
          .recordError(error, stack, reason: reason, fatal: fatal);
    } catch (_) {
      // Reporting must never be the thing that breaks.
    }
  }

  /// Ties later crashes to an account, so "which drivers does this hit?" is
  /// answerable. Only the user id — no phone number, no name.
  static Future<void> setUser(String? userId) async {
    if (!_enabled) return;
    try {
      await FirebaseCrashlytics.instance.setUserIdentifier(userId ?? '');
    } catch (_) {}
  }

  /// A breadcrumb. These are attached to whatever crash comes next, which is
  /// what turns "it crashed" into "it crashed right after the trip ended".
  static void log(String message) {
    if (!_enabled) return;
    try {
      FirebaseCrashlytics.instance.log(message);
    } catch (_) {}
  }
}
