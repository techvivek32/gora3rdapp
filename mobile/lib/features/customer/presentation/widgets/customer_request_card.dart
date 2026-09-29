import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_theme.dart';
import 'booking_card_ui.dart';

/// Shared "customer request" card, used by the Customer Rides page. A driver
/// taps Accept to register interest; an admin then assigns one accepted driver.
class CustomerRequestCard extends StatelessWidget {
  final Map<String, dynamic> booking;
  final VoidCallback onApply;
  /// Only Golden members can accept. When false, the card shows a
  /// "Golden membership required" note in place of the Accept button.
  final bool canAccept;
  const CustomerRequestCard(this.booking, {super.key, required this.onApply, this.canAccept = true});

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final service = kServiceNames[(b['serviceType'] ?? '').toString()] ?? 'Booking';
    final pickup = ((b['pickup'] as Map?)?['address'] ?? '').toString();
    final drop = ((b['drop'] as Map?)?['address'] ?? '').toString();
    final date = tripDate(b['travelDate']);
    final fare = b['estimatedFare'] ?? 0;
    final applied = b['alreadyApplied'] == true;
    final subType = (b['subType'] ?? '').toString();
    final status = (b['status'] ?? 'open').toString();
    final isOpen = status == 'open';
    // Confirmed/booked ones stay in the feed for 7 days (backend) with a stamp.
    final (String, Color)? stamp = switch (status) {
      'confirmed' || 'ongoing' => ('BOOKED', AppColors.primary),
      'completed' => ('COMPLETED', AppColors.success),
      'cancelled' => ('CANCELLED', AppColors.error),
      'expired' => ('EXPIRED', AppColors.textHint),
      _ => null,
    };

    // Round-trip return date is carried in notes as "Return date: dd-MM-yyyy".
    // Show only the number of days (under the ROUND TRIP chip).
    final rt = RegExp(r'Return date:\s*(\d{2})-(\d{2})-(\d{4})').firstMatch((b['notes'] ?? '').toString());
    final returnDate = rt != null ? DateTime(int.parse(rt.group(3)!), int.parse(rt.group(2)!), int.parse(rt.group(1)!)) : null;
    // Inclusive day count (25→26 = 2 days), consistent with the other screens.
    int? days = (returnDate != null && date != null)
        ? returnDate.difference(DateTime(date.year, date.month, date.day)).inDays + 1
        : null;
    if (days != null && days < 1) days = null;

    // Fare inclusions + round-trip extra-km terms, shown so the driver knows
    // exactly what's covered before accepting.
    final notes = (b['notes'] ?? '').toString();
    final isInclusive = RegExp(r'all\s*inclusive', caseSensitive: false).hasMatch(notes);
    final includedKm = (b['includedKm'] as num?)?.toInt() ?? 0;
    final extraKmPrice = (b['extraKmPrice'] as num?)?.toInt() ?? 0;

