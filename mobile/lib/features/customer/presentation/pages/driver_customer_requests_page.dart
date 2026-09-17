import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/contact_launcher.dart';
import '../../data/customer_repository.dart';
import '../widgets/booking_card_ui.dart';
import '../widgets/customer_request_card.dart';

/// Driver / vendor side of Customer Mode: browse customer requests in your
/// city, quote a fare (which places a small wallet commitment hold), and manage
/// the trips you've won. The driver's wallet balance is only shown to the
/// driver — never to the customer.
class DriverCustomerRequestsPage extends StatefulWidget {
  const DriverCustomerRequestsPage({super.key});

  @override
  State<DriverCustomerRequestsPage> createState() => _DriverCustomerRequestsPageState();
}

class _DriverCustomerRequestsPageState extends State<DriverCustomerRequestsPage> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  final _repo = getIt<CustomerRepository>();

  List<Map<String, dynamic>>? _available;
  List<Map<String, dynamic>>? _mine;
  bool _loadingA = true, _loadingM = true;
  String? _errA, _errM;

  @override
  void initState() {
    super.initState();
    _loadAvailable();
    _loadMine();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadAvailable() async {
    setState(() { _loadingA = true; _errA = null; });
    try {
      final d = await _repo.available();
      if (!mounted) return;
      setState(() { _available = d; _loadingA = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _errA = '$e'; _loadingA = false; });
    }
  }

  Future<void> _loadMine() async {
    setState(() { _loadingM = true; _errM = null; });
    try {
      final d = await _repo.myApplications();
      if (!mounted) return;
      setState(() { _mine = d; _loadingM = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _errM = '$e'; _loadingM = false; });
    }
  }

  void _snack(String m, {bool ok = false}) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m), backgroundColor: ok ? AppColors.success : AppColors.error));

  Future<void> _apply(Map<String, dynamic> b) async {
    final id = (b['_id'] ?? b['id'] ?? '').toString();
    final result = await showCustomerApplySheet(context, b);
    if (result == null) return;
    try {
      await _repo.apply(id, result);
      _snack('Offer sent! A commitment hold is placed on your wallet.', ok: true);
      _loadAvailable();
      _loadMine();
    } catch (e) {
      _snack('Could not apply: ${_clean(e)}');
    }
  }

  Future<void> _arrived(String id) async {
    try {
      await _repo.driverArrived(id);
      _snack('Customer notified you are arriving 🚗', ok: true);
      _loadMine();
    } catch (e) {
      _snack('Could not notify: ${_clean(e)}');
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
      _loadMine();
    } catch (e) {
      _snack('Could not cancel: ${_clean(e)}');
    }
  }

  /// OTP-gated trip start/end: ask the server to send the customer an OTP, then
  /// collect it from the driver (the customer reads it out) and verify.
  Future<void> _tripOtpFlow(String id, String action) async {
    final label = action == 'start' ? 'start' : 'complete';
    try {
      await _repo.requestTripOtp(id, action);
    } catch (e) {
      _snack('Could not send OTP: ${_clean(e)}');
      return;
    }
    if (!mounted) return;
    _snack('OTP sent to the customer — ask them to read it out.', ok: true);
    final otp = await _askOtp(action);
    if (otp == null || otp.trim().isEmpty) return;
    try {
      await _repo.verifyTripOtp(id, action, otp.trim());
      _snack(action == 'start' ? 'Trip started 🚕' : 'Trip completed 🎉', ok: true);
      _loadMine();
    } catch (e) {
      _snack('Could not $label: ${_clean(e)}');
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

  String _clean(Object e) => e.toString().replaceFirst('Exception: ', '');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Customer Requests'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [Tab(text: 'Available'), Tab(text: 'My Offers')],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _availableTab(),
          _mineTab(),
        ],
      ),
    );
  }

  Widget _availableTab() {
    if (_loadingA) return const Center(child: CircularProgressIndicator());
    if (_errA != null) return _retry(_errA!, _loadAvailable);
    final items = _available ?? [];
    if (items.isEmpty) return _empty('No customer requests in your city right now');
    return RefreshIndicator(
      onRefresh: _loadAvailable,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => CustomerRequestCard(items[i], onApply: () => _apply(items[i])),
      ),
    );
  }

  Widget _mineTab() {
    if (_loadingM) return const Center(child: CircularProgressIndicator());
    if (_errM != null) return _retry(_errM!, _loadMine);
    final items = _mine ?? [];
    if (items.isEmpty) return _empty('You have not sent any offers yet');
    return RefreshIndicator(
      onRefresh: _loadMine,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _MyOfferCard(items[i],
            onStart: (id) => _tripOtpFlow(id, 'start'),
            onComplete: (id) => _tripOtpFlow(id, 'end'),
            onArrived: _arrived,
            onCancel: _driverCancel),
      ),
    );
  }

  Widget _retry(String e, VoidCallback onRetry) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.wifi_off_rounded, size: 40, color: AppColors.textHint),
          const SizedBox(height: 8),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: Text(_clean(e), textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary))),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ]),
      );

  Widget _empty(String m) => ListView(children: [
        const SizedBox(height: 120),
        const Icon(Icons.inbox_rounded, size: 56, color: AppColors.textHint),
        const SizedBox(height: 12),
        Center(child: Text(m, style: const TextStyle(color: AppColors.textSecondary))),
      ]);
}


