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
  bool _savingCharges = false;

  late final TextEditingController _tollC;
  late final TextEditingController _parkingC;
  late final TextEditingController _otherC;

  @override
  void initState() {
    super.initState();
    String init(dynamic v) {
      final n = _num(v);
      return n > 0 ? n.toStringAsFixed(0) : '';
    }
    _tollC = TextEditingController(text: init(_b['tollCharge']));
    _parkingC = TextEditingController(text: init(_b['parkingCharge']));
    _otherC = TextEditingController(text: init(_b['otherCharge']));
  }

  @override
  void dispose() {
    _tollC.dispose();
    _parkingC.dispose();
    _otherC.dispose();
    super.dispose();
  }

  Map<String, dynamic> get _b => widget.booking;
  String get _id => (_b['_id'] ?? _b['id'] ?? '').toString();
  bool get _isCab => (_b['serviceType'] ?? 'cab').toString() == 'cab';
  // Charges can be entered only once; locked after the first save.
  bool get _chargesLocked => (_b['tripChargesSavedAt'] ?? '').toString().isNotEmpty;

  double _num(dynamic v) => v is num ? v.toDouble() : (double.tryParse('$v') ?? 0);

  /// "2h 15m" trip duration from startedAt→completedAt, or '' if unavailable.
  String get _duration {
    final s = DateTime.tryParse('${_b['startedAt'] ?? ''}');
    final e = DateTime.tryParse('${_b['completedAt'] ?? ''}');
    if (s == null || e == null || !e.isAfter(s)) return '';
    final mins = e.difference(s).inMinutes;
    final h = mins ~/ 60, m = mins % 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }

  Future<void> _saveCharges() async {
    FocusScope.of(context).unfocus();
    // One-time save — warn the driver it cannot be edited afterwards.
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save charges?'),
        content: const Text(
            'You can add these charges only once. After saving, Toll / Parking / Other cannot be edited. Double-check the amounts.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Review again')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            child: const Text('Save & lock'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _savingCharges = true);
    try {
      final updated = await _repo.updateTripCharges(
        _id,
        toll: double.tryParse(_tollC.text.trim()) ?? 0,
        parking: double.tryParse(_parkingC.text.trim()) ?? 0,
        other: double.tryParse(_otherC.text.trim()) ?? 0,
      );
      if (updated != null) widget.booking.addAll(updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Charges saved to the bill'), backgroundColor: AppColors.success),
        );
        setState(() {});
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save charges. Try again.'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _savingCharges = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final includedKm = _num(_b['includedKm'] ?? _b['estimatedDistance']);
    final trackedKm = _num(_b['trackedKm']);
    final extraKm = _num(_b['extraKm']);
    final extraCharge = _num(_b['extraCharge']);
    // Driver collects the GST-free amount — GST is the platform's, not the driver's.
    final gstAmount = _num(_b['gstAmount']);
    final rawTotal = _num(_b['finalFare'] ?? _b['fare'] ?? _b['estimatedFare'] ?? _b['totalFare']);
    final total = (rawTotal - gstAmount).clamp(0, double.infinity).toDouble();
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
    final tollCharge = _num(_b['tollCharge']);
    final parkingCharge = _num(_b['parkingCharge']);
    final otherCharge = _num(_b['otherCharge']);
    final baseFare = (total - extraCharge - extraHourCharge - tollCharge - parkingCharge - otherCharge)
        .clamp(0, double.infinity)
        .toDouble();
    final duration = _duration;

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

          // Distance (GPS) + trip duration
          _card('Distance & Duration', [
            _row('Included distance', '${includedKm.toStringAsFixed(1)} km'),
            _row('Total distance (GPS)', '${trackedKm.toStringAsFixed(1)} km'),
            if (extraKm > 0) _row('Extra distance', '${extraKm.toStringAsFixed(1)} km', highlight: true),
            if (duration.isNotEmpty) _row('Trip duration', duration),
          ]),
          SizedBox(height: 12.h),

          // Additional charges the driver adds to the bill (cab bookings only).
          if (_isCab) ...[
            _chargesCard(),
            SizedBox(height: 12.h),
          ],

          // Fare
          _card('Fare Summary', [
            _row('Base fare', '₹${baseFare.toStringAsFixed(0)}'),
            if (extraCharge > 0) _row('Extra km charge', '₹${extraCharge.toStringAsFixed(0)}', highlight: true),
            if (extraHourCharge > 0) _row('Extra hours charge', '₹${extraHourCharge.toStringAsFixed(0)}', highlight: true),
            if (tollCharge > 0) _row('Toll', '₹${tollCharge.toStringAsFixed(0)}'),
            if (parkingCharge > 0) _row('Parking', '₹${parkingCharge.toStringAsFixed(0)}'),
            if (otherCharge > 0) _row('Other charges', '₹${otherCharge.toStringAsFixed(0)}'),
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

  /// Driver enters toll / parking / other charges here; "Save" persists them and
  /// recomputes the total + cash to collect. No tax line.
  Widget _chargesCard() => Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Additional Charges',
              style: TextStyle(fontSize: 13.5.sp, fontWeight: FontWeight.w800, color: AppColors.textPrimary, fontFamily: 'Poppins')),
          SizedBox(height: 2.h),
          Text(
              _chargesLocked
                  ? 'Toll / parking / other charges were saved for this trip. They can be added only once and cannot be edited.'
                  : 'Add any toll, parking or other approved charges — these are added to the cash the customer pays. You can save them only ONCE.',
              style: TextStyle(fontSize: 10.5.sp, color: AppColors.textSecondary, fontFamily: 'Poppins')),
          SizedBox(height: 12.h),
          if (_chargesLocked) ...[
            // Read-only once saved.
            _row('Toll', '₹${_num(_b['tollCharge']).toStringAsFixed(0)}'),
            _row('Parking', '₹${_num(_b['parkingCharge']).toStringAsFixed(0)}'),
            _row('Other charges', '₹${_num(_b['otherCharge']).toStringAsFixed(0)}'),
            SizedBox(height: 10.h),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
              decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10.r)),
              child: Row(children: [
                Icon(Icons.lock_rounded, size: 16.sp, color: AppColors.success),
                SizedBox(width: 8.w),
                Expanded(child: Text('Charges saved — cannot be edited.',
                    style: TextStyle(fontSize: 11.5.sp, fontWeight: FontWeight.w700, color: AppColors.success, fontFamily: 'Poppins'))),
              ]),
            ),
          ] else ...[
            _chargeField('Toll', _tollC),
            SizedBox(height: 10.h),
            _chargeField('Parking', _parkingC),
            SizedBox(height: 10.h),
            _chargeField('Other charges', _otherC),
            SizedBox(height: 14.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _savingCharges ? null : _saveCharges,
                icon: _savingCharges
                    ? SizedBox(width: 16.w, height: 16.w, child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Icon(Icons.save_rounded, size: 18.sp),
                label: Text(_savingCharges ? 'Saving…' : 'Save charges (one time)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                ),
              ),
            ),
          ],
        ]),
      );

  Widget _chargeField(String label, TextEditingController c) => Row(
        children: [
          Expanded(
            child: Text(label, style: TextStyle(fontSize: 12.5.sp, color: AppColors.textSecondary, fontFamily: 'Poppins')),
          ),
          SizedBox(
            width: 120.w,
            child: TextField(
              controller: c,
              keyboardType: const TextInputType.numberWithOptions(decimal: false),
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, fontFamily: 'Poppins'),
              decoration: InputDecoration(
                prefixText: '₹ ',
                hintText: '0',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r), borderSide: const BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r), borderSide: const BorderSide(color: AppColors.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r), borderSide: const BorderSide(color: AppColors.primary)),
              ),
            ),
          ),
        ],
      );

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
