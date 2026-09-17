import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/car_pool_repository.dart';
import '../widgets/pool_ui.dart';

/// Driver: pool earnings summary + completed rides breakdown.
class PoolEarningsPage extends StatefulWidget {
  const PoolEarningsPage({super.key});

  @override
  State<PoolEarningsPage> createState() => _PoolEarningsPageState();
}

class _PoolEarningsPageState extends State<PoolEarningsPage> {
  final _repo = getIt<CarPoolRepository>();
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await _repo.earnings();
      if (!mounted) return;
      setState(() {
        _data = d;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rides = (_data?['rides'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Pool Earnings', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 17.sp)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: EdgeInsets.fromLTRB(14.w, 14.h, 14.w, 20.h),
                children: [
                  Container(
                    padding: EdgeInsets.all(18.w),
                    decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]), borderRadius: BorderRadius.circular(18.r)),
                    child: Column(children: [
                      Text('Total Earnings', style: TextStyle(fontSize: 13.sp, color: Colors.white.withValues(alpha: 0.9), fontFamily: 'Poppins')),
                      SizedBox(height: 6.h),
                      Text('₹${_data?['totalEarning'] ?? 0}', style: TextStyle(fontSize: 32.sp, fontWeight: FontWeight.w900, color: Colors.white, fontFamily: 'Poppins')),
                      SizedBox(height: 12.h),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                        _stat('Rides', '${_data?['totalRides'] ?? 0}'),
                        Container(width: 1, height: 30.h, color: Colors.white24),
                        _stat('Seats Sold', '${_data?['totalSeatsSold'] ?? 0}'),
                      ]),
                    ]),
                  ),
                  SizedBox(height: 8.h),
                  Padding(padding: EdgeInsets.symmetric(vertical: 6.h), child: Text('Note: earnings are collected directly from passengers.', style: TextStyle(fontSize: 11.sp, color: AppColors.textSecondary, fontFamily: 'Poppins'))),
                  SizedBox(height: 8.h),
                  Text('Completed Rides', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w800, fontFamily: 'Poppins')),
                  SizedBox(height: 10.h),
                  if (rides.isEmpty)
                    Padding(padding: EdgeInsets.symmetric(vertical: 40.h), child: Center(child: Text('No completed rides yet', style: TextStyle(fontSize: 13.sp, color: AppColors.textSecondary, fontFamily: 'Poppins'))))
                  else
                    ...rides.map((r) => GestureDetector(
                          onTap: () => context.push('/car-pool/ride/${r['_id']}'),
                          child: Container(
                            margin: EdgeInsets.only(bottom: 10.h),
                            padding: EdgeInsets.all(12.w),
                            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12.r), border: Border.all(color: AppColors.border)),
                            child: Row(children: [
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('${r['fromCity'] ?? '—'} → ${r['toCity'] ?? '—'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, fontFamily: 'Poppins')),
                                SizedBox(height: 2.h),
                                Text(fmtPoolDate(r['travelDate']), style: TextStyle(fontSize: 11.sp, color: AppColors.textSecondary, fontFamily: 'Poppins')),
                              ])),
                              Text('₹${r['totalEarning'] ?? 0}', style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w800, color: AppColors.success, fontFamily: 'Poppins')),
                            ]),
                          ),
                        )),
                ],
              ),
            ),
    );
  }

  Widget _stat(String label, String value) => Column(children: [
        Text(value, style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w800, color: Colors.white, fontFamily: 'Poppins')),
        Text(label, style: TextStyle(fontSize: 11.sp, color: Colors.white.withValues(alpha: 0.9), fontFamily: 'Poppins')),
      ]);
}
