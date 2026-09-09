import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_theme.dart';

/// Shared card chrome for Customer Mode, matching the Requirement / Available-Car
/// cards: colored top bar, tinted body, FROM→TO route, and a colored date box.

const kServiceNames = {
  'cab': 'Cabs Booking',
  'hire_driver': 'Hire a Driver',
  'luxury': 'Luxury Car',
  'car_pool': 'Car Pooling',
};

const _monthNames = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// Colored top bar + tinted body wrapper (requirement-card style).
Widget brandCard({required Widget child, Color color = AppColors.primary, VoidCallback? onTap}) {
  final card = Container(
    margin: EdgeInsets.symmetric(horizontal: 2.w, vertical: 6.h),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(10.r),
      border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 1))],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(10.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 4.h, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.vertical(top: Radius.circular(10.r)))),
          Padding(padding: EdgeInsets.all(12.r), child: child),
        ],
      ),
    ),
  );
  if (onTap == null) return card;
  return GestureDetector(onTap: onTap, child: card);
}

Widget filledChip(String text, Color color) => Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6.r)),
      child: Text(text, style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w700, color: Colors.white)),
    );

/// Vertical FROM → TO route with the connecting line.
Widget routeTimeline(String from, String to) {
  Widget point(IconData icon, Color color, String label, String text, {required bool showLine}) => IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(children: [
              Icon(icon, size: 14.sp, color: color),
              if (showLine) Expanded(child: Container(width: 2, margin: EdgeInsets.symmetric(vertical: 2.h), color: Colors.grey.shade400)),
            ]),
            SizedBox(width: 10.w),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: showLine ? 10.h : 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: TextStyle(fontSize: 9.sp, color: Colors.grey[600], fontWeight: FontWeight.w600)),
                    Text(text, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold, color: Colors.black)),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      point(Icons.trip_origin, Colors.green, 'FROM', from, showLine: to.isNotEmpty),
      if (to.isNotEmpty) point(Icons.location_on, Colors.red, 'TO', to, showLine: false),
    ],
  );
}

/// Colored date/time box (big date + time below).
Widget dateTimeBox(DateTime? date, String time, Color color) => Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8.r)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(date != null ? '${date.day} ${_monthNames[date.month]}' : '—',
              style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold, color: Colors.white, height: 1.1)),
          if (time.isNotEmpty)
            Text(time, style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: Colors.white)),
        ],
      ),
    );

/// Status → (color, label) for a customer booking.
(Color, String) bookingStatusInfo(String status) {
  switch (status) {
    case 'open': return (AppColors.info, 'OPEN');
    case 'confirmed': return (AppColors.primary, 'CONFIRMED');
    case 'ongoing': return (AppColors.warning, 'ONGOING');
    case 'completed': return (AppColors.success, 'COMPLETED');
    case 'cancelled': return (AppColors.error, 'CANCELLED');
    case 'expired': return (AppColors.textHint, 'EXPIRED');
    default: return (AppColors.textHint, status.toUpperCase());
  }
}
