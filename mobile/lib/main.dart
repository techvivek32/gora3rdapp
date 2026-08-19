import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:go_router/go_router.dart';
import 'core/config/app_config.dart';
import 'core/di/injection.dart';
import 'core/localization/app_translations.dart';
import 'core/localization/locale_controller.dart';
import 'core/network/api_client.dart';
import 'core/router/app_router.dart';
import 'core/utils/install_referrer.dart';
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
    // ONLY a brand-new requirement floats the overlay + rings. Driver-assigned,
    // trip OTP and trip start/end pushes also carry a requirementId, so gate on the
    // type — otherwise the popup + ring fired for all of them.
    if ((data['type'] ?? '').toString() == 'new_requirement') {
      // Respect the user's alert toggle even from the background/terminated
      // isolate — no overlay, no ring when alerts are off.
      if (!await alertsEnabled()) return;
      // Overlay first so it appears immediately, then hold this isolate open for
      // the ring — it is killed as soon as this handler returns. Uses the user's
      // chosen NOTIFICATION tone (the tray channel is silent, app plays the sound).
      await showRequirementOverlay(Map<String, dynamic>.from(data));
      await playRequirementRing(awaitEnd: true, kind: RingKind.notification);
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

  // Restore the saved app language before the first frame.
  await LocaleController.instance.load();

  // Seed cached platform settings (e.g. App Suggested Fare toggle) from disk so
  // cards render correctly on first paint; refreshed from the server on load.
  await AppConfig.initFromPrefs();

  // If this install came from an invite link, grab the referral code Play passed
  // along. Not awaited — it must never delay first paint.
  captureInstallReferrer();

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

class _GoraCabsAppState extends State<GoraCabsApp> with WidgetsBindingObserver {
  late final AuthBloc _authBloc;
  late final GoRouter _router;
  StreamSubscription<AuthState>? _authSub;
  Timer? _sessionHeartbeat;
  bool _sessionReplacedShowing = false; // guards against stacking the popup

  /// Ping a cheap authed endpoint. If the account was deleted/blocked, the request
  /// 401s and the ApiClient interceptor forces sign-out — so a logged-out admin
  /// action ejects the user even while they sit on a cached screen (no request of
  /// their own would otherwise fire).
  Future<void> _checkSession() async {
    if (_authBloc.state is! AuthAuthenticated) return;
    try {
      await getIt<ApiClient>().get('/users/profile');
    } catch (_) {
      // A 401 here is handled by the ApiClient interceptor (force sign-out);
      // any other error is transient and ignored.
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _authBloc = getIt<AuthBloc>()..add(AuthCheckStatusEvent());
    _router = AppRouter.createRouter(_authBloc);

    // The session can no longer be renewed (account deleted by an admin, blocked or
    // deactivated) → sign out. The router redirects to login on AuthUnauthenticated.
    ApiClient.onSessionExpired = () {
      if (mounted) _authBloc.add(AuthLogoutEvent());
    };

    // This device was signed out because the same account logged in on another
    // phone. Show the popup FIRST (so the user knows why), and only log out when
    // they tap OK — logging out first navigated to /login and hid the popup.
    ApiClient.onSessionReplaced = () {
      if (!mounted || _sessionReplacedShowing) return;
      final ctx = AppRouter.rootNavigatorKey.currentContext;
      if (ctx == null) {
        _authBloc.add(AuthLogoutEvent()); // no UI context — just sign out
        return;
      }
      _sessionReplacedShowing = true;
      showDialog(
        context: ctx,
        barrierDismissible: false,
        builder: (dctx) => AlertDialog(
          title: const Text('Logged out'),
          content: const Text('This account was just logged in on another device.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dctx).pop();
                _sessionReplacedShowing = false;
                _authBloc.add(AuthLogoutEvent()); // log out AFTER OK
              },
              child: const Text('OK'),
            ),
          ],
        ),
      ).then((_) => _sessionReplacedShowing = false);
    };

    // The floating overlay runs in a separate Flutter engine and can't reach the
    // blocs, so mirror "may this user contact posters?" into SharedPreferences
    // whenever the auth state changes. Without this the overlay's Call/WhatsApp
    // buttons stay disabled for everyone.
    void onAuthState(AuthState state) {
      if (state is AuthAuthenticated) {
        saveOverlayContactFlag(Map<String, dynamic>.from(state.user as Map));
        // While signed in, re-check the session every 60s so an admin deletion is
        // caught even with no user activity.
        _sessionHeartbeat ??= Timer.periodic(const Duration(seconds: 60), (_) => _checkSession());
      } else if (state is AuthUnauthenticated) {
        clearOverlayContactFlag();
        _sessionHeartbeat?.cancel();
        _sessionHeartbeat = null;
      }
    }

    onAuthState(_authBloc.state); // in case auth already resolved
    _authSub = _authBloc.stream.listen(onAuthState);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Foregrounding is the moment a deleted user is most likely still staring at a
    // stale screen — verify the session right away.
    if (state == AppLifecycleState.resumed) _checkSession();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sessionHeartbeat?.cancel();
    ApiClient.onSessionExpired = null;
    ApiClient.onSessionReplaced = null;
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
          // Rebuild the whole app when the language changes so every `.tr` string
          // and the Material widgets re-render in the chosen locale.
          return ListenableBuilder(
            listenable: LocaleController.instance,
            builder: (context, _) => MaterialApp.router(
              // Rekey on language change so go_router tears down and rebuilds the
              // CURRENT page too — otherwise it only re-renders on next navigation.
              // The GoRouter keeps its location, so the same screen comes back.
              key: ValueKey(LocaleController.instance.lang),
              title: 'Gora Cabs',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              themeMode: ThemeMode.light,
              locale: LocaleController.instance.locale,
              supportedLocales: kSupportedLocales,
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              routerConfig: _router,
            ),
          );
        },
      ),
    );
  }
}
