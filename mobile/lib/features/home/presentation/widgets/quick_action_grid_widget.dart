import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../../core/theme/app_theme.dart';

class QuickActionGridWidget extends StatelessWidget {
  const QuickActionGridWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final actions = [
      _QuickAction(icon: Icons.event_available_rounded, label: 'Booking'.tr, onTap: () => context.go('/requirements')),
      _QuickAction(icon: Icons.directions_car_rounded, label: 'Available Cab'.tr, onTap: () => context.go('/vehicles')),
      _QuickAction(icon: Icons.account_balance_wallet_rounded, label: 'Recharge Plans'.tr, onTap: () => context.push('/subscriptions')),
      _QuickAction(icon: Icons.location_city_rounded, label: 'My Cities'.tr, onTap: () => context.push('/select-city')),
      _QuickAction(icon: Icons.person_rounded, label: 'My Profile'.tr, onTap: () => context.push('/my-profile')),
      _QuickAction(icon: Icons.notifications_rounded, label: 'Notifications'.tr, onTap: () => context.push('/notifications')),
    ];

    const navy = Color(0xFF111827);
    final colors = [
      AppColors.primary,
      navy,
      AppColors.primary,
      navy,
      AppColors.primary,
      navy,
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
        // A vertical GridView with `padding: null` auto-applies MediaQuery padding
        // (the status-bar height) as TOP padding — that was the mysterious gap above
        // the tiles. Force zero so the grid sits directly under the marquee.
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 3,
        mainAxisSpacing: 12.w,
        crossAxisSpacing: 12.w,
        childAspectRatio: 0.72, // < 1 makes the cards taller (more height, same width)
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
        padding: EdgeInsets.symmetric(vertical: 14.r, horizontal: 8.r),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(18.r),
          boxShadow: [
            BoxShadow(color: bgColor.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon inside a glowing ring (sized to fit the larger icon).
            Container(
              width: 64.r,
              height: 64.r,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: textColor.withValues(alpha: 0.08),
                border: Border.all(color: textColor.withValues(alpha: 0.4), width: 1.5),
                boxShadow: [
                  BoxShadow(color: textColor.withValues(alpha: 0.15), blurRadius: 8, spreadRadius: 1),
                ],
              ),
              child: Icon(action.icon, color: textColor, size: 52.sp),
            ),
            SizedBox(height: 12.h),
            Text(
              action.label,
              style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w700, color: textColor, fontFamily: 'Poppins'),
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
