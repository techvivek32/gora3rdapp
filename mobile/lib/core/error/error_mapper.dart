import 'package:dio/dio.dart';

/// Converts low-level errors (mainly [DioException]) into short, user-friendly
/// messages so raw exception text never reaches the UI.
class ErrorMapper {
  static String message(Object error) {
    if (error is DioException) return _fromDio(error);
    return _clean(error.toString());
  }

  static String _fromDio(DioException err) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Request timed out. Please try again.';
      case DioExceptionType.connectionError:
        return 'Unable to connect. Please check your internet connection.';
      case DioExceptionType.cancel:
        return 'Request cancelled.';
      case DioExceptionType.badCertificate:
        return 'Unable to connect securely to the server.';
      case DioExceptionType.badResponse:
        return _fromResponse(err);
      case DioExceptionType.unknown:
        if (err.response == null) {
          return 'Unable to connect. Please check your internet connection.';
        }
        return _fromResponse(err);
    }
  }

  /// Pull the backend's own message out of the response body when present,
  /// otherwise fall back to a status-code-based message.
  static String _fromResponse(DioException err) {
    final status = err.response?.statusCode;
    final data = err.response?.data;

    final serverMsg = _extractMessage(data);
    if (serverMsg != null && serverMsg.isNotEmpty) return serverMsg;

    switch (status) {
      case 400:
        return 'Invalid request. Please check your details.';
      case 401:
        return 'Invalid credentials.';
      case 403:
        return 'You don\'t have permission to do that.';
      case 404:
        return 'Not found.';
      case 409:
        return 'This number or email is already registered.';
      case 422:
        return 'Invalid request. Please check your details.';
      case 429:
        return 'Too many attempts. Please wait and try again.';
      default:
        if (status != null && status >= 500) {
          return 'Server error. Please try again later.';
        }
        return 'Something went wrong. Please try again.';
    }
  }

  /// Backend shapes: `{ message: "..." }`, `{ message: ["a", "b"] }`
  /// (NestJS validation), or a plain string body.
  static String? _extractMessage(dynamic data) {
    if (data == null) return null;
    if (data is String) return data.isEmpty ? null : data;
    if (data is Map) {
      final msg = data['message'] ?? data['error'];
      if (msg is String) return msg;
      if (msg is List && msg.isNotEmpty) return msg.first.toString();
    }
    return null;
  }

  static String _clean(String raw) => raw.replaceAll('Exception: ', '').trim();
}
