import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import 'booking_card_ui.dart';

/// Shared "customer request" card, used by the Customer Rides page. A driver
/// taps Accept to register interest; an admin then assigns one accepted driver.
class CustomerRequestCard extends StatelessWidget {
  final Map<String, dynamic> booking;
  final VoidCallback onApply;
  /// Only Golden members can accept. When false, the card shows a
  /// "Golden membership required" note in place of the Accept button.
  final bool canAccept;
  const CustomerRequestCard(this.booking, {super.key, required this.onApply, this.canAccept = true});

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final service = kServiceNames[(b['serviceType'] ?? '').toString()] ?? 'Booking';
    final pickup = ((b['pickup'] as Map?)?['address'] ?? '').toString();
    final drop = ((b['drop'] as Map?)?['address'] ?? '').toString();
    final date = tripDate(b['travelDate']);
    final fare = b['estimatedFare'] ?? 0;
    final applied = b['alreadyApplied'] == true;
    final subType = (b['subType'] ?? '').toString();
    final status = (b['status'] ?? 'open').toString();
    final isOpen = status == 'open';
    // Confirmed/booked ones stay in the feed for 7 days (backend) with a stamp.
    final (String, Color)? stamp = switch (status) {
      'confirmed' || 'ongoing' => ('BOOKED', AppColors.primary),
      'completed' => ('COMPLETED', AppColors.success),
      'cancelled' => ('CANCELLED', AppColors.error),
      'expired' => ('EXPIRED', AppColors.textHint),
      _ => null,
    };

    // Round-trip return date is carried in notes as "Return date: dd-MM-yyyy".
    // Show only the number of days (under the ROUND TRIP chip).
    final rt = RegExp(r'Return date:\s*(\d{2})-(\d{2})-(\d{4})').firstMatch((b['notes'] ?? '').toString());
    final returnDate = rt != null ? DateTime(int.parse(rt.group(3)!), int.parse(rt.group(2)!), int.parse(rt.group(1)!)) : null;
    // Inclusive day count (25→26 = 2 days), consistent with the other screens.
    int? days = (returnDate != null && date != null)
        ? returnDate.difference(DateTime(date.year, date.month, date.day)).inDays + 1
        : null;
    if (days != null && days < 1) days = null;

    // Fare inclusions + round-trip extra-km terms, shown so the driver knows
    // exactly what's covered before accepting.
    final notes = (b['notes'] ?? '').toString();
    final isInclusive = RegExp(r'all\s*inclusive', caseSensitive: false).hasMatch(notes);
    final includedKm = (b['includedKm'] as num?)?.toInt() ?? 0;
    final extraKmPrice = (b['extraKmPrice'] as num?)?.toInt() ?? 0;
    // Local (in-city hourly package): show the package hours + extra ₹/hr.
    final isLocal = subType == 'Local';
    final packageHours = (b['packageHours'] as num?)?.toInt() ?? (b['durationHours'] as num?)?.toInt() ?? 0;
    final extraHourPrice = (b['extraHourPrice'] as num?)?.toInt() ?? 0;

