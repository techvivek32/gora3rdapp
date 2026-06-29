import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/vehicle_types.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/contact_launcher.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../users/presentation/widgets/user_card_sheet.dart';

class RequirementCardWidget extends StatelessWidget {
  final Map<String, dynamic> requirement;
  final VoidCallback? onTap;
  // When provided, shown in the top-right (actions menu on My Requirements).
  final Widget? menu;
  // True on the "My Requirements" list — treat as owner.
  final bool mine;

  const RequirementCardWidget({super.key, required this.requirement, this.onTap, this.menu, this.mine = false});

  @override
  Widget build(BuildContext context) {
    final postedBy = requirement['postedBy'] as Map<String, dynamic>?;

    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        bool isCurrentUserPremium = false;
        bool isCurrentUserOwner = mine;
        String? currentUserId;
        String? currentUserName;
        String? currentMembership;
        if (authState is AuthAuthenticated) {
          final user = authState.user;
          isCurrentUserPremium = (user['isPremium'] == true) || (user['isGolden'] == true) || (['active', 'verified', 'premium', 'golden'].contains(user['membershipType']));
          currentUserId = user['_id'] as String?;
          currentUserName = user['fullName'] as String?;
          currentMembership = user['membershipType'] as String?;
          final posterId = postedBy?['_id'];
          isCurrentUserOwner = mine || (currentUserId != null && posterId != null && currentUserId == posterId);
        }

        final acceptedByList = List.from(requirement['acceptedBy'] as List? ?? []);
        final hasCurrentUserAccepted = currentUserId != null && acceptedByList.any((id) => id.toString() == currentUserId);
        final isBooked = requirement['status'] == 'accepted';
        final isCancelled = requirement['status'] == 'cancelled';
        final isOnHold = requirement['status'] == 'on_hold';

        final memberType = (mine ? currentMembership : (postedBy?['membershipType'] as String?)) ?? 'new';
        Color topBarColor;
        String? badgeText;
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
          topBarColor = AppColors.memberVerified;
          badgeText = 'NEW USER';
        }
        final Color cardBg = topBarColor.withOpacity(0.07);
        final Color badgeColor = topBarColor;
        final Color badgeBg = topBarColor.withOpacity(0.12);

        final (statusLabel, statusColor) = _statusInfo(requirement['status'] as String?);
        final num total = (requirement['totalAmount'] as num?) ?? 0;
        final num driverEarning = (requirement['fare'] as num?) ?? 0;
        final num commission = (requirement['commission'] as num?) ?? 0;
        final notes = (requirement['notes'] as String?)?.trim() ?? '';
        final rating = (postedBy?['rating'] as num?)?.toDouble() ?? 0;
        final canContact = isCurrentUserPremium || isCurrentUserOwner;
        final mobile = postedBy?['mobile'] as String?;
        void openSheet() {
          if (postedBy != null) showUserCardSheet(context, Map<String, dynamic>.from(postedBy));
        }

