import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
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
      appBar: AppBar(
        title: TextField(
          controller: _searchCtrl,
          decoration: InputDecoration(
            hintText: 'Search by city...',
            border: InputBorder.none,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchCtrl.text.isNotEmpty
                ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchCtrl.clear(); context.read<VehiclesBloc>().add(const LoadVehiclesEvent()); })
                : null,
          ),
          onSubmitted: (v) => context.read<VehiclesBloc>().add(LoadVehiclesEvent(filters: {'search': v})),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {},
          ),
        ],
      ),
      body: BlocBuilder<VehiclesBloc, VehiclesState>(
        builder: (context, state) {
          if (state is VehiclesLoading) return const Center(child: CircularProgressIndicator());
          if (state is VehiclesError) return Center(child: Text(state.message));
          if (state is VehiclesLoaded) {
            if (state.vehicles.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.local_taxi_outlined, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('No vehicles available', style: TextStyle(fontSize: 18, color: Colors.grey)),
                    SizedBox(height: 8),
                    Text('Be the first to post your available cab', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              );
            }
            return RefreshIndicator(
              onRefresh: () async => context.read<VehiclesBloc>().add(const LoadVehiclesEvent()),
              child: ListView.separated(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: state.vehicles.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) => _VehicleCard(vehicle: state.vehicles[i]),
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/vehicles/create'),
        icon: const Icon(Icons.add),
        label: const Text('Post Vehicle'),
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
    final statusColor = status == 'available' ? Colors.green : Colors.grey;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    vehicle['listingId'] as String? ?? '',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(status.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.green, size: 16),
                const SizedBox(width: 4),
                Expanded(child: Text('${vehicle['currentCity']} → ${vehicle['destinationCity'] ?? 'Any'}',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15))),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.directions_car, color: Colors.grey.shade500, size: 16),
                const SizedBox(width: 4),
                Text((vehicle['vehicleType'] as String? ?? '').toUpperCase(),
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                const SizedBox(width: 16),
                Icon(Icons.badge_outlined, color: Colors.grey.shade500, size: 16),
                const SizedBox(width: 4),
                Text(vehicle['vehicleNumber'] as String? ?? '', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.person_outline, color: Colors.grey.shade500, size: 16),
                const SizedBox(width: 4),
                Text(vehicle['driverName'] as String? ?? '', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                const Spacer(),
                Icon(Icons.calendar_today_outlined, color: Colors.grey.shade500, size: 14),
                const SizedBox(width: 4),
                Text(vehicle['availableDate'] as String? ?? '', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