    return brandCard(
      stamp: stamp?.$1,
      stampColor: stamp?.$2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(padding: EdgeInsets.only(top: 4.h), child: Icon(Icons.circle, size: 10.sp, color: AppColors.info)),
              SizedBox(width: 8.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text('CUSTOMER', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700, color: AppColors.info)),
                      SizedBox(width: 6.w),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.h),
                        decoration: BoxDecoration(color: AppColors.info.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4.r)),
                        child: Text('APP', style: TextStyle(fontSize: 8.sp, fontWeight: FontWeight.w800, color: AppColors.info)),
                      ),
                    ]),
                    Text(service, style: TextStyle(fontSize: 11.sp, color: Colors.grey[600], fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              if (subType.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    filledChip(subType.toUpperCase(), AppColors.primary),
                    if (days != null) ...[
                      SizedBox(height: 4.h),
                      Text('$days day${days == 1 ? '' : 's'}', style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                    ],
                    // Local: show the package hours under the LOCAL tag.
                    if (isLocal && packageHours > 0) ...[
                      SizedBox(height: 4.h),
                      Text('$packageHours hours', style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                    ],
                  ],
                ),
            ],
          ),
          SizedBox(height: 10.h),
          const Divider(height: 1, color: Colors.black26),
          SizedBox(height: 10.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: routeTimeline(pickup, drop)),
              SizedBox(width: 10.w),
              dateTimeBox(date, (b['travelTime'] ?? '').toString(), AppColors.primary),
            ],
          ),
          SizedBox(height: 4.h),
          const Divider(height: 1, color: Colors.black26),
          SizedBox(height: 10.h),
          Row(children: [
            if ((b['vehicleType'] ?? '').toString().isNotEmpty) ...[
              Icon(Icons.local_taxi_rounded, size: 15.sp, color: AppColors.primary),
              SizedBox(width: 5.w),
              Flexible(
                child: Text(
                  b['vehicleType'].toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.5.sp, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
              ),
            ],
            const Spacer(),
            if (fare != 0) Text('Budget: ₹$fare', style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          ]),
          // Fare inclusions/exclusions (one clean line, no boxed background).
          SizedBox(height: 10.h),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(isInclusive ? Icons.verified_rounded : Icons.info_outline_rounded,
                size: 15.sp, color: isInclusive ? AppColors.success : AppColors.warning),
            SizedBox(width: 6.w),
            Expanded(
              child: Text(
                isInclusive
                    ? 'All Inclusive — Toll, State tax, Car parking, Driver allowance & GST included'
                    : 'Best Price — Toll, state tax & parking excluded (collect from customer)',
                style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600,
                    color: isInclusive ? AppColors.success : AppColors.warning),
              ),
            ),
          ]),
          // Included-km / extra-km (+ extra ₹/hr for Local) — one clean line.
          if (includedKm > 0 || extraKmPrice > 0 || (isLocal && extraHourPrice > 0)) ...[
            SizedBox(height: 8.h),
            Wrap(spacing: 16.w, runSpacing: 6.h, children: [
              if (includedKm > 0) _kmInfo(Icons.speed_rounded, 'Included $includedKm km'),
              if (extraKmPrice > 0) _kmInfo(Icons.add_road_rounded, 'Extra ₹$extraKmPrice/km'),
              if (isLocal && extraHourPrice > 0) _kmInfo(Icons.more_time_rounded, 'Extra ₹$extraHourPrice/hr'),
            ]),
          ],
          // Accept only while still open; once booked the stamp says it all.
          // Everyone SEES the booking, but only Golden members can accept —
          // others get a "Golden membership required" note instead of the button.
          if (isOpen) ...[
            SizedBox(height: 12.h),
            if (canAccept)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: applied ? null : onApply,
                  icon: Icon(applied ? Icons.check_rounded : Icons.check_circle_rounded, size: 18.sp),
                  label: Text(applied ? 'Accepted' : 'Accept'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: applied ? AppColors.textHint : AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 11.h),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                  ),
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 11.h, horizontal: 12.w),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.workspace_premium_rounded, size: 18.sp, color: AppColors.warning),
                    SizedBox(width: 8.w),
                    Flexible(
                      child: Text(
                        'Golden membership required to accept',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12.5.sp, fontWeight: FontWeight.w700, color: AppColors.warning),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Included-km / extra-km-rate term — plain icon + text, no background.
Widget _kmInfo(IconData icon, String label) {
  return Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 14.sp, color: AppColors.textSecondary),
    SizedBox(width: 5.w),
    Text(label, style: TextStyle(fontSize: 11.5.sp, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
  ]);
}

