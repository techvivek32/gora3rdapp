import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';

class RequirementCardWidget extends StatelessWidget {
  final Map<String, dynamic> requirement;
  final VoidCallback? onTap;

  const RequirementCardWidget({super.key, required this.requirement, this.onTap});

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

    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        bool isCurrentUserPremium = false;
        bool isCurrentUserOwner = false;
        String? currentUserId;
        if (authState is AuthAuthenticated) {
          final user = authState.user;
          isCurrentUserPremium = (user['isPremium'] == true) || (user['isGolden'] == true) || (['active', 'verified', 'premium', 'golden'].contains(user['membershipType']));
          currentUserId = user['_id'] as String?;
          final posterId = postedBy?['_id'];
          isCurrentUserOwner = currentUserId != null && posterId != null && currentUserId == posterId;
        }

        final acceptedByList = List.from(requirement['acceptedBy'] as List? ?? []);
        final hasCurrentUserAccepted = currentUserId != null &&
            acceptedByList.any((id) => id.toString() == currentUserId);
        final isBooked = requirement['status'] == 'accepted';
        final isCancelled = requirement['status'] == 'cancelled';
        final isOnHold = requirement['status'] == 'on_hold';

        final memberType = postedBy?['membershipType'] ?? 'new';
        Color topBarColor;
        String? badgeText;

        // Card colour reflects the poster's membership (own cards included):
        //   new / verified -> green, active -> blue, premium -> purple, golden -> orange
        if (memberType == 'golden') {
          topBarColor = AppColors.memberGolden;
          badgeText = 'GOLDEN USER';
        } else if (memberType == 'premium') {
          topBarColor = AppColors.memberPremium;
          badgeText = 'PREMIUM USER';
        } else if (memberType == 'active') {
          topBarColor = AppColors.memberActive;
          badgeText = 'ACTIVE USER';
        } else if (memberType == 'verified') {
          topBarColor = AppColors.memberVerified;
          badgeText = 'VERIFIED USER';
        } else {
          topBarColor = AppColors.memberVerified; // new
          badgeText = 'NEW USER';
        }
        final Color cardBg = topBarColor.withOpacity(0.07);
        final Color badgeColor = topBarColor;
        final Color badgeBg = topBarColor.withOpacity(0.12);

