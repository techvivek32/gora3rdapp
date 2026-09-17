import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/car_pool_repository.dart';
import '../widgets/pool_ui.dart';

/// Driver: manage my posted pool rides (Active / Past) + entry to Post & Earnings.
class MyPoolRidesPage extends StatefulWidget {
  const MyPoolRidesPage({super.key});

  @override
  State<MyPoolRidesPage> createState() => _MyPoolRidesPageState();
}

class _MyPoolRidesPageState extends State<MyPoolRidesPage> with SingleTickerProviderStateMixin {
  final _repo = getIt<CarPoolRepository>();
  late final TabController _tab;
  List<Map<String, dynamic>> _active = [];
  List<Map<String, dynamic>> _past = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final a = await _repo.myRides(status: 'active');
      final p = await _repo.myRides(status: 'past');
      if (!mounted) return;
      setState(() {
        _active = a;
        _past = p;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('My Pool Rides', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 17.sp)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(tooltip: 'Earnings', onPressed: () => context.push('/car-pool/earnings'), icon: const Icon(Icons.account_balance_wallet_rounded)),
        ],
        bottom: TabBar(
          controller: _tab,
          indicatorColor: Colors.white,
          labelStyle: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 13.sp),
          tabs: const [Tab(text: 'Active'), Tab(text: 'Past')],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/car-pool/post');
          _load();
        },
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Post Ride', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontFamily: 'Poppins')),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tab,
              children: [_list(_active, true), _list(_past, false)],
            ),
    );
  }

  Widget _list(List<Map<String, dynamic>> rides, bool active) {
    if (rides.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(children: [
          SizedBox(height: 120.h),
          Icon(active ? Icons.directions_car_outlined : Icons.history_rounded, size: 64.sp, color: AppColors.textHint),
          SizedBox(height: 12.h),
          Center(child: Text(active ? 'No active rides — post one!' : 'No past rides yet', style: TextStyle(fontSize: 14.sp, color: AppColors.textSecondary, fontFamily: 'Poppins'))),
        ]),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(14.w, 14.h, 14.w, 90.h),
        itemCount: rides.length,
        itemBuilder: (_, i) => _rideCard(rides[i], active),
      ),
    );
  }

  Widget _rideCard(Map<String, dynamic> r, bool active) {
    final id = (r['_id'] ?? r['id'] ?? '').toString();
    final total = (r['totalSeats'] as num?)?.toInt() ?? 0;
    final avail = (r['seatsAvailable'] as num?)?.toInt() ?? 0;
    final booked = total - avail;
    final price = (r['pricePerSeat'] as num?)?.toString() ?? '0';
    final status = (r['status'] ?? '').toString();
    return GestureDetector(
      onTap: () async {
        await context.push('/car-pool/ride/$id');
        _load();
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16.r), border: Border.all(color: AppColors.border), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))]),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('#${r['rideId'] ?? ''}', style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600, color: AppColors.textSecondary, fontFamily: 'Poppins')),
              poolStatusChip(status),
            ]),
            SizedBox(height: 10.h),
            poolRouteHeader(r),
            SizedBox(height: 12.h),
            Row(children: [
              _pill(Icons.event_seat_rounded, '$booked/$total booked'),
              SizedBox(width: 8.w),
              _pill(Icons.currency_rupee_rounded, '$price/seat'),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _pill(IconData icon, String text) => Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
        decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8.r), border: Border.all(color: AppColors.border)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13.sp, color: AppColors.primary),
          SizedBox(width: 4.w),
          Text(text, style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600, fontFamily: 'Poppins')),
        ]),
      );
}