/// Content for the "Accept this booking?" dialog. Accepting only registers your
/// interest — our team reviews everyone who accepted and assigns one driver.
/// Accepting is FREE; you only need a minimum wallet balance to be eligible (set
/// by admin). `pct`/`hold` are unused now, kept for call-site compatibility.
Widget acceptHoldContent(int fare, int pct, int hold) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        "You're accepting this booking${fare != 0 ? " (customer's budget ₹$fare)" : ''}. Our team will review everyone who accepted and assign one driver — you'll be notified if you're chosen.",
        style: TextStyle(fontSize: 13.sp, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
      ),
      SizedBox(height: 12.h),
      Container(
        padding: EdgeInsets.all(10.w),
        decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(10.r)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.verified_rounded, size: 16.sp, color: AppColors.success),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              'No commission and nothing is deducted on accept — if assigned, you collect the full fare directly from the customer.',
              style: TextStyle(fontSize: 12.5.sp, fontWeight: FontWeight.w700, color: AppColors.success),
            ),
          ),
        ]),
      ),
      SizedBox(height: 12.h),
      _holdPoint('Eligibility', 'You just need to keep a minimum wallet balance (set by admin) to accept bookings. It is only checked, never charged.'),
    ],
  );
}

Widget _holdPoint(String label, String body) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
      SizedBox(height: 2.h),
      Text(body, style: TextStyle(fontSize: 12.sp, color: AppColors.textSecondary, height: 1.35)),
    ],
  );
}

/// Centered accept dialog: the owner picks a vehicle + driver from their garage
/// (via dropdowns) before accepting a customer booking. Returns the selection
/// payload (vehicle + driver) to send with the accept call, or null if cancelled.
Future<Map<String, dynamic>?> showAcceptVehicleDriverSheet(BuildContext context, Map<String, dynamic> booking) {
  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (_) => Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
      child: _AcceptDialog(booking: booking),
    ),
  );
}

class _AcceptDialog extends StatefulWidget {
  final Map<String, dynamic> booking;
  const _AcceptDialog({required this.booking});

  @override
  State<_AcceptDialog> createState() => _AcceptDialogState();
}

