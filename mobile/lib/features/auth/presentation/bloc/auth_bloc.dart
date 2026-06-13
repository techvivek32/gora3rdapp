import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/login_usecase.dart';
import '../../domain/usecases/register_usecase.dart';
import '../../domain/usecases/verify_otp_usecase.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final LoginUseCase loginUseCase;
  final RegisterUseCase registerUseCase;
  final VerifyOtpUseCase verifyOtpUseCase;
  final AuthRepository repository;

  AuthBloc({
    required this.loginUseCase,
    required this.registerUseCase,
    required this.verifyOtpUseCase,
    required this.repository,
  }) : super(AuthInitial()) {
    on<AuthCheckStatusEvent>(_onCheckStatus);
    on<AuthLoginEvent>(_onLogin);
    on<AuthRegisterEvent>(_onRegister);
    on<AuthVerifyOtpEvent>(_onVerifyOtp);
    on<AuthLogoutEvent>(_onLogout);
  }

  Future<void> _onCheckStatus(AuthCheckStatusEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    final user = await repository.getCurrentUser();
    if (user != null) {
      emit(AuthAuthenticated(user: user));
    } else {
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onLogin(AuthLoginEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    final result = await loginUseCase(LoginParams(
      identifier: event.identifier,
      password: event.password,
      fcmToken: event.fcmToken,
    ));
    result.fold(
      (failure) => emit(AuthError(message: failure.message)),
      (authData) => emit(AuthAuthenticated(user: Map<String, dynamic>.from(authData['user'] as Map? ?? authData))),
    );
  }

  Future<void> _onRegister(AuthRegisterEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    final result = await registerUseCase(RegisterParams(
      fullName: event.fullName,
      mobile: event.mobile,
      email: event.email,
      password: event.password,
      agencyName: event.agencyName,
      city: event.city,
      state: event.state,
      role: event.role,
    ));
    result.fold(
      (failure) => emit(AuthError(message: failure.message)),
      (authData) => emit(AuthAuthenticated(user: Map<String, dynamic>.from(authData['user'] as Map? ?? authData))),
    );
  }

  Future<void> _onVerifyOtp(AuthVerifyOtpEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    final result = await verifyOtpUseCase(VerifyOtpParams(
      firebaseIdToken: event.firebaseIdToken,
      fcmToken: event.fcmToken,
    ));
    result.fold(
      (failure) => emit(AuthError(message: failure.message)),
      (authData) => emit(AuthAuthenticated(user: Map<String, dynamic>.from(authData['user'] as Map? ?? authData))),
    );
  }

  Future<void> _onLogout(AuthLogoutEvent event, Emitter<AuthState> emit) async {
    await repository.logout();
    emit(AuthUnauthenticated());
  }
}
