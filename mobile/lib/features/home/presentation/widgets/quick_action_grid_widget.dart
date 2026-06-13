import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';

class QuickActionGridWidget extends StatelessWidget {
  const QuickActionGridWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final actions = [
      _QuickAction(icon: Icons.search_rounded, label: 'Requirement', color: AppColors.info, onTap: () => context.push('/requirements/create')),
      _QuickAction(icon: Icons.directions_car_rounded, label: 'Available Cab', color: AppColors.success, onTap: () => context.push('/vehicles/create')),
      _QuickAction(icon: Icons.star_rounded, label: 'Premium Plans', color: AppColors.memberPremium, onTap: () => context.push('/subscriptions')),
      _QuickAction(icon: Icons.location_city_rounded, label: 'My Cities', color: AppColors.warning, onTap: () {}),
      _QuickAction(icon: Icons.person_rounded, label: 'My Account', color: AppColors.primary, onTap: () => context.go('/profile')),
      _QuickAction(icon: Icons.notifications_rounded, label: 'Notifications', color: AppColors.error, onTap: () => context.push('/notifications')),
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      mainAxisSpacing: 12.h,
      crossAxisSpacing: 12.w,
      childAspectRatio: 0.9,
      children: actions.map((a) => _QuickActionCard(action: a)).toList(),
    );
  }
}

class _QuickAction {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction({required this.icon, required this.label, required this.color, required this.onTap});
}

class _QuickActionCard extends StatelessWidget {
  final _QuickAction action;
  const _QuickActionCard({required this.action});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: action.onTap,
      child: Container(
        padding: EdgeInsets.all(12.r),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: AppColors.border),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48.w,
              height: 48.w,
              decoration: BoxDecoration(
                color: action.color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14.r),
              ),
              child: Icon(action.icon, color: action.color, size: 24.sp),
            ),
            SizedBox(height: 8.h),
            Text(
              action.label,
              style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
