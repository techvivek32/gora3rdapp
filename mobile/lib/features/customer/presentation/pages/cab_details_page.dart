import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/contact_launcher.dart';

/// Shown AFTER the customer taps "Book Now" on a cab and BEFORE the Review /
/// Confirm screen. It shows the trip, the cab's full details, lets the rider pick
/// the fuel type, and reads the Inclusions / Exclusions / Facilities / Terms
/// (all admin-managed per cab category). "Select Car" carries the choice onward.
class CabDetailsPage extends StatefulWidget {
  final Map<String, dynamic> data;
  const CabDetailsPage({super.key, required this.data});

  @override
  State<CabDetailsPage> createState() => _CabDetailsPageState();
}

class _CabDetailsPageState extends State<CabDetailsPage> {
  late String _fuel;
  int _tab = 0; // 0 Inclusions · 1 Exclusions · 2 Facilities · 3 T&C

  Map<String, dynamic> get _trip => Map<String, dynamic>.from(widget.data['trip'] as Map? ?? {});
  Map<String, dynamic> get _cat => Map<String, dynamic>.from(widget.data['cat'] as Map? ?? {});
  List<String> get _fuels => ((widget.data['fuels'] as List?) ?? []).map((e) => e.toString()).toList();
  Map<String, dynamic> get _fuelFares => Map<String, dynamic>.from(widget.data['fuelFares'] as Map? ?? {});
  double get _billedKm => (widget.data['billedKm'] as num?)?.toDouble() ?? 0;
  int get _toll => (widget.data['toll'] as num?)?.toInt() ?? 0;
  bool get _isBestPrice => (widget.data['incMode'] ?? 'All Inclusive').toString() == 'Best Price';
  bool get _isLocal => widget.data['isLocal'] == true;
  bool get _isRound => widget.data['isRound'] == true;
  bool get _isLowest => widget.data['isLowest'] == true;
  int get _packageHours => (widget.data['packageHours'] as num?)?.toInt() ?? 0;
  int get _extraKm => (_cat['extraKmPrice'] as num?)?.toInt() ?? 0;
  int get _extraHourPrice => (widget.data['extraHourPrice'] as num?)?.toInt() ?? 0;
  String get _editId => (widget.data['bookingId'] ?? '').toString();

  int get _fare {
    final f = _fuelFares[_fuel];
    if (f is num) return f.toInt();
    return (widget.data['noFuelFare'] as num?)?.toInt() ?? 0;
  }

  // Original (pre-discount) fare + discount %, for the struck-through price.
  Map<String, dynamic> get _fuelFaresRaw => Map<String, dynamic>.from(widget.data['fuelFaresRaw'] as Map? ?? {});
  double get _discountPct => (widget.data['discountPercent'] as num?)?.toDouble() ?? 0;
  int get _driverAllowance => (widget.data['driverAllowance'] as num?)?.toInt() ?? 0;
  // Global GST %, for the "GST (5%)" label.
  double get _gstPercent => (widget.data['gstPercent'] as num?)?.toDouble() ?? 0;
  String get _gstLabel => _gstPercent > 0 ? 'GST (${_gstPercent.round()}%)' : 'GST';

  // Fare breakdown parts for the selected fuel (base+toll and GST, discounted).
  Map<String, dynamic> get _fuelBreakdown => Map<String, dynamic>.from(widget.data['fuelBreakdown'] as Map? ?? {});
  int get _gstPart {
    final b = _fuelBreakdown[_fuel];
    if (b is Map && b['gst'] is num) return (b['gst'] as num).toInt();
    return (widget.data['noFuelGst'] as num?)?.toInt() ?? 0;
  }
  int get _basePart {
    final b = _fuelBreakdown[_fuel];
    if (b is Map && b['base'] is num) return (b['base'] as num).toInt();
    return (widget.data['noFuelBase'] as num?)?.toInt() ?? (_fare - _driverAllowance - _gstPart);
  }
  int get _rawFare {
    final f = _fuelFaresRaw[_fuel];
    if (f is num) return f.toInt();
    return (widget.data['noFuelFareRaw'] as num?)?.toInt() ?? _fare;
  }

  String _supportPhone = '';

