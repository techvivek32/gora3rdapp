import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/customer_repository.dart';
import '../widgets/booking_card_ui.dart';

/// "My Rides" — the customer's booking history grouped by lifecycle.
class CustomerMyBookingsPage extends StatefulWidget {
  const CustomerMyBookingsPage({super.key});

  @override
  State<CustomerMyBookingsPage> createState() => _CustomerMyBookingsPageState();
}

class _CustomerMyBookingsPageState extends State<CustomerMyBookingsPage> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);
  final _repo = getIt<CustomerRepository>();

  // tab index → statuses to show
  static const _groups = <List<String>>[
    ['open', 'confirmed'],                 // Upcoming
    ['ongoing'],                           // Ongoing
    ['completed', 'cancelled', 'expired'], // History
  ];
  static const _labels = ['Upcoming', 'Ongoing', 'History'];

  List<Map<String, dynamic>>? _all;
  bool _loading = true;
  String? _error;
  // Cab category name (lowercased) → image URL, to show the real cab photo.
  final Map<String, String> _carImages = {};

  String _carImageFor(Map<String, dynamic> b) {
    final name = (b['vehicleType'] ?? '').toString().trim().toLowerCase();
    return _carImages[name] ?? '';
  }

  Future<void> _loadCarImages() async {
    try {
      final res = await getIt<ApiClient>().get('/home-content/cab-categories');
      final list = (res.data['data'] as List?) ?? [];
      _carImages.clear();
      for (final e in list) {
        final m = Map<String, dynamic>.from(e as Map);
        final name = (m['name'] ?? '').toString().trim().toLowerCase();
        final img = (m['imageUrl'] ?? '').toString();
        if (name.isNotEmpty && img.isNotEmpty) _carImages[name] = img;
      }
    } catch (_) {/* non-fatal — falls back to the car icon */}
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      await _loadCarImages();
      final data = await _repo.myBookings();
      if (!mounted) return;
      setState(() { _all = data; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = '$e'; _loading = false; });
    }
  }

  List<Map<String, dynamic>> _for(List<String> statuses) =>
      (_all ?? []).where((b) => statuses.contains((b['status'] ?? '').toString())).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Bookings'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabs,
          isScrollable: false,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: _labels.map((l) => Tab(text: l)).toList(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _retry()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: TabBarView(
                    controller: _tabs,
                    children: List.generate(3, (i) => _list(_for(_groups[i]))),
                  ),
                ),
    );
  }

  Widget _retry() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 40, color: AppColors.textHint),
            const SizedBox(height: 8),
            Text(_error ?? '', style: const TextStyle(color: AppColors.textSecondary)),
            TextButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );

  Widget _list(List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 120),
          Icon(Icons.directions_car_filled_outlined, size: 56, color: AppColors.textHint),
          SizedBox(height: 12),
          Center(child: Text('Nothing here yet', style: TextStyle(color: AppColors.textSecondary))),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final b = items[i];
        final id = (b['_id'] ?? b['id'] ?? '').toString();
        return _BookingCard(
          b,
          onTrack: () => context.push('/customer/bookings/$id').then((_) => _load()),
          onEdit: () {
            final svc = (b['serviceType'] ?? 'cab').toString();
            context.push('/customer/book/$svc', extra: b).then((_) => _load());
          },
          carImage: _carImageFor(b),
          onCancel: () => _cancel(id),
        );
      },
    );
  }

  Future<void> _cancel(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this booking?', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        content: const Text('This cannot be undone.', style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: const Text('Yes, cancel'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.cancelBooking(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Booking cancelled'), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not cancel: ${e.toString().replaceFirst('Exception: ', '')}'), backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating));
    }
  }
}

class _BookingCard extends StatelessWidget {
  final Map<String, dynamic> b;
  final VoidCallback onTrack;
  final VoidCallback onEdit;
  final VoidCallback onCancel;
  final String carImage;
  const _BookingCard(this.b, {required this.onTrack, required this.onEdit, required this.onCancel, this.carImage = ''});

  String _num(dynamic v) => v is num ? v.toStringAsFixed(v == v.roundToDouble() ? 0 : 2) : '0';

