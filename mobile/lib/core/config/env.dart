/// Centralized environment configuration.
///
/// Values are injected at build/run time from a `.env` file via:
///   flutter run  --dart-define-from-file=.env
///   flutter build apk --dart-define-from-file=.env
///
/// If the file (or a key) is not provided, the `defaultValue` below is used,
/// which points at the deployed VPS so release builds work without extra flags.
class Env {
  /// REST API base, including the `/api/v1` prefix.
  ///
  /// The default is PRODUCTION on purpose. It used to be localhost, which meant
  /// a `flutter build appbundle --release` run without the flag above produced a
  /// store build that talked to the handset itself and could not even sign in —
  /// silently, because nothing fails at compile time. Point local work at a
  /// local server with the flag; never by changing this default.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://backend.goracabs.com/api/v1',
  );

  /// Socket.IO host root (NO `/api/v1` prefix).
  static const String socketBaseUrl = String.fromEnvironment(
    'SOCKET_BASE_URL',
    defaultValue: 'https://backend.goracabs.com',
  );
}
