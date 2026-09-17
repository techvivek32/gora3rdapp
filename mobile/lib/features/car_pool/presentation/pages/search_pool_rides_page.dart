import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/car_pool_repository.dart';
import '../widgets/pool_ui.dart';

/// Passenger: search & book available pool rides.
class SearchPoolRidesPage extends StatefulWidget {
  const SearchPoolRidesPage({super.key});

  @override
  State<SearchPoolRidesPage> createState() => _SearchPoolRidesPageState();
}

class _SearchPoolRidesPageState extends State<SearchPoolRidesPage> {
  final _repo = getIt<CarPoolRepository>();
  final _fromCtrl = TextEditingController();
  final _toCtrl = TextEditingController();
  DateTime? _date;
  List<Map<String, dynamic>> _rides = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void dispose() {
    _fromCtrl.dispose();
    _toCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() => _loading = true);
    try {
      final r = await _repo.available(
        from: _fromCtrl.text.trim(),
        to: _toCtrl.text.trim(),
        date: _date == null ? null : DateFormat('yyyy-MM-dd').format(_date!),
      );
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
        title: Text('Find a Pool Ride', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 17.sp)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(tooltip: 'My Bookings', onPressed: () => context.push('/car-pool/my-bookings'), icon: const Icon(Icons.confirmation_num_rounded)),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.all(14.w),
            color: AppColors.surface,
            child: Column(children: [
              Row(children: [
                Expanded(child: _field(_fromCtrl, 'From city', Icons.my_location_rounded)),
                SizedBox(width: 10.w),
                Expanded(child: _field(_toCtrl, 'To city', Icons.location_on_rounded)),
              ]),
              SizedBox(height: 10.h),
              Row(children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final d = await showDatePicker(context: context, initialDate: _date ?? DateTime.now(), firstDate: DateTime.now().subtract(const Duration(days: 1)), lastDate: DateTime.now().add(const Duration(days: 180)));
                      if (d != null) setState(() => _date = d);
                    },
                    borderRadius: BorderRadius.circular(12.r),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 14.h),
                      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12.r), border: Border.all(color: AppColors.border)),
                      child: Row(children: [
                        Icon(Icons.calendar_today_rounded, size: 18.sp, color: AppColors.primary),
                        SizedBox(width: 8.w),
                        Text(_date == null ? 'Any date' : DateFormat('d MMM').format(_date!), style: TextStyle(fontSize: 13.sp, fontFamily: 'Poppins')),
                        if (_date != null) ...[const Spacer(), GestureDetector(onTap: () => setState(() => _date = null), child: Icon(Icons.close, size: 16.sp, color: AppColors.textHint))],
                      ]),
                    ),
                  ),
                ),
                SizedBox(width: 10.w),
                SizedBox(
                  height: 48.h,
                  child: ElevatedButton.icon(
                    onPressed: _search,
                    icon: const Icon(Icons.search, color: Colors.white),
                    label: const Text('Search', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontFamily: 'Poppins')),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r))),
                  ),
                ),
              ]),
            ]),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _rides.isEmpty
                    ? RefreshIndicator(
                        onRefresh: _search,
                        child: ListView(children: [
                          SizedBox(height: 120.h),
                          Icon(Icons.directions_car_outlined, size: 64.sp, color: AppColors.textHint),
                          SizedBox(height: 12.h),
                          Center(child: Text('No rides found — try different cities/date', style: TextStyle(fontSize: 13.sp, color: AppColors.textSecondary, fontFamily: 'Poppins'))),
                        ]),
                      )
                    : RefreshIndicator(
                        onRefresh: _search,
                        child: ListView.builder(
                          padding: EdgeInsets.fromLTRB(14.w, 14.h, 14.w, 20.h),
                          itemCount: _rides.length,
                          itemBuilder: (_, i) => _rideCard(_rides[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController c, String hint, IconData icon) => TextField(
        controller: c,
        style: TextStyle(fontSize: 13.sp),
        onSubmitted: (_) => _search(),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, color: AppColors.primary, size: 18.sp),
          isDense: true,
          filled: true,
          fillColor: AppColors.background,
          contentPadding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 12.h),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: const BorderSide(color: AppColors.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: const BorderSide(color: AppColors.border)),
        ),
      );

  Widget _rideCard(Map<String, dynamic> r) {
    final id = (r['_id'] ?? '').toString();
    final avail = (r['seatsAvailable'] as num?)?.toInt() ?? 0;
    final price = (r['pricePerSeat'] as num?)?.toString() ?? '0';
    final ds = r['driverSnapshot'] is Map ? Map<String, dynamic>.from(r['driverSnapshot'] as Map) : {};
    return GestureDetector(
      onTap: () async {
        await context.push('/car-pool/ride/$id');
        _search();
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16.r), border: Border.all(color: AppColors.border), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))]),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            poolRouteHeader(r),
            SizedBox(height: 12.h),
            Row(children: [
              CircleAvatar(radius: 14.r, backgroundColor: AppColors.primary.withValues(alpha: 0.1), child: Icon(Icons.person, color: AppColors.primary, size: 16.sp)),
              SizedBox(width: 6.w),
              Expanded(child: Text((ds['name'] ?? 'Driver').toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, fontFamily: 'Poppins'))),
              _pill(Icons.event_seat_rounded, '$avail seats'),
              SizedBox(width: 6.w),
              Text('₹$price', style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w800, color: AppColors.primaryDark, fontFamily: 'Poppins')),
              Text('/seat', style: TextStyle(fontSize: 10.sp, color: AppColors.textSecondary, fontFamily: 'Poppins')),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _pill(IconData icon, String text) => Container(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
        decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8.r), border: Border.all(color: AppColors.border)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12.sp, color: AppColors.primary),
          SizedBox(width: 3.w),
          Text(text, style: TextStyle(fontSize: 10.5.sp, fontWeight: FontWeight.w600, fontFamily: 'Poppins')),
        ]),
      );
}
