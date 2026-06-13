import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'core/di/injection.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/requirements/presentation/bloc/requirements_bloc.dart';
import 'features/available_vehicles/presentation/bloc/vehicles_bloc.dart';
import 'features/notifications/presentation/bloc/notification_bloc.dart';
import 'features/chat/presentation/bloc/chat_bloc.dart';
import 'features/home/presentation/bloc/home_bloc.dart';
import 'features/subscriptions/presentation/bloc/subscription_bloc.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
    debugPrint('Background FCM: ${message.notification?.title}');
  } catch (e) {
    debugPrint('Firebase background handler error: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase (optional - app works without it)
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint('Firebase initialization skipped: $e');
  }

  // Dependency Injection
  await configureDependencies();

  // Orientation
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Status bar style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const GoraCabsApp());
}

class GoraCabsApp extends StatelessWidget {
  const GoraCabsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(create: (_) => getIt<AuthBloc>()..add(AuthCheckStatusEvent())),
        BlocProvider<HomeBloc>(create: (_) => getIt<HomeBloc>()),
        BlocProvider<RequirementsBloc>(create: (_) => getIt<RequirementsBloc>()),
        BlocProvider<VehiclesBloc>(create: (_) => getIt<VehiclesBloc>()),
        BlocProvider<NotificationBloc>(create: (_) => getIt<NotificationBloc>()),
        BlocProvider<ChatBloc>(create: (_) => getIt<ChatBloc>()),
        BlocProvider<SubscriptionBloc>(create: (_) => getIt<SubscriptionBloc>()),
      ],
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        minTextAdapt: true,
        splitScreenMode: true,
        builder: (context, child) {
          return MaterialApp.router(
            title: 'Gora Cabs',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.system,
            routerConfig: AppRouter.router,
          );
        },
      ),
    );
  }
}