  @override
  void initState() {
    super.initState();
    final def = (widget.data['defaultFuel'] ?? '').toString();
    _fuel = def.isNotEmpty ? def : (_fuels.isNotEmpty ? _fuels.first : '');
    _loadSupport();
  }

  Future<void> _loadSupport() async {
    try {
      final res = await getIt<ApiClient>().get('/settings/support-contact');
      final d = (res.data['data'] as Map?) ?? const {};
      final phone = (d['phone'] ?? '').toString().trim();
      if (mounted && phone.isNotEmpty) setState(() => _supportPhone = phone);
    } catch (_) {}
  }

  List<String> _arr(String key) => ((_cat[key] as List?) ?? []).map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();

  List<String> get _inclusions {
    final admin = _arr('inclusions');
    return admin.isNotEmpty ? admin : const ['Fuel charges', 'Driver allowance', 'Base fare'];
  }

  List<String> get _exclusions {
    final admin = _arr('exclusions');
    return <String>[
      if (_isLocal && _extraHourPrice > 0) 'Pay ₹$_extraHourPrice/hr beyond $_packageHours hours',
      if (_extraKm > 0) 'Pay ₹$_extraKm/km after ${_billedKm.round()} km',
      if (_isBestPrice) 'Toll, state tax & parking (pay the driver directly)',
      ...admin,
      'Multiple pickups / drops',
    ];
  }

  List<String> get _facilities {
    final admin = _arr('facilities');
    return admin.isNotEmpty ? admin : const ['AC', 'Comfortable seating', 'Experienced driver'];
  }

  List<String> get _terms {
    final admin = _arr('terms');
    return admin.isNotEmpty
        ? admin
        : const [
            'Your trip has a KM limit. Usage beyond it is charged at the per-km rate shown.',
            'The fare covers one pickup and one drop in the chosen cities, not within-city travel.',
            'Airport entry / parking charges, if any, are extra.',
            'On Best Price, toll, state tax & parking are paid directly to the driver.',
          ];
  }

  String _cityOf(String cityKey, String addrKey) {
    final c = (_trip[cityKey] ?? '').toString().trim();
    if (c.isNotEmpty) return c.split(',').first.trim();
    final a = ((_trip[addrKey] as Map?)?['address'] ?? '').toString().trim();
    return a.isEmpty ? '' : a.split(',').first.trim();
  }

