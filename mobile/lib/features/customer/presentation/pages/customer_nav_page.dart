import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';

/// Customer bottom-nav shell — a clean white bar with four tabs
/// (Home · Bookings · Favorites · Profile), matching the customer home design.
/// Favorites has no page yet, so it shows a "coming soon" note.
class CustomerNavPage extends StatelessWidget {
  final Widget child;
  const CustomerNavPage({super.key, required this.child});

  int _index(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    if (loc.startsWith('/customer/bookings')) return 1;
    if (loc.startsWith('/customer/profile')) return 2;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final selected = _index(context);
    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.primary,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 12, offset: const Offset(0, -2))],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 62.h,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(icon: Icons.home_rounded, label: 'Home', index: 0, selectedIndex: selected, onTap: () => context.go('/customer')),
                _NavItem(icon: Icons.receipt_long_rounded, label: 'Bookings', index: 1, selectedIndex: selected, onTap: () => context.go('/customer/bookings')),
                _NavItem(icon: Icons.settings_rounded, label: 'Settings', index: 2, selectedIndex: selected, onTap: () => context.go('/customer/profile')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index;
  final int selectedIndex;
  final VoidCallback onTap;
  const _NavItem({required this.icon, required this.label, required this.index, required this.selectedIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isSelected = index == selectedIndex;
    final color = isSelected ? Colors.white : Colors.white70;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24.sp),
            SizedBox(height: 3.h),
            Text(label, style: TextStyle(fontSize: 10.sp, color: color, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500, fontFamily: 'Poppins')),
            SizedBox(height: 3.h),
            Container(
              width: 18.w,
              height: 2.5.h,
              decoration: BoxDecoration(color: isSelected ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(2)),
            ),
          ],
        ),
      ),
    );
  }
}
