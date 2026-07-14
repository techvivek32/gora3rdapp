abstract class Failure {
  final String message;
  const Failure({required this.message});
}

class ServerFailure extends Failure {
  const ServerFailure({required super.message});
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