        return GestureDetector(
          onTap: onTap == null
              ? null
              : () {
                  if (isCancelled) return;
                  if (isBooked && !isCurrentUserOwner && !hasCurrentUserAccepted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('This requirement is already booked'),
                        backgroundColor: Colors.red[700],
                        duration: const Duration(seconds: 2),
                      ),
                    );
                    return;
                  }
                  onTap!();
                },
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(color: topBarColor.withOpacity(0.3), width: 1),
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
                      Container(
                        height: 4.h,
                        decoration: BoxDecoration(
                          color: topBarColor,
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
                            IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
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
                                              width: 10.w,
                                              height: 10.h,
                                              decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                                            ),
                                            Container(width: 2.w, height: 16.h, color: Colors.grey[400]),
                                            Container(
                                              width: 10.w,
                                              height: 10.h,
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
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        requirement['estimatedDistance'] != null
                                            ? requirement['estimatedDistance'].toString()
                                            : '—',
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
                            ...[
                              Divider(height: 1, thickness: 1, color: Colors.black26),
                              SizedBox(height: 8.h),
                              // User info section
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 24.r,
                                    backgroundColor: AppColors.primary.withOpacity(0.1),
                                    backgroundImage: postedBy?['profileImage'] != null ? NetworkImage(postedBy!['profileImage'] as String) : null,
                                    child: postedBy?['profileImage'] == null ? Icon(Icons.person, color: AppColors.primary) : null,
                                  ),
                                  SizedBox(width: 12.w),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          postedBy?['fullName'] as String? ?? 'User',
                                          style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold, color: Colors.black),
                                        ),
                                        SizedBox(height: 4.h),
                                        Text(
                                          postedBy?['agencyName'] as String? ?? '',
                                          style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (badgeText != null)
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                                      decoration: BoxDecoration(
                                        color: badgeBg,
                                        borderRadius: BorderRadius.circular(4.r),
                                        border: Border.all(color: badgeColor),
                                      ),
                                      child: Text(badgeText, style: TextStyle(fontSize: 10.sp, color: badgeColor, fontWeight: FontWeight.w600)),
                                    ),
                                ],
                              ),
                              SizedBox(height: 12.h),
                              Row(
                                children: [
                                  Icon(Icons.star, size: 16.sp, color: Colors.amber),
                                  SizedBox(width: 4.w),
                                  Text('4.9', style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold, color: Colors.black)),
                                  SizedBox(width: 8.w),
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 4.h),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      borderRadius: BorderRadius.circular(4.r),
                                    ),
                                    child: Text(_timeAgo(requirement['createdAt']), style: TextStyle(fontSize: 10.sp, color: Colors.grey[600])),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      borderRadius: BorderRadius.circular(4.r),
                                    ),
                                    child: Text('Report', style: TextStyle(fontSize: 10.sp, color: Colors.red, fontWeight: FontWeight.w600)),
                                  ),
                                ],
                              ),
                              // Owners always see their own details, even without a plan.
                              if (isCurrentUserPremium || isCurrentUserOwner) ...[
                                SizedBox(height: 12.h),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () {},
                                        icon: const Icon(Icons.phone, color: Colors.white),
                                        label: Text('Phone', style: TextStyle(fontSize: 12.sp, color: Colors.white)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primary,
                                          padding: EdgeInsets.symmetric(vertical: 10.h),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 10.w),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () {},
                                        icon: const Icon(Icons.chat, color: Colors.green),
                                        label: Text('WhatsApp', style: TextStyle(fontSize: 12.sp, color: Colors.green)),
                                        style: OutlinedButton.styleFrom(
                                          side: BorderSide(color: Colors.green, width: 1.5),
                                          padding: EdgeInsets.symmetric(vertical: 10.h),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 12.h),
                                Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                                  decoration: BoxDecoration(
                                    color: Colors.amber[50],
                                    borderRadius: BorderRadius.circular(8.r),
                                    border: Border.all(color: Colors.amber.shade200, width: 1),
                                  ),
                                  child: Text(
                                    '⚠️ Don\'t pay without reference & proper verification.',
                                    style: TextStyle(fontSize: 11.sp, color: Colors.amber[800], fontWeight: FontWeight.w500),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                SizedBox(height: 12.h),
                              ] else ...[
                                Divider(height: 1, thickness: 1, color: Colors.black26),
                                SizedBox(height: 8.h),
                                Text(
                                  'Become a premium member to contact immediately',
                                  style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: Colors.red),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: 8.h),
                              ],
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (isBooked || isCancelled || isOnHold)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Center(
                          child: Transform.rotate(
                            angle: -0.2,
                            child: _buildStampBadge(
                              text: isCancelled
                                  ? 'CANCELLED'
                                  : isOnHold
                                      ? 'ON HOLD'
                                      : hasCurrentUserAccepted
                                          ? 'ACCEPTED'
                                          : 'BOOKED',
                              color: isCancelled
                                  ? Colors.grey[600]!
                                  : isOnHold
                                      ? Colors.orange[800]!
                                      : hasCurrentUserAccepted
                                          ? Colors.green[700]!
                                          : Colors.red[700]!,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStampBadge({required String text, required Color color}) {
    return SizedBox(
      width: 110.w,
      height: 110.w,
      child: CustomPaint(
        painter: _StampRingPainter(color: color),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star, color: color, size: 9.sp),
                  SizedBox(width: 2.w),
                  Icon(Icons.star, color: color, size: 9.sp),
                  SizedBox(width: 2.w),
                  Icon(Icons.star, color: color, size: 9.sp),
                ],
              ),
              SizedBox(height: 3.h),
              Text(
                text,
                style: TextStyle(
                  color: color,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              SizedBox(height: 3.h),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star, color: color, size: 9.sp),
                  SizedBox(width: 2.w),
                  Icon(Icons.star, color: color, size: 9.sp),
                  SizedBox(width: 2.w),
                  Icon(Icons.star, color: color, size: 9.sp),
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

  String _timeAgo(dynamic createdAt) {
    if (createdAt == null) return '';
    try {
      final created = DateTime.parse(createdAt.toString()).toLocal();
      final diff = DateTime.now().difference(created);
      if (diff.inDays >= 1) return '${diff.inDays}d ago';
      if (diff.inHours >= 1) {
        final mins = diff.inMinutes % 60;
        return mins > 0 ? '${diff.inHours}hr ${mins}m ago' : '${diff.inHours}hr ago';
      }
      if (diff.inMinutes >= 1) return '${diff.inMinutes}m ago';
      return 'just now';
    } catch (_) {
      return '';
    }
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

class _StampRingPainter extends CustomPainter {
  final Color color;
  _StampRingPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final rOuter = size.width / 2 - 2;
    final rValley = rOuter - 7;
    final rInner = rOuter - 14;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    const teeth = 26;
    final path = Path();
    for (int i = 0; i < teeth; i++) {
      final a1 = (i / teeth) * 2 * pi - pi / 2;
      final a2 = ((i + 0.5) / teeth) * 2 * pi - pi / 2;
      final a3 = ((i + 1.0) / teeth) * 2 * pi - pi / 2;
      final p1x = cx + rOuter * cos(a1);
      final p1y = cy + rOuter * sin(a1);
      final p2x = cx + rValley * cos(a2);
      final p2y = cy + rValley * sin(a2);
      final p3x = cx + rOuter * cos(a3);
      final p3y = cy + rOuter * sin(a3);
      if (i == 0) {
        path.moveTo(p1x, p1y);
      } else {
        path.lineTo(p1x, p1y);
      }
      path.lineTo(p2x, p2y);
      path.lineTo(p3x, p3y);
    }
    path.close();
    canvas.drawPath(path, paint);
    canvas.drawCircle(Offset(cx, cy), rInner - 2, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
