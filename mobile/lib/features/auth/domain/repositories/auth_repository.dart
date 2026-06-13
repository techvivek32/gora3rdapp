import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';

abstract class AuthRepository {
  Future<Either<Failure, Map<String, dynamic>>> login({
    required String identifier,
    required String password,
    String? fcmToken,
  });

  Future<Either<Failure, Map<String, dynamic>>> register({
    required String fullName,
    required String mobile,
    required String email,
    required String password,
    String? agencyName,
    String? city,
    String? state,
    String role = 'driver',
  });

  Future<Either<Failure, Map<String, dynamic>>> verifyOtp({
    required String firebaseIdToken,
    String? fcmToken,
  });

  Future<Either<Failure, void>> logout();

  Future<Map<String, dynamic>?> getCurrentUser();

  Future<Either<Failure, Map<String, dynamic>>> refreshTokens();
}
