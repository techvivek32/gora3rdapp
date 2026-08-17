import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/pages/splash_page.dart';
import '../../features/auth/presentation/pages/onboarding_page.dart';
import '../../features/auth/presentation/pages/welcome_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/pages/otp_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/home/presentation/pages/select_city_page.dart';
import '../../features/requirements/presentation/pages/requirements_feed_page.dart';
import '../../features/requirements/presentation/pages/create_requirement_page.dart';
import '../../features/requirements/presentation/pages/requirement_detail_page.dart';
import '../../features/requirements/presentation/pages/my_requirements_page.dart';
import '../../features/available_vehicles/presentation/pages/vehicles_feed_page.dart';
import '../../features/available_vehicles/presentation/pages/create_vehicle_page.dart';
import '../../features/available_vehicles/presentation/pages/vehicle_detail_page.dart';
import '../../features/available_vehicles/presentation/pages/my_vehicles_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/profile/presentation/pages/kyc_page.dart';
import '../../features/profile/presentation/pages/sound_settings_page.dart';
import '../../features/info/presentation/pages/policy_page.dart';
import '../../features/wallet/presentation/pages/wallet_page.dart';
import '../../features/referral/presentation/pages/invite_page.dart';
import '../../features/garage/presentation/pages/my_garage_page.dart';
import '../localization/language_page.dart';
import '../../features/training/presentation/pages/training_videos_page.dart';
import '../../features/referral/presentation/pages/leaderboard_page.dart';
import '../../features/support/presentation/pages/support_chat_page.dart';
import '../../features/reports/presentation/pages/my_reports_page.dart';
import '../../features/users/presentation/pages/user_profile_page.dart';
import '../../features/chat/presentation/pages/chat_list_page.dart';
import '../../features/chat/presentation/pages/chat_room_page.dart';
import '../../features/notifications/presentation/pages/notifications_page.dart';
import '../../features/subscriptions/presentation/pages/subscription_plans_page.dart';
import '../../features/home/presentation/pages/main_nav_page.dart';

class _GoRouterRefreshStream extends ChangeNotifier {
  _GoRouterRefreshStream(Stream<dynamic> stream) {
    _sub = stream.listen((_) => notifyListeners());
  }
  late final StreamSubscription<dynamic> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

class AppRouter {
  static final rootNavigatorKey = GlobalKey<NavigatorState>();

  static GoRouter createRouter(AuthBloc authBloc) => GoRouter(
    navigatorKey: rootNavigatorKey,
    debugLogDiagnostics: true,
    initialLocation: '/splash',
    refreshListenable: _GoRouterRefreshStream(authBloc.stream),
    redirect: (context, state) {
      final authState = authBloc.state;
      final isAuthRoute = state.matchedLocation.startsWith('/auth');
      final isSplash = state.matchedLocation == '/splash';
      final isWelcome = state.matchedLocation == '/welcome';

      if (isSplash) return null;
      if (authState is AuthAuthenticated) {
        if (isAuthRoute || isWelcome) return '/';
        return null;
      }
      if (authState is AuthUnauthenticated) {
        if (!isAuthRoute && !isWelcome) return '/welcome';
        return null;
      }
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashPage()),
      GoRoute(path: '/welcome', builder: (_, __) => const WelcomePage()),
      GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingPage()),

      // Auth Routes
      GoRoute(path: '/auth/login', builder: (_, __) => const LoginPage()),
      GoRoute(
        path: '/auth/register',
        // ?mobile=… pre-fills the number when Login redirects an unregistered user.
        builder: (_, state) => RegisterPage(
          initialMobile: state.uri.queryParameters['mobile'],
        ),
      ),
      GoRoute(
        path: '/auth/otp',
        builder: (_, state) => OtpPage(phoneNumber: state.extra as String? ?? ''),
      ),

