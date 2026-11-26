import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

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
import 'core/utils/alert_actions.dart';
import 'core/utils/ring_player.dart';
import 'core/utils/alert_gate.dart';
import 'core/utils/crash_reporter.dart';
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
    // App is in the background/terminated — float the alert card over whatever
    // the user is doing (Truecaller-style), if it's a new-work push and the
    // "Display over other apps" permission was granted.
    final data = message.data;
    // ONLY new work floats the overlay + rings: a new requirement, a new customer
    // booking or a newly listed available car. Driver-assigned, trip OTP and trip
    // start/end pushes also carry a requirementId, so gate on the type —
    // otherwise the popup + ring fired for all of them.
    if (isLoudAlertType((data['type'] ?? '').toString())) {
      // Respect the user's alert toggle even from the background/terminated
      // isolate — no overlay, no ring when alerts are off.
      if (!await alertsEnabled()) return;

      // The same booking arriving twice is a repeat: it has already been seen
      // and heard, so drop it outright. This is the ONLY case that is silent.
      final key = '${data['requirementId'] ?? data['bookingId'] ?? ''}';
      if (await AlertGate.isDuplicate(key)) return;

      // Everything below decides whether to show a CARD. The tone is played
      // either way, and that is the point.
      //
      // The tray entry the server posts lands on a channel the app creates
      // with `playSound: false`, because when the card shows, the app plays
      // the user's chosen tone and two sounds at once is worse than one. The
      // cost was that every path which skipped the tone left the booking
      // completely mute — offline, and a second booking refused the window.
      // That is what "sometimes there is no sound" was: not a lost push, a
      // silent one.
      //
      //   offline              → tone, no card   (the "I'm not working" switch
      //                                           silences the pop-up, not the
      //                                           notification)
      //   window already busy  → tone, no card   (one overlay window to go
      //                                           round; the audio player is
      //                                           per-isolate and never was
      //                                           part of the hang this gate
      //                                           was written to stop)
      //   otherwise            → tone + card
      final showCard = await isOnline() && await AlertGate.takeWindow();
      if (showCard) {
        try {
          // Overlay first so it appears immediately, then hold this isolate
          // open for the ring — it is killed as soon as this handler returns.
          await showRequirementOverlay(Map<String, dynamic>.from(data));
        } finally {
          // Freed as soon as the card is up, so a genuinely new booking
          // seconds later still gets a card instead of waiting out the lease.
          await AlertGate.release();
        }
      }
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
  // This engine has no plugins registered, so Crashlytics cannot run here —
  // but an unhandled async error would still take the process down, and this
  // process is the one showing the driver a booking. Swallow and log instead:
  // a broken overlay card is recoverable, a dead app is not.
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Overlay isolate error: $error');
    return true;
  };
  FlutterError.onError = (details) => debugPrint('Overlay error: ${details.exception}');
  runApp(const RequirementOverlay());
}

/// Runs one startup step and refuses to let it take the launch down.
///
/// Every one of these used to be a bare `await` in [main], before `runApp`.
/// A throw in any of them — a corrupt prefs file, a plugin that fails to
/// register, a null from secure storage on a device where the keystore was
/// reset — killed the process before a single frame was drawn, so the user saw
/// the app die on launch and Play recorded a user-perceived crash. Worse, the
/// cause persists: the same user crashes on every launch, which is how a
/// handful of bad devices drags the crash rate up.
///
/// None of these steps is required for the app to show its first screen; each
/// one degrades on its own (no DI resolves to an error screen, no push means no
/// alerts, no locale means English, no cached settings means defaults).
Future<void> _startupStep(String name, Future<void> Function() run) async {
  try {
    await run();
  } catch (e, stack) {
    debugPrint('Startup step "$name" failed: $e');
    await CrashReporter.record(e, stack, reason: 'startup/$name');
  }
}

