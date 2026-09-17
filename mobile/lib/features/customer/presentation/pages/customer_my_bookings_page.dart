import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/injection.dart';
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
  late final TabController _tabs = TabController(length: 4, vsync: this);
  final _repo = getIt<CustomerRepository>();

  // tab index → statuses to show
  static const _groups = <List<String>>[
    ['open', 'confirmed'], // Upcoming
    ['ongoing'],           // Ongoing
    ['completed'],         // Completed
    ['cancelled', 'expired'], // Cancelled
  ];
  static const _labels = ['Upcoming', 'Ongoing', 'Completed', 'Cancelled'];

  List<Map<String, dynamic>>? _all;
  bool _loading = true;
  String? _error;

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
        title: const Text('My Rides'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
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
                    children: List.generate(4, (i) => _list(_for(_groups[i]))),
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
      itemBuilder: (_, i) => _BookingCard(items[i], onTap: () {
        final id = (items[i]['_id'] ?? items[i]['id'] ?? '').toString();
        context.push('/customer/bookings/$id').then((_) => _load());
      }),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final Map<String, dynamic> b;
  final VoidCallback onTap;
  const _BookingCard(this.b, {required this.onTap});

  @override
  Widget build(BuildContext context) {
    final status = (b['status'] ?? '').toString();
    final offers = (b['offers'] as List?) ?? [];
    final service = kServiceNames[(b['serviceType'] ?? '').toString()] ?? 'Booking';
    final pickup = ((b['pickup'] as Map?)?['address'] ?? '').toString();
    final drop = ((b['drop'] as Map?)?['address'] ?? '').toString();
    final date = tripDate(b['travelDate']);
    final (barColor, statusLabel) = bookingStatusInfo(status);
    final stamp = bookingStamp(status);

    return brandCard(
      color: barColor,
      onTap: onTap,
      stamp: stamp?.$1,
      stampColor: stamp?.$2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(padding: EdgeInsets.only(top: 4.h), child: Icon(Icons.circle, size: 10.sp, color: barColor)),
              SizedBox(width: 8.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(statusLabel, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700, color: barColor)),
                    Text(service, style: TextStyle(fontSize: 11.sp, color: Colors.grey[600], fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              if (status == 'open' && offers.isNotEmpty)
                filledChip('${offers.length} OFFER${offers.length == 1 ? '' : 'S'}', AppColors.primary),
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
              dateTimeBox(date, (b['travelTime'] ?? '').toString(), barColor),
            ],
          ),
          if ((b['finalFare'] ?? 0) != 0) ...[
            SizedBox(height: 8.h),
            const Divider(height: 1, color: Colors.black26),
            SizedBox(height: 8.h),
            Row(children: [
              Icon(Icons.receipt_long_rounded, size: 15.sp, color: AppColors.primary),
              SizedBox(width: 5.w),
              Text('Fare: ₹${b['finalFare']}', style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            ]),
          ],
        ],
      ),
    );
  }
}
