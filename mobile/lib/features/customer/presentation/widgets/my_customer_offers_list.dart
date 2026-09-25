import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/api_error.dart';
import '../../data/customer_repository.dart';
import '../pages/driver_customer_requests_page.dart' show MyOfferCard;
import '../utils/invoice_actions.dart';

/// The driver/vendor's WON customer trips (their accepted offers), rendered as a
/// plain column so it can be embedded inside the "Assigned" tab of My Bookings.
/// Self-fetching and self-refreshing; shows nothing when there are none.
class MyCustomerOffersList extends StatefulWidget {
  /// Shown when the driver has no won customer trips (e.g. the Assigned tab's
  /// empty state when there are also no assigned requirements).
  final Widget? emptyPlaceholder;
  const MyCustomerOffersList({super.key, this.emptyPlaceholder});

  @override
  State<MyCustomerOffersList> createState() => _MyCustomerOffersListState();
}

class _MyCustomerOffersListState extends State<MyCustomerOffersList> {
  final _repo = getIt<CustomerRepository>();
  List<Map<String, dynamic>> _mine = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await _repo.myApplications();
      if (!mounted) return;
      // Only trips this driver actually WON (their offer was selected/assigned).
      setState(() {
        _mine = d.where((b) => (b['myOffer'] as Map?)?['status'] == 'selected').toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String m, {bool ok = false}) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m), backgroundColor: ok ? AppColors.success : AppColors.error));

  Future<void> _arrived(String id) async {
    try {
      await _repo.driverArrived(id);
      _snack('Customer notified you are arriving 🚗', ok: true);
      _load();
    } catch (e) {
      _snack('Could not notify: ${serverMessage(e)}');
    }
  }

  Future<void> _driverCancel(String id) async {
    final reasonCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this trip?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('You were selected for this trip. Cancelling now may forfeit part or all of your commitment hold as a penalty (per admin policy).',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Reason (optional)',
                filled: true,
                fillColor: Colors.grey[50],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep Trip')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: const Text('Cancel Trip'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.driverCancel(id, reason: reasonCtrl.text.trim().isEmpty ? null : reasonCtrl.text.trim());
      _snack('Trip cancelled', ok: true);
      _load();
    } catch (e) {
      _snack('Could not cancel: ${serverMessage(e)}');
    }
  }

  Future<void> _tripOtpFlow(String id, String action) async {
    final label = action == 'start' ? 'start' : 'complete';
    try {
      await _repo.requestTripOtp(id, action);
    } catch (e) {
      _snack('Could not send OTP: ${serverMessage(e)}');
      return;
    }
    if (!mounted) return;
    _snack('OTP sent to the customer — ask them to read it out.', ok: true);
    final otp = await _askOtp(action);
    if (otp == null || otp.trim().isEmpty) return;
    try {
      await _repo.verifyTripOtp(id, action, otp.trim());
      _snack(action == 'start' ? 'Trip started 🚕' : 'Trip completed 🎉', ok: true);
      _load();
    } catch (e) {
      _snack('Could not $label: ${serverMessage(e)}');
    }
  }

  Future<String?> _askOtp(String action) {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(action == 'start' ? 'Start Trip OTP' : 'Complete Trip OTP'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ask the customer for the 6-digit OTP shown in their app and enter it below.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 14),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              maxLength: 6,
              autofocus: true,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 6),
              decoration: InputDecoration(
                counterText: '',
                hintText: '••••••',
                filled: true,
                fillColor: Colors.grey[50],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            child: const Text('Verify'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();
    if (_mine.isEmpty) return widget.emptyPlaceholder ?? const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 8.h, top: 4.h),
          child: Text('Customer Trips'.toUpperCase(),
              style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 0.5)),
        ),
        ..._mine.map((b) => Padding(
              padding: EdgeInsets.only(bottom: 12.h),
              child: MyOfferCard(
                b,
                onStart: (id) => _tripOtpFlow(id, 'start'),
                onComplete: (id) => _tripOtpFlow(id, 'end'),
                onArrived: _arrived,
                onCancel: _driverCancel,
                onInvoice: (id) => downloadAndOpenInvoice(context, _repo, id),
              ),
            )),
      ],
    );
  }
}
