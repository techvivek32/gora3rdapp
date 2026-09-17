import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/car_pool_repository.dart';
import '../widgets/pool_ui.dart';

/// Passenger: my pool seat bookings.
class MyPoolBookingsPage extends StatefulWidget {
  const MyPoolBookingsPage({super.key});

  @override
  State<MyPoolBookingsPage> createState() => _MyPoolBookingsPageState();
}

class _MyPoolBookingsPageState extends State<MyPoolBookingsPage> {
  final _repo = getIt<CarPoolRepository>();
  List<Map<String, dynamic>> _rides = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await _repo.myBookings();
      if (!mounted) return;
      setState(() {
        _rides = r;
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
        title: Text('My Pool Bookings', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 17.sp)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _rides.isEmpty
              ? RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(children: [
                    SizedBox(height: 120.h),
                    Icon(Icons.confirmation_num_outlined, size: 64.sp, color: AppColors.textHint),
                    SizedBox(height: 12.h),
                    Center(child: Text('No pool bookings yet', style: TextStyle(fontSize: 14.sp, color: AppColors.textSecondary, fontFamily: 'Poppins'))),
                    SizedBox(height: 8.h),
                    Center(child: TextButton(onPressed: () => context.push('/car-pool/search'), child: const Text('Find a ride'))),
                  ]),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: EdgeInsets.fromLTRB(14.w, 14.h, 14.w, 20.h),
                    itemCount: _rides.length,
                    itemBuilder: (_, i) => _card(_rides[i]),
                  ),
                ),
    );
  }

  Widget _card(Map<String, dynamic> r) {
    final id = (r['_id'] ?? '').toString();
    final mb = r['myBooking'] is Map ? Map<String, dynamic>.from(r['myBooking'] as Map) : {};
    final bookingStatus = (mb['status'] ?? '').toString();
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
              poolStatusChip(bookingStatus.isNotEmpty ? bookingStatus : (r['status'] ?? '').toString()),
            ]),
            SizedBox(height: 10.h),
            poolRouteHeader(r),
            SizedBox(height: 12.h),
            Row(children: [
              _pill(Icons.event_seat_rounded, '${mb['seats'] ?? 0} seat'),
              SizedBox(width: 8.w),
              _pill(Icons.currency_rupee_rounded, '₹${mb['amount'] ?? 0}'),
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
