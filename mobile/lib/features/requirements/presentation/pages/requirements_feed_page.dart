import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/utils/tab_refresh.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../../core/constants/vehicle_types.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/marquee_text.dart';
import '../bloc/requirements_bloc.dart';
import '../widgets/banner_card_widget.dart';
import '../widgets/requirement_card_widget.dart';
import '../../../customer/data/customer_repository.dart';
import '../../../customer/presentation/widgets/customer_request_card.dart';

const _kCaution =
    'सावधान: बिना रेफरेंस किसी भी अनजान व्यक्ति को एडवांस पेमेंट न करें।   Caution: Do not make advance payments to any unknown person without a trusted reference.';

class RequirementsFeedPage extends StatefulWidget {
  const RequirementsFeedPage({super.key});

  @override
  State<RequirementsFeedPage> createState() => _RequirementsFeedPageState();
}

class _RequirementsFeedPageState extends State<RequirementsFeedPage> {
  final _scrollController = ScrollController();
  final _apiClient = getIt<ApiClient>();
  final Set<String> _vehicleFilters = {}; // top vehicle-type filter (empty = All)
  List<Map<String, dynamic>> _lastLoadedRequirements = [];
  // Customer-mode bookings (from the customer side) merged into this feed so
  // drivers can send offers here too.
  List<Map<String, dynamic>> _customerBookings = [];
  List<Map<String, dynamic>> _banners = [];

  // Silent auto-refresh (no spinner, keeps scroll position).
  Timer? _pollTimer;
  double? _preRefreshMax;
  double _preRefreshOffset = 0;

  static const _bannerEvery = 1; // insert a banner after every N requirement cards

  @override
  void initState() {
    super.initState();
    context.read<RequirementsBloc>().add(const LoadRequirementsEvent(filters: {}));
    _loadCustomerBookings();
    _scrollController.addListener(_onScroll);
    _loadBanners();
    // Refresh the App-Suggested-Fare toggle, then rebuild so cards reflect it.
    AppConfig.refresh(getIt<ApiClient>()).then((_) { if (mounted) setState(() {}); });
    // Poll in the background so new posts / status changes appear live.
    _pollTimer = Timer.periodic(const Duration(seconds: 300), (_) => _silentRefresh());
    // Tapping the already-active "Booking" bottom-nav tab reloads this feed.
    TabRefresh.requirements.addListener(_onTabReTap);
  }

