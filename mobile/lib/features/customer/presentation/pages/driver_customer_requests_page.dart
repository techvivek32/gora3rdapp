import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/contact_launcher.dart';
import '../../data/customer_repository.dart';

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
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ApplySheet(booking: b),
    );
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
        itemBuilder: (_, i) => _RequestCard(items[i], onApply: () => _apply(items[i])),
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

const _serviceNames = {
  'cab': 'Cabs Booking', 'hire_driver': 'Hire a Driver', 'luxury': 'Luxury Car', 'car_pool': 'Car Pooling',
};

// ── Shared card styling (matches the Requirement / Available-Car cards) ──────

/// Colored top bar + tinted body wrapper, exactly like the requirement card.
Widget _brandCard({required Widget child, Color color = AppColors.primary}) => Container(
      margin: EdgeInsets.symmetric(horizontal: 2.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 1))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(height: 4.h, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.vertical(top: Radius.circular(10.r)))),
            Padding(padding: EdgeInsets.all(12.r), child: child),
          ],
        ),
      ),
    );

Widget _filledChip(String text, Color color) => Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6.r)),
      child: Text(text, style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w700, color: Colors.white)),
    );

const _monthNames = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// Colored date/time box (big date + time below), exactly like the requirement
/// card's departure box.
Widget _dateTimeBox(DateTime? date, String time, Color color) => Container(
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

/// Vertical FROM → TO route with the connecting line (requirement-card style).
Widget _routeTimeline(String from, String to) {
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

class _RequestCard extends StatelessWidget {
  final Map<String, dynamic> b;
  final VoidCallback onApply;
  const _RequestCard(this.b, {required this.onApply});

  @override
  Widget build(BuildContext context) {
    final service = _serviceNames[(b['serviceType'] ?? '').toString()] ?? 'Booking';
    final pickup = ((b['pickup'] as Map?)?['address'] ?? '').toString();
    final drop = ((b['drop'] as Map?)?['address'] ?? '').toString();
    final date = DateTime.tryParse((b['travelDate'] ?? '').toString());
    final fare = b['estimatedFare'] ?? 0;
    final applied = b['alreadyApplied'] == true;
    final subType = (b['subType'] ?? '').toString();

    return _brandCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: status + service, trip-type chip on the right
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(padding: EdgeInsets.only(top: 4.h), child: Icon(Icons.circle, size: 10.sp, color: AppColors.info)),
              SizedBox(width: 8.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('OPEN', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700, color: AppColors.info)),
                    Text(service, style: TextStyle(fontSize: 11.sp, color: Colors.grey[600], fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              if (subType.isNotEmpty) _filledChip(subType.toUpperCase(), AppColors.primary),
            ],
          ),
          SizedBox(height: 10.h),
          const Divider(height: 1, color: Colors.black26),
          SizedBox(height: 10.h),
          // Route (FROM → TO) on the left, colored date/time box on the right.
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: _routeTimeline(pickup, drop)),
              SizedBox(width: 10.w),
              _dateTimeBox(date, (b['travelTime'] ?? '').toString(), AppColors.primary),
            ],
          ),
          SizedBox(height: 4.h),
          const Divider(height: 1, color: Colors.black26),
          SizedBox(height: 10.h),
          Row(children: [
            if ((b['passengers'] ?? 0) != 0) ...[
              Icon(Icons.people_rounded, size: 15.sp, color: AppColors.primary),
              SizedBox(width: 5.w),
              Text('${b['passengers']} passenger(s)', style: TextStyle(fontSize: 12.5.sp, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
            ],
            const Spacer(),
            if (fare != 0)
              Text('Budget: ₹$fare', style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          ]),
          SizedBox(height: 12.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: applied ? null : onApply,
              icon: Icon(applied ? Icons.check_rounded : Icons.local_offer_rounded, size: 18.sp),
              label: Text(applied ? 'Offer already sent' : 'Send Offer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: applied ? AppColors.textHint : AppColors.primary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 11.h),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
              ),
            ),
          ),
        ],
      ),
    );
  }
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
    final service = _serviceNames[(b['serviceType'] ?? '').toString()] ?? 'Booking';
    final pickup = ((b['pickup'] as Map?)?['address'] ?? '').toString();
    final drop = ((b['drop'] as Map?)?['address'] ?? '').toString();
    final status = (b['status'] ?? '').toString();
    // myOffer is injected by backend for the driver's own offer on this booking.
    final myOffer = b['myOffer'] as Map? ?? {};
    final quoted = myOffer['quotedFare'] ?? b['finalFare'] ?? 0;
    final hold = myOffer['holdAmount'] ?? 0;
    final offerStatus = (myOffer['status'] ?? '').toString();
    final won = status != 'open' && (offerStatus == 'selected' || (b['selectedDriverId'] != null));
    final (chipColor, chipLabel) = _statusInfo(status, offerStatus);
    final barColor = won ? AppColors.primary : (status == 'completed' ? AppColors.success : AppColors.info);

    return _brandCard(
      color: barColor,
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
              _filledChip('₹$quoted', barColor),
            ],
          ),
          SizedBox(height: 10.h),
          const Divider(height: 1, color: Colors.black26),
          SizedBox(height: 10.h),
          // Route (FROM → TO) on the left, colored date/time box on the right.
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: _routeTimeline(pickup, drop)),
              SizedBox(width: 10.w),
              _dateTimeBox(DateTime.tryParse((b['travelDate'] ?? '').toString()), (b['travelTime'] ?? '').toString(), barColor),
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

