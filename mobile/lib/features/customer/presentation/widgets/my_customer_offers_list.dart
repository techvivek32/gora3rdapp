import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/api_error.dart';
import '../../data/customer_repository.dart';
import '../../data/trip_tracker.dart';
import '../pages/driver_customer_requests_page.dart' show MyOfferCard;
import '../pages/driver_trip_page.dart';
import '../pages/driver_trip_summary_page.dart';
import '../utils/invoice_actions.dart';

/// The driver/vendor's Assigned list: their won customer-app trips MERGED with
/// the requirement bookings assigned to them — ONE combined list (no separate
/// "Customer Trips" section), with completed bookings pushed to the bottom.
/// Self-fetches the customer trips; the requirements are passed in with a builder.
class MyCustomerOffersList extends StatefulWidget {
  /// Shown when there are no assigned requirements AND no won customer trips.
  final Widget? emptyPlaceholder;

  /// Requirement bookings assigned to the driver, merged into the same list.
  final List<Map<String, dynamic>> requirements;

  /// Builds the card for one requirement (owned by the page, which has the
  /// trip-button + menu logic).
  final Widget Function(Map<String, dynamic> req)? requirementBuilder;

  const MyCustomerOffersList({
    super.key,
    this.emptyPlaceholder,
    this.requirements = const [],
    this.requirementBuilder,
  });

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
      // If a won trip is still ONGOING but the tracker isn't running (app was
      // killed / phone restarted mid-trip), resume GPS distance tracking for it.
      final ongoing = _mine.firstWhere((b) => b['status'] == 'ongoing', orElse: () => const {});
      final oid = ongoing['_id']?.toString();
      if (oid != null && oid.isNotEmpty && TripTracker.instance.currentBookingId != oid) {
        TripTracker.instance.resumeIfActive(ongoingBookingId: oid);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String m, {bool ok = false}) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m), backgroundColor: ok ? AppColors.success : AppColors.error));

  Future<void> _openTrip(Map<String, dynamic> booking) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => DriverTripPage(booking: booking)));
    if (mounted) _load(); // refresh statuses when returning from the trip screen
  }

  Future<void> _openSummary(Map<String, dynamic> booking) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => DriverTripSummaryPage(booking: booking)));
    if (mounted) _load();
  }

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
      await TripTracker.instance.stop();
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
      final updated = await _repo.verifyTripOtp(id, action, otp.trim());
      // Start/stop GPS distance tracking with the trip.
      if (action == 'start') {
        final ok = await TripTracker.instance.start(id);
        if (!ok && mounted) _snack('Enable location to record trip distance.');
      } else {
        await TripTracker.instance.stop();
      }
      _snack(action == 'start' ? 'Trip started 🚕' : 'Trip completed 🎉', ok: true);
      // After the drop OTP, open the final-bill screen so the driver can add
      // toll/parking/other charges and download the invoice.
      if (action == 'end' && mounted && updated != null) {
        await _openSummary(updated);
      }
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

  /// A booking is "finished" (→ sinks to the bottom of the list) once it's
  /// completed, cancelled or expired; everything else is still active.
  static const _finishedStatuses = {'completed', 'cancelled', 'expired'};
  bool _reqDone(Map<String, dynamic> r) =>
      r['tripStatus']?.toString() == 'completed' || _finishedStatuses.contains(r['status']?.toString());
  bool _custDone(Map<String, dynamic> b) => _finishedStatuses.contains(b['status']?.toString());

  Widget _custCard(Map<String, dynamic> b) => Padding(
        padding: EdgeInsets.only(bottom: 12.h),
        child: MyOfferCard(
          b,
          onStart: (id) => _tripOtpFlow(id, 'start'),
          onComplete: (id) => _tripOtpFlow(id, 'end'),
          onArrived: _arrived,
          onCancel: _driverCancel,
          onInvoice: (id) => downloadAndOpenInvoice(context, _repo, id),
          onOpenTrip: _openTrip,
          onBill: _openSummary,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final reqs = widget.requirements;
    final custs = _loading ? const <Map<String, dynamic>>[] : _mine;

    // Merge requirements + customer trips into ONE list (no divider). Active
    // bookings stay on top in their original order; completed ones drop to the
    // bottom. Partitioning (not sort()) keeps the order stable within each group.
    final active = <Widget>[];
    final done = <Widget>[];
    for (final r in reqs) {
      (widget.requirementBuilder != null)
          ? (_reqDone(r) ? done : active).add(widget.requirementBuilder!(r))
          : null;
    }
    for (final b in custs) {
      (_custDone(b) ? done : active).add(_custCard(b));
    }

    if (active.isEmpty && done.isEmpty) {
      // Still loading customer trips → wait silently; otherwise show empty state.
      return _loading ? const SizedBox.shrink() : (widget.emptyPlaceholder ?? const SizedBox.shrink());
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [...active, ...done],
    );
  }
}
