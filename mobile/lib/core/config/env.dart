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
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:7001/api/v1',
  );

  /// Socket.IO host root (NO `/api/v1` prefix).
  static const String socketBaseUrl = String.fromEnvironment(
    'SOCKET_BASE_URL',
    defaultValue: 'http://localhost:7001/api/v1',
  );
}
