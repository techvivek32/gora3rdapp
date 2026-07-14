import 'dart:convert';

import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/error/error_mapper.dart';
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
  Future<Either<Failure, void>> sendLoginOtp(String mobile) async {
    try {
      await remote.loginSendOtp(mobile);
      return const Right(null);
    } catch (e) {
      // 404 = no account for this number. Flagged as its own failure so the login
      // page can route the user to Register rather than just showing an error.
      if (e is DioException && e.response?.statusCode == 404) {
        return Left(NotRegisteredFailure(message: ErrorMapper.message(e)));
      }
      return Left(ServerFailure(message: ErrorMapper.message(e)));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> loginWithOtp({required String mobile, required String otp, String? fcmToken}) async {
    try {
      final result = await remote.loginVerifyOtp(mobile, otp, fcmToken);
      final data = result['data'] as Map<String, dynamic>;
      await _saveTokens(data);
      return Right(data);
    } catch (e) {
      return Left(ServerFailure(message: ErrorMapper.message(e)));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> register({required String fullName, required String mobile, String? email, String? password, String? agencyName, String? city, String? state, String role = 'driver', String? otp, String? referralCode}) async {
    try {
      final result = await remote.register({
        'fullName': fullName, 'mobile': mobile,
        if (email != null && email.isNotEmpty) 'email': email,
        if (password != null && password.isNotEmpty) 'password': password,
        if (agencyName != null) 'agencyName': agencyName,
        if (city != null) 'city': city,
        if (state != null) 'state': state,
        'role': role,
        if (otp != null) 'otp': otp,
        if (referralCode != null && referralCode.isNotEmpty) 'referralCode': referralCode,
      });
      final data = result['data'] as Map<String, dynamic>;
      await _saveTokens(data);
      return Right(data);
    } catch (e) {
      return Left(ServerFailure(message: ErrorMapper.message(e)));
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
  Future<Either<Failure, Map<String, dynamic>>> getProfile() async {
    try {
      final result = await remote.getProfile();
      final user = result['data'] as Map<String, dynamic>;
      await storage.write(key: 'user_data', value: jsonEncode(user));
      return Right(user);
    } catch (e) {
      return Left(ServerFailure(message: e.toString().replaceAll('Exception: ', '')));
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
        final decodedUser = jsonDecode(userJson) as Map<String, dynamic>;
        return decodedUser;
      }
      return {'_id': userId};
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

  @override
  Future<Either<Failure, Map<String, dynamic>>> updateProfile(Map<String, dynamic> data) async {
    try {
      final result = await remote.updateProfile(data);
      final user = result['data'] as Map<String, dynamic>;
      await storage.write(key: 'user_data', value: jsonEncode(user));
      return Right(user);
    } catch (e) {
      return Left(ServerFailure(message: e.toString().replaceAll('Exception: ', '')));
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
      // Save user data as JSON string
      await storage.write(key: 'user_data', value: jsonEncode(user));
    }
  }
}