      // Main App Shell
      ShellRoute(
        builder: (context, state, child) => MainNavPage(child: child),
        routes: [
          GoRoute(path: '/', builder: (_, __) => const HomePage()),
          GoRoute(path: '/requirements', builder: (_, __) => const RequirementsFeedPage()),
          GoRoute(path: '/vehicles', builder: (_, __) => const VehiclesFeedPage()),
          GoRoute(path: '/profile', builder: (_, __) => const ProfilePage()),
        ],
      ),

      // Detail Routes
      GoRoute(
        path: '/my-requirements',
        // ?tab=2 deep-links to the Assigned tab (used by the assignment push).
        builder: (_, state) => MyRequirementsPage(
          initialTab: int.tryParse(state.uri.queryParameters['tab'] ?? '') ?? 0,
        ),
      ),
      GoRoute(
        path: '/requirements/create',
        builder: (_, __) => const CreateRequirementPage(),
      ),
      GoRoute(
        path: '/requirements/:id/edit',
        builder: (_, state) => CreateRequirementPage(
          requirementId: state.pathParameters['id']!,
          existing: state.extra as Map<String, dynamic>?,
        ),
      ),
      GoRoute(
        path: '/requirements/:id',
        builder: (_, state) => RequirementDetailPage(
          requirementId: state.pathParameters['id']!,
          requirement: state.extra as Map<String, dynamic>?,
        ),
      ),
      GoRoute(
        path: '/vehicles/create',
        builder: (_, __) => const CreateVehiclePage(),
      ),
      GoRoute(
        path: '/my-vehicles',
        builder: (_, __) => const MyVehiclesPage(),
      ),
      GoRoute(
        path: '/vehicles/:id/edit',
        builder: (_, state) => CreateVehiclePage(
          vehicleId: state.pathParameters['id']!,
          existing: state.extra as Map<String, dynamic>?,
        ),
      ),
      GoRoute(
        path: '/vehicles/:id',
        builder: (_, state) => VehicleDetailPage(
          vehicleId: state.pathParameters['id']!,
          vehicle: state.extra as Map<String, dynamic>?,
        ),
      ),
      GoRoute(
        path: '/users/:id',
        builder: (_, state) => UserProfilePage(
          userId: state.pathParameters['id']!,
          user: state.extra as Map<String, dynamic>?,
        ),
      ),
      GoRoute(
        path: '/my-profile',
        builder: (_, __) => const MyProfilePage(),
      ),
      GoRoute(
        path: '/kyc',
        builder: (_, __) => const KycPage(),
      ),
      GoRoute(
        path: '/sound-settings',
        builder: (_, __) => const SoundSettingsPage(),
      ),
      GoRoute(
        path: '/policy/:id',
        builder: (_, state) => PolicyPage(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/my-vehicles-garage',
        builder: (_, __) => const MyGaragePage(),
      ),
      GoRoute(
        path: '/language',
        builder: (_, __) => const LanguagePage(),
      ),
      GoRoute(
        path: '/training-videos',
        builder: (_, __) => const TrainingVideosPage(),
      ),
      GoRoute(
        path: '/invite',
        builder: (_, __) => const InvitePage(),
      ),
      GoRoute(
        path: '/support-chat',
        builder: (_, __) => const SupportChatPage(),
      ),
      GoRoute(
        path: '/leaderboard',
        builder: (_, __) => const LeaderboardPage(),
      ),
      GoRoute(
        path: '/wallet',
        builder: (_, __) => const WalletPage(),
      ),
      GoRoute(
        path: '/my-reports',
        builder: (_, __) => const MyReportsPage(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (_, __) => const NotificationsPage(),
      ),
      GoRoute(
        path: '/chats',
        builder: (_, __) => const ChatListPage(),
      ),
      GoRoute(
        path: '/chats/:chatId',
        builder: (_, state) => ChatRoomPage(chatId: state.pathParameters['chatId']!),
      ),
      GoRoute(
        path: '/subscriptions',
        builder: (_, __) => const SubscriptionPlansPage(),
      ),
      GoRoute(
        path: '/select-city',
        builder: (_, __) => const SelectCityPage(),
      ),
    ],
  );
}
