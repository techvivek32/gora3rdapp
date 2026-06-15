import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';

class VehicleDetailPage extends StatelessWidget {
  final Map<String, dynamic> vehicle;
  const VehicleDetailPage({super.key, required this.vehicle});

  @override
  Widget build(BuildContext context) {
    final status = vehicle['status'] as String? ?? 'available';
    final statusColor = status == 'available' ? AppColors.success : AppColors.textHint;
    final postedBy = vehicle['postedBy'] as Map<String, dynamic>?;
    final isPremium = postedBy != null && postedBy['mobile'] != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 4,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _formatDate(vehicle['availableDate']),
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            Text(
              vehicle['availableTime'] as String? ?? '',
              style: TextStyle(fontSize: 12.sp, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          Container(
            margin: EdgeInsets.symmetric(vertical: 10.h, horizontal: 12.w),
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4.r),
            ),
            child: Text(status.toUpperCase(), style: TextStyle(color: Colors.white, fontSize: 11.sp, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Route card
            _card(
              title: 'Route',
              child: Row(
                children: [
                  Column(
                    children: [
                      Container(width: 12.w, height: 12.h, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                      Container(width: 2.w, height: 30.h, color: Colors.grey[400]),
                      Container(width: 12.w, height: 12.h, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
                    ],
                  ),
                  SizedBox(width: 12.w),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(vehicle['currentCity'] as String? ?? '', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, color: Colors.black)),
                      SizedBox(height: 12.h),
                      Text(vehicle['destinationCity'] as String? ?? 'Any', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, color: Colors.black)),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 12.h),

            // Vehicle info card
            _card(
              title: 'Vehicle Info',
              child: Column(
                children: [
                  _infoRow(Icons.directions_car, 'Type', (vehicle['vehicleType'] as String? ?? '').toUpperCase()),
                  _infoRow(Icons.badge_outlined, 'Number', vehicle['vehicleNumber'] as String? ?? '-'),
                  _infoRow(Icons.person_outline, 'Driver', vehicle['driverName'] as String? ?? '-'),
                  _infoRow(Icons.calendar_today_outlined, 'Available Date', _formatDate(vehicle['availableDate'])),
                ],
              ),
            ),
            SizedBox(height: 12.h),

            // Contact card
            _card(
              title: 'Posted By',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24.r,
                        backgroundColor: AppColors.primary.withOpacity(0.1),
                        backgroundImage: postedBy?['profileImage'] != null ? NetworkImage(postedBy!['profileImage'] as String) : null,
                        child: postedBy?['profileImage'] == null ? Icon(Icons.person, color: AppColors.primary) : null,
                      ),
                      SizedBox(width: 12.w),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(postedBy?['fullName'] as String? ?? 'Hidden', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp, color: Colors.black)),
                          if (postedBy?['agencyName'] != null)
                            Text(postedBy!['agencyName'] as String, style: TextStyle(fontSize: 12.sp, color: Colors.grey[600])),
                        ],
                      ),
                    ],
                  ),
                  if (!isPremium) ...[
                    SizedBox(height: 12.h),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(12.r),
                      decoration: BoxDecoration(
                        color: Colors.amber[50],
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.lock_outline, color: Colors.amber[700]),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Text(
                              'Upgrade to Premium to view contact details',
                              style: TextStyle(fontSize: 12.sp, color: Colors.amber[800]),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 8.h),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => context.push('/subscriptions'),
                        icon: const Icon(Icons.star, color: Colors.amber),
                        label: const Text('Upgrade to Premium'),
                      ),
                    ),
                  ] else ...[
                    SizedBox(height: 12.h),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                        onPressed: () {},
                        icon: const Icon(Icons.call, color: Colors.white),
                        label: Text('Call ${postedBy!['mobile']}', style: const TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(height: 32.h),
          ],
        ),
      ),
    );
  }

  Widget _card({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: Colors.black26, width: 1),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 1))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 4.h,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.only(topLeft: Radius.circular(8.r), topRight: Radius.circular(8.r)),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(14.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold, color: AppColors.primary)),
                Divider(height: 12.h, thickness: 1, color: Colors.black26),
                child,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 5.h),
      child: Row(
        children: [
          Icon(icon, size: 16.sp, color: AppColors.primary),
          SizedBox(width: 10.w),
          Text('$label: ', style: TextStyle(fontSize: 13.sp, color: Colors.grey[600])),
          Expanded(child: Text(value, style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold, color: Colors.black))),
        ],
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return '-';
    try {
      final d = DateTime.parse(date.toString());
      const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${d.day} ${months[d.month]} ${d.year}';
    } catch (_) {
      return date.toString();
    }
  }
}
