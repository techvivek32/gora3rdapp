import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/di/injection.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/presentation/bloc/auth_bloc.dart';
import '../data/customer_repository.dart';

/// True once the auth state carries the role we just switched to. Drivers and
/// vendors share the non-customer side, so anything that isn't 'customer'
/// counts as the driver side — same test the router's redirect uses.
bool Function(AuthState) _roleMatcher(String role) => (s) {
      if (s is! AuthAuthenticated) return false;
      final u = s.user;
      final r = (u is Map && u['role'] != null) ? u['role'].toString() : '';
      return role == 'customer' ? r == 'customer' : (r.isNotEmpty && r != 'customer');
    };

/// Reloads the profile and waits until the AuthBloc actually reports the new
/// role, BEFORE the caller navigates.
///
/// The router redirects on whatever role the auth state currently holds, so
/// navigating while the old role is still in place bounces the user through the
/// wrong home for a frame — that's the "other home flashes for a second" bug.
/// Waiting here keeps the switch on one screen until it's really done.
Future<void> applyRoleAndWait(AuthBloc bloc, String role) async {
  final matches = _roleMatcher(role);
  if (matches(bloc.state)) {
    bloc.add(const AuthReloadProfileEvent()); // already correct — refresh in the background
    return;
  }
  final settled = bloc.stream.firstWhere(matches);
  bloc.add(const AuthReloadProfileEvent());
  await settled.timeout(const Duration(seconds: 8), onTimeout: () => bloc.state);
}

/// Switches the logged-in user between Customer and Driver/Vendor in place,
/// without going through the role-chooser screen — the Settings pages call this
/// directly (a driver sees "Switch to Customer", a customer sees "Switch to
/// Driver / Vendor").
///
/// Re-issues tokens, waits for the new role to land, then lands on the right
/// home. A first-ever switch needs onboarding, which the backend signals with
/// *_ONBOARDING_REQUIRED.
Future<void> switchRole(BuildContext context, String role) async {
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context, rootNavigator: true);
  final bloc = context.read<AuthBloc>();
  final router = GoRouter.of(context);
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );
  try {
    await getIt<CustomerRepository>().changeRole(role);
    // Hold the spinner until the router actually sees the new role.
    await applyRoleAndWait(bloc, role);
    navigator.pop(); // close the spinner
    router.go(role == 'customer' ? '/customer' : '/');
  } catch (e) {
    navigator.pop();
    final msg = e.toString();
    if (role == 'customer' && msg.contains('CUSTOMER_ONBOARDING_REQUIRED')) {
      router.push('/customer/onboarding');
      return;
    }
    if (role != 'customer' && msg.contains('DRIVER_ONBOARDING_REQUIRED')) {
      router.push('/driver/onboarding');
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text('Could not switch role: ${msg.replaceFirst('Exception: ', '')}'),
        backgroundColor: AppColors.error,
      ),
    );
  }
}