/// Bottom sheet where the driver enters a quote. Shows the commitment hold that
/// will be placed so there are no surprises.
class _ApplySheet extends StatefulWidget {
  final Map<String, dynamic> booking;
  const _ApplySheet({required this.booking});

  @override
  State<_ApplySheet> createState() => _ApplySheetState();
}

class _ApplySheetState extends State<_ApplySheet> {
  final _fare = TextEditingController();
  final _perSeat = TextEditingController();
  final _seats = TextEditingController();
  final _vehicle = TextEditingController();
  final _vehicleNo = TextEditingController();
  final _message = TextEditingController();
  final _picker = ImagePicker();
  final _api = getIt<ApiClient>();
  Uint8List? _vehicleBytes;
  bool _submitting = false;

  bool get _isPool => (widget.booking['serviceType'] ?? '').toString() == 'car_pool';
  int get _seatsWanted {
    final p = widget.booking['passengers'];
    return p is num && p > 0 ? p.toInt() : 1;
  }
  // Car pool total = per-seat × the seats the customer asked for.
  int get _poolTotal => ((num.tryParse(_perSeat.text.trim()) ?? 0) * _seatsWanted).round();

  Future<void> _pickVehiclePhoto() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1200, imageQuality: 80);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() => _vehicleBytes = bytes);
  }

  Future<String?> _uploadVehiclePhoto() async {
    if (_vehicleBytes == null) return null;
    FormData form() => FormData.fromMap({'file': MultipartFile.fromBytes(_vehicleBytes!, filename: 'vehicle.jpg'), 'folder': 'vehicles'});
    Response res;
    try {
      res = await _api.dio.post('/storage/upload', data: form());
    } catch (_) {
      res = await _api.dio.post('/storage/upload', data: form());
    }
    return res.data['data'] as String?;
  }

  int get _commitPercent {
    final v = widget.booking['commitmentPercent'];
    return v is num ? v.toInt() : 5;
  }

  int get _hold {
    final f = _isPool ? _poolTotal : (num.tryParse(_fare.text.trim()) ?? 0);
    return (f * _commitPercent / 100).round();
  }

  @override
  void initState() {
    super.initState();
    if (_isPool) {
      _seats.text = '$_seatsWanted';
    } else {
      final est = widget.booking['estimatedFare'];
      if (est != null && est != 0) _fare.text = est.toString();
    }
  }

  @override
  void dispose() {
    _fare.dispose();
    _perSeat.dispose();
    _seats.dispose();
    _vehicle.dispose();
    _vehicleNo.dispose();
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Send your offer', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          if (_isPool) ...[
            Row(children: [
              Expanded(child: TextField(
                controller: _perSeat,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                decoration: _dec('Fare per seat (₹)', Icons.event_seat_rounded),
              )),
              const SizedBox(width: 10),
              SizedBox(width: 110, child: TextField(
                controller: _seats,
                keyboardType: TextInputType.number,
                decoration: _dec('Seats', Icons.people_rounded),
              )),
            ]),
            const SizedBox(height: 6),
            Text('Customer needs $_seatsWanted seat(s) • Total ₹$_poolTotal',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 12),
          ] else ...[
            TextField(
              controller: _fare,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              decoration: _dec('Your fare (₹)', Icons.currency_rupee_rounded),
            ),
            const SizedBox(height: 12),
          ],
          TextField(controller: _vehicle, decoration: _dec('Vehicle (e.g. Swift Dzire)', Icons.directions_car_rounded)),
          const SizedBox(height: 12),
          TextField(controller: _vehicleNo, textCapitalization: TextCapitalization.characters, decoration: _dec('Vehicle number', Icons.confirmation_number_rounded)),
          const SizedBox(height: 12),
          // Optional vehicle photo — shown to the customer on the offer card.
          InkWell(
            onTap: _submitting ? null : _pickVehiclePhoto,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: _vehicleBytes != null ? 130 : 54,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: _vehicleBytes != null
                  ? Stack(fit: StackFit.expand, children: [
                      Image.memory(_vehicleBytes!, fit: BoxFit.cover),
                      Positioned(right: 8, top: 8, child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                        child: const Icon(Icons.edit, color: Colors.white, size: 16),
                      )),
                    ])
                  : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.add_a_photo_outlined, color: AppColors.primary, size: 20),
                      SizedBox(width: 8),
                      Text('Add vehicle photo (optional)', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    ]),
            ),
          ),
          const SizedBox(height: 12),
          TextField(controller: _message, maxLines: 2, decoration: _dec('Message to customer (optional)', Icons.message_rounded)),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.warning),
              const SizedBox(width: 10),
              Expanded(child: Text(
                'A commitment hold of ₹$_hold ($_commitPercent%) will be placed on your wallet. It is released automatically if you are not selected.',
                style: const TextStyle(fontSize: 12),
              )),
            ]),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _submitting ? null : () async {
                final num? perSeat = _isPool ? num.tryParse(_perSeat.text.trim()) : null;
                final num? fare = _isPool ? _poolTotal : num.tryParse(_fare.text.trim());
                if (fare == null || fare <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(_isPool ? 'Enter a valid per-seat fare' : 'Enter a valid fare')));
                  return;
                }
                final nav = Navigator.of(context);
                setState(() => _submitting = true);
                String? vehicleImage;
                try {
                  vehicleImage = await _uploadVehiclePhoto();
                } catch (_) {/* photo optional — ignore upload failure */}
                if (!mounted) return;
                nav.pop({
                  'quotedFare': fare,
                  if (_isPool && perSeat != null) 'farePerSeat': perSeat,
                  if (_isPool) 'seatsAvailable': int.tryParse(_seats.text.trim()) ?? _seatsWanted,
                  if (_vehicle.text.trim().isNotEmpty) 'vehicle': _vehicle.text.trim(),
                  if (_vehicleNo.text.trim().isNotEmpty) 'vehicleNumber': _vehicleNo.text.trim(),
                  if (vehicleImage != null && vehicleImage.isNotEmpty) 'vehicleImage': vehicleImage,
                  if (_message.text.trim().isNotEmpty) 'message': _message.text.trim(),
                });
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              child: _submitting
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Send Offer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _dec(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.primary),
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
      );
}
