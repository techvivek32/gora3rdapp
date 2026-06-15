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
          if (state is RequirementsLoading) {
            return _buildLoadingList();
          }

          if (state is RequirementsLoaded) {
            if (state.requirements.isEmpty) {
              return _buildEmptyState();
            }
            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async {
                context.read<RequirementsBloc>().add(LoadRequirementsEvent());
              },
              child: ListView.separated(
                controller: _scrollController,
                padding: EdgeInsets.all(16.r),
                itemCount: state.requirements.length + (state.isLoadingMore ? 1 : 0),
                separatorBuilder: (_, __) => SizedBox(height: 16.h),
                itemBuilder: (context, index) {
                  if (index == state.requirements.length) {
                    return Center(child: Padding(
                      padding: EdgeInsets.all(16.r),
                      child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
                    ));
                  }
                  return RequirementCardWidget(
                    requirement: state.requirements[index],
                    onTap: () => context.push('/requirements/${state.requirements[index]['_id']}'),
                  );
                },
              ),
            );
          }

          if (state is RequirementsError) {
            return Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48.sp, color: AppColors.error),
                SizedBox(height: 16.h),
                Text(state.message, style: TextStyle(color: AppColors.textSecondary)),
                SizedBox(height: 16.h),
                ElevatedButton(
                  onPressed: () => context.read<RequirementsBloc>().add(LoadRequirementsEvent()),
                  child: const Text('Retry'),
                ),
              ],
            ));
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

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
