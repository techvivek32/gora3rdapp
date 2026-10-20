import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../role_switch.dart';

/// Customer profile: identity, switch to Driver/Vendor, help, sign out. Kept intentionally
/// light — customers don't have KYC/wallet screens.
class CustomerProfilePage extends StatelessWidget {
  const CustomerProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final user = state is AuthAuthenticated ? state.user as Map<String, dynamic>? : null;
        final name = (user?['fullName'] ?? 'Customer').toString();
        final mobile = (user?['mobile'] ?? user?['phone'] ?? '').toString();
        final email = (user?['email'] ?? '').toString();
        final city = (user?['city'] ?? '').toString();
        final img = user?['profileImage']?.toString();

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(title: const Text('Settings'), backgroundColor: AppColors.primary, foregroundColor: Colors.white, automaticallyImplyLeading: false),
          // Switching sides is not a settings row — it changes which app you're in.
          // It stays pinned just above the bottom nav so it is always reachable,
          // instead of scrolling off the end of the list.
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                      backgroundImage: (img != null && img.isNotEmpty) ? NetworkImage(img) : null,
                      child: (img == null || img.isEmpty) ? const Icon(Icons.person_rounded, color: AppColors.primary, size: 32) : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                          if (mobile.isNotEmpty) Text(mobile, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                          if (email.isNotEmpty) Text(email, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
                          if (city.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                const Icon(Icons.location_city_rounded, size: 13, color: AppColors.textHint),
                                const SizedBox(width: 4),
                                Text(city, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
                              ]),
                            ),
                        ],
                      ),
                    ),
                    IconButton(onPressed: () => context.push('/my-profile'), icon: const Icon(Icons.edit_rounded, color: AppColors.primary)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _action(Icons.receipt_long_rounded, 'My Bookings', 'View your bookings', () => context.go('/customer/bookings')),
              _action(Icons.notifications_none_rounded, 'Notifications', 'Booking & trip updates', () => context.push('/notifications')),
              _action(Icons.help_outline_rounded, 'Help & Support', 'Raise a complaint', () => context.push('/customer/support')),
              _action(Icons.privacy_tip_outlined, 'Privacy Policy', '', () => context.push('/policy/privacy')),
              const SizedBox(height: 12),
              _action(Icons.logout_rounded, 'Sign Out', '', () => _signOut(context), danger: true),
              const SizedBox(height: 16),
              _switchModeCard(context),
              // Clear of the docked + button at the bottom centre.
              const SizedBox(height: 90),
            ],
          ),
        );
      },
    );
  }

  void _signOut(BuildContext context) => showDialog(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          title: const Text('Sign Out'),
          content: const Text('Are you sure you want to sign out?'),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogCtx).pop(), child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                Navigator.of(dialogCtx).pop();
                context.read<AuthBloc>().add(AuthLogoutEvent());
              },
              child: const Text('Sign Out', style: TextStyle(color: AppColors.error)),
            ),
          ],
        ),
      );

  /// Pinned bar holding the mode-switch card: a hairline rule, then the card,
  /// padded clear of the system gesture bar underneath.
  /// The "go to the other side of the app" card. Filled in the brand colour so
  /// it still stands clear of the plain settings rows above it.
  Widget _switchModeCard(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(14),
        ),
        child: ListTile(
          onTap: () => switchRole(context, 'driver'),
          dense: true,
          visualDensity: VisualDensity.compact,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          minLeadingWidth: 0,
          horizontalTitleGap: 10,
          leading: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.swap_horiz_rounded, color: Colors.white, size: 17),
          ),
          title: const Text('Switch to Driver / Vendor',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Colors.white)),
          trailing: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
        ),
      );

  Widget _action(IconData icon, String title, String subtitle, VoidCallback onTap, {bool danger = false}) {
    final c = danger ? AppColors.error : AppColors.textPrimary;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: danger ? AppColors.error : AppColors.primary),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: c)),
        subtitle: subtitle.isEmpty ? null : Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: danger ? null : const Icon(Icons.chevron_right, color: AppColors.textHint),
      ),
    );
  }
}
