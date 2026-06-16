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
    final isNew = memberType == 'new';
    final isActive = memberType == 'active';
    final color = isNew ? AppColors.primary : (isActive ? Colors.green : AppColors.primary);
    final cardBg = isNew ? AppColors.primary.withOpacity(0.05) : Colors.white;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(color: isNew ? AppColors.primary.withOpacity(0.3) : Colors.grey[300]!, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8.r),
          child: Stack(
            children: [
              // Tiled diagonal watermark
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _WatermarkPainter(),
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top border for membership
                  Container(
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(8.r),
                        topRight: Radius.circular(8.r),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(12.r),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header - Three sections
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // 1. Date & Time
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      _formatDate(requirement['travelDate']),
                                      style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold, color: Colors.black),
                                    ),
                                    Text(
                                      requirement['travelTime'] ?? '',
                                      style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: 8.w),
                              VerticalDivider(width: 1, thickness: 1, color: Colors.black26),
                              SizedBox(width: 8.w),
                              // 2. Today badge
                              Expanded(
                                flex: 2,
                                child: Center(
                                  child: Container(
                                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                                    decoration: BoxDecoration(
                                      color: Colors.blue[50],
                                      borderRadius: BorderRadius.circular(4.r),
                                    ),
                                    child: Text(
                                      'Today',
                                      style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600, color: Colors.blue[700]),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 8.w),
                              VerticalDivider(width: 1, thickness: 1, color: Colors.black26),
                              SizedBox(width: 8.w),
                              // 3. Icons
                              Expanded(
                                flex: 2,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(6.r),
                                      decoration: BoxDecoration(
                                        color: Colors.green[50],
                                        borderRadius: BorderRadius.circular(6.r),
                                      ),
                                      child: Icon(Icons.volume_up, size: 18.sp, color: Colors.green),
                                    ),
                                    SizedBox(width: 8.w),
                                    Container(
                                      padding: EdgeInsets.all(6.r),
                                      decoration: BoxDecoration(
                                        color: Colors.blue[50],
                                        borderRadius: BorderRadius.circular(6.r),
                                      ),
                                      child: Icon(Icons.location_pin, size: 18.sp, color: Colors.blue),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: 12.h),
                        Divider(height: 1, thickness: 1, color: Colors.black26),
                        SizedBox(height: 12.h),

                        // Route section with distance
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Column(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Container(
                                          width: 10.w, height: 10.h,
                                          decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                                        ),
                                        Container(width: 2.w, height: 16.h, color: Colors.grey[400]),
                                        Container(
                                          width: 10.w, height: 10.h,
                                          decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                        ),
                                      ],
                                    ),
                                    SizedBox(width: 8.w),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            requirement['pickupCity'] ?? '',
                                            style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: Colors.black),
                                          ),
                                          SizedBox(height: 6.h),
                                          Text(
                                            requirement['dropCity'] ?? '',
                                            style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: Colors.black),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Distance on right - centered
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    requirement['distance']?.toString() ?? '284',
                                    style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.bold, color: Colors.green),
                                  ),
                                  Text('KM', style: TextStyle(fontSize: 8.sp, color: Colors.grey[600])),
                                ],
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: 12.h),
                        Divider(height: 1, thickness: 1, color: Colors.black26),
                        SizedBox(height: 12.h),

                        // Vehicle type
                        Row(
                          children: [
                            Icon(Icons.directions_car, size: 14.sp, color: Colors.black),
                            SizedBox(width: 6.w),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _formatVehicleType(requirement['vehicleType']),
                                  style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold, color: Colors.black),
                                ),
                                Text(
                                  'Any Fuel | Carrier Does Not Matter',
                                  style: TextStyle(fontSize: 11.sp, color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ],
                        ),

                        SizedBox(height: 6.h),

                        // Trip type
                        Row(
                          children: [
                            Icon(_getTripTypeIcon(requirement['tripType']), size: 14.sp, color: Colors.black),
                            SizedBox(width: 6.w),
                            Text(
                              (requirement['tripType'] as String? ?? '').replaceAll('_', ' ').toUpperCase(),
                              style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold, color: Colors.black),
                            ),
                          ],
                        ),

                        SizedBox(height: 6.h),
                        Divider(height: 1, thickness: 1, color: Colors.black26),
                        SizedBox(height: 6.h),

                        // Booking
                        Row(
                          children: [
                            Icon(Icons.receipt_long, size: 14.sp, color: Colors.black),
                            SizedBox(width: 6.w),
                            Text('Booking', style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold, color: Colors.black)),
                          ],
                        ),

                        SizedBox(height: 4.h),

                        // No Saavari Stickers
                        Row(
                          children: [
                            Icon(Icons.do_not_disturb_alt, size: 14.sp, color: Colors.black),
                            SizedBox(width: 6.w),
                            Text('No Saavari Stickers', style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold, color: Colors.black)),
                          ],
                        ),

                        SizedBox(height: 12.h),
                        Divider(height: 1, thickness: 1, color: Colors.black26),
                        SizedBox(height: 8.h),

                        // Warning banner
                        if (isNew)
                          Text(
                            'Become a premium member to contact immediately',
                            style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: Colors.red),
                            textAlign: TextAlign.center,
                          ),

                        SizedBox(height: 12.h),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getTripTypeIcon(String? tripType) {
    switch (tripType) {
      case 'one_way': return Icons.arrow_forward;
      case 'round_trip': return Icons.loop;
      case 'airport_transfer': return Icons.flight;
      case 'local': return Icons.location_city;
      case 'outstation': return Icons.map;
      default: return Icons.route;
    }
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
    return type.split('_').map((w) => w[0].toUpperCase() + w.substring(1)).join(' ') + ' Car';
  }

  String _formatDate(dynamic date) {
    if (date == null) return '';
    try {
      final d = DateTime.parse(date.toString());
      return '${d.day} ${_monthName(d.month)}';
    } catch (_) {
      return date.toString();
    }
  }

  String _monthName(int m) {
    const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[m];
  }
}

class _WatermarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const text = 'Secure Member';
    const angle = -0.5;
    const rowGap = 36.0;
    const colGap = 120.0;

    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.grey.withOpacity(0.2),
          letterSpacing: 1.2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final diagLen = (size.width * size.width + size.height * size.height);
    final steps = (diagLen / colGap).ceil() + 4;
    final rows = (size.height / rowGap).ceil() + 4;

    for (int row = -2; row < rows; row++) {
      for (int col = -2; col < steps; col++) {
        final x = col * colGap;
        final y = row * rowGap;
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(angle);
        tp.paint(canvas, Offset.zero);
        canvas.restore();
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
