import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';

class QuickActionGridWidget extends StatelessWidget {
  const QuickActionGridWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final actions = [
      _QuickAction(icon: Icons.search_rounded, label: 'Requirement', onTap: () => context.go('/requirements')),
      _QuickAction(icon: Icons.directions_car_rounded, label: 'Available Cab', onTap: () => context.go('/vehicles')),
      _QuickAction(icon: Icons.star_rounded, label: 'Premium Plans', onTap: () => context.push('/subscriptions')),
      _QuickAction(icon: Icons.location_city_rounded, label: 'My Cities', onTap: () => context.push('/select-city')),
      _QuickAction(icon: Icons.person_rounded, label: 'My Account', onTap: () => context.push('/my-profile')),
      _QuickAction(icon: Icons.notifications_rounded, label: 'Notifications', onTap: () => context.push('/notifications')),
    ];

    final colors = [
      AppColors.primary,
      Colors.black,
      AppColors.primary,
      Colors.black,
      AppColors.primary,
      Colors.black,
    ];

    final textColors = [
      Colors.white,
      AppColors.primary,
      Colors.white,
      AppColors.primary,
      Colors.white,
      AppColors.primary,
    ];

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 3,
        mainAxisSpacing: 12.w,
        crossAxisSpacing: 12.w,
        childAspectRatio: 0.75, // < 1 makes the cards taller (more height, same width)
        children: List.generate(actions.length, (index) {
          return _QuickActionCard(
            action: actions[index],
            bgColor: colors[index],
            textColor: textColors[index],
          );
        }),
      ),
    );
  }
}

class _QuickAction {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickAction({required this.icon, required this.label, required this.onTap});
}

class _QuickActionCard extends StatelessWidget {
  final _QuickAction action;
  final Color bgColor;
  final Color textColor;
  const _QuickActionCard({required this.action, required this.bgColor, required this.textColor});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: action.onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 10.r, horizontal: 8.r),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(action.icon, color: textColor, size: 40.sp),
            SizedBox(height: 8.h),
            Text(
              action.label,
              style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w600, color: textColor, fontFamily: 'Poppins'),
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
