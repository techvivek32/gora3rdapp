import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../bloc/requirements_bloc.dart';
import '../widgets/requirement_card_widget.dart';
import '../widgets/cancel_reason_sheet.dart';

class MyRequirementsPage extends StatefulWidget {
  const MyRequirementsPage({super.key});

  @override
  State<MyRequirementsPage> createState() => _MyRequirementsPageState();
}

class _MyRequirementsPageState extends State<MyRequirementsPage> {
  @override
  void initState() {
    super.initState();
    if (context.read<RequirementsBloc>().state is! MyRequirementsLoaded) {
      context.read<RequirementsBloc>().add(const LoadMyRequirementsEvent());
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(
            'My Requirements',
            style: TextStyle(fontFamily: 'Poppins', fontSize: 17.sp, fontWeight: FontWeight.bold),
          ),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: Container(
              color: Colors.white,
              child: const TabBar(
                indicatorColor: AppColors.primary,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textHint,
                labelStyle: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold),
                tabs: [
                  Tab(text: 'Running'),
                  Tab(text: 'Booked'),
                ],
              ),
            ),
          ),
        ),
        body: BlocConsumer<RequirementsBloc, RequirementsState>(
          listener: (context, state) {
            if (state is RequirementCancelled) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Requirement cancelled'), backgroundColor: AppColors.success),
              );
              context.read<RequirementsBloc>().add(const LoadMyRequirementsEvent());
            }
            if (state is RequirementsError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.message), backgroundColor: AppColors.error),
              );
            }
          },
          buildWhen: (prev, curr) =>
              curr is RequirementsLoading ||
              curr is MyRequirementsLoaded ||
              curr is RequirementsError,
          builder: (context, state) {
            if (state is RequirementsLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state is RequirementsError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 48.sp, color: AppColors.error),
                    SizedBox(height: 12.h),
                    Text(state.message, style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Poppins', fontSize: 14.sp)),
                    SizedBox(height: 16.h),
                    ElevatedButton(
                      onPressed: () => context.read<RequirementsBloc>().add(const LoadMyRequirementsEvent()),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }

            if (state is MyRequirementsLoaded) {
              final running = state.requirements.where((r) => r['status'] != 'accepted').toList();
              final booked = state.requirements.where((r) => r['status'] == 'accepted').toList();
              return TabBarView(
                children: [
                  _buildList(context, running, 'No running requirements', showMenu: true),
                  _buildList(context, booked, 'No booked requirements'),
                ],
              );
            }

            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, List<Map<String, dynamic>> items, String emptyText, {bool showMenu = false}) {
    return RefreshIndicator(
      onRefresh: () async {
        context.read<RequirementsBloc>().add(const LoadMyRequirementsEvent());
        await Future.delayed(const Duration(milliseconds: 500));
      },
      child: items.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(height: 0.3.sh),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.post_add_outlined, size: 64.sp, color: AppColors.textHint),
                      SizedBox(height: 12.h),
                      Text(emptyText, style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Poppins', fontSize: 15.sp)),
                    ],
                  ),
                ),
              ],
            )
          : ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final req = items[index];
                return Padding(
                  padding: EdgeInsets.only(bottom: 12.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Actions menu (Running tab only; not for cancelled ones).
                      if (showMenu && req['status'] != 'cancelled')
                        Align(
                          alignment: Alignment.centerRight,
                          child: _buildMenu(context, req),
                        ),
                      // Cards are display-only — no navigation to the detail screen.
                      RequirementCardWidget(requirement: req),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildMenu(BuildContext context, Map<String, dynamic> req) {
    final isHeld = req['status'] == 'on_hold';
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
      onSelected: (value) => _onMenuAction(context, value, req),
      itemBuilder: (_) => [
        _menuItem('edit', Icons.edit_outlined, 'Edit'),
        _menuItem('booked', Icons.check_circle_outline, 'Booked'),
        _menuItem(isHeld ? 'unhold' : 'hold', isHeld ? Icons.play_circle_outline : Icons.pause_circle_outline, isHeld ? 'Unhold' : 'Hold'),
        _menuItem('cancel', Icons.cancel_outlined, 'Cancel', color: AppColors.error),
      ],
    );
  }

  PopupMenuItem<String> _menuItem(String value, IconData icon, String label, {Color? color}) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 20.sp, color: color ?? AppColors.textSecondary),
          SizedBox(width: 10.w),
          Text(label, style: TextStyle(fontFamily: 'Poppins', fontSize: 14.sp, color: color ?? AppColors.textPrimary)),
        ],
      ),
    );
  }

  void _onMenuAction(BuildContext context, String action, Map<String, dynamic> req) {
    final id = req['_id'] as String;
    final bloc = context.read<RequirementsBloc>();
    switch (action) {
      case 'edit':
        context.push('/requirements/$id/edit', extra: req);
        break;
      case 'booked':
        bloc.add(SetRequirementStatusEvent(id: id, status: 'accepted'));
        break;
      case 'hold':
        bloc.add(SetRequirementStatusEvent(id: id, status: 'on_hold'));
        break;
      case 'unhold':
        bloc.add(SetRequirementStatusEvent(id: id, status: 'active'));
        break;
      case 'cancel':
        CancelReasonSheet.show(context, onConfirm: (reason) {
          Navigator.pop(context); // close the reason sheet
          bloc.add(CancelRequirementEvent(id: id, reason: reason));
        });
        break;
    }
  }
}
