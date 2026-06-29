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
import '../../features/info/presentation/pages/policy_page.dart';
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
  static final _rootNavigatorKey = GlobalKey<NavigatorState>();

  static GoRouter createRouter(AuthBloc authBloc) => GoRouter(
    navigatorKey: _rootNavigatorKey,
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
      GoRoute(path: '/auth/register', builder: (_, __) => const RegisterPage()),
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
        builder: (_, __) => const MyRequirementsPage(),
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
        path: '/policy/:id',
        builder: (_, state) => PolicyPage(id: state.pathParameters['id']!),
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
