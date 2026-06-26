import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/vehicle_types.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/marquee_text.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../requirements/presentation/widgets/banner_card_widget.dart';
import '../../../users/presentation/widgets/user_card_sheet.dart';
import '../bloc/vehicles_bloc.dart';
import '../widgets/vehicles_filter_sheet.dart';

const _kCaution =
    'सावधान: बिना रेफरेंस किसी भी अनजान व्यक्ति को एडवांस पेमेंट न करें।   Caution: Do not make advance payments to any unknown person without a trusted reference.';

class VehiclesFeedPage extends StatefulWidget {
  const VehiclesFeedPage({super.key});

  @override
  State<VehiclesFeedPage> createState() => _VehiclesFeedPageState();
}

class _VehiclesFeedPageState extends State<VehiclesFeedPage> {
  final _scrollController = ScrollController();
  final _searchCtrl = TextEditingController();
  final _apiClient = getIt<ApiClient>();
  List<Map<String, dynamic>> _lastLoadedVehicles = [];
  List<Map<String, dynamic>> _lastMyAccepted = [];
  bool _lastHasMore = false;
  List<Map<String, dynamic>> _banners = [];
  Map<String, dynamic> _filters = {};

  void _openFilter() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => VehiclesFilterSheet(
        initialFilters: _filters,
        onApply: (filters) {
          setState(() => _filters = filters);
          context.read<VehiclesBloc>().add(LoadVehiclesEvent(filters: filters.isEmpty ? null : filters));
        },
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    context.read<VehiclesBloc>().add(const LoadVehiclesEvent());
    _scrollController.addListener(_onScroll);
    _loadBanners();
  }

  Future<void> _loadBanners() async {
    try {
      final res = await _apiClient.get('/banners');
      final data = res.data as Map<String, dynamic>?;
      final list = (data?['data'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .toList();
      if (mounted && list.isNotEmpty) {
        setState(() => _banners = list);
      }
    } catch (_) {}
  }

  Map<String, dynamic>? _randomBanner() {
    if (_banners.isEmpty) return null;
    return _banners[Random().nextInt(_banners.length)];
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      context.read<VehiclesBloc>().add(LoadMoreVehiclesEvent());
    }
  }

  bool _isExpired(Map<String, dynamic> v) {
    try {
      final dateStr = v['availableDate'] as String?;
      final timeStr = (v['availableTime'] as String?) ?? '00:00';
      if (dateStr == null) return false;
      final d = DateTime.parse(dateStr);
      final parts = timeStr.split(':');
      final h = int.tryParse(parts[0]) ?? 0;
      final m = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
      return DateTime(d.year, d.month, d.day, h, m).isBefore(DateTime.now());
    } catch (_) {
      return false;
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
            icon: const Icon(Icons.history_rounded, color: Colors.white),
            tooltip: 'My Vehicles',
            onPressed: () => context.push('/my-vehicles'),
          ),
          IconButton(icon: const Icon(Icons.filter_list, color: Colors.white), tooltip: 'Filter', onPressed: _openFilter),
          IconButton(icon: Icon(Icons.add, color: Colors.white, size: 28.sp), onPressed: () => context.push('/vehicles/create')),
        ],
      ),
      body: BlocBuilder<VehiclesBloc, VehiclesState>(
        builder: (context, state) {
          if (state is VehiclesLoaded) {
            _lastLoadedVehicles = state.vehicles;
            _lastMyAccepted = state.myAccepted;
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
          List<Map<String, dynamic>> myAccepted = [];
          if (state is VehiclesLoaded) {
            vehicles = state.vehicles.where((v) => !_isExpired(v)).toList();
            myAccepted = state.myAccepted.where((v) => !_isExpired(v)).toList();
          } else {
            vehicles = _lastLoadedVehicles.where((v) => !_isExpired(v)).toList();
            myAccepted = _lastMyAccepted.where((v) => !_isExpired(v)).toList();
          }

          final hasMyAccepted = myAccepted.isNotEmpty;

          // Build flat mixed list: vehicles interleaved with banners
          final List<dynamic> items = [];
          if (hasMyAccepted) items.add('accepted_section');
          for (int i = 0; i < vehicles.length; i++) {
            items.add(vehicles[i]);
            if (_banners.isNotEmpty) {
              items.add({'_type': 'banner', 'banner': _randomBanner()!});
            }
          }

          if (vehicles.isEmpty && !hasMyAccepted) {
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
              itemCount: items.length,
              separatorBuilder: (_, __) => SizedBox(height: 12.h),
              itemBuilder: (context, index) {
                final item = items[index];
                if (item == 'accepted_section') {
                  return _buildMyAcceptedSection(myAccepted);
                }
                if (item is Map && item['_type'] == 'banner') {
                  return BannerCardWidget(
                    banner: item['banner'] as Map<String, dynamic>,
                    apiClient: _apiClient,
                  );
                }
                final v = item as Map<String, dynamic>;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 22.h,
                      child: MarqueeText(
                        text: _kCaution,
                        style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, color: AppColors.error),
                      ),
                    ),
                    SizedBox(height: 6.h),
                    // Card is display-only; only the avatar/name open the profile popup.
                    VehicleCard(vehicle: v),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildMyAcceptedSection(List<Map<String, dynamic>> myAccepted) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 8.h),
          child: Row(
            children: [
              Container(
                width: 4.w,
                height: 18.h,
                decoration: BoxDecoration(color: Colors.green[700], borderRadius: BorderRadius.circular(2.r)),
              ),
              SizedBox(width: 8.w),
              Text(
                'My Accepted Cabs',
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold, color: Colors.green[800]),
              ),
              SizedBox(width: 8.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(color: Colors.green.shade300),
                ),
                child: Text('${myAccepted.length}', style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.bold, color: Colors.green[700])),
              ),
            ],
          ),
        ),
        SizedBox(height: 4.h),
        ...myAccepted.map((v) => Padding(
          padding: EdgeInsets.only(bottom: 10.h),
          child: VehicleCard(
            vehicle: v,
            onTap: () => context.push('/vehicles/${v['_id']}', extra: v).then((result) {
              if (result == true && mounted) {
                context.read<VehiclesBloc>().add(const LoadVehiclesEvent());
              }
            }),
          ),
        )),
        Divider(height: 1, thickness: 1, color: Colors.grey[300]),
        SizedBox(height: 8.h),
      ],
    );
  }
}