  void _onTabReTap() {
    if (!mounted) return;
    if (_scrollController.hasClients) {
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
    context.read<RequirementsBloc>().add(const LoadRequirementsEvent(filters: {}));
    _loadCustomerBookings();
  }

  Future<void> _loadCustomerBookings() async {
    try {
      final d = await getIt<CustomerRepository>().available();
      if (mounted) setState(() => _customerBookings = d);
    } catch (_) {}
  }

  void _reloadAll() {
    context.read<RequirementsBloc>().add(const LoadRequirementsEvent(filters: {}));
    _loadCustomerBookings();
  }

  Future<void> _applyCustomer(Map<String, dynamic> b) async {
    final id = (b['_id'] ?? b['id'] ?? '').toString();
    final result = await showCustomerApplySheet(context, b);
    if (result == null) return;
    try {
      await getIt<CustomerRepository>().apply(id, result);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Offer sent! A commitment hold is placed on your wallet.'), backgroundColor: AppColors.success));
      _loadCustomerBookings();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not apply: ${e.toString().replaceFirst('Exception: ', '')}'), backgroundColor: AppColors.error));
    }
  }

  void _silentRefresh() {
    if (!mounted) return;
    final bloc = context.read<RequirementsBloc>();
    if (bloc.state is! RequirementsLoaded) return;
    // Remember scroll so we can keep the user in place if new cards are prepended.
    if (_scrollController.hasClients) {
      _preRefreshMax = _scrollController.position.maxScrollExtent;
      _preRefreshOffset = _scrollController.offset;
    } else {
      _preRefreshMax = null;
    }
    bloc.add(const RefreshRequirementsEvent());
  }

  // After a silent refresh, if new cards were added above the viewport, shift the
  // offset so the user stays on the same card instead of jumping.
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

  int _createdMs(dynamic m) {
    final s = (m is Map ? (m['createdAt'] ?? '') : '').toString();
    return DateTime.tryParse(s)?.millisecondsSinceEpoch ?? 0;
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      context.read<RequirementsBloc>().add(LoadMoreRequirementsEvent());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 4,
        automaticallyImplyLeading: false,
        title: Text('Booking'.tr, style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold, color: Colors.white)),
        actions: [
          IconButton(
            icon: Icon(Icons.history_rounded, color: Colors.white),
            tooltip: 'My Bookings',
            onPressed: () => context.push('/my-requirements'),
          ),
          IconButton(
            icon: Icon(Icons.add, color: Colors.white, size: 28.sp),
            onPressed: () => context.push('/requirements/create'),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(50.h),
          child: _buildVehicleFilterBar(),
        ),
      ),
      body: BlocConsumer<RequirementsBloc, RequirementsState>(
        listenWhen: (prev, curr) => curr is RequirementsLoaded,
        listener: (context, state) => _restoreScrollAfterRefresh(),
        builder: (context, state) {
          if (state is RequirementsLoaded) {
            _lastLoadedRequirements = state.requirements;
          }


          if (state is RequirementsLoading) {
            return _buildLoadingList();
          }

          List<Map<String, dynamic>> requirements = [];
          bool isLoadingMore = false;
          // Show every requirement the backend returns (the backend applies the
          // 7-day expiry, so pagination stays correct and "load more" works).
          if (state is RequirementsLoaded) {
            requirements = List<Map<String, dynamic>>.from(state.requirements);
            isLoadingMore = state.isLoadingMore;
          } else {
            requirements = List<Map<String, dynamic>>.from(_lastLoadedRequirements);
            isLoadingMore = false;
          }

          // Apply the top vehicle-type filter (empty = All) to both feeds.
          List<Map<String, dynamic>> customerBookings = List<Map<String, dynamic>>.from(_customerBookings);
          if (_vehicleFilters.isNotEmpty) {
            requirements = requirements.where((r) => _vehicleFilters.contains(r['vehicleType'])).toList();
            customerBookings = customerBookings.where((r) => _vehicleFilters.contains(r['vehicleType'])).toList();
          }

          // Merge requirements (app + WhatsApp) with customer-side bookings, newest first.
          final List<Map<String, dynamic>> merged = [
            ...requirements.map((r) => {'_kind': 'req', 'data': r}),
            ...customerBookings.map((c) => {'_kind': 'cust', 'data': c}),
          ];
          merged.sort((a, b) => _createdMs(b['data']).compareTo(_createdMs(a['data'])));

          // Build flat mixed list: cards interleaved with banners.
          final List<dynamic> items = [];
          for (int i = 0; i < merged.length; i++) {
            items.add(merged[i]);
            if (_banners.isNotEmpty && (i + 1) % _bannerEvery == 0) {
              items.add({'_type': 'banner', 'banner': _randomBanner()!});
            }
          }
          if (isLoadingMore) items.add('loading');

          if (merged.isEmpty) {
            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async => _reloadAll(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [SizedBox(height: MediaQuery.of(context).size.height * 0.35), _buildEmptyState()],
              ),
            );
          }
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async => _reloadAll(),
            child: ListView.separated(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.only(left: 8.r, right: 8.r, top: 16.r, bottom: 140.h),
              itemCount: items.length,
              separatorBuilder: (_, __) => SizedBox(height: 16.h),
              itemBuilder: (context, index) {
                final item = items[index];
                if (item == 'loading') {
                  return Center(child: Padding(
                    padding: EdgeInsets.all(16.r),
                    child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
                  ));
                }
                if (item is Map && item['_type'] == 'banner') {
                  return BannerCardWidget(banner: item['banner'] as Map<String, dynamic>, apiClient: _apiClient);
                }
                final entry = item as Map<String, dynamic>;
                final data = entry['data'] as Map<String, dynamic>;
                // Customer-side booking → offer/apply card.
                if (entry['_kind'] == 'cust') {
                  return CustomerRequestCard(data, onApply: () => _applyCustomer(data));
                }
                // Requirement card with the caution marquee above it.
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
                    RequirementCardWidget(requirement: data),
                  ],
                );
              },
            ),
          );

          // ignore: dead_code
          if (state is RequirementsError) {
            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async => _reloadAll(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                  Center(child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 48.sp, color: AppColors.error),
                      SizedBox(height: 16.h),
                      Text(state.message, style: TextStyle(color: AppColors.textSecondary), textAlign: TextAlign.center),
                      SizedBox(height: 16.h),
                      ElevatedButton(
                        onPressed: _reloadAll,
                        child: const Text('Retry'),
                      ),
                    ],
                  )),
                ],
              ),
            );
          }

          return const SizedBox();
        },
      ),
    );
  }

  Widget _buildLoadingList() {
    return ListView.separated(
      padding: EdgeInsets.all(16.r),
      itemCount: 5,
      separatorBuilder: (_, __) => SizedBox(height: 12.h),
      itemBuilder: (_, __) => Container(
        height: 140.h,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 64.sp, color: AppColors.textHint),
          SizedBox(height: 16.h),
          Text('No bookings found',
              style: TextStyle(fontSize: 16.sp, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
          SizedBox(height: 8.h),
          Text(
            'Be the first to post a booking!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.sp, color: AppColors.textHint),
          ),
          SizedBox(height: 24.h),
          ElevatedButton.icon(
            onPressed: () => context.push('/requirements/create'),
            icon: const Icon(Icons.add),
            label: const Text('Post Booking'),
          ),
        ],
      ),
    );
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
                o['label']!.tr,
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

  @override
  void dispose() {
    _pollTimer?.cancel();
    TabRefresh.requirements.removeListener(_onTabReTap);
    _scrollController.dispose();
    super.dispose();
  }
}