    return brandCard(
      stamp: stamp?.$1,
      stampColor: stamp?.$2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(padding: EdgeInsets.only(top: 4.h), child: Icon(Icons.circle, size: 10.sp, color: AppColors.info)),
              SizedBox(width: 8.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text('CUSTOMER', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700, color: AppColors.info)),
                      SizedBox(width: 6.w),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.h),
                        decoration: BoxDecoration(color: AppColors.info.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4.r)),
                        child: Text('APP', style: TextStyle(fontSize: 8.sp, fontWeight: FontWeight.w800, color: AppColors.info)),
                      ),
                    ]),
                    Text(service, style: TextStyle(fontSize: 11.sp, color: Colors.grey[600], fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              if (subType.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    filledChip(subType.toUpperCase(), AppColors.primary),
                    if (days != null) ...[
                      SizedBox(height: 4.h),
                      Text('$days day${days == 1 ? '' : 's'}', style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                    ],
                  ],
                ),
            ],
          ),
          SizedBox(height: 10.h),
          const Divider(height: 1, color: Colors.black26),
          SizedBox(height: 10.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: routeTimeline(pickup, drop)),
              SizedBox(width: 10.w),
              dateTimeBox(date, (b['travelTime'] ?? '').toString(), AppColors.primary),
            ],
          ),
          SizedBox(height: 4.h),
          const Divider(height: 1, color: Colors.black26),
          SizedBox(height: 10.h),
          Row(children: [
            if ((b['vehicleType'] ?? '').toString().isNotEmpty) ...[
              Icon(Icons.local_taxi_rounded, size: 15.sp, color: AppColors.primary),
              SizedBox(width: 5.w),
              Flexible(
                child: Text(
                  b['vehicleType'].toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.5.sp, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
              ),
            ],
            const Spacer(),
            if (fare != 0) Text('Budget: ₹$fare', style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          ]),
          // Fare inclusions/exclusions (one clean line, no boxed background).
          SizedBox(height: 10.h),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(isInclusive ? Icons.verified_rounded : Icons.info_outline_rounded,
                size: 15.sp, color: isInclusive ? AppColors.success : AppColors.warning),
            SizedBox(width: 6.w),
            Expanded(
              child: Text(
                isInclusive
                    ? 'All Inclusive — Toll, State tax, Car parking, Driver allowance & GST included'
                    : 'Best Price — Toll, state tax & parking excluded (collect from customer)',
                style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600,
                    color: isInclusive ? AppColors.success : AppColors.warning),
              ),
            ),
          ]),
          // Included-km / extra-km terms — outside, no white background.
          if (includedKm > 0 || extraKmPrice > 0) ...[
            SizedBox(height: 8.h),
            Row(children: [
              if (includedKm > 0) _kmInfo(Icons.speed_rounded, 'Included $includedKm km'),
              if (includedKm > 0 && extraKmPrice > 0) SizedBox(width: 16.w),
              if (extraKmPrice > 0) _kmInfo(Icons.add_road_rounded, 'Extra ₹$extraKmPrice/km'),
            ]),
          ],
          // Accept only while still open; once booked the stamp says it all.
          // Everyone SEES the booking, but only Golden members can accept —
          // others get a "Golden membership required" note instead of the button.
          if (isOpen) ...[
            SizedBox(height: 12.h),
            if (canAccept)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: applied ? null : onApply,
                  icon: Icon(applied ? Icons.check_rounded : Icons.check_circle_rounded, size: 18.sp),
                  label: Text(applied ? 'Accepted' : 'Accept'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: applied ? AppColors.textHint : AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 11.h),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                  ),
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 11.h, horizontal: 12.w),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.workspace_premium_rounded, size: 18.sp, color: AppColors.warning),
                    SizedBox(width: 8.w),
                    Flexible(
                      child: Text(
                        'Golden membership required to accept',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12.5.sp, fontWeight: FontWeight.w700, color: AppColors.warning),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Included-km / extra-km-rate term — plain icon + text, no background.
Widget _kmInfo(IconData icon, String label) {
  return Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 14.sp, color: AppColors.textSecondary),
    SizedBox(width: 5.w),
    Text(label, style: TextStyle(fontSize: 11.5.sp, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
  ]);
}

/// Content for the "Accept this booking?" dialog. Accepting only registers your
/// interest — our team reviews everyone who accepted and assigns one driver.
/// Accepting is FREE; you only need a minimum wallet balance to be eligible (set
/// by admin). `pct`/`hold` are unused now, kept for call-site compatibility.
Widget acceptHoldContent(int fare, int pct, int hold) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        "You're accepting this booking${fare != 0 ? " (customer's budget ₹$fare)" : ''}. Our team will review everyone who accepted and assign one driver — you'll be notified if you're chosen.",
        style: TextStyle(fontSize: 13.sp, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
      ),
      SizedBox(height: 12.h),
      Container(
        padding: EdgeInsets.all(10.w),
        decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(10.r)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.verified_rounded, size: 16.sp, color: AppColors.success),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              'No commission and nothing is deducted on accept — if assigned, you collect the full fare directly from the customer.',
              style: TextStyle(fontSize: 12.5.sp, fontWeight: FontWeight.w700, color: AppColors.success),
            ),
          ),
        ]),
      ),
      SizedBox(height: 12.h),
      _holdPoint('Eligibility', 'You just need to keep a minimum wallet balance (set by admin) to accept bookings. It is only checked, never charged.'),
    ],
  );
}

Widget _holdPoint(String label, String body) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
      SizedBox(height: 2.h),
      Text(body, style: TextStyle(fontSize: 12.sp, color: AppColors.textSecondary, height: 1.35)),
    ],
  );
}
