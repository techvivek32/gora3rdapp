import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/customer_repository.dart';
import '../utils/invoice_actions.dart';

/// Shown to the driver right after they complete a trip: distance breakdown
/// (included vs extra km), any extra charge, total fare, advance already paid to
/// the platform, and the balance the driver collected in cash. From here the
/// driver downloads the invoice or returns home.
class DriverTripSummaryPage extends StatefulWidget {
  final Map<String, dynamic> booking;
  const DriverTripSummaryPage({super.key, required this.booking});

  @override
  State<DriverTripSummaryPage> createState() => _DriverTripSummaryPageState();
}

class _DriverTripSummaryPageState extends State<DriverTripSummaryPage> {
  final _repo = getIt<CustomerRepository>();
  bool _downloading = false;

  Map<String, dynamic> get _b => widget.booking;
  String get _id => (_b['_id'] ?? _b['id'] ?? '').toString();

  double _num(dynamic v) => v is num ? v.toDouble() : (double.tryParse('$v') ?? 0);

  @override
  Widget build(BuildContext context) {
    final includedKm = _num(_b['includedKm'] ?? _b['estimatedDistance']);
    final trackedKm = _num(_b['trackedKm']);
    final extraKm = _num(_b['extraKm']);
    final extraCharge = _num(_b['extraCharge']);
    final total = _num(_b['finalFare'] ?? _b['fare'] ?? _b['estimatedFare'] ?? _b['totalFare']);
    final advance = (_b['advanceStatus']?.toString() == 'paid') ? _num(_b['advanceAmount']) : 0.0;
    final collected = (total - advance).clamp(0, double.infinity).toDouble();
    final isRound = (_b['subType'] ?? '').toString() == 'Round Trip';
    final retM = RegExp(r'Return date:\s*(\d{2})-(\d{2})-(\d{4})').firstMatch((_b['notes'] ?? '').toString());
    final returnLabel = retM == null ? '' : '${retM.group(1)}-${retM.group(2)}-${retM.group(3)}';
    final isLocal = (_b['subType'] ?? '').toString() == 'Local';
    final packageHours = _num(_b['packageHours']);
    final extraHours = _num(_b['extraHours']);
    final extraHourCharge = _num(_b['extraHourCharge']);
    final extraHourPrice = _num(_b['extraHourPrice']);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        title: const Text('Trip Completed', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        centerTitle: true,
      ),
      body: ListView(
        padding: EdgeInsets.all(16.w),
        children: [
          SizedBox(height: 8.h),
          Center(
            child: Container(
              padding: EdgeInsets.all(18.w),
              decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.12), shape: BoxShape.circle),
              child: Icon(Icons.check_circle_rounded, color: AppColors.success, size: 56.sp),
            ),
          ),
          SizedBox(height: 12.h),
          Center(
            child: Text('Trip completed successfully!',
                style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w800, color: AppColors.textPrimary, fontFamily: 'Poppins')),
          ),
          SizedBox(height: 4.h),
          Center(
            child: Text('Booking ID: ${(_b['humanId'] ?? _b['bookingId'] ?? _id).toString()}',
                style: TextStyle(fontSize: 12.sp, color: AppColors.textSecondary, fontFamily: 'Poppins')),
          ),
          if (isRound || isLocal) ...[
            SizedBox(height: 8.h),
            Center(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 5.h),
                decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20.r)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(isLocal ? Icons.timelapse_rounded : Icons.sync_rounded, size: 13.sp, color: AppColors.primary),
                  SizedBox(width: 5.w),
                  Text(
                    isLocal
                        ? 'Local · ${packageHours.toStringAsFixed(0)}-hour package'
                        : (returnLabel.isNotEmpty ? 'Round Trip · Return $returnLabel' : 'Round Trip'),
                    style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w700, color: AppColors.primary, fontFamily: 'Poppins'),
                  ),
                ]),
              ),
            ),
          ],
          SizedBox(height: 20.h),

          // Duration (Local hourly packages)
          if (isLocal) ...[
            _card('Duration', [
              _row('Package', '${packageHours.toStringAsFixed(0)} hours'),
              if (extraHourPrice > 0) _row('Extra hour rate', '₹${extraHourPrice.toStringAsFixed(0)}/hr'),
              if (extraHours > 0) _row('Extra hours', '${extraHours.toStringAsFixed(0)} hr', highlight: true),
            ]),
            SizedBox(height: 12.h),
          ],

          // Distance
          _card('Distance', [
            _row('Included distance', '${includedKm.toStringAsFixed(1)} km'),
            _row('Total distance run', '${trackedKm.toStringAsFixed(1)} km'),
            if (extraKm > 0) _row('Extra distance', '${extraKm.toStringAsFixed(1)} km', highlight: true),
          ]),
          SizedBox(height: 12.h),

          // Fare
          _card('Fare Summary', [
            _row('Base fare', '₹${(total - extraCharge - extraHourCharge).toStringAsFixed(0)}'),
            if (extraCharge > 0) _row('Extra km charge', '₹${extraCharge.toStringAsFixed(0)}', highlight: true),
            if (extraHourCharge > 0) _row('Extra hours charge', '₹${extraHourCharge.toStringAsFixed(0)}', highlight: true),
            const Divider(height: 20),
            _row('Total fare', '₹${total.toStringAsFixed(0)}', bold: true),
            if (advance > 0) _row('Advance paid (to platform)', '- ₹${advance.toStringAsFixed(0)}'),
          ]),
          SizedBox(height: 12.h),

          // Amount collected
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Amount collected (cash)', style: TextStyle(fontSize: 12.sp, color: AppColors.textSecondary, fontFamily: 'Poppins')),
                  SizedBox(height: 2.h),
                  Text('from the customer', style: TextStyle(fontSize: 10.5.sp, color: AppColors.textSecondary, fontFamily: 'Poppins')),
                ]),
                Text('₹${collected.toStringAsFixed(0)}',
                    style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.w900, color: AppColors.success, fontFamily: 'Poppins')),
              ],
            ),
          ),
          if (advance > 0) ...[
            SizedBox(height: 8.h),
            Text('The ₹${advance.toStringAsFixed(0)} advance has been credited to your wallet.',
                style: TextStyle(fontSize: 11.sp, color: AppColors.textSecondary, fontFamily: 'Poppins')),
          ],
          SizedBox(height: 24.h),

          OutlinedButton.icon(
            onPressed: _downloading ? null : _downloadInvoice,
            icon: _downloading
                ? SizedBox(width: 18.w, height: 18.w, child: const CircularProgressIndicator(strokeWidth: 2))
                : Icon(Icons.download_rounded, size: 20.sp),
            label: Text(_downloading ? 'Preparing…' : 'Download Invoice'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              padding: EdgeInsets.symmetric(vertical: 14.h),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
            ),
          ),
          SizedBox(height: 10.h),
          ElevatedButton(
            onPressed: () => context.go('/'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 15.h),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
            ),
            child: Text('Go to Home', style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w800, fontFamily: 'Poppins')),
          ),
          SizedBox(height: 16.h),
        ],
      ),
    );
  }

  Widget _card(String title, List<Widget> children) => Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontSize: 13.5.sp, fontWeight: FontWeight.w800, color: AppColors.textPrimary, fontFamily: 'Poppins')),
          SizedBox(height: 10.h),
          ...children,
        ]),
      );

  Widget _row(String label, String value, {bool bold = false, bool highlight = false}) => Padding(
        padding: EdgeInsets.symmetric(vertical: 4.h),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(child: Text(label, style: TextStyle(fontSize: 12.5.sp, color: AppColors.textSecondary, fontFamily: 'Poppins'))),
            Text(value,
                style: TextStyle(
                  fontSize: bold ? 14.5.sp : 12.5.sp,
                  fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
                  color: highlight ? AppColors.primary : AppColors.textPrimary,
                  fontFamily: 'Poppins',
                )),
          ],
        ),
      );

  Future<void> _downloadInvoice() async {
    setState(() => _downloading = true);
    try {
      await downloadAndOpenInvoice(context, _repo, _id);
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }
}
