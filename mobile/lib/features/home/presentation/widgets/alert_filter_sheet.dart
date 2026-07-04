import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/constants/vehicle_types.dart';
import '../../../../core/theme/app_theme.dart';

const _tripTypes = ['one_way', 'round_trip', 'airport_transfer', 'local', 'outstation'];

String _tripLabel(String v) => v.replaceAll('_', ' ').split(' ').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');

/// Shows the alert-filter chooser. Returns `{vehicles: [...], trips: [...]}` on
/// Save, or `null` if the user dismissed it (so the toggle stays off).
Future<Map<String, List<String>>?> showAlertFilterSheet(
  BuildContext context, {
  List<String> initialVehicles = const [],
  List<String> initialTrips = const [],
}) {
  return showModalBottomSheet<Map<String, List<String>>>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true, // cover the bottom nav bar + center FAB so nothing overlaps
    backgroundColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20.r))),
    builder: (_) => _AlertFilterSheet(initialVehicles: initialVehicles, initialTrips: initialTrips),
  );
}

class _AlertFilterSheet extends StatefulWidget {
  final List<String> initialVehicles;
  final List<String> initialTrips;
  const _AlertFilterSheet({required this.initialVehicles, required this.initialTrips});

  @override
  State<_AlertFilterSheet> createState() => _AlertFilterSheetState();
}

class _AlertFilterSheetState extends State<_AlertFilterSheet> {
  late final Set<String> _vehicles = widget.initialVehicles.toSet();
  late final Set<String> _trips = widget.initialTrips.toSet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.82),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 10.h),
            Container(width: 42.w, height: 4.h, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(4.r))),
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 4.h),
              child: Row(
                children: [
                  Icon(Icons.filter_alt_rounded, color: AppColors.primary, size: 22.sp),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text('My Alert', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Text(
                'You will only get alerts for the vehicle and ride types you pick. Leave a section empty to get all of them.',
                style: TextStyle(fontSize: 12.sp, color: AppColors.textSecondary, fontFamily: 'Poppins'),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 8.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionHeader('Ride Type', _trips.length, () => setState(_trips.clear)),
                    SizedBox(height: 8.h),
                    Wrap(
                      spacing: 8.w,
                      runSpacing: 8.h,
                      children: _tripTypes.map((t) => _chip(_tripLabel(t), _trips.contains(t), (sel) {
                            setState(() => sel ? _trips.add(t) : _trips.remove(t));
                          })).toList(),
                    ),
                    SizedBox(height: 20.h),
                    _sectionHeader('Vehicle Types', _vehicles.length, () => setState(_vehicles.clear)),
                    SizedBox(height: 8.h),
                    Wrap(
                      spacing: 8.w,
                      runSpacing: 8.h,
                      children: kVehicleTypes.map((v) => _chip(v['label']!, _vehicles.contains(v['value']), (sel) {
                            setState(() => sel ? _vehicles.add(v['value']!) : _vehicles.remove(v['value']));
                          })).toList(),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 16.h),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, {'vehicles': _vehicles.toList(), 'trips': _trips.toList()}),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                  ),
                  child: Text('Save & Turn On Alerts', style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, int count, VoidCallback onClear) {
    return Row(
      children: [
        Text(title, style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700, fontFamily: 'Poppins')),
        SizedBox(width: 6.w),
        if (count > 0)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 1.h),
            decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(20.r)),
            child: Text('$count', style: TextStyle(fontSize: 10.sp, color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        const Spacer(),
        if (count > 0)
          GestureDetector(
            onTap: onClear,
            child: Text('Clear', style: TextStyle(fontSize: 12.sp, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          ),
      ],
    );
  }

  Widget _chip(String label, bool selected, ValueChanged<bool> onSelected) {
    return FilterChip(
      label: Text(label, style: TextStyle(fontSize: 12.sp, color: selected ? Colors.white : AppColors.textPrimary, fontFamily: 'Poppins')),
      selected: selected,
      onSelected: onSelected,
      showCheckmark: false,
      backgroundColor: Colors.grey[100],
      selectedColor: AppColors.primary,
      side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
    );
  }
}
