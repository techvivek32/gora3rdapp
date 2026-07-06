import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../core/constants/vehicle_types.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/contact_launcher.dart';
import '../../../../core/widgets/marquee_text.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../requirements/presentation/widgets/banner_card_widget.dart';
import '../../../users/presentation/widgets/user_card_sheet.dart';
import '../bloc/vehicles_bloc.dart';

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
  final Set<String> _vehicleFilters = {}; // top vehicle-type filter (empty = All)
  List<Map<String, dynamic>> _lastLoadedVehicles = [];
  List<Map<String, dynamic>> _lastMyAccepted = [];
  bool _lastHasMore = false;
  List<Map<String, dynamic>> _banners = [];

  // Silent auto-refresh (no spinner, keeps scroll position).
  Timer? _pollTimer;
  double? _preRefreshMax;
  double _preRefreshOffset = 0;

  @override
  void initState() {
    super.initState();
    context.read<VehiclesBloc>().add(const LoadVehiclesEvent());
    _scrollController.addListener(_onScroll);
    _loadBanners();
    _pollTimer = Timer.periodic(const Duration(seconds: 12), (_) => _silentRefresh());
  }

  void _silentRefresh() {
    if (!mounted) return;
    final bloc = context.read<VehiclesBloc>();
    if (bloc.state is! VehiclesLoaded) return;
    if (_scrollController.hasClients) {
      _preRefreshMax = _scrollController.position.maxScrollExtent;
      _preRefreshOffset = _scrollController.offset;
    } else {
      _preRefreshMax = null;
    }
    bloc.add(const RefreshVehiclesEvent());
  }

  void _restoreScrollAfterRefresh() {
    final preMax = _preRefreshMax;
    final preOffset = _preRefreshOffset;
    _preRefreshMax = null;
    if (preMax == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final newMax = _scrollController.position.maxScrollExtent;
      final delta = newMax - preMax;
      if (delta > 0 && preOffset > 0) {
        _scrollController.jumpTo((preOffset + delta).clamp(0.0, newMax));
      }
    });
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

  Widget _buildVehicleFilterBar() {
    final options = <Map<String, String>>[
      {'value': 'all', 'label': 'All Vehicles'},
      ...kVehicleTypes,
    ];
    return Container(
      color: Colors.white,
      height: 50.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        itemCount: options.length,
        separatorBuilder: (_, __) => SizedBox(width: 8.w),
        itemBuilder: (_, i) {
          final o = options[i];
          final isAll = o['value'] == 'all';
          // "All Vehicles" is active only when no specific type is selected.
          final selected = isAll ? _vehicleFilters.isEmpty : _vehicleFilters.contains(o['value']);
          return GestureDetector(
            onTap: () => setState(() {
              if (isAll) {
                _vehicleFilters.clear();
              } else {
                final v = o['value']!;
                _vehicleFilters.contains(v) ? _vehicleFilters.remove(v) : _vehicleFilters.add(v);
              }
            }),
            child: Container(
              alignment: Alignment.center,
              padding: EdgeInsets.symmetric(horizontal: 14.w),
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : Colors.grey[100],
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(color: selected ? AppColors.primary : AppColors.border, width: 1),
              ),
              child: Text(
                o['label']!,
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Poppins',
                  color: selected ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  bool _isExpired(Map<String, dynamic> v) {
    try {
      final dateStr = v['availableDate'] as String?;
      if (dateStr == null) return false;
      // Keep the listing visible for the WHOLE available day (ignore the time of
      // day). Use only the date part so timezone never shifts the day.
      final datePart = dateStr.contains('T') ? dateStr.split('T').first : dateStr;
      final p = datePart.split('-');
      if (p.length != 3) return false;
      final endOfDay = DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]), 23, 59, 59);
      return endOfDay.isBefore(DateTime.now());
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
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
          IconButton(icon: Icon(Icons.add, color: Colors.white, size: 28.sp), onPressed: () => context.push('/vehicles/create')),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(50.h),
          child: _buildVehicleFilterBar(),
        ),
      ),
      body: BlocConsumer<VehiclesBloc, VehiclesState>(
        listenWhen: (prev, curr) => curr is VehiclesLoaded,
        listener: (context, state) => _restoreScrollAfterRefresh(),
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

          // Apply the top vehicle-type filter (empty = All).
          if (_vehicleFilters.isNotEmpty) {
            vehicles = vehicles.where((v) => _vehicleFilters.contains(v['vehicleType'])).toList();
            myAccepted = myAccepted.where((v) => _vehicleFilters.contains(v['vehicleType'])).toList();
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
              padding: EdgeInsets.only(left: 8.w, right: 8.w, top: 16.r, bottom: 140.h),
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
  final bool mine; // true on the "My Vehicles" list — treat as owner
  const VehicleCard({super.key, required this.vehicle, this.onTap, this.menu, this.mine = false});

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
        bool isCurrentUserOwner = mine;
        String? currentUserId;
        String? currentUserName;
        String? currentMembership;
        if (authState is AuthAuthenticated) {
          final user = authState.user;
          currentUserId = user['_id'] as String?;
          currentUserName = user['fullName'] as String?;
          currentMembership = user['membershipType'] as String?;
          final posterId = postedByMap?['_id'];
          isCurrentUserOwner = mine || (currentUserId != null && posterId != null && currentUserId == posterId);
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
        // Cancelled / booked / on-hold listings are read-only for everyone except
        // the owner (who still manages them from My Vehicles).
        final bool locked = (isBooked || isOnHold || isCancelled) && !isCurrentUserOwner;

        final memberType = (mine ? currentMembership : (postedByMap?['membershipType'] as String?)) ?? 'new';
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

        return GestureDetector(
          onTap: onTap == null || locked
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
                  // Dim + block interaction on read-only (cancelled/booked/hold) cards.
                  Opacity(
                    opacity: locked ? 0.2 : 1.0,
                    child: AbsorbPointer(
                      absorbing: locked,
                      child: Column(
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
                            // 1. Route (left) + date/time box (right)
                            IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        Column(
                                          children: [
                                            Icon(Icons.trip_origin, size: 14.sp, color: topBarColor),
                                            Expanded(child: Container(width: 2.w, color: Colors.grey[400])),
                                            Icon(Icons.location_on, size: 18.sp, color: topBarColor),
                                          ],
                                        ),
                                        SizedBox(width: 10.w),
                                        Expanded(
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              _routePlace(vehicle['currentCity'] as String?, vehicle['currentState'] as String?),
                                              SizedBox(height: 10.h),
                                              _routePlace(vehicle['destinationCity'] as String? ?? 'Any', vehicle['destinationState'] as String?),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(width: 10.w),
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                                    decoration: BoxDecoration(
                                      color: topBarColor,
                                      borderRadius: BorderRadius.circular(8.r),
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(_formatDateFull(vehicle['availableDate']), style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold, color: Colors.white)),
                                        SizedBox(height: 2.h),
                                        Text(_formatTime12(vehicle['availableTime'] as String?), style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold, color: Colors.white)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 10.h),
                            Divider(height: 1, thickness: 1, color: Colors.black26),
                            SizedBox(height: 10.h),

                            // 2. Vehicle availability
                            Row(
                              children: [
                                Icon(Icons.directions_car, size: 18.sp, color: topBarColor),
                                SizedBox(width: 8.w),
                                Expanded(
                                  child: Text('${vehicleTypeLabel(vehicle['vehicleType'] as String?)} is available',
                                      style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold, color: Colors.black)),
                                ),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                                  decoration: BoxDecoration(
                                    color: topBarColor.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(6.r),
                                  ),
                                  child: Text(
                                    (vehicle['tripType'] as String?) == 'round_trip' ? 'Round Trip' : 'One Way',
                                    style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600, color: topBarColor),
                                  ),
                                ),
                              ],
                            ),

                            // 3. Notes
                            if (((vehicle['notes'] as String?) ?? '').trim().isNotEmpty) ...[
                              SizedBox(height: 10.h),
                              Divider(height: 1, thickness: 1, color: Colors.black26),
                              SizedBox(height: 10.h),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.chat_bubble_outline, size: 16.sp, color: topBarColor),
                                  SizedBox(width: 8.w),
                                  Expanded(child: Text((vehicle['notes'] as String).trim(), style: TextStyle(fontSize: 13.sp, color: Colors.black87))),
                                ],
                              ),
                            ],

                            SizedBox(height: 10.h),
                            Divider(height: 1, thickness: 1, color: Colors.black26),
                            SizedBox(height: 10.h),

                            // 4. Poster + time ago
                            Row(
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          postedByMap?['fullName'] as String? ?? (mine ? (currentUserName ?? 'You') : 'User'),
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold, color: Colors.black),
                                        ),
                                      ),
                                      if (badgeText != null) ...[
                                        SizedBox(width: 6.w),
                                        Container(
                                          padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                                          decoration: BoxDecoration(
                                            color: badgeBg,
                                            borderRadius: BorderRadius.circular(4.r),
                                            border: Border.all(color: badgeColor),
                                          ),
                                          child: Text(badgeText, style: TextStyle(fontSize: 9.sp, color: badgeColor, fontWeight: FontWeight.w600)),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                SizedBox(width: 8.w),
                                Text(_timeAgo(vehicle['createdAt']), style: TextStyle(fontSize: 11.sp, color: Colors.grey[600])),
                              ],
                            ),
                            SizedBox(height: 12.h),
                            Divider(height: 1, thickness: 1, color: Colors.black26),
                            SizedBox(height: 10.h),

                            // 5. Actions: Call, WhatsApp, User Detail (open to everyone)
                            Builder(builder: (context) {
                              final mobile = postedByMap?['mobile'] as String? ?? postedByMap?['driverMobile'] as String?;
                              void openSheet() {
                                if (postedByMap != null) showUserCardSheet(context, Map<String, dynamic>.from(postedByMap));
                              }
                              void snackNoNumber() => ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Contact number not available')),
                                  );
                              return Row(
                                children: [
                                  _CardAction(
                                    icon: const Icon(Icons.call, color: Colors.white, size: 18),
                                    circleColor: const Color(0xFF2196F3),
                                    label: 'Call',
                                    onTap: (mobile != null && mobile.isNotEmpty) ? () => callNumber(mobile) : snackNoNumber,
                                  ),
                                  SizedBox(width: 20.w),
                                  _CardAction(
                                    icon: const FaIcon(FontAwesomeIcons.whatsapp, color: Colors.white, size: 18),
                                    circleColor: const Color(0xFF25D366),
                                    label: 'Whatsapp',
                                    onTap: (mobile != null && mobile.isNotEmpty) ? () => openWhatsApp(mobile) : snackNoNumber,
                                  ),
                                  const Spacer(),
                                  _CardAction(
                                    icon: Icon(Icons.person_outline, color: topBarColor, size: 22),
                                    label: 'User Detail',
                                    onTap: openSheet,
                                  ),
                                  if (menu != null) ...[
                                    SizedBox(width: 8.w),
                                    menu!,
                                  ],
                                ],
                              );
                            }),
                          ],
                        ),
                      ),
                    ],
                      ),
                    ),
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
    return Container(
      width: 150.w,
      height: 150.w,
      // Highlight the stamp so it pops against the dimmed card behind it.
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.85),
        boxShadow: [BoxShadow(color: color.withOpacity(0.35), blurRadius: 12, spreadRadius: 1)],
      ),
      child: CustomPaint(
        painter: _StampRingPainter(color: color),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star, color: color, size: 12.sp),
                  SizedBox(width: 3.w),
                  Icon(Icons.star, color: color, size: 12.sp),
                  SizedBox(width: 3.w),
                  Icon(Icons.star, color: color, size: 12.sp),
                ],
              ),
              SizedBox(height: 4.h),
              Text(
                text,
                style: TextStyle(
                  color: color,
                  fontSize: 19.sp,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              SizedBox(height: 4.h),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star, color: color, size: 12.sp),
                  SizedBox(width: 3.w),
                  Icon(Icons.star, color: color, size: 12.sp),
                  SizedBox(width: 3.w),
                  Icon(Icons.star, color: color, size: 12.sp),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _routePlace(String? city, String? state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(city ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold, color: Colors.black)),
        if (state != null && state.trim().isNotEmpty)
          Text(state, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.sp, color: Colors.grey[600])),
      ],
    );
  }

  String _formatDateFull(dynamic date) {
    if (date == null) return '';
    try {
      final d = DateTime.parse(date.toString());
      const months = ['', 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
      return '${d.day} ${months[d.month]}';
    } catch (_) {
      return date.toString();
    }
  }

  String _formatTime12(String? t) {
    if (t == null || t.isEmpty) return '';
    final parts = t.split(':');
    if (parts.length < 2) return t;
    int h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    final period = h >= 12 ? 'pm' : 'am';
    int h12 = h % 12;
    if (h12 == 0) h12 = 12;
    return '${h12.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} $period';
  }

  String _timeAgo(dynamic createdAt) {
    if (createdAt == null) return '';
    try {
      final d = DateTime.parse(createdAt.toString());
      final diff = DateTime.now().difference(d);
      if (diff.inMinutes < 1) return 'just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes} minute${diff.inMinutes == 1 ? '' : 's'} ago';
      if (diff.inHours < 24) return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
      return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
    } catch (_) {
      return '';
    }
  }
}

class _CardAction extends StatelessWidget {
  final Widget icon;
  final String label;
  final VoidCallback onTap;
  final Color? circleColor;
  const _CardAction({required this.icon, required this.label, required this.onTap, this.circleColor});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (circleColor != null)
            CircleAvatar(radius: 18.r, backgroundColor: circleColor, child: icon)
          else
            SizedBox(height: 36.r, child: Center(child: icon)),
          SizedBox(height: 4.h),
          Text(label, style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        ],
      ),
    );
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
