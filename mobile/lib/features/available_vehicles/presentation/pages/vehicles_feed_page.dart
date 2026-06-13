import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../bloc/vehicles_bloc.dart';

class VehiclesFeedPage extends StatefulWidget {
  const VehiclesFeedPage({super.key});

  @override
  State<VehiclesFeedPage> createState() => _VehiclesFeedPageState();
}

class _VehiclesFeedPageState extends State<VehiclesFeedPage> {
  final _scrollController = ScrollController();
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<VehiclesBloc>().add(const LoadVehiclesEvent());
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      context.read<VehiclesBloc>().add(LoadMoreVehiclesEvent());
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: TextField(
          controller: _searchCtrl,
          decoration: InputDecoration(
            hintText: 'Search by city...',
            border: InputBorder.none,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchCtrl.text.isNotEmpty
                ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchCtrl.clear(); context.read<VehiclesBloc>().add(const LoadVehiclesEvent()); })
                : null,
          ),
          onSubmitted: (v) => context.read<VehiclesBloc>().add(LoadVehiclesEvent(filters: {'search': v})),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {},
          ),
        ],
      ),
      body: BlocBuilder<VehiclesBloc, VehiclesState>(
        builder: (context, state) {
          if (state is VehiclesLoading) {
            return Center(child: CircularProgressIndicator(color: AppColors.primary));
          }
          if (state is VehiclesError) {
            return Center(child: Text(state.message, style: TextStyle(color: AppColors.textSecondary)));
          }
          if (state is VehiclesLoaded) {
            if (state.vehicles.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.local_taxi_outlined, size: 64.sp, color: AppColors.textHint),
                    SizedBox(height: 16.h),
                    Text('No vehicles available', style: TextStyle(fontSize: 18.sp, color: AppColors.textSecondary)),
                    SizedBox(height: 8.h),
                    Text('Be the first to post your available cab', style: TextStyle(color: AppColors.textHint)),
                  ],
                ),
              );
            }
            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async => context.read<VehiclesBloc>().add(const LoadVehiclesEvent()),
              child: ListView.separated(
                controller: _scrollController,
                padding: EdgeInsets.all(16.r),
                itemCount: state.vehicles.length,
                separatorBuilder: (_, __) => SizedBox(height: 12.h),
                itemBuilder: (_, i) => _VehicleCard(vehicle: state.vehicles[i]),
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        onPressed: () => context.push('/vehicles/create'),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Post Vehicle', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  final Map<String, dynamic> vehicle;
  const _VehicleCard({required this.vehicle});

  @override
  Widget build(BuildContext context) {
    final status = vehicle['status'] as String? ?? 'available';
    final statusColor = status == 'available' ? AppColors.success : AppColors.textHint;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.r),
        side: BorderSide(color: AppColors.border, width: 1),
      ),
      child: Padding(
        padding: EdgeInsets.all(14.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    vehicle['listingId'] as String? ?? '',
                    style: TextStyle(fontSize: 12.sp, color: AppColors.textHint),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Text(status.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 10.sp, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            SizedBox(height: 10.h),
            Row(
              children: [
                Icon(Icons.location_on, color: AppColors.success, size: 16.sp),
                SizedBox(width: 4.w),
                Expanded(child: Text('${vehicle['currentCity']} → ${vehicle['destinationCity'] ?? 'Any'}',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15.sp, color: AppColors.textPrimary))),
              ],
            ),
            SizedBox(height: 6.h),
            Row(
              children: [
                Icon(Icons.directions_car, color: AppColors.textHint, size: 16.sp),
                SizedBox(width: 4.w),
                Text((vehicle['vehicleType'] as String? ?? '').toUpperCase(),
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13.sp)),
                SizedBox(width: 16.w),
                Icon(Icons.badge_outlined, color: AppColors.textHint, size: 16.sp),
                SizedBox(width: 4.w),
                Text(vehicle['vehicleNumber'] as String? ?? '', style: TextStyle(color: AppColors.textSecondary, fontSize: 13.sp)),
              ],
            ),
            SizedBox(height: 6.h),
            Row(
              children: [
                Icon(Icons.person_outline, color: AppColors.textHint, size: 16.sp),
                SizedBox(width: 4.w),
                Text(vehicle['driverName'] as String? ?? '', style: TextStyle(color: AppColors.textSecondary, fontSize: 13.sp)),
                const Spacer(),
                Icon(Icons.calendar_today_outlined, color: AppColors.textHint, size: 14.sp),
                SizedBox(width: 4.w),
                Text(vehicle['availableDate'] as String? ?? '', style: TextStyle(color: AppColors.textHint, fontSize: 12.sp)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