class _MyOfferCard extends StatelessWidget {
  final Map<String, dynamic> b;
  final void Function(String id) onStart;
  final void Function(String id) onComplete;
  final void Function(String id) onArrived;
  final void Function(String id) onCancel;
  const _MyOfferCard(this.b, {required this.onStart, required this.onComplete, required this.onArrived, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    final id = (b['_id'] ?? b['id'] ?? '').toString();
    final service = kServiceNames[(b['serviceType'] ?? '').toString()] ?? 'Booking';
    final pickup = ((b['pickup'] as Map?)?['address'] ?? '').toString();
    final drop = ((b['drop'] as Map?)?['address'] ?? '').toString();
    final status = (b['status'] ?? '').toString();
    // myOffer is injected by backend for the driver's own offer on this booking.
    final myOffer = b['myOffer'] as Map? ?? {};
    final quoted = myOffer['quotedFare'] ?? b['finalFare'] ?? 0;
    final hold = myOffer['holdAmount'] ?? 0;
    final offerStatus = (myOffer['status'] ?? '').toString();
    // Won ONLY if THIS driver's offer was the selected one — not merely because
    // some driver was selected (that would light up losing drivers' cards too).
    final won = offerStatus == 'selected';
    final (chipColor, chipLabel) = _statusInfo(status, offerStatus);
    final barColor = won ? AppColors.primary : (status == 'completed' ? AppColors.success : AppColors.info);
    // Stamp overlay from the driver's own perspective.
    final lost = !won && status != 'open';
    final (String, Color)? stamp = lost
        ? ('NOT SELECTED', Colors.grey.shade600)
        : won && status == 'completed'
            ? ('COMPLETED', Colors.green.shade700)
            : won && status == 'cancelled'
                ? ('CANCELLED', Colors.red.shade700)
                : won && status == 'expired'
                    ? ('EXPIRED', Colors.grey.shade600)
                    : null;

    return brandCard(
      color: barColor,
      stamp: stamp?.$1,
      stampColor: stamp?.$2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(padding: EdgeInsets.only(top: 4.h), child: Icon(Icons.circle, size: 10.sp, color: chipColor)),
              SizedBox(width: 8.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(chipLabel, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700, color: chipColor)),
                    Text(service, style: TextStyle(fontSize: 11.sp, color: Colors.grey[600], fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              filledChip('₹$quoted', barColor),
            ],
          ),
          SizedBox(height: 10.h),
          const Divider(height: 1, color: Colors.black26),
          SizedBox(height: 10.h),
          // Route (FROM → TO) on the left, colored date/time box on the right.
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: routeTimeline(pickup, drop)),
              SizedBox(width: 10.w),
              dateTimeBox(tripDate(b['travelDate']), (b['travelTime'] ?? '').toString(), barColor),
            ],
          ),
          SizedBox(height: 4.h),
          const Divider(height: 1, color: Colors.black26),
          SizedBox(height: 10.h),
          Row(children: [
            Text('Your quote: ₹$quoted', style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, color: AppColors.primary)),
            const Spacer(),
            if (hold != 0) Text('Hold: ₹$hold', style: TextStyle(fontSize: 12.sp, color: AppColors.textSecondary)),
          ]),
          // Customer contact — visible only once this driver is selected.
          if (won && (b['customer'] is Map) && (((b['customer'] as Map)['mobile'] ?? '').toString().isNotEmpty)) ...[
            SizedBox(height: 10.h),
            Container(
              padding: EdgeInsets.all(10.r),
              decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(10.r)),
              child: Row(children: [
                CircleAvatar(radius: 18.r, backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                    child: Icon(Icons.person_rounded, color: AppColors.primary, size: 20.sp)),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(((b['customer'] as Map)['name'] ?? 'Customer').toString(),
                          style: TextStyle(fontSize: 13.5.sp, fontWeight: FontWeight.w700)),
                      Text(((b['customer'] as Map)['mobile'] ?? '').toString(),
                          style: TextStyle(fontSize: 12.sp, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => callNumber(((b['customer'] as Map)['mobile'] ?? '').toString()),
                  icon: Icon(Icons.call_rounded, color: AppColors.success, size: 22.sp),
                  tooltip: 'Call customer',
                ),
              ]),
            ),
          ],
          if (won && status == 'confirmed') ...[
            SizedBox(height: 12.h),
            Row(children: [
              Expanded(child: OutlinedButton.icon(
                onPressed: () => onArrived(id),
                icon: Icon(Icons.directions_car_filled_rounded, size: 18.sp),
                label: const Text('Arriving'),
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary, side: const BorderSide(color: AppColors.primary), padding: EdgeInsets.symmetric(vertical: 10.h)),
              )),
              SizedBox(width: 10.w),
              Expanded(child: ElevatedButton.icon(
                onPressed: () => onStart(id),
                icon: Icon(Icons.play_arrow_rounded, size: 18.sp),
                label: const Text('Start Trip'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, padding: EdgeInsets.symmetric(vertical: 10.h)),
              )),
            ]),
          ],
          if (won && status == 'ongoing') ...[
            SizedBox(height: 12.h),
            SizedBox(width: double.infinity, child: ElevatedButton.icon(
              onPressed: () => onComplete(id),
              icon: Icon(Icons.flag_rounded, size: 18.sp),
              label: const Text('Complete Trip'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white, padding: EdgeInsets.symmetric(vertical: 11.h)),
            )),
          ],
          // Driver can cancel while the trip hasn't been completed (penalty may apply).
          if (won && (status == 'confirmed' || status == 'ongoing')) ...[
            SizedBox(height: 8.h),
            SizedBox(width: double.infinity, child: TextButton.icon(
              onPressed: () => onCancel(id),
              icon: Icon(Icons.close_rounded, size: 16.sp, color: AppColors.error),
              label: Text('Cancel Trip', style: TextStyle(color: AppColors.error, fontSize: 13.sp)),
            )),
          ],
        ],
      ),
    );
  }

  (Color, String) _statusInfo(String status, String offerStatus) {
    if (status == 'open') return (AppColors.info, 'PENDING');
    if (offerStatus == 'released' || (status != 'open' && offerStatus == 'applied')) return (AppColors.textHint, 'NOT SELECTED');
    if (status == 'confirmed') return (AppColors.primary, 'WON');
    if (status == 'ongoing') return (AppColors.warning, 'ONGOING');
    if (status == 'completed') return (AppColors.success, 'COMPLETED');
    return (AppColors.textHint, status.toUpperCase());
  }
}