  void _next() {
    context.push('/customer/cab-confirm', extra: {
      'trip': _trip,
      'cat': _cat,
      'fuel': _fuel.isEmpty ? 'Standard' : _fuel,
      'distanceKm': widget.data['distanceKm'] ?? 0,
      'billedKm': _billedKm,
      'minKm': widget.data['minKm'] ?? 0,
      'fare': _fare,
      'baseFare': _basePart,
      'driverAllowance': _driverAllowance,
      'gstAmount': _gstPart,
      'gstPercent': _gstPercent,
      'toll': _toll,
      'incMode': widget.data['incMode'] ?? 'All Inclusive',
      'isRound': widget.data['isRound'] == true,
      'isLocal': _isLocal,
      'packageHours': _packageHours,
      'extraHourPrice': _extraHourPrice,
      'bookingId': _editId,
      'inclusions': _isBestPrice ? <String>[] : _inclusions,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0.5,
        centerTitle: true,
        title: Text('Cab Details', style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w800, fontFamily: 'Poppins')),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 24.h),
        children: [
          _tripBanner(),
          SizedBox(height: 12.h),
          _cabCard(),
          SizedBox(height: 12.h),
          _breakdownCard(),
          SizedBox(height: 12.h),
          _benefitsRow(),
          SizedBox(height: 12.h),
          _tabsCard(),
          SizedBox(height: 12.h),
          _supportCard(),
        ],
      ),
    );
  }

  // ── Trip banner (route + pickup + "Modify") ────────────────────────────────
  Widget _tripBanner() {
    final from = _cityOf('pickupCity', 'pickup');
    final to = _cityOf('dropCity', 'drop');
    final sub = (_trip['subType'] ?? 'One Way').toString();
    final date = (_trip['travelDate'] ?? '').toString();
    final time = (_trip['travelTime'] ?? '').toString();
    final route = _isLocal ? '$from · Local' : (_isRound ? '$from → $to → $from' : '$from → $to');
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14.r), border: Border.all(color: AppColors.primary.withValues(alpha: 0.2))),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(sub, style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w700, color: AppColors.primary, fontFamily: 'Poppins')),
            SizedBox(height: 2.h),
            Text(route, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w800, color: AppColors.textPrimary, fontFamily: 'Poppins')),
            SizedBox(height: 3.h),
            Text('Pickup: $date${time.isNotEmpty ? ' | $time' : ''}', style: TextStyle(fontSize: 11.5.sp, color: AppColors.textSecondary, fontFamily: 'Poppins')),
          ]),
        ),
        SizedBox(width: 8.w),
        OutlinedButton(
          onPressed: () => context.pop(),
          style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary, side: BorderSide(color: AppColors.primary), padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r))),
          child: Text('Modify', style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700, fontFamily: 'Poppins')),
        ),
      ]),
    );
  }

  // ── The main cab card (image, price, features, fuel, Select Car) ────────────
  Widget _cabCard() {
    final img = (_cat['imageUrl'] ?? '').toString();
    final seats = (_cat['seats'] as num?)?.toInt() ?? 4;
    final bags = (_cat['bags'] ?? '').toString();
    final vclass = (_cat['vehicleClass'] ?? '').toString().trim();
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16.r), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(child: Text('${_cat['name'] ?? 'Cab'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w800, color: AppColors.textPrimary, fontFamily: 'Poppins'))),
                  if (_isLowest) ...[
                    SizedBox(width: 8.w),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.h),
                      decoration: BoxDecoration(color: AppColors.warning, borderRadius: BorderRadius.circular(5.r)),
                      child: Text('Lowest Price', style: TextStyle(fontSize: 8.5.sp, fontWeight: FontWeight.w800, color: Colors.white, fontFamily: 'Poppins')),
                    ),
                  ],
                ]),
                SizedBox(height: 4.h),
                Text('$seats seater ${vclass.isEmpty ? '' : '$vclass '}AC Cab', style: TextStyle(fontSize: 12.sp, fontStyle: FontStyle.italic, color: AppColors.textSecondary, fontFamily: 'Poppins')),
                SizedBox(height: 10.h),
                if (_discountPct > 0 && _rawFare > _fare)
                  Padding(
                    padding: EdgeInsets.only(bottom: 2.h),
                    child: Row(children: [
                      Text('₹$_rawFare',
                          style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600, color: AppColors.textSecondary, decoration: TextDecoration.lineThrough, fontFamily: 'Poppins')),
                      SizedBox(width: 7.w),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.h),
                        decoration: BoxDecoration(color: AppColors.success, borderRadius: BorderRadius.circular(5.r)),
                        child: Text('${_discountPct.round()}% OFF', style: TextStyle(fontSize: 9.sp, fontWeight: FontWeight.w800, color: Colors.white, fontFamily: 'Poppins')),
                      ),
                    ]),
                  ),
                Text('₹$_fare', style: TextStyle(fontSize: 26.sp, fontWeight: FontWeight.w900, color: AppColors.primary, fontFamily: 'Poppins')),
                if (_toll > 0)
                  Padding(
                    padding: EdgeInsets.only(top: 2.h),
                    child: Text('+ ₹$_toll Charges and Taxes', style: TextStyle(fontSize: 11.5.sp, color: AppColors.textSecondary, fontFamily: 'Poppins')),
                  ),
              ]),
            ),
            SizedBox(width: 8.w),
            ClipRRect(
              borderRadius: BorderRadius.circular(10.r),
              child: SizedBox(
                width: 120.r,
                child: AspectRatio(
                  aspectRatio: 4 / 3,
                  child: img.isNotEmpty
                      ? CachedNetworkImage(imageUrl: img, fit: BoxFit.cover, errorWidget: (_, __, ___) => Icon(Icons.directions_car_filled_rounded, size: 42.sp, color: AppColors.primary.withValues(alpha: 0.7)))
                      : Icon(Icons.directions_car_filled_rounded, size: 42.sp, color: AppColors.primary.withValues(alpha: 0.7)),
                ),
              ),
            ),
          ]),
          SizedBox(height: 14.h),
          _featureLine(Icons.badge_rounded, _driverAllowance > 0 ? 'Driver allowance: ₹$_driverAllowance (included)' : 'Driver allowance included'),
          if (_isLocal)
            _featureLine(Icons.timelapse_rounded, '$_packageHours hrs · ${_billedKm.round()} km included${_extraHourPrice > 0 ? '  |  Extra ₹$_extraHourPrice/hr' : ''}')
          else
            _featureLine(Icons.speed_rounded, _extraKm > 0 ? '${_billedKm.round()} kms included  |  Post limit: ₹$_extraKm/km' : '${_billedKm.round()} kms included'),
          if (bags.isNotEmpty) _featureLine(Icons.luggage_rounded, 'Luggage: $bags'),
          if (_fuels.isNotEmpty) ...[
            SizedBox(height: 10.h),
            _fuelBox(),
          ],
          SizedBox(height: 14.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _next,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, padding: EdgeInsets.symmetric(vertical: 14.h), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r))),
              child: Text(_editId.isNotEmpty ? 'SAVE' : 'SELECT CAR', style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w800, letterSpacing: 0.5, fontFamily: 'Poppins')),
            ),
          ),
        ],
      ),
    );
  }

  // Fare breakdown — Base Fare / Driver Allowance / GST, summing to the total.
  Widget _breakdownCard() {
    final base = _basePart;
    final allowance = _driverAllowance;
    final gst = _gstPart;
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14.r), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Fare Breakdown', style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w800, color: AppColors.textPrimary, fontFamily: 'Poppins')),
          SizedBox(height: 10.h),
          _brRow('Base Fare', base),
          if (allowance > 0) _brRow('Driver Allowance', allowance),
          if (gst > 0) _brRow(_gstLabel, gst),
          Padding(padding: EdgeInsets.symmetric(vertical: 6.h), child: Divider(height: 1, color: AppColors.border)),
          _brRow('Total Fare', _fare, bold: true),
        ],
      ),
    );
  }

  Widget _brRow(String label, int amount, {bool bold = false}) => Padding(
        padding: EdgeInsets.symmetric(vertical: 3.h),
        child: Row(children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: bold ? 13.sp : 12.sp, fontWeight: bold ? FontWeight.w800 : FontWeight.w600, color: bold ? AppColors.textPrimary : AppColors.textSecondary, fontFamily: 'Poppins'))),
          Text('₹$amount', style: TextStyle(fontSize: bold ? 14.sp : 12.5.sp, fontWeight: bold ? FontWeight.w900 : FontWeight.w700, color: bold ? AppColors.primary : AppColors.textPrimary, fontFamily: 'Poppins')),
        ]),
      );

  // 24×7 "Your Travel Expert" card — dials the admin-configured support number.
  Widget _supportCard() {
    if (_supportPhone.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(color: const Color(0xFFEAF4FF), borderRadius: BorderRadius.circular(14.r), border: Border.all(color: const Color(0xFFBFDCFF))),
      child: Row(children: [
        Container(
          width: 46.w,
          height: 46.w,
          decoration: const BoxDecoration(color: Color(0xFF1E88E5), shape: BoxShape.circle),
          child: Icon(Icons.headset_mic_rounded, color: Colors.white, size: 24.sp),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text('Your Travel Expert', style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w800, color: AppColors.textPrimary, fontFamily: 'Poppins')),
            SizedBox(height: 2.h),
            Text('Get expert advice for smarter travel plans', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10.sp, color: AppColors.textSecondary, fontFamily: 'Poppins')),
          ]),
        ),
        SizedBox(width: 10.w),
        GestureDetector(
          onTap: () => callNumber(_supportPhone),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 9.h),
            decoration: BoxDecoration(color: const Color(0xFF1E88E5), borderRadius: BorderRadius.circular(24.r)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.call_rounded, color: Colors.white, size: 14.sp),
              SizedBox(width: 5.w),
              Text('Call 24×7', style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w800, color: Colors.white, fontFamily: 'Poppins')),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _featureLine(IconData icon, String text) => Padding(
        padding: EdgeInsets.only(bottom: 8.h),
        child: Row(children: [
          Icon(icon, size: 16.sp, color: AppColors.primary),
          SizedBox(width: 10.w),
          Expanded(child: Text(text, style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontFamily: 'Poppins'))),
        ]),
      );

  Widget _fuelBox() {
    final single = _fuels.length == 1;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(color: AppColors.info.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(12.r)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Select Fuel Type', style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w800, color: AppColors.textPrimary, fontFamily: 'Poppins')),
          SizedBox(height: 8.h),
          // Fuels on a single line (side by side).
          Row(
            children: _fuels.map((f) {
              final sel = _fuel == f;
              return Padding(
                padding: EdgeInsets.only(right: 16.w),
                child: InkWell(
                  onTap: single ? null : () => setState(() => _fuel = f),
                  borderRadius: BorderRadius.circular(8.r),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(sel ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded, size: 18.sp, color: sel ? AppColors.primary : AppColors.textHint),
                    SizedBox(width: 6.w),
                    Text(f, style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, color: sel ? AppColors.textPrimary : AppColors.textSecondary, fontFamily: 'Poppins')),
                  ]),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Trust strip: zero cost · free cancellation · support ────────────────────
  Widget _benefitsRow() {
    Widget item(IconData icon, String l1, String l2) => Expanded(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 20.sp, color: AppColors.primary),
            SizedBox(height: 5.h),
            Text(l1, textAlign: TextAlign.center, style: TextStyle(fontSize: 10.5.sp, fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontFamily: 'Poppins')),
            Text(l2, textAlign: TextAlign.center, style: TextStyle(fontSize: 9.5.sp, color: AppColors.textSecondary, fontFamily: 'Poppins')),
          ]),
        );
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 14.h),
      decoration: BoxDecoration(color: AppColors.info.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(14.r)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        item(Icons.currency_rupee_rounded, 'Book Now', 'at Zero Cost'),
        _vDiv(),
        item(Icons.verified_user_rounded, 'Free Cancellation', 'Till 1 Hour'),
        _vDiv(),
        item(Icons.headset_mic_rounded, '24×7', 'Customer Support'),
      ]),
    );
  }

  Widget _vDiv() => Container(width: 1, height: 36.h, color: AppColors.border);

  // ── Inclusions / Exclusions / Facilities / T&C (segmented tabs) ─────────────
  Widget _tabsCard() {
    const labels = ['INCLUSIONS', 'EXCLUSIONS', 'FACILITIES', 'T&C'];
    final List<List<String>> content = [_inclusions, _exclusions, _facilities, _terms];
    final isExcl = _tab == 1;
    final accent = isExcl ? AppColors.primary : AppColors.success;
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16.r), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Segmented tab bar.
          Container(
            decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10.r)),
            padding: EdgeInsets.all(3.w),
            child: Row(children: List.generate(labels.length, (i) {
              final sel = _tab == i;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _tab = i),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 9.h),
                    decoration: BoxDecoration(color: sel ? AppColors.primary : Colors.transparent, borderRadius: BorderRadius.circular(8.r)),
                    child: Text(labels[i], textAlign: TextAlign.center, style: TextStyle(fontSize: 10.5.sp, fontWeight: FontWeight.w800, color: sel ? Colors.white : AppColors.textSecondary, fontFamily: 'Poppins')),
                  ),
                ),
              );
            })),
          ),
          SizedBox(height: 14.h),
          if (content[_tab].isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 6.h),
              child: Text('Nothing listed here.', style: TextStyle(fontSize: 12.5.sp, color: AppColors.textSecondary, fontFamily: 'Poppins')),
            )
          else
            ...content[_tab].map((e) => Padding(
                  padding: EdgeInsets.symmetric(vertical: 6.h),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      margin: EdgeInsets.only(top: 7.h),
                      width: 5.w,
                      height: 5.w,
                      decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(child: Text(e, style: TextStyle(fontSize: 12.5.sp, height: 1.4, color: AppColors.textPrimary, fontFamily: 'Poppins'))),
                  ]),
                )),
        ],
      ),
    );
  }
}
