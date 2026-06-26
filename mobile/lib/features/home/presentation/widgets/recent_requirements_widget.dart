import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/vehicle_types.dart';

class RecentRequirementsWidget extends StatelessWidget {
  final List<Map<String, dynamic>> requirements;
  const RecentRequirementsWidget({super.key, required this.requirements});

  @override
  Widget build(BuildContext context) {
    if (requirements.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Recent Requirements', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              GestureDetector(
                onTap: () => context.go('/requirements'),
                child: Text('See All', style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: requirements.length,
          itemBuilder: (_, i) => _RecentCard(req: requirements[i]),
        ),
      ],
    );
  }
}

class _RecentCard extends StatelessWidget {
  final Map<String, dynamic> req;
  const _RecentCard({required this.req});

  static const _tripColors = {
    'one_way': Colors.blue,
    'round_trip': Colors.green,
    'airport_transfer': Colors.purple,
    'local': Colors.orange,
    'outstation': Colors.teal,
  };

  @override
  Widget build(BuildContext context) {
    final tripType = req['tripType'] as String? ?? 'one_way';
    final color = _tripColors[tripType] ?? Colors.grey;

    return GestureDetector(
      onTap: () => context.push('/requirements/${req['_id']}'),
      child: Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                child: Text(
                  tripType.replaceAll('_', ' ').toUpperCase(),
                  style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${req['pickupCity']} → ${req['dropCity']}',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(vehicleTypeLabel(req['vehicleType'] as String?), style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}
