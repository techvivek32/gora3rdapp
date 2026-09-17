import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/contact_launcher.dart';
import '../../data/car_pool_repository.dart';
import '../widgets/pool_ui.dart';

/// Shared ride detail. Driver (owner) sees passengers + lifecycle controls;
/// passengers see ride info + book/cancel/rate.
class PoolRideDetailPage extends StatefulWidget {
  final String rideId;
  const PoolRideDetailPage({super.key, required this.rideId});

  @override
  State<PoolRideDetailPage> createState() => _PoolRideDetailPageState();
}

class _PoolRideDetailPageState extends State<PoolRideDetailPage> {
  final _repo = getIt<CarPoolRepository>();
  Map<String, dynamic>? _ride;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await _repo.getRide(widget.rideId);
      if (!mounted) return;
      setState(() {
        _ride = r;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _isOwner => _ride?['bookings'] is List;

  void _snack(String m, {bool ok = false}) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: ok ? AppColors.success : AppColors.error, behavior: SnackBarBehavior.floating));

  Future<void> _run(Future<void> Function() action, String okMsg) async {
    setState(() => _busy = true);
    try {
      await action();
      await _load();
      if (mounted) _snack(okMsg, ok: true);
    } catch (e) {
      if (mounted) _snack('Failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Ride Details', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 17.sp)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.canPop() ? context.pop() : context.go('/car-pool/my-rides')),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _ride == null
              ? Center(child: Text('Ride not found', style: TextStyle(fontFamily: 'Poppins', fontSize: 14.sp)))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(14.w, 14.h, 14.w, 20.h),
                    children: _isOwner ? _driverView() : _passengerView(),
                  ),
                ),
    );
  }

  // ─── Driver view ─────────────────────────────────────────────────────────────
  List<Widget> _driverView() {
    final r = _ride!;
    final status = (r['status'] ?? '').toString();
    final bookings = (r['bookings'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final activeBookings = bookings.where((b) => b['status'] == 'confirmed' || b['status'] == 'picked' || b['status'] == 'completed').toList();
    final total = (r['totalSeats'] as num?)?.toInt() ?? 0;
    final avail = (r['seatsAvailable'] as num?)?.toInt() ?? 0;

    return [
      _headerCard(r),
      SizedBox(height: 14.h),
      _sectionTitle('Passengers (${activeBookings.length})'),
      if (activeBookings.isEmpty)
        _emptyBox('No bookings yet', 'Passengers will appear here when they book.')
      else
        ...activeBookings.map((b) => _passengerRow(b, showContact: true)),
      SizedBox(height: 8.h),
      Text('$avail of $total seats still available', style: TextStyle(fontSize: 12.sp, color: AppColors.textSecondary, fontFamily: 'Poppins')),
      SizedBox(height: 18.h),
      ..._driverActions(status, activeBookings),
    ];
  }

  List<Widget> _driverActions(String status, List<Map<String, dynamic>> bookings) {
    if (status == 'active') {
      return [
        Row(children: [
          Expanded(child: _btn('Edit', Icons.edit_rounded, AppColors.info, () async { await context.push('/car-pool/post', extra: _ride); _load(); })),
          SizedBox(width: 10.w),
          Expanded(child: _btn('Stop Ride', Icons.stop_circle_rounded, AppColors.error, () => _confirmStop())),
        ]),
        SizedBox(height: 10.h),
        _btn('Start Ride', Icons.play_arrow_rounded, AppColors.success, () => _run(() => _repo.startRide(widget.rideId), 'Ride started'), full: true),
      ];
    }
    if (status == 'started') {
      final confirmed = bookings.where((b) => b['status'] == 'confirmed').toList();
      return [
        if (confirmed.isNotEmpty)
          _btn('Mark Passengers Picked Up', Icons.how_to_reg_rounded, AppColors.info, () => _pickupSheet(confirmed), full: true),
        SizedBox(height: 10.h),
        _btn('Complete Ride', Icons.flag_rounded, AppColors.success, () => _run(() => _repo.completeRide(widget.rideId), 'Ride completed'), full: true),
      ];
    }
    return [
      Center(child: Text(status == 'completed' ? '✅ Ride completed' : '❌ Ride cancelled', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600, color: poolStatusColor(status), fontFamily: 'Poppins'))),
      if (status == 'completed' && (_ride!['totalEarning'] as num? ?? 0) > 0) ...[
        SizedBox(height: 8.h),
        Center(child: Text('Earned: ₹${_ride!['totalEarning']}', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800, color: AppColors.success, fontFamily: 'Poppins'))),
      ],
    ];
  }

  void _confirmStop() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Stop this ride?', style: TextStyle(fontFamily: 'Poppins')),
        content: const Text('All booked passengers will be notified it is cancelled.', style: TextStyle(fontFamily: 'Poppins')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('No')),
          TextButton(onPressed: () { Navigator.pop(ctx); _run(() => _repo.stopRide(widget.rideId), 'Ride stopped'); }, child: const Text('Yes, stop', style: TextStyle(color: AppColors.error))),
        ],
      ),
    );
  }

  void _pickupSheet(List<Map<String, dynamic>> confirmed) {
    final selected = <String>{};
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24.r))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, MediaQuery.of(ctx).viewInsets.bottom + 20.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40.w, height: 4.h, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
              SizedBox(height: 16.h),
              Text('Select passengers picked up', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700, fontFamily: 'Poppins')),
              SizedBox(height: 8.h),
              ...confirmed.map((b) {
                final bid = (b['_id'] ?? '').toString();
                final sel = selected.contains(bid);
                return CheckboxListTile(
                  value: sel,
                  onChanged: (v) => setSheet(() => v == true ? selected.add(bid) : selected.remove(bid)),
                  title: Text('${b['passengerName'] ?? 'Passenger'} (${b['seats']} seat)', style: TextStyle(fontFamily: 'Poppins', fontSize: 14.sp)),
                  activeColor: AppColors.primary,
                  contentPadding: EdgeInsets.zero,
                );
              }),
              SizedBox(height: 8.h),
              SizedBox(
                width: double.infinity,
                height: 48.h,
                child: ElevatedButton(
                  onPressed: selected.isEmpty ? null : () { Navigator.pop(ctx); _run(() => _repo.markPickup(widget.rideId, selected.toList()), 'Marked as picked up'); },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r))),
                  child: Text('Mark as Picked Up', style: TextStyle(fontWeight: FontWeight.w700, fontFamily: 'Poppins', fontSize: 14.sp)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Passenger view ──────────────────────────────────────────────────────────
  List<Widget> _passengerView() {
    final r = _ride!;
    final status = (r['status'] ?? '').toString();
    final avail = (r['seatsAvailable'] as num?)?.toInt() ?? 0;
    final myBooking = r['myBooking'] is Map ? Map<String, dynamic>.from(r['myBooking'] as Map) : null;
    final ds = r['driverSnapshot'] is Map ? Map<String, dynamic>.from(r['driverSnapshot'] as Map) : {};
    final bookingStatus = (myBooking?['status'] ?? '').toString();
    final booked = myBooking != null && (bookingStatus == 'confirmed' || bookingStatus == 'picked' || bookingStatus == 'completed');

    return [
      _headerCard(r),
      SizedBox(height: 14.h),
      _sectionTitle('Driver'),
      Container(
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14.r), border: Border.all(color: AppColors.border)),
        child: Row(children: [
          CircleAvatar(radius: 22.r, backgroundColor: AppColors.primary.withValues(alpha: 0.1), child: Icon(Icons.person, color: AppColors.primary, size: 24.sp)),
          SizedBox(width: 12.w),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text((ds['name'] ?? 'Driver').toString(), style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700, fontFamily: 'Poppins')),
            Text('${ds['vehicle'] ?? ''} ${ds['vehicleNumber'] ?? ''}'.trim(), style: TextStyle(fontSize: 12.sp, color: AppColors.textSecondary, fontFamily: 'Poppins')),
          ])),
          if (booked && (ds['phone'] ?? '').toString().isNotEmpty)
            IconButton(onPressed: () => callNumber(ds['phone'].toString()), icon: Icon(Icons.call, color: AppColors.success, size: 24.sp)),
        ]),
      ),
      SizedBox(height: 14.h),
      if (myBooking != null) ...[
        _sectionTitle('My Booking'),
        Container(
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14.r), border: Border.all(color: AppColors.border)),
          child: Column(children: [
            _kv('Seats', '${myBooking['seats']}'),
            _kv('Amount', '₹${myBooking['amount']}'),
            _kv('Status', poolStatusLabel(bookingStatus)),
          ]),
        ),
        SizedBox(height: 14.h),
      ],
      ..._passengerActions(status, avail, myBooking, booked, bookingStatus),
    ];
  }

  List<Widget> _passengerActions(String status, int avail, Map<String, dynamic>? myBooking, bool booked, String bookingStatus) {
    if (booked) {
      return [
        if (bookingStatus == 'completed' && (myBooking?['rating'] ?? 0) == 0)
          _btn('Rate Ride', Icons.star_rounded, AppColors.warning, () => _rateSheet(), full: true)
        else if (status == 'active')
          _btn('Cancel Booking', Icons.cancel_rounded, AppColors.error, () => _run(() => _repo.cancelBooking(widget.rideId), 'Booking cancelled'), full: true)
        else
          Center(child: Text('You are booked on this ride', style: TextStyle(fontSize: 13.sp, color: AppColors.textSecondary, fontFamily: 'Poppins'))),
      ];
    }
    if (status == 'active' && avail > 0) {
      return [_btn('Book Seats', Icons.event_seat_rounded, AppColors.primary, () => _bookSheet(avail), full: true)];
    }
    return [Center(child: Text(avail <= 0 ? 'Ride is full' : 'Ride not available for booking', style: TextStyle(fontSize: 13.sp, color: AppColors.textSecondary, fontFamily: 'Poppins')))];
  }

  void _bookSheet(int avail) {
    final price = (_ride!['pricePerSeat'] as num?)?.toDouble() ?? 0;
    int seats = 1;
    final pickupCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24.r))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, MediaQuery.of(ctx).viewInsets.bottom + 20.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40.w, height: 4.h, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
              SizedBox(height: 16.h),
              Text('Book Seats', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w700, fontFamily: 'Poppins')),
              SizedBox(height: 16.h),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Seats', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600, fontFamily: 'Poppins')),
                Row(children: [
                  IconButton(onPressed: seats > 1 ? () => setSheet(() => seats--) : null, icon: const Icon(Icons.remove_circle_outline)),
                  Text('$seats', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w800, fontFamily: 'Poppins')),
                  IconButton(onPressed: seats < avail ? () => setSheet(() => seats++) : null, icon: const Icon(Icons.add_circle_outline)),
                ]),
              ]),
              SizedBox(height: 8.h),
              TextField(controller: pickupCtrl, decoration: InputDecoration(labelText: 'Pickup point (optional)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)))),
              SizedBox(height: 16.h),
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12.r)),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Total (pay driver directly)', style: TextStyle(fontSize: 13.sp, fontFamily: 'Poppins')),
                  Text('₹${(seats * price).toStringAsFixed(0)}', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800, color: AppColors.primaryDark, fontFamily: 'Poppins')),
                ]),
              ),
              SizedBox(height: 16.h),
              SizedBox(
                width: double.infinity,
                height: 50.h,
                child: ElevatedButton(
                  onPressed: () { Navigator.pop(ctx); _run(() => _repo.book(widget.rideId, seats, pickupPoint: pickupCtrl.text.trim()).then((_) {}), 'Seats booked'); },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r))),
                  child: Text('Confirm Booking', style: TextStyle(fontWeight: FontWeight.w700, fontFamily: 'Poppins', fontSize: 15.sp)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _rateSheet() {
    int rating = 5;
    final reviewCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24.r))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, MediaQuery.of(ctx).viewInsets.bottom + 20.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(child: Container(width: 40.w, height: 4.h, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
              SizedBox(height: 16.h),
              Text('Rate your ride', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w700, fontFamily: 'Poppins')),
              SizedBox(height: 16.h),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(5, (i) => IconButton(
                onPressed: () => setSheet(() => rating = i + 1),
                icon: Icon(i < rating ? Icons.star_rounded : Icons.star_border_rounded, color: AppColors.warning, size: 34.sp),
              ))),
              TextField(controller: reviewCtrl, decoration: InputDecoration(labelText: 'Review (optional)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)))),
              SizedBox(height: 16.h),
              SizedBox(
                width: double.infinity,
                height: 50.h,
                child: ElevatedButton(
                  onPressed: () { Navigator.pop(ctx); _run(() => _repo.rate(widget.rideId, rating.toDouble(), review: reviewCtrl.text.trim()), 'Thanks for rating'); },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r))),
                  child: Text('Submit', style: TextStyle(fontWeight: FontWeight.w700, fontFamily: 'Poppins', fontSize: 15.sp)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Shared bits ─────────────────────────────────────────────────────────────
  Widget _headerCard(Map<String, dynamic> r) {
    final total = (r['totalSeats'] as num?)?.toInt() ?? 0;
    final avail = (r['seatsAvailable'] as num?)?.toInt() ?? 0;
    final price = (r['pricePerSeat'] as num?)?.toString() ?? '0';
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16.r), border: Border.all(color: AppColors.border), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('#${r['rideId'] ?? ''}', style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600, color: AppColors.textSecondary, fontFamily: 'Poppins')),
            poolStatusChip((r['status'] ?? '').toString()),
          ]),
          SizedBox(height: 12.h),
          poolRouteHeader(r),
          SizedBox(height: 12.h),
          Row(children: [
            _pill(Icons.event_seat_rounded, '$avail/$total free'),
            SizedBox(width: 8.w),
            _pill(Icons.currency_rupee_rounded, '$price/seat'),
            if ((r['vehicle'] ?? '').toString().isNotEmpty) ...[SizedBox(width: 8.w), _pill(Icons.directions_car_rounded, r['vehicle'].toString())],
          ]),
          if ((r['notes'] ?? '').toString().isNotEmpty) ...[
            SizedBox(height: 10.h),
            Text(r['notes'].toString(), style: TextStyle(fontSize: 12.sp, color: AppColors.textSecondary, fontFamily: 'Poppins')),
          ],
        ],
      ),
    );
  }

  Widget _passengerRow(Map<String, dynamic> b, {bool showContact = false}) {
    final phone = (b['passengerMobile'] ?? '').toString();
    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12.r), border: Border.all(color: AppColors.border)),
      child: Row(children: [
        CircleAvatar(radius: 18.r, backgroundColor: AppColors.primary.withValues(alpha: 0.1), child: Icon(Icons.person, color: AppColors.primary, size: 20.sp)),
        SizedBox(width: 10.w),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text((b['passengerName'] ?? 'Passenger').toString(), style: TextStyle(fontSize: 13.5.sp, fontWeight: FontWeight.w700, fontFamily: 'Poppins')),
          Text('${b['seats']} seat • ₹${b['amount']} • ${poolStatusLabel((b['status'] ?? '').toString())}', style: TextStyle(fontSize: 11.sp, color: AppColors.textSecondary, fontFamily: 'Poppins')),
        ])),
        if (showContact && phone.isNotEmpty) IconButton(onPressed: () => callNumber(phone), icon: Icon(Icons.call, color: AppColors.success, size: 22.sp)),
      ]),
    );
  }

  Widget _sectionTitle(String t) => Padding(padding: EdgeInsets.only(bottom: 8.h), child: Text(t, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w800, color: AppColors.textPrimary, fontFamily: 'Poppins')));

  Widget _kv(String k, String v) => Padding(
        padding: EdgeInsets.symmetric(vertical: 4.h),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(k, style: TextStyle(fontSize: 13.sp, color: AppColors.textSecondary, fontFamily: 'Poppins')),
          Text(v, style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, fontFamily: 'Poppins')),
        ]),
      );

  Widget _emptyBox(String title, String sub) => Container(
        width: double.infinity,
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12.r), border: Border.all(color: AppColors.border)),
        child: Column(children: [
          Icon(Icons.people_outline_rounded, size: 40.sp, color: AppColors.textHint),
          SizedBox(height: 8.h),
          Text(title, style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, fontFamily: 'Poppins')),
          Text(sub, textAlign: TextAlign.center, style: TextStyle(fontSize: 11.sp, color: AppColors.textSecondary, fontFamily: 'Poppins')),
        ]),
      );

  Widget _pill(IconData icon, String text) => Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
        decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8.r), border: Border.all(color: AppColors.border)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13.sp, color: AppColors.primary),
          SizedBox(width: 4.w),
          Text(text, style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600, fontFamily: 'Poppins')),
        ]),
      );

  Widget _btn(String label, IconData icon, Color color, VoidCallback onTap, {bool full = false}) => SizedBox(
        width: full ? double.infinity : null,
        height: 48.h,
        child: ElevatedButton.icon(
          onPressed: _busy ? null : onTap,
          icon: Icon(icon, size: 18.sp),
          label: Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontFamily: 'Poppins', fontSize: 13.5.sp)),
          style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r))),
        ),
      );
}
