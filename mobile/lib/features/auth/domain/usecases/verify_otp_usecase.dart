import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/auth_repository.dart';

class VerifyOtpParams {
  final String firebaseIdToken;
  final String? fcmToken;
  VerifyOtpParams({required this.firebaseIdToken, this.fcmToken});
}

class VerifyOtpUseCase {
  final AuthRepository repository;
  VerifyOtpUseCase(this.repository);

  Future<Either<Failure, Map<String, dynamic>>> call(VerifyOtpParams params) {
    return repository.verifyOtp(firebaseIdToken: params.firebaseIdToken, fcmToken: params.fcmToken);
  }
}
