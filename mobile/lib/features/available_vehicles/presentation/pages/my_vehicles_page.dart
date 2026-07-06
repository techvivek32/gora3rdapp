import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../bloc/vehicles_bloc.dart';
import 'vehicles_feed_page.dart';

class MyVehiclesPage extends StatefulWidget {
  const MyVehiclesPage({super.key});

  @override
  State<MyVehiclesPage> createState() => _MyVehiclesPageState();
}

class _MyVehiclesPageState extends State<MyVehiclesPage> {
  @override
  void initState() {
    super.initState();
    context.read<VehiclesBloc>().add(const LoadMyVehiclesEvent());
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text('My Vehicles', style: TextStyle(fontFamily: 'Poppins', fontSize: 17.sp, fontWeight: FontWeight.bold)),
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
                tabs: [Tab(text: 'Running'), Tab(text: 'Booked')],
              ),
            ),
          ),
        ),
        body: BlocConsumer<VehiclesBloc, VehiclesState>(
          listener: (context, state) {
            if (state is VehicleCancelled) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Vehicle cancelled'), backgroundColor: AppColors.success),
              );
              context.read<VehiclesBloc>().add(const LoadMyVehiclesEvent());
            }
            if (state is VehicleUpdated) {
              context.read<VehiclesBloc>().add(const LoadMyVehiclesEvent());
            }
            if (state is VehiclesError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.message), backgroundColor: AppColors.error),
              );
            }
          },
          buildWhen: (p, c) => c is VehiclesLoading || c is MyVehiclesLoaded || c is VehiclesError,
          builder: (context, state) {
            if (state is VehiclesLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state is VehiclesError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 48.sp, color: AppColors.error),
                    SizedBox(height: 12.h),
                    Text(state.message, style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Poppins')),
                    SizedBox(height: 16.h),
                    ElevatedButton(
                      onPressed: () => context.read<VehiclesBloc>().add(const LoadMyVehiclesEvent()),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }
            if (state is MyVehiclesLoaded) {
              // Cancelled listings show under Booked (not Running).
              final running = state.vehicles
                  .where((v) => v['status'] != 'booked' && v['status'] != 'cancelled')
                  .toList();
              final booked = state.vehicles
                  .where((v) => v['status'] == 'booked' || v['status'] == 'cancelled')
                  .toList();
              return TabBarView(
                children: [
                  _buildList(context, running, 'No running vehicles', showMenu: true),
                  _buildList(context, booked, 'No booked vehicles'),
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
        context.read<VehiclesBloc>().add(const LoadMyVehiclesEvent());
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
                      Icon(Icons.local_taxi_outlined, size: 64.sp, color: AppColors.textHint),
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
                final v = items[index];
                final menu = (showMenu && v['status'] != 'cancelled') ? _buildMenu(context, v) : null;
                return Padding(
                  padding: EdgeInsets.only(bottom: 12.h),
                  child: VehicleCard(vehicle: v, menu: menu, mine: true),
                );
              },
            ),
    );
  }

  Widget _buildMenu(BuildContext context, Map<String, dynamic> v) {
    final isHeld = v['status'] == 'on_hold';
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
      padding: EdgeInsets.zero,
      tooltip: 'Options',
      constraints: BoxConstraints(minWidth: 160.w),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
      onSelected: (value) => _onMenuAction(context, value, v),
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

  void _onMenuAction(BuildContext context, String action, Map<String, dynamic> v) {
    final id = v['_id'] as String;
    final bloc = context.read<VehiclesBloc>();
    switch (action) {
      case 'edit':
        context.push('/vehicles/$id/edit', extra: v);
        break;
      case 'booked':
        bloc.add(SetVehicleStatusEvent(id: id, status: 'booked'));
        break;
      case 'hold':
        bloc.add(SetVehicleStatusEvent(id: id, status: 'on_hold'));
        break;
      case 'unhold':
        bloc.add(SetVehicleStatusEvent(id: id, status: 'available'));
        break;
      case 'cancel':
        bloc.add(CancelVehicleEvent(id: id, reason: ''));
        break;
    }
  }
}