class VehicleCard extends StatelessWidget {
  final Map<String, dynamic> vehicle;
  final VoidCallback? onTap;
  final Widget? menu;
  const VehicleCard({super.key, required this.vehicle, this.onTap, this.menu});

  @override
  Widget build(BuildContext context) {
    final status = vehicle['status'] as String? ?? 'available';
    final postedBy = vehicle['postedBy'];
    final postedByMap = postedBy is Map ? postedBy : null;
    final isBooked = status == 'booked';
    final isOnHold = status == 'on_hold';
    final isCancelled = status == 'cancelled';

    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        bool isCurrentUserPremium = false;
        bool isCurrentUserOwner = false;
        String? currentUserId;
        if (authState is AuthAuthenticated) {
          final user = authState.user;
          isCurrentUserPremium = (user['isPremium'] == true) || (user['isGolden'] == true) || (['active', 'verified', 'premium', 'golden'].contains(user['membershipType']));
          currentUserId = user['_id'] as String?;
          final posterId = postedByMap?['_id'];
          isCurrentUserOwner = currentUserId != null && posterId != null && currentUserId == posterId;
        }

        final acceptedByRaw = vehicle['acceptedBy'];
        final acceptedByIds = <String>[];
        if (acceptedByRaw is List) {
          for (final e in acceptedByRaw) {
            final id = e is Map ? e['_id']?.toString() : e?.toString();
            if (id != null) acceptedByIds.add(id);
          }
        }
        final hasCurrentUserAccepted = currentUserId != null && acceptedByIds.contains(currentUserId);

        final memberType = postedByMap?['membershipType'] ?? 'new';
        Color topBarColor;
        String? badgeText;

        // Card colour reflects the poster's membership (own cards included):
        //   new / verified -> green, active -> blue, premium -> purple, golden -> orange
        if (memberType == 'golden') {
          topBarColor = AppColors.memberGolden;
          badgeText = 'GOLDEN USER';
        } else if (memberType == 'premium') {
          topBarColor = AppColors.memberPremium;
          badgeText = 'PREMIUM USER';
        } else if (memberType == 'active') {
          topBarColor = AppColors.memberActive;
          badgeText = 'ACTIVE USER';
        } else if (memberType == 'verified') {
          topBarColor = AppColors.memberVerified;
          badgeText = 'VERIFIED USER';
        } else {
          topBarColor = AppColors.memberVerified; // new
          badgeText = 'NEW USER';
        }
        final Color cardBg = topBarColor.withOpacity(0.07);
        final Color badgeColor = topBarColor;
        final Color badgeBg = topBarColor.withOpacity(0.12);

        final statusColor = status == 'available' ? AppColors.success : AppColors.textHint;

        return GestureDetector(
          onTap: onTap == null
              ? null
              : () {
                  if (isBooked && !isCurrentUserOwner && !hasCurrentUserAccepted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('This vehicle is already booked'),
                        backgroundColor: Colors.red,
                        duration: Duration(seconds: 2),
                      ),
                    );
                    return;
                  }
                  onTap!();
                },
          child: Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(color: topBarColor.withOpacity(0.3), width: 1),
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
                          color: topBarColor,
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
                                      children: menu != null
                                          ? [menu!]
                                          : [
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
                                Text(vehicleTypeLabel(vehicle['vehicleType'] as String?), style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold, color: Colors.black)),
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
                            ...[
                              Divider(height: 1, thickness: 1, color: Colors.black26),
                              SizedBox(height: 8.h),
                              Row(
                                children: [
                                  GestureDetector(
                                    onTap: postedByMap == null ? null : () => showUserCardSheet(context, Map<String, dynamic>.from(postedByMap)),
                                    child: CircleAvatar(
                                      radius: 24.r,
                                      backgroundColor: AppColors.primary.withOpacity(0.1),
                                      backgroundImage: postedByMap?['profileImage'] != null ? NetworkImage(postedByMap!['profileImage'] as String) : null,
                                      child: postedByMap?['profileImage'] == null ? Icon(Icons.person, color: AppColors.primary) : null,
                                    ),
                                  ),
                                  SizedBox(width: 12.w),
                                  Expanded(
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: postedByMap == null ? null : () => showUserCardSheet(context, Map<String, dynamic>.from(postedByMap)),
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
                                  ),
                                  if (badgeText != null)
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                                      decoration: BoxDecoration(
                                        color: badgeBg,
                                        borderRadius: BorderRadius.circular(4.r),
                                        border: Border.all(color: badgeColor),
                                      ),
                                      child: Text(badgeText, style: TextStyle(fontSize: 10.sp, color: badgeColor, fontWeight: FontWeight.w600)),
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
                              // Owners always see their own details, even without a plan.
                              if (isCurrentUserPremium || isCurrentUserOwner) ...[
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
                                SizedBox(height: 12.h),
                              ] else ...[
                                Divider(height: 1, thickness: 1, color: Colors.black26),
                                SizedBox(height: 8.h),
                                Text(
                                  'Become a premium member to contact immediately',
                                  style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: Colors.red),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: 8.h),
                              ],
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (isBooked || isOnHold || isCancelled)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Center(
                          child: Transform.rotate(
                            angle: -0.2,
                            child: _buildStampBadge(
                              text: isCancelled
                                  ? 'CANCELLED'
                                  : isOnHold
                                      ? 'ON HOLD'
                                      : hasCurrentUserAccepted
                                          ? 'ACCEPTED'
                                          : 'BOOKED',
                              color: isCancelled
                                  ? Colors.grey[600]!
                                  : isOnHold
                                      ? Colors.orange[800]!
                                      : hasCurrentUserAccepted
                                          ? Colors.green[700]!
                                          : Colors.red[700]!,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStampBadge({required String text, required Color color}) {
    return SizedBox(
      width: 110.w,
      height: 110.w,
      child: CustomPaint(
        painter: _StampRingPainter(color: color),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star, color: color, size: 9.sp),
                  SizedBox(width: 2.w),
                  Icon(Icons.star, color: color, size: 9.sp),
                  SizedBox(width: 2.w),
                  Icon(Icons.star, color: color, size: 9.sp),
                ],
              ),
              SizedBox(height: 3.h),
              Text(
                text,
                style: TextStyle(
                  color: color,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              SizedBox(height: 3.h),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star, color: color, size: 9.sp),
                  SizedBox(width: 2.w),
                  Icon(Icons.star, color: color, size: 9.sp),
                  SizedBox(width: 2.w),
                  Icon(Icons.star, color: color, size: 9.sp),
                ],
              ),
            ],
          ),
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

class _StampRingPainter extends CustomPainter {
  final Color color;
  _StampRingPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final rOuter = size.width / 2 - 2;
    final rValley = rOuter - 7;
    final rInner = rOuter - 14;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    const teeth = 26;
    final path = Path();
    for (int i = 0; i < teeth; i++) {
      final a1 = (i / teeth) * 2 * pi - pi / 2;
      final a2 = ((i + 0.5) / teeth) * 2 * pi - pi / 2;
      final a3 = ((i + 1.0) / teeth) * 2 * pi - pi / 2;
      final p1x = cx + rOuter * cos(a1);
      final p1y = cy + rOuter * sin(a1);
      final p2x = cx + rValley * cos(a2);
      final p2y = cy + rValley * sin(a2);
      final p3x = cx + rOuter * cos(a3);
      final p3y = cy + rOuter * sin(a3);
      if (i == 0) {
        path.moveTo(p1x, p1y);
      } else {
        path.lineTo(p1x, p1y);
      }
      path.lineTo(p2x, p2y);
      path.lineTo(p3x, p3y);
    }
    path.close();
    canvas.drawPath(path, paint);
    canvas.drawCircle(Offset(cx, cy), rInner - 2, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
