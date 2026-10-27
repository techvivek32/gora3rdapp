abstract class Failure {
  final String message;

  /// The backend's machine-readable code, when it sent one (see
  /// `ErrorMapper.code`). Lets a page act on a specific refusal — e.g.
  /// VERIFICATION_REQUIRED sends the member to KYC — rather than only showing
  /// the message.
  final String? code;

  const Failure({required this.message, this.code});
}

class ServerFailure extends Failure {
  const ServerFailure({required super.message, super.code});
}

class NetworkFailure extends Failure {
  const NetworkFailure({required super.message});
}

class CacheFailure extends Failure {
  const CacheFailure({required super.message});
}

class AuthFailure extends Failure {
  const AuthFailure({required super.message});
}

/// The mobile number has no account yet (backend replies 404 to send-login-otp).
/// Its own type so callers can branch on it — the login page sends these users to
/// Register instead of showing an error.
class NotRegisteredFailure extends Failure {
  const NotRegisteredFailure({required super.message});
}
