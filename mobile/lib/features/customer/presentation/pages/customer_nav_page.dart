import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';

/// Customer bottom-nav shell — mirrors the driver's MainNavPage look (orange
/// BottomAppBar with a centered black FAB) so both modes feel like one app.
/// The FAB opens a quick service picker; tabs are Home · My Rides · Support ·
/// Profile.
class CustomerNavPage extends StatelessWidget {
  final Widget child;
  const CustomerNavPage({super.key, required this.child});

  int _index(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    if (loc.startsWith('/customer/bookings')) return 1;
    if (loc.startsWith('/customer/profile')) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final selected = _index(context);
    return Scaffold(
      body: child,
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.black,
        onPressed: () => _showServicePicker(context),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        color: AppColors.primary,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        height: 65.h,
        padding: EdgeInsets.zero,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(icon: Icons.home_rounded, label: 'Home', index: 0, selectedIndex: selected, onTap: () => context.go('/customer')),
            _NavItem(icon: Icons.receipt_long_rounded, label: 'My Rides', index: 1, selectedIndex: selected, onTap: () => context.go('/customer/bookings')),
            const SizedBox(width: 48),
            _NavItem(icon: Icons.support_agent_rounded, label: 'Support', index: 2, selectedIndex: selected, onTap: () => context.push('/support-chat')),
            _NavItem(icon: Icons.settings_rounded, label: 'Settings', index: 3, selectedIndex: selected, onTap: () => context.go('/customer/profile')),
          ],
        ),
      ),
    );
  }

  void _showServicePicker(BuildContext context) {
    const services = [
      ('cab', 'Cabs Booking', Icons.local_taxi_rounded, AppColors.primary),
      ('hire_driver', 'Hire a Driver', Icons.badge_rounded, AppColors.info),
      ('luxury', 'Luxury Car', Icons.workspace_premium_rounded, Color(0xFF9333EA)),
      ('car_pool', 'Car Pooling', Icons.groups_rounded, AppColors.success),
    ];
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24.r))),
      builder: (ctx) => Container(
        padding: EdgeInsets.all(24.r),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40.w, height: 4.h, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
            SizedBox(height: 20.h),
            Text('Book a service', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w700, fontFamily: 'Poppins')),
            SizedBox(height: 20.h),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 16.w,
              crossAxisSpacing: 16.w,
              childAspectRatio: 1.4,
              children: services.map((s) => _PickCard(
                title: s.$2,
                icon: s.$3,
                color: s.$4,
                onTap: () { Navigator.pop(ctx); context.push('/customer/book/${s.$1}'); },
              )).toList(),
            ),
            SizedBox(height: 8.h),
          ],
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
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isSelected ? Colors.white : Colors.white70, size: 24.sp),
            SizedBox(height: 2.h),
            Text(label, style: TextStyle(fontSize: 10.sp, color: isSelected ? Colors.white : Colors.white70, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400)),
          ],
        ),
      ),
    );
  }
}

class _PickCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _PickCard({required this.title, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 30.sp),
            SizedBox(height: 8.h),
            Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontFamily: 'Poppins')),
          ],
        ),
      ),
    );
  }
}
