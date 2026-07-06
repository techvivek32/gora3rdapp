import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/marquee_text.dart';
import '../bloc/requirements_bloc.dart';
import '../widgets/banner_card_widget.dart';
import '../widgets/requirement_card_widget.dart';

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
  String _searchQuery = '';
  List<Map<String, dynamic>> _lastLoadedRequirements = [];
  List<Map<String, dynamic>> _lastMyAccepted = [];
  bool _lastHasMore = false;
  List<Map<String, dynamic>> _banners = [];

  // Silent auto-refresh (no spinner, keeps scroll position).
  Timer? _pollTimer;
  double? _preRefreshMax;
  double _preRefreshOffset = 0;

  static const _bannerEvery = 1; // insert a banner after every N requirement cards

  @override
  void initState() {
    super.initState();
    context.read<RequirementsBloc>().add(LoadRequirementsEvent());
    _scrollController.addListener(_onScroll);
    _loadBanners();
    // Poll in the background so new posts / status changes appear live.
    _pollTimer = Timer.periodic(const Duration(seconds: 12), (_) => _silentRefresh());
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
        title: Text('Requirement', style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold, color: Colors.white)),
        actions: [
          IconButton(
            icon: Icon(Icons.history_rounded, color: Colors.white),
            tooltip: 'My Requirements',
            onPressed: () => context.push('/my-requirements'),
          ),
          IconButton(
            icon: Icon(Icons.add, color: Colors.white, size: 28.sp),
            onPressed: () => context.push('/requirements/create'),
          ),
        ],
      ),
      body: BlocConsumer<RequirementsBloc, RequirementsState>(
        listenWhen: (prev, curr) => curr is RequirementsLoaded,
        listener: (context, state) => _restoreScrollAfterRefresh(),
        builder: (context, state) {
          if (state is RequirementsLoaded) {
            _lastLoadedRequirements = state.requirements;
            _lastMyAccepted = state.myAccepted;
            _lastHasMore = state.hasMore;
          }


          if (state is RequirementsLoading) {
            return _buildLoadingList();
          }

          List<Map<String, dynamic>> requirements = [];
          List<Map<String, dynamic>> myAccepted = [];
          bool isLoadingMore = false;
          if (state is RequirementsLoaded) {
            requirements = state.requirements.where((r) => !_isExpired(r)).toList();
            myAccepted = state.myAccepted.where((r) => !_isExpired(r)).toList();
            isLoadingMore = state.isLoadingMore;
          } else {
            requirements = _lastLoadedRequirements.where((r) => !_isExpired(r)).toList();
            myAccepted = _lastMyAccepted.where((r) => !_isExpired(r)).toList();
            isLoadingMore = false;
          }

          final hasMyAccepted = myAccepted.isNotEmpty;

          // Build flat mixed list: requirements interleaved with banners
          final List<dynamic> items = [];
          if (hasMyAccepted) items.add('accepted_section');
          for (int i = 0; i < requirements.length; i++) {
            items.add(requirements[i]);
            // After every card insert a random banner
            if (_banners.isNotEmpty && (i + 1) % _bannerEvery == 0) {
              items.add({'_type': 'banner', 'banner': _randomBanner()!});
            }
          }
          if (isLoadingMore) items.add('loading');

          if (requirements.isEmpty && !hasMyAccepted) {
            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async => context.read<RequirementsBloc>().add(LoadRequirementsEvent()),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [SizedBox(height: MediaQuery.of(context).size.height * 0.35), _buildEmptyState()],
              ),
            );
          }
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async => context.read<RequirementsBloc>().add(LoadRequirementsEvent()),
            child: ListView.separated(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.only(left: 8.r, right: 8.r, top: 16.r, bottom: 140.h),
              itemCount: items.length,
              separatorBuilder: (_, __) => SizedBox(height: 16.h),
              itemBuilder: (context, index) {
                final item = items[index];
                if (item == 'accepted_section') {
                  return _buildMyAcceptedSection(myAccepted);
                }
                if (item == 'loading') {
                  return Center(child: Padding(
                    padding: EdgeInsets.all(16.r),
                    child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
                  ));
                }
                if (item is Map && item['_type'] == 'banner') {
                  return BannerCardWidget(banner: item['banner'] as Map<String, dynamic>, apiClient: _apiClient);
                }
                final req = item as Map<String, dynamic>;
                // Cards are display-only here — no navigation to the detail screen.
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
                    RequirementCardWidget(requirement: req),
                  ],
                );
              },
            ),
          );

          if (state is RequirementsError) {
            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async => context.read<RequirementsBloc>().add(LoadRequirementsEvent()),
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
                        onPressed: () => context.read<RequirementsBloc>().add(LoadRequirementsEvent()),
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
                'My Accepted Requirements',
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold, color: Colors.green[800]),
              ),
              SizedBox(width: 8.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(10.r), border: Border.all(color: Colors.green.shade300)),
                child: Text('${myAccepted.length}', style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.bold, color: Colors.green[700])),
              ),
            ],
          ),
        ),
        SizedBox(height: 4.h),
        ...myAccepted.map((req) => Padding(
          padding: EdgeInsets.only(bottom: 10.h),
          child: Stack(
            children: [
              RequirementCardWidget(
                requirement: req,
                onTap: () => context.push('/requirements/${req['_id']}', extra: req).then((result) {
                  if (result == true && mounted) {
                    context.read<RequirementsBloc>().add(const LoadRequirementsEvent());
                  }
                }),
              ),
            ],
          ),
        )),
        Divider(height: 1, thickness: 1, color: Colors.grey[300]),
        SizedBox(height: 8.h),
      ],
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
          Text('No requirements found', style: TextStyle(fontSize: 16.sp, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
          SizedBox(height: 8.h),
          Text('Be the first to post a requirement!', style: TextStyle(fontSize: 13.sp, color: AppColors.textHint)),
          SizedBox(height: 24.h),
          ElevatedButton.icon(
            onPressed: () => context.push('/requirements/create'),
            icon: const Icon(Icons.add),
            label: const Text('Post Requirement'),
          ),
        ],
      ),
    );
  }

  bool _isExpired(Map<String, dynamic> req) {
    try {
      final dateStr = req['travelDate'] as String?;
      if (dateStr == null) return false;
      // Keep the requirement visible for the WHOLE travel day (ignore the time
      // of day). Use only the date part so timezone never shifts the day.
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
    super.dispose();
  }
}
