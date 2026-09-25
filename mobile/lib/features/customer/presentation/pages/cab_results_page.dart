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
  // Fare mode: 'All Inclusive' (distance + toll) or 'Best Price' (distance only).
  String _incMode = 'All Inclusive';
  // Selected fuel per cab card (keyed by category id/name). Only fuels the admin
  // priced for that category are offered; the fare uses the selected fuel's rate.
  final Map<String, String> _cardFuel = {};
  final Set<String> _expanded = {};

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
    // Global minimum bill km (applies to all cabs). Non-fatal if it fails.
    double minKm = 0;
    try {
      final res = await _api.get('/settings');
      minKm = ((res.data['data']?['minBillKm']) as num?)?.toDouble() ?? 0;
    } catch (_) {}
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
            Text('$sub  •  $date${time.isNotEmpty ? ', $time' : ''}', style: TextStyle(fontSize: 11.sp, color: AppColors.textSecondary, fontFamily: 'Poppins')),
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

  IconData _fuelIcon(String f) =>
      f == 'Diesel' ? Icons.local_gas_station_rounded : f == 'CNG' ? Icons.eco_rounded : Icons.local_gas_station_outlined;

  // Per-card fuel chips. Shows only the fuels the admin priced for this category;
  // tapping one re-computes that card's fare. Nothing renders if none are set.
  Widget _cardFuelChips(Map<String, dynamic> cat) {
    final avail = _availableFuels(cat);
    if (avail.isEmpty) return const SizedBox.shrink();
    final selected = _fuelOf(cat);
    final single = avail.length == 1;
    return Padding(
      padding: EdgeInsets.only(top: 10.h),
      child: Wrap(
        spacing: 8.w,
        runSpacing: 8.h,
        children: avail.map((f) {
          final sel = selected == f;
          return GestureDetector(
            onTap: single ? null : () => setState(() => _cardFuel[_catId(cat)] = f),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 11.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: sel ? AppColors.primary.withValues(alpha: 0.12) : Colors.white,
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(color: sel ? AppColors.primary : AppColors.border, width: sel ? 1.4 : 1),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(_fuelIcon(f), size: 13.sp, color: sel ? AppColors.primary : AppColors.textSecondary),
                SizedBox(width: 4.w),
                Text(f, style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w700, color: sel ? AppColors.primary : AppColors.textSecondary, fontFamily: 'Poppins')),
              ]),
            ),
          );
        }).toList(),
      ),
    );
  }

  // Top toggle: All Inclusive (distance + toll) vs Best Price (distance only).
  Widget _modeToggle() {
    const modes = ['All Inclusive', 'Best Price'];
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

  Widget _cabCard(Map<String, dynamic> cat) {
    final id = (cat['_id'] ?? cat['name'] ?? '').toString();
    final base = _baseFare(cat); // distance-only
    final fare = _fareFor(cat); // + toll when All Inclusive
    final high = (fare * 1.15).round();
    final hasFare = fare > 0;
    final kms = _distanceKm > 0 ? '${_distanceKm.round()} Kms' : '—';
    final expanded = _expanded.contains(id);
    final img = (cat['imageUrl'] ?? '').toString();
    final seats = (cat['seats'] as num?)?.toInt() ?? 4;
    final bags = (cat['bags'] ?? '').toString();

    return Container(
      margin: EdgeInsets.only(bottom: 14.h),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16.r), border: Border.all(color: AppColors.border), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(12.w),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10.r),
                  child: SizedBox(
                    width: 100.r,
                    child: AspectRatio(
                      aspectRatio: 4 / 3, // exact 4:3 box for the recommended image
                      child: Container(
                        color: Colors.white,
                        child: img.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: img,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                                placeholder: (_, __) => Icon(Icons.directions_car_filled_rounded, size: 40.sp, color: AppColors.primary.withValues(alpha: 0.5)),
                                errorWidget: (_, __, ___) => Icon(Icons.directions_car_filled_rounded, size: 44.sp, color: AppColors.primary.withValues(alpha: 0.7)),
                              )
                            : Icon(Icons.directions_car_filled_rounded, size: 44.sp, color: AppColors.primary.withValues(alpha: 0.7)),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text((cat['name'] ?? 'Cab').toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w800, fontFamily: 'Poppins')),
                      SizedBox(height: 2.h),
                      Text('${(cat['vehicleClass'] ?? '').toString().isEmpty ? 'Cab' : cat['vehicleClass']} | AC', style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: AppColors.info, fontFamily: 'Poppins')),
                      SizedBox(height: 3.h),
                      Row(children: List.generate(5, (i) => Icon(i < 4 ? Icons.star_rounded : Icons.star_border_rounded, size: 14.sp, color: AppColors.warning))),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Your price', style: TextStyle(fontSize: 10.sp, color: AppColors.textSecondary, fontFamily: 'Poppins')),
                    Text(hasFare ? '₹$fare - ₹$high' : 'On request', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w800, color: AppColors.textPrimary, fontFamily: 'Poppins')),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(spacing: 8.w, runSpacing: 8.h, children: [
                  _chip(Icons.event_seat_rounded, '$seats Seats'),
                  if (bags.isNotEmpty) _chip(Icons.luggage_rounded, bags),
                  _chip(Icons.speed_rounded, kms),
                ]),
                _cardFuelChips(cat),
                if (_isMinApplied)
                  Padding(
                    padding: EdgeInsets.only(top: 6.h),
                    child: Text(
                      'Minimum ${_minKm.round()} km billed (your trip is ${_distanceKm.round()} km).',
                      style: TextStyle(fontSize: 10.5.sp, color: AppColors.warning, fontWeight: FontWeight.w700, fontFamily: 'Poppins'),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: 8.h),
          if (expanded && hasFare)
            Padding(
              padding: EdgeInsets.fromLTRB(12.w, 10.h, 12.w, 0),
              child: Container(
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(10.r)),
                child: Column(children: [
                  _fareRow('Distance fare (${_billableKm.round()} km)', '₹$base'),
                  if (_isMinApplied) _fareRow('Minimum ${_minKm.round()} km applied', ''),
                  if (!_isBestPrice && _toll > 0) _fareRow('Toll (auto)', '₹${_toll.round()}'),
                  const Divider(height: 14),
                  _fareRow('Estimated total', '₹$fare', bold: true),
                  SizedBox(height: 4.h),
                  Text(_isBestPrice
                      ? 'Best Price — toll & other charges paid directly to the driver.'
                      : 'Final fare is confirmed by the driver offer. Pay the driver directly.',
                    style: TextStyle(fontSize: 10.sp, color: AppColors.textSecondary, fontFamily: 'Poppins')),
                ]),
              ),
            ),
          Divider(height: 20.h, color: AppColors.border),
          Padding(
            padding: EdgeInsets.fromLTRB(12.w, 0, 12.w, 12.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () => setState(() => expanded ? _expanded.remove(id) : _expanded.add(id)),
                  child: Row(children: [
                    Text('Fare breakup', style: TextStyle(fontSize: 12.5.sp, fontWeight: FontWeight.w700, color: AppColors.info, fontFamily: 'Poppins')),
                    Icon(expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: AppColors.info, size: 20.sp),
                  ]),
                ),
                ElevatedButton(
                  onPressed: () => _openConfirm(cat),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, padding: EdgeInsets.symmetric(horizontal: 22.w, vertical: 11.h), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r))),
                  child: Text(_isEdit ? 'Save' : 'Book Now', style: TextStyle(fontSize: 13.5.sp, fontWeight: FontWeight.w700, fontFamily: 'Poppins')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String text) => Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20.r), border: Border.all(color: AppColors.border)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13.sp, color: AppColors.textSecondary),
          SizedBox(width: 4.w),
          Text(text, style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600, color: AppColors.textSecondary, fontFamily: 'Poppins')),
        ]),
      );

  Widget _fareRow(String k, String v, {bool bold = false}) => Padding(
        padding: EdgeInsets.symmetric(vertical: 2.h),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(k, style: TextStyle(fontSize: 12.sp, fontWeight: bold ? FontWeight.w800 : FontWeight.w500, fontFamily: 'Poppins')),
          Text(v, style: TextStyle(fontSize: 12.sp, fontWeight: bold ? FontWeight.w800 : FontWeight.w600, color: bold ? AppColors.primary : AppColors.textPrimary, fontFamily: 'Poppins')),
        ]),
      );
}
