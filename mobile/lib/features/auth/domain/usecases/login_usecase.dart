import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/auth_repository.dart';

class LoginParams {
  final String identifier;
  final String password;
  final String? fcmToken;
  LoginParams({required this.identifier, required this.password, this.fcmToken});
}

class LoginUseCase {
  final AuthRepository repository;
  LoginUseCase(this.repository);

  Future<Either<Failure, Map<String, dynamic>>> call(LoginParams params) {
    return repository.login(
      identifier: params.identifier,
      password: params.password,
      fcmToken: params.fcmToken,
    );
  }
}
