import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_theme.dart';

class RequirementCardWidget extends StatelessWidget {
  final Map<String, dynamic> requirement;
  final VoidCallback onTap;

  const RequirementCardWidget({super.key, required this.requirement, required this.onTap});

  Color get _membershipColor {
    final postedBy = requirement['postedBy'] as Map<String, dynamic>?;
    final type = postedBy?['membershipType'] ?? 'new';
    switch (type) {
      case 'golden': return AppColors.memberGolden;
      case 'premium': return AppColors.memberPremium;
      case 'verified': return AppColors.memberVerified;
      case 'active': return AppColors.memberActive;
      default: return AppColors.memberNew;
    }
  }

  @override
  Widget build(BuildContext context) {
    final postedBy = requirement['postedBy'] as Map<String, dynamic>?;
    final memberType = postedBy?['membershipType'] ?? 'new';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: AppColors.border),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                // Booking ID
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Text(
                    '#${requirement['bookingId'] ?? 'N/A'}',
                    style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600, color: AppColors.primary, fontFamily: 'Courier'),
                  ),
                ),
                const SizedBox(width: 8),
                // Trip type badge
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                  decoration: BoxDecoration(
                    color: _getTripTypeColor().withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Text(
                    (requirement['tripType'] as String? ?? '').replaceAll('_', ' ').toUpperCase(),
                    style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w600, color: _getTripTypeColor()),
                  ),
                ),
                const Spacer(),
                // Membership Badge
                _MembershipBadgeWidget(type: memberType),
              ],
            ),

            SizedBox(height: 12.h),

            // Route
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.trip_origin, size: 14.sp, color: AppColors.success),
                          SizedBox(width: 4.w),
                          Text(requirement['pickupCity'] ?? '', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                        ],
                      ),
                      Padding(
                        padding: EdgeInsets.only(left: 7.w),
                        child: Container(
                          height: 16.h,
                          width: 1,
                          color: AppColors.border,
                        ),
                      ),
                      Row(
                        children: [
                          Icon(Icons.location_on_rounded, size: 14.sp, color: AppColors.error),
                          SizedBox(width: 4.w),
                          Text(requirement['dropCity'] ?? '', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.directions_car_outlined, size: 14.sp, color: AppColors.textSecondary),
                        SizedBox(width: 4.w),
                        Text(_formatVehicleType(requirement['vehicleType']), style: TextStyle(fontSize: 12.sp, color: AppColors.textSecondary)),
                      ],
                    ),
                    SizedBox(height: 6.h),
                    Row(
                      children: [
                        Icon(Icons.people_outline, size: 14.sp, color: AppColors.textSecondary),
                        SizedBox(width: 4.w),
                        Text('${requirement['numberOfVehicles'] ?? 1} vehicle(s)', style: TextStyle(fontSize: 12.sp, color: AppColors.textSecondary)),
                      ],
                    ),
                  ],
                ),
              ],
            ),

            SizedBox(height: 12.h),
            Divider(height: 1, color: AppColors.border),
            SizedBox(height: 10.h),

            // Footer
            Row(
              children: [
                Icon(Icons.calendar_today_outlined, size: 13.sp, color: AppColors.textHint),
                SizedBox(width: 4.w),
                Text(_formatDate(requirement['travelDate']), style: TextStyle(fontSize: 12.sp, color: AppColors.textSecondary)),
                SizedBox(width: 12.w),
                Icon(Icons.access_time, size: 13.sp, color: AppColors.textHint),
                SizedBox(width: 4.w),
                Text(requirement['travelTime'] ?? '', style: TextStyle(fontSize: 12.sp, color: AppColors.textSecondary)),
                const Spacer(),
                // Map button
                GestureDetector(
                  onTap: () {},
                  child: Container(
                    padding: EdgeInsets.all(6.r),
                    decoration: BoxDecoration(color: AppColors.info.withOpacity(0.1), borderRadius: BorderRadius.circular(8.r)),
                    child: Icon(Icons.map_outlined, size: 16.sp, color: AppColors.info),
                  ),
                ),
                SizedBox(width: 8.w),
                // Voice button
                GestureDetector(
                  onTap: () {},
                  child: Container(
                    padding: EdgeInsets.all(6.r),
                    decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(8.r)),
                    child: Icon(Icons.mic_outlined, size: 16.sp, color: AppColors.success),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getTripTypeColor() {
    switch (requirement['tripType']) {
      case 'one_way': return AppColors.info;
      case 'round_trip': return AppColors.success;
      case 'airport_transfer': return AppColors.memberPremium;
      case 'local': return AppColors.warning;
      case 'outstation': return AppColors.primary;
      default: return AppColors.textSecondary;
    }
  }

  String _formatVehicleType(String? type) {
    if (type == null) return '';
    return type.split('_').map((w) => w[0].toUpperCase() + w.substring(1)).join(' ');
  }

  String _formatDate(dynamic date) {
    if (date == null) return '';
    try {
      final d = DateTime.parse(date.toString());
      return '${d.day} ${_monthName(d.month)} ${d.year}';
    } catch (_) {
      return date.toString();
    }
  }

  String _monthName(int m) {
    const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[m];
  }
}

class _MembershipBadgeWidget extends StatelessWidget {
  final String type;
  const _MembershipBadgeWidget({required this.type});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    String icon;

    switch (type) {
      case 'golden': color = AppColors.memberGolden; label = 'Golden'; icon = '👑';
      case 'premium': color = AppColors.memberPremium; label = 'Premium'; icon = '⭐';
      case 'verified': color = AppColors.memberVerified; label = 'Verified'; icon = '✓';
      case 'active': color = AppColors.memberActive; label = 'Active'; icon = '✓';
      default: color = AppColors.memberNew; label = 'New'; icon = '👤';
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6.r),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: TextStyle(fontSize: 10.sp)),
          SizedBox(width: 3.w),
          Text(label, style: TextStyle(fontSize: 10.sp, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