        return GestureDetector(
          onTap: onTap == null
              ? null
              : () {
                  if (isCancelled) return;
                  if (isBooked && !isCurrentUserOwner && !hasCurrentUserAccepted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: const Text('This requirement is already booked'), backgroundColor: Colors.red[700], duration: const Duration(seconds: 2)),
                    );
                    return;
                  }
                  onTap!();
                },
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(color: topBarColor.withOpacity(0.3), width: 1),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 1))],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10.r),
              child: Stack(
                children: [
                  Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _WatermarkPainter()))),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 4.h,
                        decoration: BoxDecoration(color: topBarColor, borderRadius: BorderRadius.vertical(top: Radius.circular(10.r))),
                      ),
                      Padding(
                        padding: EdgeInsets.all(12.r),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header: status (Open) + requirement ID, trip type / secure on the right
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: EdgeInsets.only(top: 4.h),
                                  child: Icon(Icons.circle, size: 10.sp, color: statusColor),
                                ),
                                SizedBox(width: 8.w),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(statusLabel, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700, color: statusColor)),
                                      Text('ID-${requirement['requirementId'] ?? requirement['bookingId'] ?? ''}',
                                          style: TextStyle(fontSize: 11.sp, color: Colors.grey[600], fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    if (menu != null) ...[
                                      menu!,
                                      SizedBox(height: 6.h),
                                    ],
                                    _chip((requirement['tripType'] as String? ?? '').replaceAll('_', ' ').toUpperCase(), topBarColor, filled: true),
                                    if (requirement['tripType'] == 'round_trip')
                                      Builder(builder: (_) {
                                        final d = _roundTripDays(requirement['travelDate'], requirement['returnDate']);
                                        if (d.isEmpty) return const SizedBox.shrink();
                                        return Padding(
                                          padding: EdgeInsets.only(top: 4.h),
                                          child: Text(d, style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w700, color: topBarColor)),
                                        );
                                      }),
                                  ],
                                ),
                              ],
                            ),
                            SizedBox(height: 10.h),
                            Divider(height: 1, color: Colors.black26),
                            SizedBox(height: 10.h),

                            // 3. Vertical route: FROM -> stops -> TO
                            Builder(builder: (context) {
                              final rawStops = requirement['stops'];
                              // Keep only well-formed stop entries (maps with an address).
                              final stops = rawStops is List
                                  ? rawStops.whereType<Map>().where((m) => (m['address'] ?? '').toString().trim().isNotEmpty).toList()
                                  : const <Map>[];

                              Widget point(IconData icon, Color color, String label, String text, {required bool showLine}) {
                                return IntrinsicHeight(
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Column(
                                        children: [
                                          Icon(icon, size: 14.sp, color: color),
                                          if (showLine)
                                            Expanded(
                                              child: Container(
                                                width: 2,
                                                margin: EdgeInsets.symmetric(vertical: 2.h),
                                                color: Colors.grey.shade400,
                                              ),
                                            ),
                                        ],
                                      ),
                                      SizedBox(width: 10.w),
                                      Expanded(
                                        child: Padding(
                                          padding: EdgeInsets.only(bottom: showLine ? 10.h : 0),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(label, style: TextStyle(fontSize: 9.sp, color: Colors.grey[600], fontWeight: FontWeight.w600)),
                                              Text(text,
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold, color: Colors.black)),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }

                              final timeline = Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  point(Icons.trip_origin, Colors.green, 'FROM', requirement['pickupCity'] as String? ?? '', showLine: true),
                                  ...stops.asMap().entries.map((e) {
                                    return point(Icons.add_location_alt, topBarColor, 'STOP ${e.key + 1}', (e.value['address'] ?? '').toString(), showLine: true);
                                  }),
                                  point(Icons.location_on, Colors.red, 'TO', requirement['dropCity'] as String? ?? '', showLine: false),
                                ],
                              );

                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Total distance, vertical, on the left of the route.
                                  if (requirement['estimatedDistance'] != null) ...[
                                    RotatedBox(
                                      quarterTurns: 3,
                                      child: Text('${requirement['estimatedDistance']} KM',
                                          style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.bold, color: topBarColor)),
                                    ),
                                    SizedBox(width: 8.w),
                                  ],
                                  Expanded(child: timeline),
                                ],
                              );
                            }),
                            SizedBox(height: 10.h),
                            Divider(height: 1, color: Colors.black26),
                            SizedBox(height: 10.h),

                            // 4. vehicle + date/time box
                            Row(
                              children: [
                                Icon(Icons.directions_car, size: 18.sp, color: topBarColor),
                                SizedBox(width: 8.w),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(_formatVehicleType(requirement['vehicleType']), style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold, color: Colors.black)),
                                      Text('Any Fuel | Carrier Does Not Matter', style: TextStyle(fontSize: 11.sp, color: Colors.grey[600])),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                                  decoration: BoxDecoration(color: topBarColor, borderRadius: BorderRadius.circular(8.r)),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Text(_formatDate(requirement['travelDate']), style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold, color: Colors.white)),
                                      Text(requirement['travelTime'] as String? ?? '', style: TextStyle(fontSize: 12.sp, color: Colors.white)),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            // 5. notes
                            if (notes.isNotEmpty) ...[
                              SizedBox(height: 10.h),
                              Divider(height: 1, color: Colors.black26),
                              SizedBox(height: 10.h),
                              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Icon(Icons.chat_bubble, size: 16.sp, color: topBarColor),
                                SizedBox(width: 8.w),
                                Expanded(child: Text(notes, style: TextStyle(fontSize: 13.sp, color: Colors.black87))),
                              ]),
                            ],

                            SizedBox(height: 10.h),
                            Divider(height: 1, color: Colors.black26),
                            SizedBox(height: 10.h),

                            // 6. pricing breakdown
                            IntrinsicHeight(
                              child: Row(
                                children: [
                                  Expanded(child: _priceCol(Icons.account_balance_wallet, 'Total Amount', total, topBarColor)),
                                  VerticalDivider(width: 1, color: Colors.black26),
                                  Expanded(child: _priceCol(Icons.person, "Driver's Earning", driverEarning, topBarColor)),
                                  VerticalDivider(width: 1, color: Colors.black26),
                                  Expanded(child: _priceCol(Icons.percent, 'Commission', commission, topBarColor)),
                                ],
                              ),
                            ),
                            SizedBox(height: 10.h),
                            Divider(height: 1, color: Colors.black26),
                            SizedBox(height: 10.h),

                            // 7. poster
                            Row(
                              children: [
                                GestureDetector(
                                  onTap: postedBy == null ? null : openSheet,
                                  child: CircleAvatar(
                                    radius: 20.r,
                                    backgroundColor: topBarColor.withOpacity(0.12),
                                    backgroundImage: postedBy?['profileImage'] != null ? NetworkImage(postedBy!['profileImage'] as String) : null,
                                    child: postedBy?['profileImage'] == null ? Icon(Icons.emoji_events, color: topBarColor, size: 20.sp) : null,
                                  ),
                                ),
                                SizedBox(width: 10.w),
                                Expanded(
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: postedBy == null ? null : openSheet,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(children: [
                                          Flexible(child: Text(postedBy?['fullName'] as String? ?? (mine ? (currentUserName ?? 'You') : 'User'), overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold, color: Colors.black))),
                                          if ((postedBy?['isVerified'] == true) || memberType == 'verified' || memberType == 'golden') ...[
                                            SizedBox(width: 4.w),
                                            Icon(Icons.verified, size: 14.sp, color: const Color(0xFF2196F3)),
                                          ],
                                        ]),
                                        Text(
                                          [postedBy?['agencyName'], postedBy?['city'], postedBy?['state']].where((e) => e != null && (e as String).isNotEmpty).join(', '),
                                          maxLines: 1, overflow: TextOverflow.ellipsis,
                                          style: TextStyle(fontSize: 11.sp, color: Colors.grey[600]),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (badgeText != null)
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                                    decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(4.r), border: Border.all(color: badgeColor)),
                                    child: Text(badgeText, style: TextStyle(fontSize: 8.sp, color: badgeColor, fontWeight: FontWeight.w600)),
                                  ),
                              ],
                            ),
                            SizedBox(height: 12.h),
                            Divider(height: 1, color: Colors.black26),
                            SizedBox(height: 10.h),

                            // 8. actions (gated)
                            if (canContact)
                              Row(
                                children: [
                                  _action(const Icon(Icons.call, color: Color(0xFF2196F3), size: 22), 'Phone',
                                      (mobile != null && mobile.isNotEmpty) ? () => callNumber(mobile) : openSheet),
                                  _action(const FaIcon(FontAwesomeIcons.whatsapp, color: Color(0xFF25D366), size: 22), 'Whatsapp',
                                      (mobile != null && mobile.isNotEmpty) ? () => openWhatsApp(mobile) : openSheet),
                                  _action(Icon(Icons.notifications_active, color: Colors.amber.shade700, size: 22), 'Advice',
                                      () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Don't pay without reference!")))),
                                  _ratingAction(rating),
                                  _action(Icon(Icons.report, color: Colors.red.shade400, size: 22), 'Report',
                                      postedBy?['_id'] == null
                                          ? null
                                          : () => context.push('/users/${postedBy!['_id']}', extra: {...postedBy, '__openReport': true})),
                                ],
                              )
                            else
                              GestureDetector(
                                onTap: null,
                                child: SizedBox(
                                  width: double.infinity,
                                  child: Text('Become a premium member to contact immediately',
                                      textAlign: TextAlign.center, style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: Colors.red)),
                                ),
                              ),
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
                              text: isCancelled ? 'CANCELLED' : isOnHold ? 'ON HOLD' : hasCurrentUserAccepted ? 'ACCEPTED' : 'BOOKED',
                              color: isCancelled ? Colors.grey[600]! : isOnHold ? Colors.orange[800]! : hasCurrentUserAccepted ? Colors.green[700]! : Colors.red[700]!,
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

  Widget _chip(String text, Color color, {bool filled = false}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: filled ? color.withOpacity(0.12) : Colors.grey[100],
        borderRadius: BorderRadius.circular(6.r),
        border: filled ? Border.all(color: color.withOpacity(0.5)) : null,
      ),
      child: Text(text, style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w700, color: filled ? color : Colors.grey[700])),
    );
  }

  Widget _priceCol(IconData icon, String label, num amount, Color color) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 16.sp, color: color),
        SizedBox(height: 4.h),
        Text('₹${amount.round()}', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold, color: Colors.black)),
        SizedBox(height: 2.h),
        Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 10.sp, color: Colors.grey[600])),
      ],
    );
  }

  Widget _action(Widget icon, String label, VoidCallback? onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            SizedBox(height: 4.h),
            Text(label, style: TextStyle(fontSize: 10.sp, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _ratingAction(double rating) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.star, size: 16.sp, color: Colors.amber),
            SizedBox(width: 2.w),
            Text(rating > 0 ? rating.toStringAsFixed(1) : '—', style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold, color: Colors.black)),
          ]),
          SizedBox(height: 4.h),
          Text('Rating', style: TextStyle(fontSize: 10.sp, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  (String, Color) _statusInfo(String? status) {
    switch (status) {
      case 'accepted':
        return ('Booked', Colors.red.shade600);
      case 'on_hold':
        return ('On Hold', Colors.orange.shade700);
      case 'cancelled':
        return ('Cancelled', Colors.grey.shade600);
      default:
        return ('Open', Colors.green.shade600);
    }
  }

  // Inclusive day count between travel and return dates, e.g. 30 Jun -> 2 Jul = "3 days".
  String _roundTripDays(dynamic travel, dynamic ret) {
    final t = DateTime.tryParse(travel?.toString() ?? '');
    final r = DateTime.tryParse(ret?.toString() ?? '');
    if (t == null || r == null) return '';
    final days = DateTime(r.year, r.month, r.day).difference(DateTime(t.year, t.month, t.day)).inDays + 1;
    if (days < 1) return '';
    return '$days day${days == 1 ? '' : 's'}';
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
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.star, color: color, size: 9.sp),
                SizedBox(width: 2.w),
                Icon(Icons.star, color: color, size: 9.sp),
                SizedBox(width: 2.w),
                Icon(Icons.star, color: color, size: 9.sp),
              ]),
              SizedBox(height: 3.h),
              Text(text, style: TextStyle(color: color, fontSize: 14.sp, fontWeight: FontWeight.w900, letterSpacing: 2)),
              SizedBox(height: 3.h),
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.star, color: color, size: 9.sp),
                SizedBox(width: 2.w),
                Icon(Icons.star, color: color, size: 9.sp),
                SizedBox(width: 2.w),
                Icon(Icons.star, color: color, size: 9.sp),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  String _formatVehicleType(String? type) => type == null ? '' : vehicleTypeLabel(type);

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
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey.withOpacity(0.2), letterSpacing: 1.2),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final rows = (size.height / rowGap).ceil() + 4;
    final cols = (size.width / colGap).ceil() + 4;

    for (int row = -2; row < rows; row++) {
      for (int col = -2; col < cols; col++) {
        canvas.save();
        canvas.translate(col * colGap, row * rowGap);
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
