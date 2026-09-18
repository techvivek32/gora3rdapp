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
import '../../features/customer/presentation/pages/role_select_page.dart';
import '../../features/customer/presentation/pages/customer_login_page.dart';
import '../../features/customer/presentation/pages/customer_register_page.dart';
import '../../features/customer/presentation/pages/customer_onboarding_page.dart';
import '../../features/customer/presentation/pages/driver_onboarding_page.dart';
import '../../features/customer/presentation/pages/customer_nav_page.dart';
import '../../features/customer/presentation/pages/customer_home_page.dart';
import '../../features/customer/presentation/pages/customer_booking_form_page.dart';
import '../../features/customer/presentation/pages/customer_my_bookings_page.dart';
import '../../features/customer/presentation/pages/customer_booking_detail_page.dart';
import '../../features/customer/presentation/pages/customer_profile_page.dart';
import '../../features/customer/presentation/pages/customer_support_page.dart';
import '../../features/customer/presentation/pages/customer_saved_locations_page.dart';
import '../../features/customer/presentation/pages/driver_customer_requests_page.dart';
import '../../features/car_pool/presentation/pages/post_ride_page.dart';
import '../../features/car_pool/presentation/pages/my_pool_rides_page.dart';
import '../../features/car_pool/presentation/pages/pool_ride_detail_page.dart';
import '../../features/car_pool/presentation/pages/pool_earnings_page.dart';
import '../../features/car_pool/presentation/pages/search_pool_rides_page.dart';
import '../../features/car_pool/presentation/pages/my_pool_bookings_page.dart';

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

  /// Role lives in the JWT and is mirrored on the loaded profile map.
  static String _roleOf(AuthAuthenticated s) {
    final u = s.user;
    return (u is Map && u['role'] != null) ? u['role'].toString() : '';
  }

  static GoRouter createRouter(AuthBloc authBloc) => GoRouter(
    navigatorKey: rootNavigatorKey,
    debugLogDiagnostics: true,
    initialLocation: '/splash',
    refreshListenable: _GoRouterRefreshStream(authBloc.stream),
    redirect: (context, state) {
      final authState = authBloc.state;
      final loc = state.matchedLocation;
      // Auth screens reachable while logged out: driver/agency (/auth/*) and the
      // dedicated customer login/register pages.
      final isCustomerAuth = loc == '/customer/login' || loc == '/customer/register';
      final isAuthRoute = loc.startsWith('/auth') || isCustomerAuth;
      final isSplash = loc == '/splash';
      final isWelcome = loc == '/welcome';

      if (isSplash) return null;
      if (authState is AuthAuthenticated) {
        final isCustomer = _roleOf(authState) == 'customer';
        // Coming from auth/welcome → land on the role's home.
        if (isAuthRoute || isWelcome) return isCustomer ? '/customer' : '/';
        // Keep each role on its own home root; shared detail routes are untouched.
        if (isCustomer && loc == '/') return '/customer';
        if (!isCustomer && loc == '/customer') return '/';
        return null;
      }
      if (authState is AuthUnauthenticated) {
        // Role selection + the auth screens are reachable while logged out.
        if (!isAuthRoute && !isWelcome && loc != '/role-select') return '/welcome';
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

      // Role selection (first-open choice + Profile → Change Role)
      GoRoute(path: '/role-select', builder: (_, __) => const RoleSelectPage()),

      // Dedicated Customer auth (separate from the driver/agency /auth flow)
      GoRoute(path: '/customer/login', builder: (_, __) => const CustomerLoginPage()),
      GoRoute(path: '/customer/onboarding', builder: (_, __) => const CustomerOnboardingPage()),
      GoRoute(path: '/driver/onboarding', builder: (_, __) => const DriverOnboardingPage()),
      GoRoute(
        path: '/customer/register',
        builder: (_, state) => CustomerRegisterPage(initialMobile: state.uri.queryParameters['mobile']),
      ),

      // Customer Mode Shell (bottom nav: Book · My Rides · Profile)
      ShellRoute(
        builder: (context, state, child) => CustomerNavPage(child: child),
        routes: [
          GoRoute(path: '/customer', builder: (_, __) => const CustomerHomePage()),
          GoRoute(path: '/customer/bookings', builder: (_, __) => const CustomerMyBookingsPage()),
          GoRoute(path: '/customer/profile', builder: (_, __) => const CustomerProfilePage()),
        ],
      ),
      // Customer detail routes (pushed above the shell)
      // ── Car Pooling (Gora Pool) ──
      GoRoute(
        path: '/car-pool/post',
        builder: (_, state) {
          final existing = state.extra is Map ? Map<String, dynamic>.from(state.extra as Map) : null;
          return PostRidePage(
            rideId: existing == null ? null : (existing['_id'] ?? existing['id'])?.toString(),
            existing: existing,
          );
        },
      ),
      GoRoute(path: '/car-pool/my-rides', builder: (_, __) => const MyPoolRidesPage()),
      GoRoute(path: '/car-pool/earnings', builder: (_, __) => const PoolEarningsPage()),
      GoRoute(path: '/car-pool/search', builder: (_, __) => const SearchPoolRidesPage()),
      GoRoute(path: '/car-pool/my-bookings', builder: (_, __) => const MyPoolBookingsPage()),
      GoRoute(path: '/car-pool/ride/:id', builder: (_, state) => PoolRideDetailPage(rideId: state.pathParameters['id']!)),

      GoRoute(
        path: '/customer/book/:serviceType',
        // `extra` carries an existing booking Map when editing (from the detail page).
        builder: (_, state) {
          final existing = state.extra is Map ? Map<String, dynamic>.from(state.extra as Map) : null;
          return CustomerBookingFormPage(
            serviceType: state.pathParameters['serviceType']!,
            bookingId: existing == null ? null : (existing['_id'] ?? existing['id'])?.toString(),
            existing: existing,
          );
        },
      ),
      GoRoute(
        path: '/customer/bookings/:id',
        builder: (_, state) => CustomerBookingDetailPage(bookingId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/customer/support',
        builder: (_, __) => const CustomerSupportPage(),
      ),
      GoRoute(
        path: '/customer/saved-locations',
        builder: (_, __) => const CustomerSavedLocationsPage(),
      ),
      // Driver / vendor side of Customer Mode
      GoRoute(
        path: '/customer-requests',
        builder: (_, __) => const DriverCustomerRequestsPage(),
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