/// Portrait is locked on phones only.
///
/// Play Console asks us to "remove resizability and orientation restrictions to
/// support large screen devices". The app was calling
/// `setPreferredOrientations([portraitUp])` unconditionally, which is a runtime
/// `setRequestedOrientation` and is exactly what that check looks for.
///
/// On Android 16 the lock is void on large screens anyway: for apps targeting
/// SDK 36 the system ignores orientation and resizability restrictions on any
/// display at least 600dp wide. So tablets and unfolded foldables already
/// rotate — this just stops fighting them, and leaves phones exactly as they
/// were, where 62 portrait-designed screens stay portrait.
void _applyOrientationPolicy() {
  final view = WidgetsBinding.instance.platformDispatcher.implicitView;
  final shortestSide = view == null
      ? 0.0
      : (view.physicalSize / view.devicePixelRatio).shortestSide;
  // 0 means the view is not laid out yet — treat an unknown screen as a phone.
  final isPhone = shortestSide <= 0 || shortestSide < 600;
  SystemChrome.setPreferredOrientations(
    isPhone
        ? const [DeviceOrientation.portraitUp]
        : const [
            DeviceOrientation.portraitUp,
            DeviceOrientation.portraitDown,
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ],
  );
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

  // Crash reporting, as early as possible so the startup steps below are
  // covered. Installs the two global handlers as well — see CrashReporter.
  await CrashReporter.init();

  // Cheap, local, and the first screen genuinely needs them: DI builds the
  // blocs, and locale and settings are two SharedPreferences reads that decide
  // what the first frame says.
  await _startupStep('dependencies', configureDependencies);
  await _startupStep('locale', LocaleController.instance.load);
  await _startupStep('settings', AppConfig.initFromPrefs);

  // Push setup runs AFTER the first frame, and is not awaited.
  //
  // It used to be awaited here, and inside it is
  // `FirebaseMessaging.requestPermission()` — which puts up the Android 13+
  // notification dialog and waits for an answer. So on a fresh install the
  // whole of main() stopped on that dialog, and because runApp had not been
  // reached yet there was nothing behind it: the very first thing a new user
  // saw was a permission prompt floating on an empty window, for as long as
  // they took to decide. Verified on an emulator — the UI appeared the instant
  // the dialog was dismissed, not before.
  //
  // Nothing on the first screen needs push to be ready, so it waits its turn.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _startupStep('push', PushNotificationService.instance.init);
  });

  // If this install came from an invite link, grab the referral code Play passed
  // along. Not awaited — it must never delay first paint.
  captureInstallReferrer();

  _applyOrientationPolicy();

  // Icon brightness only.
  //
  // `statusBarColor: Colors.transparent` used to be set here too, and that is
  // what Play Console flagged as "your app uses deprecated APIs or parameters
  // for edge-to-edge". It compiles to Window.setStatusBarColor(), deprecated at
  // API 35 and a no-op at API 36 — so the line had stopped doing anything on
  // the devices it was written for, while still being the thing being reported.
  //
  // There is deliberately no setEnabledSystemUIMode(edgeToEdge) call to go with
  // this. The app targets SDK 36, and Flutter already uses edgeToEdge by
  // default there with no way to opt out, so calling it would be a no-op that
  // reads like a fix. Under edge-to-edge the bars are transparent by
  // definition, which is what the removed line was asking for anyway.
  //
  // What edge-to-edge actually needs from us is that screens respect the
  // insets, since the system bars now sit on top of the app rather than beside
  // it — see the bottom-inset handling in location_picker_page.
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light, // iOS equivalent
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
        final user = Map<String, dynamic>.from(state.user as Map);
        saveOverlayContactFlag(user);
        // So a crash report can answer "which account?" without carrying a
        // phone number into Crashlytics.
        CrashReporter.setUser('${user['_id'] ?? user['id'] ?? ''}');
        // While signed in, re-check the session every 60s so an admin deletion is
        // caught even with no user activity.
        _sessionHeartbeat ??= Timer.periodic(const Duration(seconds: 60), (_) => _checkSession());
      } else if (state is AuthUnauthenticated) {
        clearOverlayContactFlag();
        CrashReporter.setUser(null);
        _sessionHeartbeat?.cancel();
        _sessionHeartbeat = null;
      }
    }

    onAuthState(_authBloc.state); // in case auth already resolved
    _authSub = _authBloc.stream.listen(onAuthState);
  }

  @override
  void didChangeMetrics() {
    // A foldable opening changes the screen from phone-sized to tablet-sized
    // while the app is running. The policy is decided from the screen width, so
    // it has to be re-decided here or an unfolded device stays portrait-locked —
    // which is the restriction Play asked us to drop.
    _applyOrientationPolicy();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Foregrounding is the moment a deleted user is most likely still staring at a
    // stale screen — verify the session right away.
    if (state == AppLifecycleState.resumed) _checkSession();

    // The floating bubble is a way BACK INTO the app from somewhere else, so it
    // has no job while Gora is the app on screen — there it is just a circle
    // sitting on top of our own UI, and being a system overlay it swallows
    // taps on whatever is beneath it (it ate the "Secure this booking" switch
    // on the edit form, which read as a dead control).
    //
    // So: take it away on resume, put it back when the app goes away. Both are
    // no-ops when the partner is offline — `showOnlineBubble` checks that
    // itself, and `hideOnlineBubble` on an absent overlay does nothing.
    if (state == AppLifecycleState.resumed) {
      hideOnlineBubble();
      _runPendingAlertAction();
    } else if (state == AppLifecycleState.paused) {
      showOnlineBubble();
    }
  }

  /// Carry out whatever the floating overlay parked before bringing us forward.
  ///
  /// The overlay runs in its own engine with no router, so tapping Chat or
  /// Accept there can only leave a note and open the app; this is the other
  /// half of that hand-off. Nothing parked is the normal case, and costs one
  /// SharedPreferences read.
  Future<void> _runPendingAlertAction() async {
    final pending = await consumePendingAlertAction();
    if (pending == null) return;
    // Read the root navigator's context fresh, after the await — so there is
    // nothing stale to guard against, and null simply means the app is going
    // away. (A `mounted` check here would be about the wrong widget.)
    final ctx = AppRouter.rootNavigatorKey.currentContext;
    if (ctx == null) return;
    switch (pending.kind) {
      case AlertAction.chat:
        await openChatWith(ctx, pending.id, requirementId: pending.requirementId);
        break;
      case AlertAction.accept:
        openCustomerBookingToAccept(ctx, pending.id);
        break;
      case AlertAction.contact:
        break; // nothing to route to — Call/WhatsApp leave the app themselves
    }
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
