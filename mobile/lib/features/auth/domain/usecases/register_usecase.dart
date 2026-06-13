import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/auth_repository.dart';

class RegisterParams {
  final String fullName, mobile, email, password;
  final String? agencyName, city, state;
  final String role;
  RegisterParams({required this.fullName, required this.mobile, required this.email, required this.password, this.agencyName, this.city, this.state, this.role = 'driver'});
}

class RegisterUseCase {
  final AuthRepository repository;
  RegisterUseCase(this.repository);

  Future<Either<Failure, Map<String, dynamic>>> call(RegisterParams params) {
    return repository.register(
      fullName: params.fullName, mobile: params.mobile, email: params.email,
      password: params.password, agencyName: params.agencyName, city: params.city,
      state: params.state, role: params.role,
    );
  }
}
