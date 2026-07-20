import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import '../config/env.dart';

class ApiClient {
  static const _baseUrl = Env.apiBaseUrl;

  /// Called once when the session can no longer be renewed — i.e. the refresh
  /// token was rejected because the account was deleted, blocked or deactivated.
  /// main.dart wires this up to sign the user out and send them to the login page.
  static void Function()? onSessionExpired;

  late final Dio _dio;
  final FlutterSecureStorage _storage;

  ApiClient(this._storage) {
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.addAll([
      _AuthInterceptor(_storage, _dio),
      if (const bool.fromEnvironment('dart.vm.product') == false)
        PrettyDioLogger(requestHeader: false, requestBody: true, responseBody: true),
    ]);
  }

  Dio get dio => _dio;

  Future<Response> get(String path, {Map<String, dynamic>? params}) =>
      _dio.get(path, queryParameters: params);

  Future<Response> post(String path, {dynamic data}) =>
      _dio.post(path, data: data);

  Future<Response> put(String path, {dynamic data}) =>
      _dio.put(path, data: data);

  Future<Response> delete(String path) => _dio.delete(path);

  Future<Response> patch(String path, {dynamic data}) =>
      _dio.patch(path, data: data);
}

class _AuthInterceptor extends Interceptor {
  final FlutterSecureStorage _storage;
  final Dio _dio;

  /// Guards against a burst of 401s (several in-flight requests) each firing a logout.
  static bool _signingOut = false;

  _AuthInterceptor(this._storage, this._dio);

  Future<void> _forceSignOut() async {
    if (_signingOut) return;
    _signingOut = true;
    await _storage.deleteAll();
    ApiClient.onSessionExpired?.call();
    // Allow a future session to expire again after this one is handled.
    Future.delayed(const Duration(seconds: 3), () => _signingOut = false);
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await _storage.read(key: 'access_token');
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      // A 401 from the refresh endpoint itself means the account is gone, blocked
      // or deactivated. Never try to refresh a refresh (that recurses forever) —
      // sign out immediately.
      if (err.requestOptions.path.contains('/auth/refresh')) {
        await _forceSignOut();
        return handler.next(err);
      }

      // Try to refresh token
      final refreshToken = await _storage.read(key: 'refresh_token');
      final userId = await _storage.read(key: 'user_id');

      // A logged-in user with no refresh token can't recover — sign out.
      if (refreshToken == null || userId == null) {
        final hadSession = await _storage.read(key: 'access_token') != null;
        if (hadSession) await _forceSignOut();
      } else {
        try {
          final response = await _dio.post('/auth/refresh',
              data: {'userId': userId, 'refreshToken': refreshToken});

          final newToken = response.data['data']['accessToken'];
          await _storage.write(key: 'access_token', value: newToken);

          // Retry original request with refreshed token.
          // FormData streams are consumed on first use, so multipart retries
          // will fail here — that's handled by the caller, not by wiping tokens.
          err.requestOptions.headers['Authorization'] = 'Bearer $newToken';
          try {
            final retried = await _dio.request(
              err.requestOptions.path,
              options: Options(
                method: err.requestOptions.method,
                headers: err.requestOptions.headers,
              ),
              data: err.requestOptions.data,
              queryParameters: err.requestOptions.queryParameters,
            );
            return handler.resolve(retried);
          } catch (_) {
            // Retry failed (e.g. FormData consumed) but token was refreshed —
            // do NOT delete storage; just propagate the original error.
            return handler.next(err);
          }
        } on DioException catch (e) {
          // Only sign out when the refresh is DEFINITIVELY rejected: 401/403 means
          // the refresh token is invalid/expired/revoked or the account is gone or
          // blocked. A network blip, timeout, or 5xx (server restart, deploy, brief
          // outage) must NOT log the user out — otherwise ONE transient failure on
          // any of the frequent token refreshes permanently kicks them out. Leave
          // the session intact; the next request simply retries the refresh.
          final code = e.response?.statusCode;
          if (code == 401 || code == 403) {
            await _forceSignOut();
          }
          // else: transient — fall through and propagate the original error only.
        } catch (_) {
          // Non-Dio error (parsing, etc.) — treat as transient, keep the session.
        }
      }
    }
    handler.next(err);
  }
}
