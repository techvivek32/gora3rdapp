import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../data/customer_repository.dart';

/// "How do you want to use Gora Taxi Partner?" — shown on first open (from
/// welcome) and reachable from Profile → Change Role. If the user is already
/// logged in, picking a role switches it in place; otherwise it routes to the
/// right sign-up/login flow.
class RoleSelectPage extends StatefulWidget {
  const RoleSelectPage({super.key});

  @override
  State<RoleSelectPage> createState() => _RoleSelectPageState();
}

class _RoleSelectPageState extends State<RoleSelectPage> {
  bool _busy = false;

  bool get _loggedIn => context.read<AuthBloc>().state is AuthAuthenticated;

  Future<void> _pick(String role) async {
    if (_busy) return;
    if (!_loggedIn) {
      // Logged-out: customers get their own dedicated login/sign-up; drivers &
      // vendors use the existing /auth flow.
      if (role == 'customer') {
        context.go('/customer/login');
      } else {
        context.go('/auth/login');
      }
      return;
    }
    // Already logged in → switch role in place (re-issues tokens). Switching to
    // Customer for the first time needs a quick onboarding (city etc.) — the
    // backend signals that with CUSTOMER_ONBOARDING_REQUIRED and we route there;
    // an already-onboarded account switches directly. Same idea both directions.
    setState(() => _busy = true);
    try {
      await getIt<CustomerRepository>().changeRole(role);
      if (!mounted) return;
      context.read<AuthBloc>().add(const AuthReloadProfileEvent());
      context.go(role == 'customer' ? '/customer' : '/');
    } catch (e) {
      final msg = e.toString();
      if (role == 'customer' && msg.contains('CUSTOMER_ONBOARDING_REQUIRED')) {
        if (!mounted) return;
        setState(() => _busy = false);
        context.push('/customer/onboarding');
        return;
      }
      if (role != 'customer' && msg.contains('DRIVER_ONBOARDING_REQUIRED')) {
        if (!mounted) return;
        setState(() => _busy = false);
        context.push('/driver/onboarding');
        return;
      }
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not switch role: ${msg.replaceFirst('Exception: ', '')}'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _loggedIn ? AppBar(title: const Text('Change Role'), backgroundColor: AppColors.primary, foregroundColor: Colors.white) : null,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              const Text('How do you want to use\nGora Taxi Partner?',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              const Text('You can switch anytime from Profile → Change Role.',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 32),
              _RoleCard(
                icon: Icons.person_pin_circle_rounded,
                title: '👤 Customer',
                subtitle: 'Book a cab, hire a driver, luxury or car pool',
                onTap: _busy ? null : () => _pick('customer'),
              ),
              const SizedBox(height: 16),
              _RoleCard(
                icon: Icons.local_taxi_rounded,
                title: '🚕 Driver / Vendor',
                subtitle: 'Post duties, get customer bookings & leads',
                onTap: _busy ? null : () => _pick('driver'),
              ),
              const Spacer(),
              if (_busy) const Center(child: CircularProgressIndicator()),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  const _RoleCard({required this.icon, required this.title, required this.subtitle, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            CircleAvatar(radius: 26, backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                child: Icon(icon, color: AppColors.primary, size: 28)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }
}
