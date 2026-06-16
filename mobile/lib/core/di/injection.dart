import 'package:get_it/get_it.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../network/api_client.dart';
import '../../features/auth/data/datasources/auth_remote_datasource.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/login_usecase.dart';
import '../../features/auth/domain/usecases/register_usecase.dart';
import '../../features/auth/domain/usecases/verify_otp_usecase.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';

import '../../features/requirements/data/datasources/requirements_remote_datasource.dart';
import '../../features/requirements/data/repositories/requirements_repository_impl.dart';
import '../../features/requirements/domain/repositories/requirements_repository.dart';
import '../../features/requirements/presentation/bloc/requirements_bloc.dart';

import '../../features/available_vehicles/data/repositories/vehicles_repository_impl.dart';
import '../../features/available_vehicles/domain/repositories/vehicles_repository.dart';
import '../../features/available_vehicles/presentation/bloc/vehicles_bloc.dart';

import '../../features/notifications/presentation/bloc/notification_bloc.dart';
import '../../features/chat/presentation/bloc/chat_bloc.dart';
import '../../features/home/presentation/bloc/home_bloc.dart';
import '../../features/subscriptions/presentation/bloc/subscription_bloc.dart';

final getIt = GetIt.instance;

Future<void> configureDependencies() async {
  // Core
  const storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  final prefs = await SharedPreferences.getInstance();

  getIt.registerSingleton(storage);
  getIt.registerSingleton(prefs);
  getIt.registerSingleton(ApiClient(storage));

  // Auth
  getIt.registerLazySingleton<AuthRemoteDataSource>(
      () => AuthRemoteDataSourceImpl(getIt<ApiClient>()));
  getIt.registerLazySingleton<AuthRepository>(
      () => AuthRepositoryImpl(getIt<AuthRemoteDataSource>(), getIt<FlutterSecureStorage>()));
  getIt.registerLazySingleton(() => LoginUseCase(getIt<AuthRepository>()));
  getIt.registerLazySingleton(() => RegisterUseCase(getIt<AuthRepository>()));
  getIt.registerLazySingleton(() => VerifyOtpUseCase(getIt<AuthRepository>()));
  getIt.registerFactory(() => AuthBloc(
    loginUseCase: getIt<LoginUseCase>(),
    registerUseCase: getIt<RegisterUseCase>(),
    verifyOtpUseCase: getIt<VerifyOtpUseCase>(),
    repository: getIt<AuthRepository>(),
  ));

  // Requirements
  getIt.registerLazySingleton<RequirementsRemoteDataSource>(
      () => RequirementsRemoteDataSourceImpl(getIt<ApiClient>()));
  getIt.registerLazySingleton<RequirementsRepository>(
      () => RequirementsRepositoryImpl(getIt<RequirementsRemoteDataSource>()));
  getIt.registerFactory(() => RequirementsBloc(getIt<RequirementsRepository>()));

  // Vehicles
  getIt.registerLazySingleton<VehiclesRepository>(
      () => VehiclesRepositoryImpl(getIt<ApiClient>()));
  getIt.registerFactory(() => VehiclesBloc(getIt<VehiclesRepository>()));

  // Other BLoCs
  getIt.registerFactory(() => HomeBloc(getIt<ApiClient>(), getIt<SharedPreferences>()));
  getIt.registerFactory(() => NotificationBloc(getIt<ApiClient>()));
  getIt.registerFactory(() => ChatBloc(getIt<ApiClient>()));
  getIt.registerFactory(() => SubscriptionBloc(getIt<ApiClient>()));
}
