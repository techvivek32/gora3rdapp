import 'dart:math';
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

/// Parse a stored travelDate to the intended CALENDAR day, ignoring any time /
/// timezone so "8 Sep" never displays as "7 Sep" after a UTC round-trip. Uses
/// only the yyyy-MM-dd part and builds a local midnight DateTime.
DateTime? tripDate(dynamic raw) {
  if (raw == null) return null;
  final s = raw.toString();
  if (s.isEmpty) return null;
  final datePart = s.contains('T') ? s.split('T').first : s;
  final p = datePart.split('-');
  if (p.length == 3) {
    final y = int.tryParse(p[0]), m = int.tryParse(p[1]), d = int.tryParse(p[2]);
    if (y != null && m != null && d != null) return DateTime(y, m, d);
  }
  return DateTime.tryParse(s);
}

/// Format a travelDate string as a plain "yyyy-MM-dd" so the server stores the
/// exact calendar day the customer picked (no time/timezone shift).
String ymdString(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Colored top bar + tinted body wrapper (requirement-card style). When [stamp]
/// is set (a terminal state like CANCELLED / EXPIRED / COMPLETED) the body is
/// dimmed and a rotated rubber-stamp is pressed over the card.
Widget brandCard({required Widget child, Color color = AppColors.primary, VoidCallback? onTap, String? stamp, Color? stampColor}) {
  final dimmed = stamp != null && stamp.isNotEmpty;
  final body = ClipRRect(
    borderRadius: BorderRadius.circular(10.r),
    child: Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(height: 4.h, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.vertical(top: Radius.circular(10.r)))),
            Opacity(
              opacity: dimmed ? 0.35 : 1.0,
              child: Padding(padding: EdgeInsets.all(12.r), child: child),
            ),
          ],
        ),
        if (dimmed)
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: Transform.rotate(angle: -0.2, child: bookingStampBadge(stamp, stampColor ?? color)),
              ),
            ),
          ),
      ],
    ),
  );
  final card = Container(
    margin: EdgeInsets.symmetric(horizontal: 2.w, vertical: 6.h),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(10.r),
      border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 1))],
    ),
    child: body,
  );
  if (onTap == null) return card;
  // opaque → the whole card (including the dimmed/stamped area) stays tappable,
  // so a completed/cancelled booking still opens its details.
  return GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: card);
}

/// Round rubber-stamp badge (same look as the requirement card's stamp).
Widget bookingStampBadge(String text, Color color) => SizedBox(
      width: 140.w,
      height: 140.w,
      child: CustomPaint(
        painter: _StampRingPainter(color: color, topText: text, bottomText: 'GORA TAXI PARTNER'),
        child: Center(
          child: SizedBox(
            width: 88.w,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _stars(color),
                  SizedBox(height: 4.h),
                  Text(text, style: TextStyle(color: color, fontSize: 19.sp, fontWeight: FontWeight.w900, letterSpacing: 2)),
                  SizedBox(height: 4.h),
                  _stars(color),
                ],
              ),
            ),
          ),
        ),
      ),
    );

Widget _stars(Color color) => Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.star, color: color, size: 12.sp),
      SizedBox(width: 3.w),
      Icon(Icons.star, color: color, size: 12.sp),
      SizedBox(width: 3.w),
      Icon(Icons.star, color: color, size: 12.sp),
    ]);

/// Terminal-state stamp text/color for a booking, or null when the card should
/// stay active (open / confirmed / ongoing).
(String, Color)? bookingStamp(String status) {
  switch (status) {
    case 'cancelled': return ('CANCELLED', Colors.red.shade700);
    case 'expired': return ('EXPIRED', Colors.grey.shade600);
    case 'completed': return ('COMPLETED', Colors.green.shade700);
    default: return null;
  }
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

class _StampRingPainter extends CustomPainter {
  final Color color;
  final String topText;
  final String bottomText;
  _StampRingPainter({required this.color, required this.topText, required this.bottomText});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rOuter = size.width / 2 - 2;
    final rInner = rOuter - 20;
    final rText = (rOuter + rInner) / 2;

    final outerPaint = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 4;
    final innerPaint = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 3;
    canvas.drawCircle(center, rOuter, outerPaint);
    canvas.drawCircle(center, rInner, innerPaint);

    final style = TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1.2, height: 1.0);
    _drawArcText(canvas, center, topText, rText, style, top: true);
    _drawArcText(canvas, center, bottomText, rText, style, top: false);
  }

  void _drawArcText(Canvas canvas, Offset center, String text, double radius, TextStyle style, {required bool top}) {
    if (text.isEmpty || radius <= 0) return;
    final painters = <TextPainter>[];
    double totalWidth = 0;
    for (final ch in text.split('')) {
      final tp = TextPainter(text: TextSpan(text: ch, style: style), textDirection: TextDirection.ltr)..layout();
      painters.add(tp);
      totalWidth += tp.width;
    }
    final span = totalWidth / radius;
    final centerAngle = top ? -pi / 2 : pi / 2;
    double consumed = 0;
    for (final tp in painters) {
      final charSpan = tp.width / radius;
      final offset = consumed + charSpan / 2 - span / 2;
      final theta = top ? centerAngle + offset : centerAngle - offset;
      canvas.save();
      canvas.translate(center.dx, center.dy);
      if (top) {
        canvas.rotate(theta + pi / 2);
        canvas.translate(0, -radius);
      } else {
        canvas.rotate(theta - pi / 2);
        canvas.translate(0, radius);
      }
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
      consumed += charSpan;
    }
  }

  @override
  bool shouldRepaint(covariant _StampRingPainter old) =>
      old.color != color || old.topText != topText || old.bottomText != bottomText;
}

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
