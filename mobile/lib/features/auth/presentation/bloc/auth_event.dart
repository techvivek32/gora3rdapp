part of 'auth_bloc.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();
  @override
  List<Object?> get props => [];
}

class AuthCheckStatusEvent extends AuthEvent {}

class AuthLoginEvent extends AuthEvent {
  final String identifier;
  final String password;
  final String? fcmToken;
  const AuthLoginEvent({required this.identifier, required this.password, this.fcmToken});
  @override
  List<Object?> get props => [identifier, password];
}

class AuthRegisterEvent extends AuthEvent {
  final String fullName;
  final String mobile;
  final String email;
  final String password;
  final String? agencyName;
  final String? city;
  final String? state;
  final String role;
  const AuthRegisterEvent({
    required this.fullName, required this.mobile, required this.email,
    required this.password, this.agencyName, this.city, this.state,
    this.role = 'driver',
  });
  @override
  List<Object?> get props => [email, mobile];
}

class AuthVerifyOtpEvent extends AuthEvent {
  final String firebaseIdToken;
  final String? fcmToken;
  const AuthVerifyOtpEvent({required this.firebaseIdToken, this.fcmToken});
  @override
  List<Object?> get props => [firebaseIdToken];
}

class AuthLogoutEvent extends AuthEvent {}
