import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';

/// The "Explore Cabs" results screen. Cab classes are ADMIN-MANAGED (name, class,
/// image, per-km price, seats, bags — from the admin panel); the fare is
/// distanceKm × pricePerKm. Book Now posts the booking so drivers send offers.
class CabResultsPage extends StatefulWidget {
  final Map<String, dynamic> trip;
  const CabResultsPage({super.key, required this.trip});

  @override
  State<CabResultsPage> createState() => _CabResultsPageState();
}

class _CabResultsPageState extends State<CabResultsPage> {
  final _api = getIt<ApiClient>();
  bool _loading = true;
  double _distanceKm = 0;
  double _minBillKm = 0; // global minimum billable distance (all cabs), from settings
  double _toll = 0; // estimated route toll (₹), auto from Google Routes API
  List<Map<String, dynamic>> _cats = [];
  List<String> _inclusions = [];
  // Fare mode: 'Best Price' (distance only) or 'All Inclusive' (distance + toll).
  // Defaults to Best Price (shown first in the toggle).
  String _incMode = 'Best Price';
  // Selected fuel per cab card (keyed by category id/name). Only fuels the admin
  // priced for that category are offered; the fare uses the selected fuel's rate.
  final Map<String, String> _cardFuel = {};

  // Fallback classes if the admin hasn't added any yet (so the screen still works).
  static const _defaultCats = <Map<String, dynamic>>[
    {'name': 'Wagon R or equivalent', 'vehicleClass': 'Compact', 'imageUrl': '', 'pricePerKm': 12, 'seats': 4, 'bags': '1 Small bag'},
    {'name': 'Dzire or equivalent', 'vehicleClass': 'Sedan', 'imageUrl': '', 'pricePerKm': 15, 'seats': 4, 'bags': '2 Small bags'},
    {'name': 'Ertiga or equivalent', 'vehicleClass': 'SUV', 'imageUrl': '', 'pricePerKm': 18, 'seats': 6, 'bags': '2 Bags'},
    {'name': 'Innova Crysta', 'vehicleClass': 'Premium SUV', 'imageUrl': '', 'pricePerKm': 22, 'seats': 7, 'bags': '3 Bags'},
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  bool get _isRound => (widget.trip['subType'] ?? '').toString() == 'Round Trip';

  // When a bookingId is passed in, this screen edits that booking instead of
  // creating a new one (the Edit Booking flow reuses the cab-class picker).
  String get _editId => (widget.trip['bookingId'] ?? '').toString();
  bool get _isEdit => _editId.isNotEmpty;

  Future<void> _load() async {
    double dist = (widget.trip['distanceKm'] as num?)?.toDouble() ?? 0;
    double toll = 0;
    List<Map<String, dynamic>> cats = [];
    try {
      final pk = widget.trip['pickup'] as Map?;
      final dp = widget.trip['drop'] as Map?;
      final pLat = (pk?['lat'] as num?)?.toDouble() ?? 0;
      final pLng = (pk?['lng'] as num?)?.toDouble() ?? 0;
      final dLat = (dp?['lat'] as num?)?.toDouble() ?? 0;
      final dLng = (dp?['lng'] as num?)?.toDouble() ?? 0;
      // Always call the route endpoint (for the toll estimate + fresh distance).
      if (pLat != 0 && dLat != 0) {
        final res = await _api.get('/places/route', params: {'points': '$pLat,$pLng;$dLat,$dLng'});
        final d = res.data['data'];
        final rd = (d?['distanceKm'] as num?)?.toDouble() ?? 0;
        if (rd > 0) dist = rd;
        toll = (d?['tollInr'] as num?)?.toDouble() ?? 0;
      }
    } catch (_) {}
    try {
      final res = await _api.get('/home-content/cab-categories');
      final list = (res.data['data'] as List?) ?? [];
      cats = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {}
    if (cats.isEmpty) cats = _defaultCats.map((e) => Map<String, dynamic>.from(e)).toList();
    // Global cab settings (min bill km + toll/tax fallback). Non-fatal if it fails.
    double minKm = 0;
    double tollTaxPerKm = 0;
    try {
      final res = await _api.get('/settings');
      minKm = ((res.data['data']?['minBillKm']) as num?)?.toDouble() ?? 0;
      tollTaxPerKm = ((res.data['data']?['tollTaxPerKm']) as num?)?.toDouble() ?? 0;
    } catch (_) {}
    // When Google returns no toll amount (empty on many long/inter-state routes,
    // and it never includes state tax), fall back to the admin ₹/km estimate for
    // inter-city trips so "All Inclusive" still reflects toll + state tax.
    if (toll <= 0 && tollTaxPerKm > 0 && dist >= 50) {
      toll = (dist * tollTaxPerKm).roundToDouble();
    }
    List<String> inc = [];
    try {
      final res = await _api.get('/home-content/inclusions');
      inc = ((res.data['data'] as List?) ?? []).map((e) => e.toString()).toList();
    } catch (_) {}
    if (inc.isEmpty) {
      inc = ['Toll tax', 'State tax', 'Car parking', 'Driver allowance', 'GST', 'No hidden charges'];
    }
    if (!mounted) return;
    setState(() {
      _distanceKm = _isRound ? dist * 2 : dist;
      _minBillKm = minKm;
      _toll = _isRound ? toll * 2 : toll;
      _cats = cats;
      _inclusions = inc;
      _loading = false;
    });
  }

  bool get _isBestPrice => _incMode == 'Best Price';

  // Distance-only fare (Best Price). All Inclusive adds the route toll.
  int _fareFor(Map<String, dynamic> cat) => _baseFare(cat) + (_isBestPrice ? 0 : _toll.round());

  String _catId(Map<String, dynamic> cat) => (cat['_id'] ?? cat['name'] ?? '').toString();

  // Fuels the admin priced for this category (price > 0). Empty = base rate only.
  List<String> _availableFuels(Map<String, dynamic> cat) {
    final out = <String>[];
    if (((cat['pricePerKmPetrol'] as num?) ?? 0) > 0) out.add('Petrol');
    if (((cat['pricePerKmDiesel'] as num?) ?? 0) > 0) out.add('Diesel');
    if (((cat['pricePerKmCng'] as num?) ?? 0) > 0) out.add('CNG');
    return out;
  }

  // The fuel selected for a card — the stored one, else the first available.
  String _fuelOf(Map<String, dynamic> cat) {
    final avail = _availableFuels(cat);
    if (avail.isEmpty) return '';
    final sel = _cardFuel[_catId(cat)];
    return (sel != null && avail.contains(sel)) ? sel : avail.first;
  }

  /// Per-km rate for the card's selected fuel; falls back to pricePerKm.
  double _rate(Map<String, dynamic> cat) {
    final f = _fuelOf(cat);
    if (f.isEmpty) return (cat['pricePerKm'] as num?)?.toDouble() ?? 0;
    final key = f == 'Diesel' ? 'pricePerKmDiesel' : f == 'CNG' ? 'pricePerKmCng' : 'pricePerKmPetrol';
    final r = (cat[key] as num?)?.toDouble() ?? 0;
    return r > 0 ? r : ((cat['pricePerKm'] as num?)?.toDouble() ?? 0);
  }

  /// Global minimum billable distance for ALL cabs (platform setting; 0 = none).
  double get _minKm => _minBillKm;

  /// The distance actually charged: at least the global minimum km.
  double get _billableKm => _distanceKm < _minKm ? _minKm : _distanceKm;

  /// True when the trip is shorter than the minimum, so the fare is bumped up.
  bool get _isMinApplied => _minKm > 0 && _distanceKm < _minKm;

  int _baseFare(Map<String, dynamic> cat) => (_billableKm * _rate(cat)).round();

  // Book Now → open the confirmation/review page. The booking is only posted
  // there when the customer taps "Confirm Booking".
  void _openConfirm(Map<String, dynamic> cat) {
    final t = widget.trip;
    final fuel = _fuelOf(cat);
    context.push('/customer/cab-confirm', extra: {
      'trip': t,
      'cat': cat,
      'fuel': fuel.isEmpty ? 'Standard' : fuel,
      'distanceKm': _distanceKm,
      // Distance the fare is billed on (>= global minimum) + minimum info.
      'billedKm': _billableKm,
      'minKm': _minKm,
      'fare': _fareFor(cat),
      'baseFare': _baseFare(cat),
      'toll': _isBestPrice ? 0 : _toll.round(),
      'incMode': _incMode,
      'isRound': _isRound,
      'bookingId': _editId,
      'inclusions': _isBestPrice ? <String>[] : _inclusions,
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.trip;
    // Prefer the first NON-EMPTY of [city, full address]; '' is not null so a
    // plain ?? would keep an empty city and render a blank "→ Mumbai" header.
    String pick(List<String?> vals, String fallback) {
      final v = vals.firstWhere((x) => x != null && x.trim().isNotEmpty, orElse: () => fallback)!.trim();
      return v.split(',').first.trim(); // "Rajkot, Gujarat, India" → "Rajkot"
    }
    final from = pick([t['pickupCity']?.toString(), (t['pickup'] as Map?)?['address']?.toString()], 'From');
    final to = pick([t['dropCity']?.toString(), (t['drop'] as Map?)?['address']?.toString()], 'To');
    final sub = (t['subType'] ?? 'One Way').toString();
    final date = (t['travelDate'] ?? '').toString();
    final time = (t['travelTime'] ?? '').toString();
    final returnDate = (t['returnDate'] ?? '').toString();

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0.5,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$from → $to', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700, fontFamily: 'Poppins')),
            Text('$sub  •  $date${time.isNotEmpty ? ', $time' : ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.sp, color: AppColors.textSecondary, fontFamily: 'Poppins')),
            if (_isRound && returnDate.isNotEmpty)
              Text('Return  •  $returnDate', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600, color: AppColors.primary, fontFamily: 'Poppins')),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 20.h),
              children: [
                _modeToggle(),
                SizedBox(height: 12.h),
                _inclusionsCard(),
                SizedBox(height: 12.h),
                ..._cats.map(_cabCard),
              ],
            ),
    );
  }

  // Top toggle: All Inclusive (distance + toll) vs Best Price (distance only).
  Widget _modeToggle() {
    const modes = ['Best Price', 'All Inclusive'];
    return Container(
      padding: EdgeInsets.all(6.w),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14.r), border: Border.all(color: AppColors.border)),
      child: Row(
        children: modes.map((m) {
          final sel = _incMode == m;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _incMode = m),
              behavior: HitTestBehavior.opaque,
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: 3.w),
                padding: EdgeInsets.symmetric(vertical: 9.h),
                decoration: BoxDecoration(color: sel ? AppColors.primary : Colors.transparent, borderRadius: BorderRadius.circular(10.r)),
                child: Text(m, textAlign: TextAlign.center, style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700, color: sel ? Colors.white : AppColors.textSecondary, fontFamily: 'Poppins')),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // Fare-mode info card. All Inclusive lists what's covered + the auto toll;
  // Best Price notes that it's distance-only and extras are paid directly.
  Widget _inclusionsCard() {
    final best = _isBestPrice;
    final accent = best ? AppColors.warning : AppColors.success;
    return Container(
      padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 12.h),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(best ? Icons.savings_rounded : Icons.verified_rounded, color: accent, size: 18.sp),
            SizedBox(width: 6.w),
            Text(best ? 'Best Price' : 'All Inclusive Fare',
                style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w800, color: accent, fontFamily: 'Poppins')),
            const Spacer(),
            if (_distanceKm > 0)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 3.h),
                decoration: BoxDecoration(color: accent.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(20.r)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.speed_rounded, size: 12.sp, color: accent),
                  SizedBox(width: 3.w),
                  Text('${_distanceKm.round()} km${_isRound ? ' • round' : ''}', style: TextStyle(fontSize: 10.5.sp, fontWeight: FontWeight.w700, color: accent, fontFamily: 'Poppins')),
                ]),
              ),
          ]),
          SizedBox(height: 8.h),
          if (best)
            Text(
              'Distance-based price only. Toll, state tax & parking and other charges are paid directly to the driver by you.',
              style: TextStyle(fontSize: 11.5.sp, height: 1.35, color: AppColors.textSecondary, fontFamily: 'Poppins'),
            )
          else ...[
            Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: _inclusions.map((t) => Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.check_circle_rounded, size: 14.sp, color: AppColors.success),
                SizedBox(width: 4.w),
                Text(t, style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600, color: AppColors.textSecondary, fontFamily: 'Poppins')),
              ])).toList(),
            ),
            if (_toll > 0) ...[
              SizedBox(height: 8.h),
              Row(children: [
                Icon(Icons.toll_rounded, size: 14.sp, color: AppColors.success),
                SizedBox(width: 5.w),
                Text('Toll ≈ ₹${_toll.round()} (auto-added on route)', style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w700, color: AppColors.success, fontFamily: 'Poppins')),
              ]),
            ],
          ],
        ],
      ),
    );
  }

  /// Cheapest fare across all cab classes (drives the "Lowest Price" badge).
  int get _minFare {
    int m = 0;
    for (final c in _cats) {
      final f = _fareFor(c);
      if (f > 0 && (m == 0 || f < m)) m = f;
    }
    return m;
  }

  Widget _cabCard(Map<String, dynamic> cat) {
    final fare = _fareFor(cat); // + toll when All Inclusive
    final hasFare = fare > 0;
    final img = (cat['imageUrl'] ?? '').toString();
    final seats = (cat['seats'] as num?)?.toInt() ?? 4;
    final bags = (cat['bags'] ?? '').toString();
    final vclass = (cat['vehicleClass'] ?? '').toString().trim();
    final extraKm = (cat['extraKmPrice'] as num?)?.toInt() ?? 0; // ₹/km beyond included
    final charges = (_isBestPrice ? 0 : _toll.round());
    final isLowest = hasFare && fare == _minFare;

    return Container(
      margin: EdgeInsets.only(bottom: 14.h),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16.r), border: Border.all(color: AppColors.border), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3))]),
      child: Padding(
        padding: EdgeInsets.all(14.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name + seater/rating on the left, car image (+ Lowest badge) on the right.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        text: TextSpan(
                          style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800, color: AppColors.textPrimary, fontFamily: 'Poppins'),
                          children: [
                            TextSpan(text: (cat['name'] ?? 'Cab').toString()),
                            TextSpan(text: '  or similar', style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      SizedBox(height: 6.h),
                      Text('$seats seater ${vclass.isEmpty ? '' : '$vclass '}AC Cab', style: TextStyle(fontSize: 12.5.sp, fontStyle: FontStyle.italic, color: AppColors.textSecondary, fontFamily: 'Poppins')),
                      SizedBox(height: 10.h),
                      Text(hasFare ? '₹$fare' : 'On request', style: TextStyle(fontSize: 24.sp, fontWeight: FontWeight.w800, color: AppColors.primary, fontFamily: 'Poppins')),
                      if (hasFare && charges > 0)
                        Padding(
                          padding: EdgeInsets.only(top: 2.h),
                          child: Text('+ ₹$charges Charges and Taxes', style: TextStyle(fontSize: 11.5.sp, color: AppColors.textSecondary, fontFamily: 'Poppins')),
                        ),
                    ],
                  ),
                ),
                SizedBox(width: 8.w),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (isLowest)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                        decoration: BoxDecoration(color: AppColors.warning, borderRadius: BorderRadius.circular(6.r)),
                        child: Text('Lowest Price', style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w800, color: Colors.white, fontFamily: 'Poppins')),
                      ),
                    SizedBox(height: 6.h),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10.r),
                      child: SizedBox(
                        width: 110.r,
                        child: AspectRatio(
                          aspectRatio: 4 / 3,
                          child: img.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: img,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => Icon(Icons.directions_car_filled_rounded, size: 40.sp, color: AppColors.primary.withValues(alpha: 0.5)),
                                  errorWidget: (_, __, ___) => Icon(Icons.directions_car_filled_rounded, size: 44.sp, color: AppColors.primary.withValues(alpha: 0.7)),
                                )
                              : Icon(Icons.directions_car_filled_rounded, size: 44.sp, color: AppColors.primary.withValues(alpha: 0.7)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 12.h),
            // Feature lines.
            _featureLine(Icons.badge_rounded, 'Driver allowance included'),
            _featureLine(
              Icons.speed_rounded,
              extraKm > 0
                  ? '${_billableKm.round()} kms included  |  Post limit: ₹$extraKm/km'
                  : '${_billableKm.round()} kms included',
            ),
            if (bags.isNotEmpty) _featureLine(Icons.luggage_rounded, 'Luggage: $bags'),
            if (_isMinApplied)
              Padding(
                padding: EdgeInsets.only(top: 2.h),
                child: Text(
                  'Minimum ${_minKm.round()} km billed (your trip is ${_distanceKm.round()} km).',
                  style: TextStyle(fontSize: 10.5.sp, color: AppColors.warning, fontWeight: FontWeight.w700, fontFamily: 'Poppins'),
                ),
              ),
            // Select Fuel Type box.
            _fuelBox(cat),
            SizedBox(height: 14.h),
            // Full-width SELECT CAR button.
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _openConfirm(cat),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, padding: EdgeInsets.symmetric(vertical: 14.h), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r))),
                child: Text(_isEdit ? 'SAVE' : 'SELECT CAR', style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w800, letterSpacing: 0.5, fontFamily: 'Poppins')),
              ),
            ),
          ],
        ),
      ),
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

  // "Select Fuel Type" box with radio options (only the fuels the admin priced).
  Widget _fuelBox(Map<String, dynamic> cat) {
    final avail = _availableFuels(cat);
    if (avail.isEmpty) return const SizedBox.shrink();
    final selected = _fuelOf(cat);
    final single = avail.length == 1;
    return Container(
      margin: EdgeInsets.only(top: 4.h),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(color: AppColors.info.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(12.r)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Select Fuel Type', style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w800, color: AppColors.textPrimary, fontFamily: 'Poppins')),
          SizedBox(height: 8.h),
          Row(
            children: avail.map((f) {
              final sel = selected == f;
              return Padding(
                padding: EdgeInsets.only(right: 20.w),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: single ? null : () => setState(() => _cardFuel[_catId(cat)] = f),
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
}
