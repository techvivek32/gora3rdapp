import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_theme.dart';

class MainNavPage extends StatelessWidget {
  final Widget child;
  const MainNavPage({super.key, required this.child});

  int _getSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/requirements')) return 1;
    if (location.startsWith('/vehicles')) return 2;
    if (location.startsWith('/profile')) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _getSelectedIndex(context);

    return Scaffold(
      body: child,
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () => _showPostOptions(context),
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
            _NavItem(icon: Icons.home_rounded, label: 'Home', index: 0, selectedIndex: selectedIndex, onTap: () => context.go('/')),
            _NavItem(icon: Icons.search_rounded, label: 'Needs', index: 1, selectedIndex: selectedIndex, onTap: () => context.go('/requirements')),
            const SizedBox(width: 48),
            _NavItem(icon: Icons.directions_car_rounded, label: 'Cabs', index: 2, selectedIndex: selectedIndex, onTap: () => context.go('/vehicles')),
            _NavItem(icon: Icons.settings_rounded, label: 'Settings', index: 3, selectedIndex: selectedIndex, onTap: () => context.go('/profile')),
          ],
        ),
      ),
    );
  }

  void _showPostOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (ctx) => Container(
        padding: EdgeInsets.all(24.r),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40.w, height: 4.h, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
            SizedBox(height: 20.h),
            Text('Post New', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w700)),
            SizedBox(height: 20.h),
            Row(
              children: [
                Expanded(
                  child: _PostOptionCard(
                    icon: Icons.search_rounded,
                    title: 'Requirement',
                    subtitle: 'Need a vehicle?',
                    color: AppColors.info,
                    onTap: () { Navigator.pop(ctx); context.push('/requirements/create'); },
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: _PostOptionCard(
                    icon: Icons.directions_car_rounded,
                    title: 'Available Cab',
                    subtitle: 'Have a vehicle?',
                    color: AppColors.success,
                    onTap: () { Navigator.pop(ctx); context.push('/vehicles/create'); },
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),
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

class _PostOptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _PostOptionCard({required this.icon, required this.title, required this.subtitle, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(20.r),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32.sp),
            SizedBox(height: 8.h),
            Text(title, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            SizedBox(height: 4.h),
            Text(subtitle, style: TextStyle(fontSize: 12.sp, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
