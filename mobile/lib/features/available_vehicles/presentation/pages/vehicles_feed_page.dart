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
        backgroundColor: AppColors.primary,
        elevation: 4,
        automaticallyImplyLeading: false,
        title: Text('Available Cabs', style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold, color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list, color: Colors.white),
            onPressed: () {},
          ),
          IconButton(
            icon: Icon(Icons.add, color: Colors.white, size: 28.sp),
            onPressed: () => context.push('/vehicles/create'),
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
    final postedBy = vehicle['postedBy'] as Map<String, dynamic>?;
    final memberType = postedBy?['membershipType'] ?? 'new';
    final isNew = memberType == 'new';
    final isActive = memberType == 'active';
    final color = isNew ? AppColors.primary : (isActive ? Colors.green : AppColors.primary);
    final cardBg = isNew ? AppColors.primary.withOpacity(0.05) : Colors.white;
    final statusColor = status == 'available' ? AppColors.success : AppColors.textHint;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: isNew ? AppColors.primary.withOpacity(0.3) : Colors.grey[300]!, width: 1),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 1)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8.r),
        child: Stack(
          children: [
            // Diagonal watermark
            Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: Transform.rotate(
                    angle: -0.6,
                    child: Text(
                      'Secure Member',
                      style: TextStyle(
                        fontSize: 28.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.withOpacity(0.08),
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top border
                Container(
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(8.r),
                      topRight: Radius.circular(8.r),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(12.r),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header row: listingId | status badge
                      IntrinsicHeight(
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    vehicle['listingId'] as String? ?? '',
                                    style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold, color: Colors.black),
                                  ),
                                  Text(
                                    _formatDate(vehicle['availableDate']),
                                    style: TextStyle(fontSize: 11.sp, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: 8.w),
                            VerticalDivider(width: 1, thickness: 1, color: Colors.black26),
                            SizedBox(width: 8.w),
                            Expanded(
                              flex: 2,
                              child: Center(
                                child: Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4.r),
                                  ),
                                  child: Text(
                                    status.toUpperCase(),
                                    style: TextStyle(color: statusColor, fontSize: 11.sp, fontWeight: FontWeight.w600),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 10.h),
                      Divider(height: 1, thickness: 1, color: Colors.black26),
                      SizedBox(height: 10.h),

                      // Route
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        width: 10.w, height: 10.h,
                                        decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                                      ),
                                      Container(width: 2.w, height: 16.h, color: Colors.grey[400]),
                                      Container(
                                        width: 10.w, height: 10.h,
                                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                      ),
                                    ],
                                  ),
                                  SizedBox(width: 8.w),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          vehicle['currentCity'] as String? ?? '',
                                          style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: Colors.black),
                                        ),
                                        SizedBox(height: 6.h),
                                        Text(
                                          vehicle['destinationCity'] as String? ?? 'Any',
                                          style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: Colors.black),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 10.h),
                      Divider(height: 1, thickness: 1, color: Colors.black26),
                      SizedBox(height: 10.h),

                      // Vehicle type
                      Row(
                        children: [
                          Icon(Icons.directions_car, size: 14.sp, color: Colors.black),
                          SizedBox(width: 6.w),
                          Text(
                            (vehicle['vehicleType'] as String? ?? '').toUpperCase(),
                            style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold, color: Colors.black),
                          ),
                        ],
                      ),
                      SizedBox(height: 6.h),

                      // Vehicle number
                      Row(
                        children: [
                          Icon(Icons.badge_outlined, size: 14.sp, color: Colors.black),
                          SizedBox(width: 6.w),
                          Text(
                            vehicle['vehicleNumber'] as String? ?? '',
                            style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold, color: Colors.black),
                          ),
                        ],
                      ),
                      SizedBox(height: 6.h),

                      // Driver name
                      Row(
                        children: [
                          Icon(Icons.person_outline, size: 14.sp, color: Colors.black),
                          SizedBox(width: 6.w),
                          Text(
                            vehicle['driverName'] as String? ?? '',
                            style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold, color: Colors.black),
                          ),
                        ],
                      ),

                      if (isNew) ...[
                        SizedBox(height: 10.h),
                        Divider(height: 1, thickness: 1, color: Colors.black26),
                        SizedBox(height: 8.h),
                        Text(
                          'Become a premium member to contact immediately',
                          style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 4.h),
                      ] else
                        SizedBox(height: 10.h),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return '';
    try {
      final d = DateTime.parse(date.toString());
      const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${d.day} ${months[d.month]}';
    } catch (_) {
      return date.toString();
    }
  }
}
