import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/customer_repository.dart';

/// Booking review / confirmation screen. Shown after the customer taps "Book Now"
/// on the cab-results screen — it lists the full trip + fare details, and only
/// posts the booking when "Confirm Booking" is tapped.
class CabConfirmPage extends StatefulWidget {
  final Map<String, dynamic> data;
  const CabConfirmPage({super.key, required this.data});

  @override
  State<CabConfirmPage> createState() => _CabConfirmPageState();
}

class _CabConfirmPageState extends State<CabConfirmPage> {
  bool _busy = false;
  // Per-cab info tabs come from the selected cab (admin-set on each category).
  int _infoTab = 0;
  static const _tabs = [
    ('Inclusions', 'inclusions'),
    ('Exclusions', 'exclusions'),
    ('Facilities', 'facilities'),
    ('T&C', 'terms'),
  ];

  List<String> _infoList(String key) => ((_cat[key] as List?) ?? []).map((e) => e.toString()).toList();
  bool get _hasAnyInfo => _tabs.any((t) => _infoList(t.$2).isNotEmpty);

  Map<String, dynamic> get _trip => Map<String, dynamic>.from(widget.data['trip'] as Map? ?? {});
  Map<String, dynamic> get _cat => Map<String, dynamic>.from(widget.data['cat'] as Map? ?? {});
  String get _fuel => (widget.data['fuel'] ?? 'Petrol').toString();
  double get _distanceKm => (widget.data['distanceKm'] as num?)?.toDouble() ?? 0;
  // Distance the fare is billed on (>= category minimum) and the minimum itself.
  double get _billedKm => (widget.data['billedKm'] as num?)?.toDouble() ?? _distanceKm;
  double get _minKm => (widget.data['minKm'] as num?)?.toDouble() ?? 0;
  bool get _isMinApplied => _minKm > 0 && _distanceKm < _minKm;
  int get _fare => (widget.data['fare'] as num?)?.toInt() ?? 0;
  bool get _isRound => widget.data['isRound'] == true;
  String get _editId => (widget.data['bookingId'] ?? '').toString();
  bool get _isEdit => _editId.isNotEmpty;
  List<String> get _inclusions => ((widget.data['inclusions'] as List?) ?? []).map((e) => e.toString()).toList();
  int get _toll => (widget.data['toll'] as num?)?.toInt() ?? 0;
  int get _baseFare => (widget.data['baseFare'] as num?)?.toInt() ?? _fare;
  String get _incMode => (widget.data['incMode'] ?? 'All Inclusive').toString();
  bool get _isBestPrice => _incMode == 'Best Price';

  String _cityOf(String cityKey, String addrKey) {
    final t = _trip;
    final city = (t[cityKey] ?? '').toString().trim();
    if (city.isNotEmpty) return city;
    final addr = ((t[addrKey] as Map?)?['address'] ?? '').toString().trim();
    return addr.isEmpty ? '—' : addr;
  }

