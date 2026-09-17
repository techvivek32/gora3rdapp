import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';

/// Shared bits for the car-pool screens: status colors, date parsing, and the
/// route + date/time header used on ride cards and detail pages.

DateTime? poolDate(dynamic raw) {
  if (raw == null) return null;
  final s = raw.toString();
  if (s.isEmpty) return null;
  // Take just the yyyy-MM-dd part so timezone never shifts the day.
  final datePart = s.split('T').first;
  final d = DateTime.tryParse(datePart);
  return d == null ? null : DateTime(d.year, d.month, d.day);
}

String fmtPoolDate(dynamic raw) {
  final d = poolDate(raw);
  return d == null ? '' : DateFormat('d MMM yyyy').format(d);
}

Color poolStatusColor(String status) {
  switch (status) {
    case 'active':
      return AppColors.success;
    case 'started':
      return AppColors.info;
    case 'completed':
      return AppColors.textSecondary;
    case 'cancelled':
      return AppColors.error;
    case 'confirmed':
      return AppColors.success;
    case 'picked':
      return AppColors.info;
    default:
      return AppColors.textHint;
  }
}

String poolStatusLabel(String status) {
  switch (status) {
    case 'active':
      return 'Active';
    case 'started':
      return 'In Progress';
    case 'completed':
      return 'Completed';
    case 'cancelled':
      return 'Cancelled';
    case 'confirmed':
      return 'Confirmed';
    case 'picked':
      return 'Picked Up';
    default:
      return status;
  }
}

Widget poolStatusChip(String status) {
  final c = poolStatusColor(status);
  return Container(
    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
    decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20.r), border: Border.all(color: c.withValues(alpha: 0.4))),
    child: Text(poolStatusLabel(status), style: TextStyle(fontSize: 10.5.sp, fontWeight: FontWeight.w700, color: c, fontFamily: 'Poppins')),
  );
}

/// FROM → TO route line with a date/time box on the right.
Widget poolRouteHeader(Map<String, dynamic> ride) {
  final from = (ride['fromCity'] ?? (ride['from'] as Map?)?['address'] ?? '—').toString();
  final to = (ride['toCity'] ?? (ride['to'] as Map?)?['address'] ?? '—').toString();
  final date = fmtPoolDate(ride['travelDate']);
  final time = (ride['departureTime'] ?? '').toString();
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.circle, size: 10.sp, color: AppColors.primary),
              SizedBox(width: 6.w),
              Expanded(child: Text(from, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700, fontFamily: 'Poppins'))),
            ]),
            Padding(
              padding: EdgeInsets.only(left: 4.5.w),
              child: SizedBox(height: 14.h, child: VerticalDivider(color: AppColors.border, thickness: 1.5, width: 12.w)),
            ),
            Row(children: [
              Icon(Icons.location_on, size: 12.sp, color: AppColors.error),
              SizedBox(width: 5.w),
              Expanded(child: Text(to, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700, fontFamily: 'Poppins'))),
            ]),
          ],
        ),
      ),
      SizedBox(width: 8.w),
      Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
        decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10.r)),
        child: Column(children: [
          Text(date, style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w700, color: AppColors.primaryDark, fontFamily: 'Poppins')),
          if (time.isNotEmpty) Text(time, style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w600, color: AppColors.textSecondary, fontFamily: 'Poppins')),
        ]),
      ),
    ],
  );
}
