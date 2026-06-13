import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../bloc/requirements_bloc.dart';

class RequirementDetailPage extends StatefulWidget {
  final String requirementId;
  const RequirementDetailPage({super.key, required this.requirementId});

  @override
  State<RequirementDetailPage> createState() => _RequirementDetailPageState();
}

class _RequirementDetailPageState extends State<RequirementDetailPage> {
  Map<String, dynamic>? _requirement;

  @override
  void initState() {
    super.initState();
    context.read<RequirementsBloc>().add(LoadRequirementDetailEvent(widget.requirementId));
  }

  static const _tripColors = {
    'one_way': Colors.blue,
    'round_trip': Colors.green,
    'airport_transfer': Colors.purple,
    'local': Colors.orange,
    'outstation': Colors.teal,
  };

  Widget _infoRow(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocConsumer<RequirementsBloc, RequirementsState>(
        listener: (context, state) {
          if (state is RequirementDetailLoaded) setState(() => _requirement = state.requirement);
        },
        builder: (context, state) {
          if (state is RequirementsLoading) return const Center(child: CircularProgressIndicator());
          if (_requirement == null) return const Center(child: CircularProgressIndicator());

          final req = _requirement!;
          final tripType = req['tripType'] as String? ?? 'one_way';
          final color = _tripColors[tripType] ?? Colors.grey;
          final postedBy = req['postedBy'] as Map<String, dynamic>?;
          final isPremiumUser = postedBy != null && postedBy['mobile'] != null;

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 120,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(req['bookingId'] as String? ?? '', style: const TextStyle(fontSize: 14)),
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [color.withOpacity(0.8), color]),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('From', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                        Text(req['pickupCity'] as String? ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                        Text(req['pickupState'] as String? ?? '', style: TextStyle(color: Colors.grey.shade600)),
                                      ],
                                    ),
                                  ),
                                  Icon(Icons.arrow_forward, color: color, size: 28),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        const Text('To', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                        Text(req['dropCity'] as String? ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                        Text(req['dropState'] as String? ?? '', style: TextStyle(color: Colors.grey.shade600)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 24),
                              _infoRow(Icons.directions_car, 'Vehicle Type', (req['vehicleType'] as String? ?? '').toUpperCase()),
                              _infoRow(Icons.confirmation_number_outlined, 'Number of Vehicles', '${req['numberOfVehicles'] ?? 1}'),
                              _infoRow(Icons.calendar_today_outlined, 'Travel Date', req['travelDate'] as String? ?? ''),
                              _infoRow(Icons.access_time, 'Travel Time', req['travelTime'] as String? ?? ''),
                              if (req['estimatedDistance'] != null)
                                _infoRow(Icons.route_outlined, 'Distance', '${req['estimatedDistance']} km'),
                              if (req['notes'] != null && (req['notes'] as String).isNotEmpty)
                                _infoRow(Icons.notes, 'Notes', req['notes'] as String),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Posted By', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundImage: postedBy?['profileImage'] != null
                                        ? NetworkImage(postedBy!['profileImage'] as String)
                                        : null,
                                    child: postedBy?['profileImage'] == null ? const Icon(Icons.person) : null,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(postedBy?['fullName'] as String? ?? 'Hidden', style: const TextStyle(fontWeight: FontWeight.w600)),
                                        if (postedBy?['agencyName'] != null)
                                          Text(postedBy!['agencyName'] as String, style: TextStyle(color: Colors.grey.shade600)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (!isPremiumUser) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.amber.shade200),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.lock_outline, color: Colors.amber.shade700),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('Contact Locked', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber.shade800)),
                                            const Text('Upgrade to Premium to view contact details', style: TextStyle(fontSize: 12)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: () => context.push('/subscriptions'),
                                    icon: const Icon(Icons.star, color: Colors.amber),
                                    label: const Text('Upgrade to Premium'),
                                  ),
                                ),
                              ] else ...[
                                const SizedBox(height: 12),
                                if (postedBy!['mobile'] != null)
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: () {},
                                      icon: const Icon(Icons.call),
                                      label: Text('Call ${postedBy['mobile']}'),
                                    ),
                                  ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: _requirement != null
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton.icon(
                  onPressed: () => context.read<RequirementsBloc>().add(AcceptRequirementEvent(widget.requirementId)),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Accept Requirement', style: TextStyle(fontSize: 16)),
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                ),
              ),
            )
          : null,
    );
  }
}
