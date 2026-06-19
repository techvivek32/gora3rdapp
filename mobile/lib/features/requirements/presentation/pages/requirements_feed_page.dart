import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../bloc/requirements_bloc.dart';
import '../widgets/requirement_card_widget.dart';
import '../widgets/requirements_filter_sheet.dart';

class RequirementsFeedPage extends StatefulWidget {
  const RequirementsFeedPage({super.key});

  @override
  State<RequirementsFeedPage> createState() => _RequirementsFeedPageState();
}

class _RequirementsFeedPageState extends State<RequirementsFeedPage> {
  final _scrollController = ScrollController();
  String _searchQuery = '';
  List<Map<String, dynamic>> _lastLoadedRequirements = [];
  List<Map<String, dynamic>> _lastMyAccepted = [];
  bool _lastHasMore = false;

  @override
  void initState() {
    super.initState();
    context.read<RequirementsBloc>().add(LoadRequirementsEvent());
    _scrollController.addListener(_onScroll);
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
            icon: Icon(Icons.filter_list_rounded, color: Colors.white),
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24.r))),
              builder: (_) => RequirementsFilterSheet(
                initialFilters: const {},
                onApply: (filters) => context.read<RequirementsBloc>().add(FilterRequirementsEvent(filters: filters)),
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.add, color: Colors.white, size: 28.sp),
            onPressed: () => context.push('/requirements/create'),
          ),
        ],
      ),
      body: BlocBuilder<RequirementsBloc, RequirementsState>(
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
            myAccepted = state.myAccepted;
            isLoadingMore = state.isLoadingMore;
          } else {
            requirements = _lastLoadedRequirements.where((r) => !_isExpired(r)).toList();
            myAccepted = _lastMyAccepted;
            isLoadingMore = false;
          }

          final hasMyAccepted = myAccepted.isNotEmpty;
          final headerOffset = hasMyAccepted ? 1 : 0;

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
              padding: EdgeInsets.only(left: 16.r, right: 16.r, top: 16.r, bottom: 140.h),
              itemCount: requirements.length + headerOffset + (isLoadingMore ? 1 : 0),
              separatorBuilder: (_, __) => SizedBox(height: 16.h),
              itemBuilder: (context, index) {
                if (hasMyAccepted && index == 0) {
                  return _buildMyAcceptedSection(myAccepted);
                }
                final reqIndex = index - headerOffset;
                if (reqIndex == requirements.length) {
                  return Center(child: Padding(
                    padding: EdgeInsets.all(16.r),
                    child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
                  ));
                }
                return RequirementCardWidget(
                  requirement: requirements[reqIndex],
                  onTap: () => context.push(
                    '/requirements/${requirements[reqIndex]['_id']}',
                    extra: requirements[reqIndex],
                  ).then((result) {
                    if (result == true && mounted) {
                      context.read<RequirementsBloc>().add(LoadRequirementsEvent());
                    }
                  }),
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
      final timeStr = (req['travelTime'] as String?) ?? '00:00';
      if (dateStr == null) return false;
      final d = DateTime.parse(dateStr);
      final timeParts = timeStr.split(':');
      final h = int.tryParse(timeParts[0]) ?? 0;
      final m = timeParts.length > 1 ? (int.tryParse(timeParts[1]) ?? 0) : 0;
      final departure = DateTime(d.year, d.month, d.day, h, m);
      return departure.isBefore(DateTime.now());
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