class _AcceptDialogState extends State<_AcceptDialog> {
  final _api = getIt<ApiClient>();
  List<Map<String, dynamic>> _vehicles = [];
  List<Map<String, dynamic>> _drivers = [];
  Map<String, dynamic>? _vehicle;
  Map<String, dynamic>? _driver;
  bool _loading = true;
  String? _err;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final v = await _api.get('/garage');
      final d = await _api.get('/garage/drivers');
      List<Map<String, dynamic>> parse(dynamic raw) =>
          (raw as List? ?? []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      if (!mounted) return;
      setState(() {
        _vehicles = parse(v.data['data']);
        _drivers = parse(d.data['data']);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _err = '$e'; _loading = false; });
    }
  }

  String _vehicleLabel(Map<String, dynamic> v) {
    final name = (v['modelName'] ?? '').toString().trim();
    final type = (v['vehicleType'] ?? '').toString().trim();
    final base = name.isNotEmpty ? name : (type.isNotEmpty ? type : 'Vehicle');
    final reg = (v['registrationNumber'] ?? '').toString().trim();
    return reg.isNotEmpty ? '$base • $reg' : base;
  }

  String _driverLabel(Map<String, dynamic> d) {
    final name = (d['fullName'] ?? 'Driver').toString().trim();
    final phone = (d['phone'] ?? '').toString().trim();
    return phone.isNotEmpty ? '$name • $phone' : name;
  }

  @override
  Widget build(BuildContext context) {
    final fare = widget.booking['estimatedFare'] ?? 0;
    final canSubmit = _vehicle != null && _driver != null;
    final emptyGarage = !_loading && _err == null && (_vehicles.isEmpty || _drivers.isEmpty);

    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 16.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Accept this booking', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          SizedBox(height: 4.h),
          Text(
            fare != 0 ? "Choose the vehicle & driver for this trip (budget ₹$fare)." : 'Choose the vehicle & driver for this trip.',
            style: TextStyle(fontSize: 12.5.sp, color: AppColors.textSecondary),
          ),
          SizedBox(height: 18.h),
          if (_loading)
            const Padding(padding: EdgeInsets.symmetric(vertical: 28), child: Center(child: CircularProgressIndicator()))
          else if (_err != null)
            Text('Could not load your garage: $_err', style: TextStyle(fontSize: 12.5.sp, color: AppColors.error))
          else if (emptyGarage) ...[
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12.r)),
              child: Row(children: [
                Icon(Icons.info_outline_rounded, size: 18.sp, color: AppColors.warning),
                SizedBox(width: 10.w),
                Expanded(child: Text(
                  _vehicles.isEmpty && _drivers.isEmpty
                      ? 'Add at least one vehicle and one driver in My Garage first.'
                      : _vehicles.isEmpty ? 'Add at least one vehicle in My Garage first.' : 'Add at least one driver in My Garage first.',
                  style: TextStyle(fontSize: 12.5.sp, fontWeight: FontWeight.w600, color: AppColors.warning),
                )),
              ]),
            ),
            SizedBox(height: 14.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () { Navigator.pop(context); context.push('/my-vehicles-garage'); },
                icon: Icon(Icons.garage_rounded, size: 18.sp),
                label: const Text('Open My Garage'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, padding: EdgeInsets.symmetric(vertical: 12.h)),
              ),
            ),
          ] else ...[
            _label('Select Vehicle'),
            SizedBox(height: 6.h),
            _dropdown<Map<String, dynamic>>(
              hint: 'Choose a vehicle',
              icon: Icons.directions_car_rounded,
              value: _vehicle,
              items: _vehicles,
              labelFor: _vehicleLabel,
              onChanged: (v) => setState(() => _vehicle = v),
            ),
            SizedBox(height: 16.h),
            _label('Select Driver'),
            SizedBox(height: 6.h),
            _dropdown<Map<String, dynamic>>(
              hint: 'Choose a driver',
              icon: Icons.person_rounded,
              value: _driver,
              items: _drivers,
              labelFor: _driverLabel,
              onChanged: (d) => setState(() => _driver = d),
            ),
            SizedBox(height: 20.h),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 12.h), side: const BorderSide(color: AppColors.border)),
                  child: Text('Cancel', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: canSubmit
                      ? () {
                          final v = _vehicle!;
                          final d = _driver!;
                          final photos = (v['carPhotos'] as List?)?.whereType<String>().toList() ?? const [];
                          final name = (v['modelName'] ?? '').toString().trim();
                          final type = (v['vehicleType'] ?? '').toString().trim();
                          Navigator.pop(context, {
                            'vehicle': name.isNotEmpty ? name : type,
                            'vehicleNumber': (v['registrationNumber'] ?? '').toString(),
                            if (photos.isNotEmpty) 'vehicleImage': photos.first,
                            'driverName': (d['fullName'] ?? '').toString(),
                            'driverPhone': (d['phone'] ?? '').toString(),
                          });
                        }
                      : null,
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, padding: EdgeInsets.symmetric(vertical: 12.h), disabledBackgroundColor: AppColors.textHint),
                  child: Text('Accept', style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _label(String t) => Text(t, style: TextStyle(fontSize: 13.5.sp, fontWeight: FontWeight.w800, color: AppColors.textPrimary));

  Widget _dropdown<T>({
    required String hint,
    required IconData icon,
    required T? value,
    required List<T> items,
    required String Function(T) labelFor,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary),
          hint: Row(children: [
            Icon(icon, size: 18.sp, color: AppColors.textSecondary),
            SizedBox(width: 8.w),
            Text(hint, style: TextStyle(fontSize: 13.sp, color: AppColors.textSecondary)),
          ]),
          items: items
              .map((e) => DropdownMenuItem<T>(
                    value: e,
                    child: Row(children: [
                      Icon(icon, size: 18.sp, color: AppColors.primary),
                      SizedBox(width: 8.w),
                      Expanded(child: Text(labelFor(e), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
                    ]),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
