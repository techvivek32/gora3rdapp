import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../bloc/vehicles_bloc.dart';

class VehiclesFeedPage extends StatefulWidget {
  const VehiclesFeedPage({super.key});

  @override
  State<VehiclesFeedPage> createState() => _VehiclesFeedPageState();
}

class _VehiclesFeedPageState extends State<VehiclesFeedPage> {
  final _scrollController = ScrollController();
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _lastLoadedVehicles = [];
  bool _lastHasMore = false;

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
          IconButton(icon: const Icon(Icons.filter_list, color: Colors.white), onPressed: () {}),
          IconButton(icon: Icon(Icons.add, color: Colors.white, size: 28.sp), onPressed: () => context.push('/vehicles/create')),
        ],
      ),
      body: BlocBuilder<VehiclesBloc, VehiclesState>(
        builder: (context, state) {
          if (state is VehiclesLoaded) {
            _lastLoadedVehicles = state.vehicles;
            _lastHasMore = state.hasMore;
          }

          if (state is VehiclesLoading) {
            return Center(child: CircularProgressIndicator(color: AppColors.primary));
          }
          if (state is VehiclesError) {
            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async => context.read<VehiclesBloc>().add(const LoadVehiclesEvent()),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                  Center(child: Text(state.message, style: TextStyle(color: AppColors.textSecondary))),
                ],
              ),
            );
          }

          List<Map<String, dynamic>> vehicles = [];
          if (state is VehiclesLoaded) {
            vehicles = state.vehicles;
          } else {
            vehicles = _lastLoadedVehicles;
          }

          if (vehicles.isEmpty) {
            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async => context.read<VehiclesBloc>().add(const LoadVehiclesEvent()),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.35),
                  Center(
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
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async => context.read<VehiclesBloc>().add(const LoadVehiclesEvent()),
            child: ListView.separated(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.only(left: 16.w, right: 16.w, top: 16.r, bottom: 140.h),
              itemCount: vehicles.length,
              separatorBuilder: (_, __) => SizedBox(height: 12.h),
              itemBuilder: (context, i) => _VehicleCard(
                vehicle: vehicles[i],
                onTap: () => context.push('/vehicles/${vehicles[i]['_id']}', extra: vehicles[i]).then((result) {
                  if (result == true && mounted) {
                    context.read<VehiclesBloc>().add(const LoadVehiclesEvent());
                  }
                }),
              ),
            ),
          );
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
  final VoidCallback onTap;
  const _VehicleCard({required this.vehicle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final status = vehicle['status'] as String? ?? 'available';
    final postedBy = vehicle['postedBy'];
    final postedByMap = postedBy is Map ? postedBy : null;
    final memberType = postedByMap?['membershipType'] ?? 'new';
    final isPosterNew = memberType == 'new';
    final isActive = memberType == 'active';
    final color = isPosterNew ? AppColors.primary : (isActive ? Colors.green : AppColors.primary);
    final cardBg = isPosterNew ? AppColors.primary.withOpacity(0.05) : Colors.white;
    final statusColor = status == 'available' ? AppColors.success : AppColors.textHint;

    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        bool isCurrentUserPremium = false;
        bool isCurrentUserOwner = false;
        if (authState is AuthAuthenticated) {
          final user = authState.user;
          isCurrentUserPremium = (user['isPremium'] == true) || (user['isGolden'] == true) || (user['membershipType'] != null && user['membershipType'] != 'free');
          final currentUserId = user['_id'];
          final posterId = postedByMap?['_id'];
          isCurrentUserOwner = currentUserId != null && posterId != null && currentUserId == posterId;
        }

        return GestureDetector(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(color: isPosterNew ? AppColors.primary.withOpacity(0.3) : Colors.grey[300]!, width: 1),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 1)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8.r),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _WatermarkPainter(),
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                            IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(_formatDate(vehicle['availableDate']), style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold, color: Colors.black)),
                                        Text(vehicle['availableTime'] as String? ?? '', style: TextStyle(fontSize: 12.sp, color: Colors.grey[600])),
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
                                          color: statusColor.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(4.r),
                                        ),
                                        child: Text(status.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 11.sp, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 8.w),
                                  VerticalDivider(width: 1, thickness: 1, color: Colors.black26),
                                  SizedBox(width: 8.w),
                                  Expanded(
                                    flex: 2,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Container(
                                          padding: EdgeInsets.all(6.r),
                                          decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(6.r)),
                                          child: Icon(Icons.volume_up, size: 18.sp, color: Colors.green),
                                        ),
                                        SizedBox(width: 8.w),
                                        Container(
                                          padding: EdgeInsets.all(6.r),
                                          decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(6.r)),
                                          child: Icon(Icons.location_pin, size: 18.sp, color: Colors.blue),
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
                                            Container(width: 10.w, height: 10.h, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                                            Container(width: 2.w, height: 16.h, color: Colors.grey[400]),
                                            Container(width: 10.w, height: 10.h, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
                                          ],
                                        ),
                                        SizedBox(width: 8.w),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(vehicle['currentCity'] as String? ?? '', style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: Colors.black)),
                                              SizedBox(height: 6.h),
                                              Text(vehicle['destinationCity'] as String? ?? 'Any', style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: Colors.black)),
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
                            Row(
                              children: [
                                Icon(Icons.directions_car, size: 14.sp, color: Colors.black),
                                SizedBox(width: 6.w),
                                Text((vehicle['vehicleType'] as String? ?? '').toUpperCase(), style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold, color: Colors.black)),
                              ],
                            ),
                            SizedBox(height: 6.h),
                            Row(
                              children: [
                                Icon(Icons.badge_outlined, size: 14.sp, color: Colors.black),
                                SizedBox(width: 6.w),
                                Text(vehicle['vehicleNumber'] as String? ?? '', style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold, color: Colors.black)),
                              ],
                            ),
                            SizedBox(height: 6.h),
                            if (!isCurrentUserOwner) ...[
                              Divider(height: 1, thickness: 1, color: Colors.black26),
                              SizedBox(height: 8.h),
                              // New driver info section
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 24.r,
                                    backgroundColor: AppColors.primary.withOpacity(0.1),
                                    backgroundImage: postedByMap?['profileImage'] != null ? NetworkImage(postedByMap!['profileImage'] as String) : null,
                                    child: postedByMap?['profileImage'] == null ? Icon(Icons.person, color: AppColors.primary) : null,
                                  ),
                                  SizedBox(width: 12.w),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          postedByMap?['fullName'] as String? ?? vehicle['driverName'] as String? ?? 'Driver',
                                          style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold, color: Colors.black),
                                        ),
                                        SizedBox(height: 4.h),
                                        Text(
                                          postedByMap?['agencyName'] as String? ?? 'Agency Name',
                                          style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (postedByMap != null && (postedByMap['isPremium'] == true || postedByMap['isGolden'] == true || postedByMap['membershipType'] != 'free'))
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                                      decoration: BoxDecoration(
                                        color: Colors.green[50],
                                        borderRadius: BorderRadius.circular(4.r),
                                        border: Border.all(color: Colors.green),
                                      ),
                                      child: Text('ACTIVE USER', style: TextStyle(fontSize: 10.sp, color: Colors.green, fontWeight: FontWeight.w600)),
                                    ),
                                ],
                              ),
                              SizedBox(height: 12.h),
                              Row(
                                children: [
                                  Icon(Icons.star, size: 16.sp, color: Colors.amber),
                                  SizedBox(width: 4.w),
                                  Text('4.9', style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold, color: Colors.black)),
                                  SizedBox(width: 8.w),
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 4.h),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      borderRadius: BorderRadius.circular(4.r),
                                    ),
                                    child: Text('1hr 9 mins ago', style: TextStyle(fontSize: 10.sp, color: Colors.grey[600])),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      borderRadius: BorderRadius.circular(4.r),
                                    ),
                                    child: Text('Report', style: TextStyle(fontSize: 10.sp, color: Colors.red, fontWeight: FontWeight.w600)),
                                  ),
                                ],
                              ),
                              SizedBox(height: 12.h),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () {},
                                      icon: const Icon(Icons.phone, color: Colors.white),
                                      label: Text('Phone', style: TextStyle(fontSize: 12.sp, color: Colors.white)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        padding: EdgeInsets.symmetric(vertical: 10.h),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 10.w),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () {},
                                      icon: const Icon(Icons.chat, color: Colors.green),
                                      label: Text('WhatsApp', style: TextStyle(fontSize: 12.sp, color: Colors.green)),
                                      style: OutlinedButton.styleFrom(
                                        side: BorderSide(color: Colors.green, width: 1.5),
                                        padding: EdgeInsets.symmetric(vertical: 10.h),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 12.h),
                              Container(
                                width: double.infinity,
                                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                                decoration: BoxDecoration(
                                  color: Colors.amber[50],
                                  borderRadius: BorderRadius.circular(8.r),
                                  border: Border.all(color: Colors.amber.shade200, width: 1),
                                ),
                                child: Text(
                                  '⚠️ Don\'t pay without reference & proper verification.',
                                  style: TextStyle(fontSize: 11.sp, color: Colors.amber[800], fontWeight: FontWeight.w500),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                            if (!isCurrentUserPremium) ...[
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
          ),
        );
      },
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

class _WatermarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const text = 'Secure Member';
    const angle = -0.5;
    const rowGap = 36.0;
    const colGap = 120.0;

    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.grey.withOpacity(0.2),
          letterSpacing: 1.2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final rows = (size.height / rowGap).ceil() + 4;
    final cols = (size.width / colGap).ceil() + 4;

    for (int row = -2; row < rows; row++) {
      for (int col = -2; col < cols; col++) {
        final x = col * colGap;
        final y = row * rowGap;
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(angle);
        tp.paint(canvas, Offset.zero);
        canvas.restore();
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
