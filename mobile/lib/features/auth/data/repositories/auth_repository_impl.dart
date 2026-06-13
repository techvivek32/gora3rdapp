import 'package:dartz/dartz.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/error/failures.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remote;
  final FlutterSecureStorage storage;

  AuthRepositoryImpl(this.remote, this.storage);

  @override
  Future<Either<Failure, Map<String, dynamic>>> login({required String identifier, required String password, String? fcmToken}) async {
    try {
      final result = await remote.login(identifier, password, fcmToken);
      final data = result['data'] as Map<String, dynamic>;
      await _saveTokens(data);
      return Right(data);
    } catch (e) {
      return Left(ServerFailure(message: e.toString().replaceAll('Exception: ', '')));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> register({required String fullName, required String mobile, required String email, required String password, String? agencyName, String? city, String? state, String role = 'driver'}) async {
    try {
      final result = await remote.register({
        'fullName': fullName, 'mobile': mobile, 'email': email, 'password': password,
        if (agencyName != null) 'agencyName': agencyName,
        if (city != null) 'city': city,
        if (state != null) 'state': state,
        'role': role,
      });
      final data = result['data'] as Map<String, dynamic>;
      await _saveTokens(data);
      return Right(data);
    } catch (e) {
      return Left(ServerFailure(message: e.toString().replaceAll('Exception: ', '')));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> verifyOtp({required String firebaseIdToken, String? fcmToken}) async {
    try {
      final result = await remote.verifyOtp(firebaseIdToken, fcmToken);
      final data = result['data'] as Map<String, dynamic>;
      await _saveTokens(data);
      return Right(data);
    } catch (e) {
      return Left(AuthFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> logout() async {
    try {
      final fcmToken = await storage.read(key: 'fcm_token');
      await remote.logout(fcmToken);
      await storage.deleteAll();
      return const Right(null);
    } catch (e) {
      await storage.deleteAll();
      return const Right(null);
    }
  }

  @override
  Future<Map<String, dynamic>?> getCurrentUser() async {
    try {
      final token = await storage.read(key: 'access_token');
      final userId = await storage.read(key: 'user_id');
      final userJson = await storage.read(key: 'user_data');
      if (token == null || userId == null) return null;
      if (userJson != null) {
        // Return cached user data
        return {'_id': userId};
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> refreshTokens() async {
    try {
      final userId = await storage.read(key: 'user_id');
      final refreshToken = await storage.read(key: 'refresh_token');
      if (userId == null || refreshToken == null) {
        return Left(AuthFailure(message: 'No refresh token'));
      }
      final result = await remote.refreshTokens(userId, refreshToken);
      await _saveTokens(result['data'] as Map<String, dynamic>);
      return Right(result['data'] as Map<String, dynamic>);
    } catch (e) {
      return Left(AuthFailure(message: e.toString()));
    }
  }

  Future<void> _saveTokens(Map<String, dynamic> data) async {
    if (data['accessToken'] != null) {
      await storage.write(key: 'access_token', value: data['accessToken']);
    }
    if (data['refreshToken'] != null) {
      await storage.write(key: 'refresh_token', value: data['refreshToken']);
    }
    final user = data['user'];
    if (user != null && user['_id'] != null) {
      await storage.write(key: 'user_id', value: user['_id']);
    }
  }
}
