import 'package:flutter/material.dart';
import '../../../../core/constants/vehicle_types.dart';

class VehiclesFilterSheet extends StatefulWidget {
  final Map<String, dynamic> initialFilters;
  final ValueChanged<Map<String, dynamic>> onApply;
  const VehiclesFilterSheet({super.key, required this.initialFilters, required this.onApply});

  @override
  State<VehiclesFilterSheet> createState() => _VehiclesFilterSheetState();
}

class _VehiclesFilterSheetState extends State<VehiclesFilterSheet> {
  String? _vehicleType;
  final _cityCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _vehicleType = widget.initialFilters['vehicleType'] as String?;
    _cityCtrl.text = (widget.initialFilters['currentCity'] as String?) ?? '';
  }

  @override
  void dispose() {
    _cityCtrl.dispose();
    super.dispose();
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
                const Text('Filter Cabs', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                TextButton(
                  onPressed: () => setState(() {
                    _vehicleType = null;
                    _cityCtrl.clear();
                  }),
                  child: const Text('Clear All'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Current City', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _cityCtrl,
              decoration: InputDecoration(
                hintText: 'e.g. Ahmedabad',
                prefixIcon: const Icon(Icons.location_on_outlined),
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Vehicle Type', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: kVehicleTypes.map((v) => FilterChip(
                    label: Text(v['label']!, style: const TextStyle(fontSize: 11)),
                    selected: _vehicleType == v['value'],
                    onSelected: (_) => setState(() => _vehicleType = _vehicleType == v['value'] ? null : v['value']),
                  )).toList(),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  widget.onApply({
                    if (_vehicleType != null) 'vehicleType': _vehicleType!,
                    if (_cityCtrl.text.trim().isNotEmpty) 'currentCity': _cityCtrl.text.trim(),
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
