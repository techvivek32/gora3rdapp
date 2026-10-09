import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../data/customer_repository.dart';
import '../role_switch.dart';

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
      // Wait for the new role to reach the router before navigating, otherwise
      // its redirect still sees the old one and flashes the wrong home.
      await applyRoleAndWait(context.read<AuthBloc>(), role);
      if (!mounted) return;
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
    const blue = Color(0xFF1E5BC6);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _loggedIn ? AppBar(title: const Text('Change Role'), backgroundColor: AppColors.primary, foregroundColor: Colors.white) : null,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Brand logo — only on the first-open screen (the Change-Role AppBar
              // already names the app when logged in).
              if (!_loggedIn) ...[
                const SizedBox(height: 10),
                // Brand logo on a transparent background (navy wordmark, no tagline)
                // so it sits cleanly on the white page.
                Center(child: Image.asset('assets/images/gora_logo_white.png', height: 112, fit: BoxFit.contain)),
                const SizedBox(height: 16),
              ] else
                const SizedBox(height: 20),
              const Text('How do you want to use\nGora Taxi Partner?',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, height: 1.25, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              const Text('You can switch anytime from Profile – Change Role.',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 26),
              _RoleCard(
                image: 'assets/images/role_customer.png',
                title: 'Customer',
                subtitle: 'Book a cab, hire a driver\nor car pool',
                accent: blue,
                onTap: _busy ? null : () => _pick('customer'),
              ),
              const SizedBox(height: 18),
              _RoleCard(
                image: 'assets/images/role_driver.png',
                title: 'Driver / Vendor',
                subtitle: 'Post duties, get customer\nbookings & leads',
                accent: AppColors.primary,
                onTap: _busy ? null : () => _pick('driver'),
              ),
              if (_busy) ...[
                const SizedBox(height: 24),
                const Center(child: CircularProgressIndicator()),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String image;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback? onTap;
  const _RoleCard({required this.image, required this.title, required this.subtitle, required this.accent, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accent.withValues(alpha: 0.18)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 14, offset: const Offset(0, 6))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Illustration banner — rounded to match the card's top corners.
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: AspectRatio(
                aspectRatio: 412 / 180,
                child: Image.asset(image, fit: BoxFit.cover),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 14, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: accent)),
                        const SizedBox(height: 4),
                        Text(subtitle, style: const TextStyle(fontSize: 13, height: 1.3, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                    child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 22),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
