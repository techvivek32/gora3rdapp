import 'package:flutter/material.dart';
import '../../../../core/constants/vehicle_types.dart';

class RequirementsFilterSheet extends StatefulWidget {
  final Map<String, dynamic> initialFilters;
  final ValueChanged<Map<String, dynamic>> onApply;
  const RequirementsFilterSheet({super.key, required this.initialFilters, required this.onApply});

  @override
  State<RequirementsFilterSheet> createState() => _RequirementsFilterSheetState();
}

class _RequirementsFilterSheetState extends State<RequirementsFilterSheet> {
  late String? _vehicleType;
  late String? _tripType;
  late String? _status;

  final _vehicleTypes = kVehicleTypes;
  final _tripTypes = ['one_way', 'round_trip', 'airport_transfer', 'local', 'outstation'];
  final _statuses = ['pending', 'accepted', 'completed', 'cancelled', 'expired'];

  @override
  void initState() {
    super.initState();
    _vehicleType = widget.initialFilters['vehicleType'] as String?;
    _tripType = widget.initialFilters['tripType'] as String?;
    _status = widget.initialFilters['status'] as String?;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Filter Requirements', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                TextButton(
                  onPressed: () => setState(() { _vehicleType = null; _tripType = null; _status = null; }),
                  child: const Text('Clear All'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Vehicle Type', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _vehicleTypes.map((v) => FilterChip(
                label: Text(v['label']!, style: const TextStyle(fontSize: 11)),
                selected: _vehicleType == v['value'],
                onSelected: (_) => setState(() => _vehicleType = _vehicleType == v['value'] ? null : v['value']),
              )).toList(),
            ),
            const SizedBox(height: 16),
            const Text('Trip Type', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _tripTypes.map((t) => FilterChip(
                label: Text(t.replaceAll('_', ' ').toUpperCase(), style: const TextStyle(fontSize: 11)),
                selected: _tripType == t,
                onSelected: (_) => setState(() => _tripType = _tripType == t ? null : t),
              )).toList(),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  widget.onApply({
                    if (_vehicleType != null) 'vehicleType': _vehicleType!,
                    if (_tripType != null) 'tripType': _tripType!,
                    if (_status != null) 'status': _status!,
                  });
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                child: const Text('Apply Filters', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