  Future<void> _confirm() async {
    if (_busy) return;
    setState(() => _busy = true);
    final t = _trip;
    final notes = <String>[];
    if (t['notes'] != null && (t['notes'] as String).isNotEmpty) notes.add(t['notes'].toString());
    notes.add('Fuel: $_fuel');
    if (_isBestPrice) {
      notes.add('Best Price — toll/tax/parking paid directly by rider');
    } else {
      if (_toll > 0) notes.add('Toll included (auto): ₹$_toll');
      if (_inclusions.isNotEmpty) notes.add('All Inclusive: ${_inclusions.join(', ')}');
    }
    final body = <String, dynamic>{
      if (!_isEdit) 'serviceType': 'cab',
      if (t['subType'] != null) 'subType': t['subType'],
      'vehicleType': (_cat['name'] ?? 'Cab').toString(),
      'pickup': t['pickup'],
      'pickupCity': t['pickupCity'],
      'drop': t['drop'],
      'dropCity': t['dropCity'],
      'travelDate': t['travelDate'],
      'travelTime': t['travelTime'],
      'passengers': t['passengers'] ?? 1,
      if (_fare > 0) 'estimatedFare': _fare,
      if (_distanceKm > 0) 'estimatedDistance': _distanceKm.round(),
      'notes': notes.join(' • '),
    };
    try {
      final repo = getIt<CustomerRepository>();
      final booking = _isEdit ? await repo.updateBooking(_editId, body) : await repo.createBooking(body);
      if (!mounted) return;
      final id = (booking['_id'] ?? booking['id'] ?? _editId).toString();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_isEdit ? 'Booking updated — drivers will re-send offers' : 'Booking confirmed — drivers will send offers'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ));
      context.go('/customer/bookings/$id');
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not ${_isEdit ? 'update' : 'book'}: ${e.toString().replaceFirst('Exception: ', '')}'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _trip;
    final img = (_cat['imageUrl'] ?? '').toString();
    final seats = (_cat['seats'] as num?)?.toInt() ?? 4;
    final bags = (_cat['bags'] ?? '').toString();
    final high = (_fare * 1.15).round();
    final date = (t['travelDate'] ?? '').toString();
    final time = (t['travelTime'] ?? '').toString();
    final sub = (t['subType'] ?? 'One Way').toString();
    final pax = (t['passengers'] as num?)?.toInt() ?? 1;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0.5,
        centerTitle: true,
        title: Text('Confirm Booking', style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w800, fontFamily: 'Poppins')),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(14.w, 14.h, 14.w, 20.h),
        children: [
          // Route
          _card(
            'Trip',
            Icons.route_rounded,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _routeRow(Icons.trip_origin_rounded, AppColors.success, 'FROM', _cityOf('pickupCity', 'pickup')),
                Padding(padding: EdgeInsets.only(left: 9.w), child: SizedBox(height: 18.h, child: const VerticalDivider(thickness: 1.2, color: AppColors.border))),
                _routeRow(Icons.location_on_rounded, AppColors.error, 'TO', _cityOf('dropCity', 'drop')),
                SizedBox(height: 10.h),
                Wrap(spacing: 8.w, runSpacing: 8.h, children: [
                  _pill(Icons.swap_horiz_rounded, sub),
                  _pill(Icons.speed_rounded, _distanceKm > 0 ? '${_distanceKm.round()} km${_isRound ? ' (round)' : ''}' : '—'),
                  _pill(Icons.people_rounded, '$pax passenger(s)'),
                  if (date.isNotEmpty) _pill(Icons.event_rounded, '$date${time.isNotEmpty ? ', $time' : ''}'),
                ]),
              ],
            ),
          ),
          SizedBox(height: 12.h),
          // Cab + fuel
          _card(
            'Your Cab',
            Icons.local_taxi_rounded,
            Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10.r),
                child: SizedBox(
                  width: 84.r,
                  child: AspectRatio(
                    aspectRatio: 4 / 3, // exact 4:3 box
                    child: Container(
                      color: Colors.white,
                      child: img.isNotEmpty
                          ? CachedNetworkImage(imageUrl: img, fit: BoxFit.cover, width: double.infinity, height: double.infinity, errorWidget: (_, __, ___) => Icon(Icons.directions_car_filled_rounded, size: 34.sp, color: AppColors.primary.withValues(alpha: 0.6)))
                          : Icon(Icons.directions_car_filled_rounded, size: 34.sp, color: AppColors.primary.withValues(alpha: 0.6)),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text((_cat['name'] ?? 'Cab').toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w800, fontFamily: 'Poppins')),
                  SizedBox(height: 3.h),
                  Text('${(_cat['vehicleClass'] ?? 'Cab').toString()} • $seats seats${bags.isNotEmpty ? ' • $bags' : ''}', style: TextStyle(fontSize: 11.sp, color: AppColors.textSecondary, fontFamily: 'Poppins')),
                  SizedBox(height: 6.h),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                    decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(6.r)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.local_gas_station_rounded, size: 12.sp, color: AppColors.primary),
                      SizedBox(width: 4.w),
                      Text('Fuel: $_fuel', style: TextStyle(fontSize: 10.5.sp, fontWeight: FontWeight.w700, color: AppColors.primary, fontFamily: 'Poppins')),
                    ]),
                  ),
                ]),
              ),
            ]),
          ),
          SizedBox(height: 12.h),
          // Fare
          _card(
            'Fare Estimate',
            Icons.currency_rupee_rounded,
            Column(children: [
              _fareRow('Distance fare (${_billedKm.round()} km)', '₹$_baseFare'),
              if (_isMinApplied) ...[
                SizedBox(height: 6.h),
                Text(
                  'Minimum ${_minKm.round()} km bill applies — your trip is ${_distanceKm.round()} km, so it is charged as ${_minKm.round()} km.',
                  style: TextStyle(fontSize: 10.5.sp, color: AppColors.warning, fontWeight: FontWeight.w600, fontFamily: 'Poppins'),
                ),
              ],
              if (!_isBestPrice && _toll > 0) ...[
                SizedBox(height: 6.h),
                _fareRow('Toll (auto on route)', '₹$_toll'),
              ],
              const Divider(height: 18),
              _fareRow('Estimated total', _fare > 0 ? '₹$_fare – ₹$high' : 'On request', bold: true),
              SizedBox(height: 6.h),
              Text(_isBestPrice
                  ? 'Best Price — toll & other charges paid directly to the driver. Final fare confirmed by the driver offer.'
                  : 'Final fare is confirmed by the driver offer. Pay the driver directly.',
                style: TextStyle(fontSize: 10.5.sp, color: AppColors.textSecondary, fontFamily: 'Poppins')),
            ]),
          ),
          SizedBox(height: 12.h),
          if (_isBestPrice)
            Container(
              padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 12.h),
              decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(14.r), border: Border.all(color: AppColors.warning.withValues(alpha: 0.35))),
              child: Row(children: [
                Icon(Icons.savings_rounded, color: AppColors.warning, size: 18.sp),
                SizedBox(width: 8.w),
                Expanded(child: Text('Best Price — distance-based only. Toll, tax & parking paid directly to the driver by you.', style: TextStyle(fontSize: 11.5.sp, height: 1.3, color: AppColors.textSecondary, fontFamily: 'Poppins'))),
              ]),
            )
          else if (_inclusions.isNotEmpty)
            Container(
              padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 12.h),
              decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(14.r), border: Border.all(color: AppColors.success.withValues(alpha: 0.35))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(Icons.verified_rounded, color: AppColors.success, size: 18.sp),
                  SizedBox(width: 6.w),
                  Text('All Inclusive Fare', style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w800, color: AppColors.success, fontFamily: 'Poppins')),
                ]),
                SizedBox(height: 8.h),
                Wrap(spacing: 8.w, runSpacing: 8.h, children: _inclusions.map((t) => Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.check_circle_rounded, size: 13.sp, color: AppColors.success),
                  SizedBox(width: 4.w),
                  Text(t, style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600, color: AppColors.textSecondary, fontFamily: 'Poppins')),
                ])).toList()),
              ]),
            ),
          if (_hasAnyInfo) ...[
            SizedBox(height: 12.h),
            _infoTabsCard(),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(14.w, 8.h, 14.w, 12.h),
          child: SizedBox(
            width: double.infinity,
            height: 52.h,
            child: ElevatedButton(
              onPressed: _busy ? null : _confirm,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, disabledBackgroundColor: AppColors.textHint, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r))),
              child: _busy
                  ? SizedBox(width: 22.w, height: 22.w, child: const CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                  : Text(_isEdit ? 'SAVE BOOKING' : 'CONFIRM BOOKING', style: TextStyle(fontSize: 15.5.sp, fontWeight: FontWeight.w800, letterSpacing: 0.5, fontFamily: 'Poppins')),
            ),
          ),
        ),
      ),
    );
  }

  // Admin-managed 4-tab info section (Inclusions / Exclusions / Facilities / T&C).
  Widget _infoTabsCard() {
    final key = _tabs[_infoTab].$2;
    final items = _infoList(key);
    IconData icon;
    Color color;
    switch (key) {
      case 'exclusions':
        icon = Icons.cancel_rounded;
        color = AppColors.error;
        break;
      case 'facilities':
        icon = Icons.star_rounded;
        color = AppColors.warning;
        break;
      case 'terms':
        icon = Icons.article_rounded;
        color = AppColors.textSecondary;
        break;
      default:
        icon = Icons.check_circle_rounded;
        color = AppColors.success;
    }
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16.r), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tab row.
          Row(
            children: _tabs.asMap().entries.map((e) {
              final i = e.key;
              final sel = i == _infoTab;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _infoTab = i),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: sel ? AppColors.primary : Colors.transparent, width: 2.5)),
                    ),
                    child: Text(e.value.$1, textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11.5.sp, fontWeight: sel ? FontWeight.w800 : FontWeight.w600, color: sel ? AppColors.primary : AppColors.textSecondary, fontFamily: 'Poppins')),
                  ),
                ),
              );
            }).toList(),
          ),
          const Divider(height: 1, color: AppColors.border),
          Padding(
            padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 14.h),
            child: items.isEmpty
                ? Text('No items listed.', style: TextStyle(fontSize: 12.sp, color: AppColors.textHint, fontFamily: 'Poppins'))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: items.map((t) => Padding(
                          padding: EdgeInsets.symmetric(vertical: 4.h),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Icon(icon, size: 15.sp, color: color),
                            SizedBox(width: 8.w),
                            Expanded(child: Text(t, style: TextStyle(fontSize: 12.5.sp, color: AppColors.textPrimary, fontFamily: 'Poppins'))),
                          ]),
                        )).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _card(String title, IconData icon, Widget child) => Container(
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16.r), border: Border.all(color: AppColors.border)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 18.sp, color: AppColors.primary),
              SizedBox(width: 8.w),
              Text(title, style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w800, fontFamily: 'Poppins')),
            ]),
            SizedBox(height: 12.h),
            child,
          ],
        ),
      );

  Widget _routeRow(IconData icon, Color color, String label, String value) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18.sp, color: color),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: TextStyle(fontSize: 9.5.sp, fontWeight: FontWeight.w700, color: AppColors.textHint, letterSpacing: 0.4, fontFamily: 'Poppins')),
              Text(value, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontFamily: 'Poppins')),
            ]),
          ),
        ],
      );

  Widget _pill(IconData icon, String text) => Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
        decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(20.r)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13.sp, color: AppColors.textSecondary),
          SizedBox(width: 4.w),
          Text(text, style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600, color: AppColors.textSecondary, fontFamily: 'Poppins')),
        ]),
      );

  Widget _fareRow(String k, String v, {bool bold = false}) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k, style: TextStyle(fontSize: 13.sp, fontWeight: bold ? FontWeight.w800 : FontWeight.w500, fontFamily: 'Poppins')),
          Text(v, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w800, color: AppColors.primary, fontFamily: 'Poppins')),
        ],
      );
}
