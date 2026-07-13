import 'package:dio/dio.dart';

/// Pulls the backend's own error text out of a failed request.
///
/// Nest's exception filter returns `{ message: "Incorrect OTP" }` (or a list of
/// validation strings). Without this, `e.toString()` on a DioException gives the
/// user a stack-trace-flavoured dump instead of the one sentence that matters.
String serverMessage(Object error, {String fallback = 'Something went wrong'}) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map) {
      final msg = data['message'] ?? data['error'];
      if (msg is String && msg.trim().isNotEmpty) return msg;
      if (msg is List && msg.isNotEmpty) return msg.first.toString();
    }
  }
  return fallback;
}