  @override
  Widget build(BuildContext context) {
    final status = (b['status'] ?? '').toString();
    final sub = (b['subType'] ?? '').toString();
    final isLocal = sub == 'Local';
    final isRound = sub == 'Round Trip';
    final offers = (b['offers'] as List?) ?? [];
    final bookingId = (b['bookingId'] ?? b['humanId'] ?? '').toString();
    final fromCity = ((b['pickupCity'] ?? '').toString().trim().isNotEmpty
            ? (b['pickupCity']).toString()
            : ((b['pickup'] as Map?)?['address'] ?? '').toString())
        .split(',').first.trim();
    final toCity = ((b['dropCity'] ?? '').toString().trim().isNotEmpty
            ? (b['dropCity']).toString()
            : ((b['drop'] as Map?)?['address'] ?? '').toString())
        .split(',').first.trim();
    final pickupAddr = ((b['pickup'] as Map?)?['address'] ?? '').toString();
    final dt = tripDate(b['travelDate']);
    final date = dt != null ? DateFormat('dd-MM-yyyy').format(dt) : '';
    final time = (b['travelTime'] ?? '').toString();
    final includedKm = (b['includedKm'] as num?)?.toInt() ?? (b['estimatedDistance'] as num?)?.toInt() ?? 0;
    final packageHours = (b['packageHours'] as num?)?.toInt() ?? 0;
    final total = (b['finalFare'] as num?) ?? (b['estimatedFare'] as num?) ?? 0;
    final advance = (b['advanceStatus']?.toString() == 'paid') ? ((b['advanceAmount'] as num?) ?? 0) : 0;
    final toPay = (total - advance).clamp(0, double.infinity);
    final (barColor, statusLabel) = bookingStatusInfo(status);
    final stamp = bookingStamp(status);

    final route = isLocal ? '$fromCity · Local' : (isRound ? '$fromCity → $toCity → $fromCity' : '$fromCity → $toCity');

    final canCancel = status == 'open' || status == 'confirmed';
    final canEdit = status == 'open';

    return brandCard(
      color: barColor,
      stamp: stamp?.$1,
      stampColor: stamp?.$2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status + Booking ID.
          Row(children: [
            Icon(Icons.circle, size: 10.sp, color: barColor),
            SizedBox(width: 8.w),
            Text(statusLabel, style: TextStyle(fontSize: 13.5.sp, fontWeight: FontWeight.w800, color: barColor)),
            const Spacer(),
            if (status == 'open' && offers.isNotEmpty)
              filledChip('${offers.length} OFFER${offers.length == 1 ? '' : 'S'}', AppColors.primary)
            else if (sub.isNotEmpty)
              filledChip(sub.toUpperCase(), AppColors.primary),
          ]),
          if (bookingId.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(left: 18.w, top: 2.h),
              child: Text('ID: $bookingId', style: TextStyle(fontSize: 10.5.sp, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
            ),
          SizedBox(height: 10.h),
          const Divider(height: 1, color: Colors.black26),
          SizedBox(height: 10.h),
          // Route + car icon.
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(Icons.location_on_rounded, size: 16.sp, color: AppColors.primary),
                  SizedBox(width: 6.w),
                  Expanded(child: Text(route, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w800, color: AppColors.textPrimary))),
                ]),
                SizedBox(height: 6.h),
                Row(children: [
                  Icon(Icons.calendar_today_rounded, size: 13.sp, color: AppColors.textSecondary),
                  SizedBox(width: 6.w),
                  Text('$date${time.isNotEmpty ? ' | $time' : ''}', style: TextStyle(fontSize: 11.5.sp, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                ]),
                if (pickupAddr.isNotEmpty) ...[
                  SizedBox(height: 4.h),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.my_location_rounded, size: 13.sp, color: AppColors.textSecondary),
                    SizedBox(width: 6.w),
                    Expanded(child: Text(pickupAddr, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.sp, color: AppColors.textSecondary))),
                  ]),
                ],
                if (includedKm > 0) ...[
                  SizedBox(height: 4.h),
                  Row(children: [
                    Icon(Icons.speed_rounded, size: 13.sp, color: AppColors.textSecondary),
                    SizedBox(width: 6.w),
                    Text(isLocal ? '$packageHours hrs · $includedKm km included' : '$includedKm kms included', style: TextStyle(fontSize: 11.sp, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                  ]),
                ],
              ]),
            ),
            SizedBox(width: 8.w),
            carImage.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8.r),
                    child: SizedBox(
                      width: 84.r,
                      child: AspectRatio(
                        aspectRatio: 4 / 3,
                        child: CachedNetworkImage(
                          imageUrl: carImage,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Icon(Icons.directions_car_filled_rounded, size: 40.sp, color: AppColors.primary.withValues(alpha: 0.6)),
                        ),
                      ),
                    ),
                  )
                : Icon(Icons.directions_car_filled_rounded, size: 40.sp, color: AppColors.primary.withValues(alpha: 0.6)),
          ]),
          if (total != 0) ...[
            SizedBox(height: 10.h),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Icon(Icons.currency_rupee_rounded, size: 15.sp, color: AppColors.primary),
              Text(_num(total), style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
              SizedBox(width: 6.w),
              if (advance > 0) Text('(to pay ₹${_num(toPay)})', style: TextStyle(fontSize: 11.sp, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
            ]),
          ],
          SizedBox(height: 12.h),
          const Divider(height: 1, color: Colors.black26),
          SizedBox(height: 10.h),
          // Action buttons — compact, left-aligned (wrap if needed).
          Wrap(spacing: 8.w, runSpacing: 8.h, children: [
            if (canCancel) _btn('Cancel', Icons.cancel_outlined, AppColors.error, onCancel),
            if (canEdit) _btn('Edit', Icons.edit_rounded, AppColors.info, onEdit),
            _btn('Track', Icons.location_on_rounded, AppColors.primary, onTrack),
          ]),
        ],
      ),
    );
  }

  Widget _btn(String label, IconData icon, Color color, VoidCallback onTap) => ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15.sp, color: Colors.white),
          SizedBox(width: 5.w),
          Text(label, style: TextStyle(fontSize: 12.5.sp, fontWeight: FontWeight.w700, color: Colors.white)),
        ]),
      );
}
