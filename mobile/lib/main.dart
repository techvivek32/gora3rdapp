import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:go_router/go_router.dart';
import 'core/di/injection.dart';
import 'core/network/api_client.dart';
import 'core/router/app_router.dart';
import 'core/utils/membership.dart';
import 'core/utils/ring_player.dart';
import 'core/services/push_notification_service.dart';
import 'core/theme/app_theme.dart';
import 'features/requirements/presentation/widgets/requirement_overlay.dart';
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
    // App is in the background/terminated — float the requirement card over
    // whatever the user is doing (Truecaller-style), if it's a requirement push
    // and the "Display over other apps" permission was granted.
    final data = message.data;
    if ((data['requirementId'] ?? '').toString().isNotEmpty) {
      await playRequirementRing();
      await showRequirementOverlay(Map<String, dynamic>.from(data));
    }
  } catch (e) {
    debugPrint('Firebase background handler error: $e');
  }
}

/// Separate Flutter entry point that renders the floating overlay window.
/// Referenced by name ("overlayMain") from the native OverlayService.
@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RequirementOverlay());
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

  // Push notifications (permission, channel, foreground/tap handlers)
  await PushNotificationService.instance.init();

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

class GoraCabsApp extends StatefulWidget {
  const GoraCabsApp({super.key});

  @override
  State<GoraCabsApp> createState() => _GoraCabsAppState();
}

class _GoraCabsAppState extends State<GoraCabsApp> {
  late final AuthBloc _authBloc;
  late final GoRouter _router;
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    _authBloc = getIt<AuthBloc>()..add(AuthCheckStatusEvent());
    _router = AppRouter.createRouter(_authBloc);

    // The session can no longer be renewed (account deleted by an admin, blocked or
    // deactivated) → sign out. The router redirects to login on AuthUnauthenticated.
    ApiClient.onSessionExpired = () {
      if (mounted) _authBloc.add(AuthLogoutEvent());
    };

    // The floating overlay runs in a separate Flutter engine and can't reach the
    // blocs, so mirror "may this user contact posters?" into SharedPreferences
    // whenever the auth state changes. Without this the overlay's Call/WhatsApp
    // buttons stay disabled for everyone.
    void syncOverlayFlag(AuthState state) {
      if (state is AuthAuthenticated) {
        saveOverlayContactFlag(Map<String, dynamic>.from(state.user as Map));
      } else if (state is AuthUnauthenticated) {
        clearOverlayContactFlag();
      }
    }

    syncOverlayFlag(_authBloc.state); // in case auth already resolved
    _authSub = _authBloc.stream.listen(syncOverlayFlag);
  }

  @override
  void dispose() {
    ApiClient.onSessionExpired = null;
    _authSub?.cancel();
    _authBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: _authBloc),
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
            themeMode: ThemeMode.light,
            routerConfig: _router,
          );
        },
      ),
    );
  }
}
