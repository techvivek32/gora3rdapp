import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/indian_states.dart';
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
  double _gstPercent = 0; // global GST %, added to the All-Inclusive fare
  List<Map<String, dynamic>> _cats = [];
  List<String> _inclusions = [];
  // Fare mode: 'Best Price' (distance only) or 'All Inclusive' (distance + toll).
  // Defaults to Best Price (shown first in the toggle).
  String _incMode = 'Best Price';
  // Selected fuel per cab card (keyed by category id/name). Only fuels the admin
  // priced for that category are offered; the fare uses the selected fuel's rate.
  final Map<String, String> _cardFuel = {};
  // Cards whose inline "Fare breakup" section is currently expanded (keyed by cat id).
  final Set<String> _expandedFare = {};

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
  // Local = in-city hourly package (no destination; fare is per the chosen package).
  bool get _isLocal => (widget.trip['subType'] ?? '').toString() == 'Local';
  int get _localHours => (widget.trip['durationHours'] as num?)?.toInt() ?? 8;

  DateTime? _parseTripDate(dynamic v) => v == null ? null : DateTime.tryParse(v.toString());

  // Number of days the trip spans: trip-start date → trip-end date, inclusive
  // (same day = 1, next day = 2, …). Used for included km = KM/day × days.
  int get _days {
    final s = _parseTripDate(widget.trip['travelDate']);
    final e = _parseTripDate(widget.trip['tripEndDate']);
    if (s == null || e == null) return 1;
    final diff = DateTime(e.year, e.month, e.day).difference(DateTime(s.year, s.month, s.day)).inDays;
    return diff < 0 ? 1 : diff + 1;
  }

  // Km included in a Local package for this cab = hours × the cab's km/hour.
  int _localIncludedKm(Map<String, dynamic> cat) {
    final perHr = (cat['packageKmPerHour'] as num?)?.toDouble() ?? 0;
    return (perHr * _localHours).round();
  }

  // True when this cab offers Local packages (admin set a km/hour rate).
  bool _localOffered(Map<String, dynamic> cat) => ((cat['packageKmPerHour'] as num?)?.toDouble() ?? 0) > 0;

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
      // Route endpoint is used for the fresh DISTANCE only. Toll is NOT taken from
      // Google anymore — it comes solely from the admin ₹/km rate (see below).
      // Intermediate stops are added as waypoints so the distance routes THROUGH
      // them (pickup;stop1;stop2;drop) instead of pickup→drop direct.
      if (pLat != 0 && dLat != 0) {
        final stopPts = ((widget.trip['stops'] as List?) ?? [])
            .whereType<Map>()
            .map((s) {
              final la = (s['lat'] as num?)?.toDouble() ?? 0;
              final ln = (s['lng'] as num?)?.toDouble() ?? 0;
              return (la != 0 && ln != 0) ? '$la,$ln' : null;
            })
            .whereType<String>()
            .toList();
        final points = ['$pLat,$pLng', ...stopPts, '$dLat,$dLng'].join(';');
        final res = await _api.get('/places/route', params: {'points': points});
        final d = res.data['data'];
        final rd = (d?['distanceKm'] as num?)?.toDouble() ?? 0;
        if (rd > 0) dist = rd;
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
    double gst = 0;
    try {
      final res = await _api.get('/settings');
      minKm = ((res.data['data']?['minBillKm']) as num?)?.toDouble() ?? 0;
      tollTaxPerKm = ((res.data['data']?['tollTaxPerKm']) as num?)?.toDouble() ?? 0;
      gst = ((res.data['data']?['gstPercent']) as num?)?.toDouble() ?? 0;
    } catch (_) {}
    // Toll for "All Inclusive" = the admin per-km rate × distance (the single
    // source of truth). 0 = no toll. Google toll auto-detect is intentionally
    // not used (unreliable for Indian routes + never includes state tax).
    if (tollTaxPerKm > 0) {
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
      _gstPercent = gst;
      _cats = cats;
      _inclusions = inc;
      _loading = false;
    });
  }

  bool get _isBestPrice => _incMode == 'Best Price';

  // Route toll (₹) applied only to the All-Inclusive mode (Local has none).
  int get _tollRound => (_isBestPrice || _isLocal) ? 0 : _toll.round();

  // GST is a tax on what the customer actually pays — i.e. on the (net base + toll)
  // PLUS the driver allowance. e.g. ₹18000 base + ₹300 allowance → GST on ₹18300.
  int _gstOnParts(int netBaseToll, int allowance) =>
      _gstPercent > 0 ? ((netBaseToll + allowance) * _gstPercent / 100).round() : 0;

  // ── Fare breakdown parts (for the details/confirm "Base / GST / Allowance") ──
  // Ride fare + toll (pre-GST, pre-discount) for a fuel. Toll is All-Inclusive only.
  int _baseTollForFuel(Map<String, dynamic> cat, String fuel) =>
      _baseFareForFuel(cat, fuel) + _tollRound;
  // Net base+toll the customer pays (after the cab discount).
  int _netBaseForFuel(Map<String, dynamic> cat, String fuel) => _discounted(_baseTollForFuel(cat, fuel), cat);
  // GST shown/charged: on (net base+toll + allowance). Already final — not re-discounted.
  int _gstForFuel(Map<String, dynamic> cat, String fuel) =>
      _gstOnParts(_netBaseForFuel(cat, fuel), _allowanceFor(cat));

  // No-fuel (single selected-fuel rate) equivalents.
  int _baseTollNoFuel(Map<String, dynamic> cat) => _baseFare(cat) + _tollRound;
  int _netBaseNoFuel(Map<String, dynamic> cat) => _discounted(_baseTollNoFuel(cat), cat);

  // Final fare = net base+toll + driver allowance + GST (on net base + allowance).
  // The allowance is added AFTER the discount so the driver gets their full amount.
  int _rawFareFor(Map<String, dynamic> cat) {
    final rb = _baseTollNoFuel(cat);
    final al = _allowanceFor(cat);
    return rb + al + _gstOnParts(rb, al);
  }
  int _fareFor(Map<String, dynamic> cat) {
    final nb = _netBaseNoFuel(cat);
    final al = _allowanceFor(cat);
    return nb + al + _gstOnParts(nb, al);
  }

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

  // The pickup's state (for state-wise fuel pricing), derived from the pickup
  // address/city the customer selected. Empty = no state → use the base rate.
  String? _pickupStateCache;
  String get _pickupState {
    _pickupStateCache ??= stateFromText(
      '${((widget.trip['pickup'] as Map?)?['address'] ?? '')} ${widget.trip['pickupCity'] ?? ''}',
    );
    return _pickupStateCache!;
  }

  /// State-wise ₹/km override for this cab + fuel, or 0 when none applies.
  double _stateRate(Map<String, dynamic> cat, String fuel) {
    if (_pickupState.isEmpty) return 0;
    final sp = cat['statePricing'];
    if (sp is! List) return 0;
    final key = fuel == 'Diesel' ? 'diesel' : fuel == 'CNG' ? 'cng' : 'petrol';
    for (final e in sp) {
      if (e is Map && (e['state'] ?? '').toString().toLowerCase() == _pickupState.toLowerCase()) {
        return (e[key] as num?)?.toDouble() ?? 0;
      }
    }
    return 0;
  }

  /// Per-cab discount percent (0–100).
  double _discountPct(Map<String, dynamic> cat) {
    final p = (cat['discountPercent'] as num?)?.toDouble() ?? 0;
    return p.clamp(0, 100).toDouble();
  }

  /// Apply the cab's discount to a fare (rounded).
  int _discounted(int fare, Map<String, dynamic> cat) {
    final p = _discountPct(cat);
    return p > 0 ? (fare * (1 - p / 100)).round() : fare;
  }

  /// Driver allowance added to the fare (One Way / Round Trip only; not Local).
  /// Round Trip: days × daily rate. One Way: distance ≤ threshold → base, else max.
  int _allowanceFor(Map<String, dynamic> cat) {
    if (_isLocal) return 0;
    if (_isRound) {
      final daily = (cat['allowanceDailyRate'] as num?)?.toInt() ?? 0;
      return daily * _days;
    }
    final baseR = (cat['allowanceBaseRate'] as num?)?.toInt() ?? 0;
    final maxR = (cat['allowanceMaxRate'] as num?)?.toInt() ?? 0;
    if (baseR == 0 && maxR == 0) return 0;
    final thr = (cat['allowanceDistanceThreshold'] as num?)?.toDouble() ?? 0;
    return _distanceKm <= thr ? baseR : maxR;
  }

  /// Per-km rate for the card's selected fuel; prefers the pickup state's rate,
  /// then the base fuel rate, then pricePerKm.
  double _rate(Map<String, dynamic> cat) => _rateForFuel(cat, _fuelOf(cat));

  /// Minimum included km for this cab.
  /// Round Trip → the cab's KM/day × trip days. One Way (and round trips with no
  /// KM/day set) → the global flat minimum, exactly as before.
  double _minKmFor(Map<String, dynamic> cat) {
    if (_isRound) {
      final daily = (cat['dailyKmLimit'] as num?)?.toDouble() ?? 0;
      if (daily > 0) return daily * _days;
    }
    return _minBillKm;
  }

  /// The distance actually charged for this cab: at least the per-day minimum.
  double _billableKmFor(Map<String, dynamic> cat) {
    final m = _minKmFor(cat);
    return _distanceKm < m ? m : _distanceKm;
  }

  /// True when the route is shorter than this cab's minimum, so the fare is bumped.
  bool _isMinAppliedFor(Map<String, dynamic> cat) {
    final m = _minKmFor(cat);
    return m > 0 && _distanceKm < m;
  }

  // Local package fare = included km (hours × km/hr) × per-km rate. Otherwise
  // distance-based (at least the per-day minimum included km).
  int _baseFare(Map<String, dynamic> cat) =>
      _isLocal ? (_localIncludedKm(cat) * _rate(cat)).round() : (_billableKmFor(cat) * _rate(cat)).round();

  // Per-fuel rate: pickup state's rate first, then the base fuel rate, then pricePerKm.
  double _rateForFuel(Map<String, dynamic> cat, String fuel) {
    if (fuel.isEmpty) return (cat['pricePerKm'] as num?)?.toDouble() ?? 0;
    final sr = _stateRate(cat, fuel);
    if (sr > 0) return sr;
    final key = fuel == 'Diesel' ? 'pricePerKmDiesel' : fuel == 'CNG' ? 'pricePerKmCng' : 'pricePerKmPetrol';
    final r = (cat[key] as num?)?.toDouble() ?? 0;
    return r > 0 ? r : ((cat['pricePerKm'] as num?)?.toDouble() ?? 0);
  }

  int _baseFareForFuel(Map<String, dynamic> cat, String fuel) =>
      _isLocal ? (_localIncludedKm(cat) * _rateForFuel(cat, fuel)).round() : (_billableKmFor(cat) * _rateForFuel(cat, fuel)).round();

  // Original (pre-discount) per-fuel fare = base+toll + allowance + GST(on base+allowance).
  int _rawFareForFuel(Map<String, dynamic> cat, String fuel) {
    final rb = _baseTollForFuel(cat, fuel);
    final al = _allowanceFor(cat);
    return rb + al + _gstOnParts(rb, al);
  }

  // Discounted fare actually charged = net base+toll + allowance + GST(on net+allowance).
  int _fareForFuel(Map<String, dynamic> cat, String fuel) {
    final nb = _netBaseForFuel(cat, fuel);
    final al = _allowanceFor(cat);
    return nb + al + _gstOnParts(nb, al);
  }

  /// Discounted price range across the fuels (for the card's "₹X – ₹Y").
  (int, int) _fareRange(Map<String, dynamic> cat) {
    final fuels = _availableFuels(cat);
    if (fuels.isEmpty) return (_fareFor(cat), _fareFor(cat));
    final fares = fuels.map((f) => _fareForFuel(cat, f)).toList()..sort();
    return (fares.first, fares.last);
  }

  /// Original (pre-discount) price range — shown struck through when discounted.
  (int, int) _rawFareRange(Map<String, dynamic> cat) {
    final fuels = _availableFuels(cat);
    if (fuels.isEmpty) return (_rawFareFor(cat), _rawFareFor(cat));
    final fares = fuels.map((f) => _rawFareForFuel(cat, f)).toList()..sort();
    return (fares.first, fares.last);
  }

  // Book Now → open the cab-details screen (fuel pick + inclusions/exclusions/
  // facilities/T&C). The Review/Confirm screen comes AFTER that, on "Next".
  void _openDetails(Map<String, dynamic> cat) {
    final t = widget.trip;
    final fuels = _availableFuels(cat);
    final fuelFares = {for (final f in fuels) f: _fareForFuel(cat, f)};
    final fuelFaresRaw = {for (final f in fuels) f: _rawFareForFuel(cat, f)};
    // Per-fuel breakdown (net base+toll, and final GST on net base + allowance) so
    // the details and review screens can show Base Fare / GST / Driver Allowance split.
    final fuelBreakdown = {
      for (final f in fuels) f: {
        'base': _netBaseForFuel(cat, f),
        'gst': _gstForFuel(cat, f),
      }
    };
    context.push('/customer/cab-details', extra: {
      'trip': t,
      'cat': cat,
      'fuels': fuels,
      'fuelFares': fuelFares,
      // Original (pre-discount) fares + discount %, for the struck-through price.
      'fuelFaresRaw': fuelFaresRaw,
      'noFuelFareRaw': _rawFareFor(cat),
      'discountPercent': _discountPct(cat),
      'driverAllowance': _allowanceFor(cat),
      'gstPercent': _gstPercent,
      // Fare-breakdown parts (base+toll and GST), per fuel + no-fuel fallback.
      'fuelBreakdown': fuelBreakdown,
      'noFuelBase': _netBaseNoFuel(cat),
      'noFuelGst': _gstOnParts(_netBaseNoFuel(cat), _allowanceFor(cat)),
      'isLowest': _fareFor(cat) > 0 && _fareFor(cat) == _minFare,
      'defaultFuel': _fuelOf(cat),
      'distanceKm': _isLocal ? 0 : _distanceKm,
      // Distance the fare is billed on. For Local it's the package's included km.
      'billedKm': _isLocal ? _localIncludedKm(cat).toDouble() : _billableKmFor(cat),
      'minKm': _minKmFor(cat),
      'noFuelFare': _fareFor(cat), // fallback when the cab has no per-fuel pricing
      'toll': (_isBestPrice || _isLocal) ? 0 : _toll.round(),
      'incMode': _incMode,
      'isRound': _isRound,
      'isLocal': _isLocal,
      'packageHours': _isLocal ? _localHours : 0,
      'extraHourPrice': _isLocal ? ((cat['extraHourPrice'] as num?)?.toInt() ?? 0) : 0,
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
    // Local: only cabs the admin configured for hourly packages are shown.
    final cats = _isLocal ? _cats.where(_localOffered).toList() : _cats;

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
            Text(_isLocal ? '$from · Local' : (_isRound ? '$from → $to → $from' : '$from → $to'), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700, fontFamily: 'Poppins')),
            Text(
                _isLocal
                    ? '$_localHours-hour package  •  $date${time.isNotEmpty ? ', $time' : ''}'
                    : '$sub  •  $date${time.isNotEmpty ? ', $time' : ''}',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.sp, color: AppColors.textSecondary, fontFamily: 'Poppins')),
            if (_isRound && returnDate.isNotEmpty)
              Text('Return  •  $returnDate', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600, color: AppColors.primary, fontFamily: 'Poppins')),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : cats.isEmpty
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.w),
                    child: Text(
                      _isLocal ? 'No cabs offer Local hourly packages yet.' : 'No cabs available.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13.sp, color: AppColors.textSecondary, fontFamily: 'Poppins'),
                    ),
                  ),
                )
              : ListView(
                  padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 20.h),
                  children: [
                    if (!_isLocal) ...[
                      _modeToggle(),
                      SizedBox(height: 12.h),
                    ],
                    _inclusionsCard(),
                    SizedBox(height: 12.h),
                    ...cats.map(_cabCard),
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
  // Local hourly-package info card (shown instead of the Best/All-Inclusive card).
  Widget _localInfoCard() {
    const accent = AppColors.primary;
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
            Icon(Icons.timelapse_rounded, color: accent, size: 18.sp),
            SizedBox(width: 6.w),
            Text('$_localHours-Hour Local Package',
                style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w800, color: accent, fontFamily: 'Poppins')),
          ]),
          SizedBox(height: 8.h),
          Text(
            'In-city hourly rental from your pickup. Each cab below shows the included km and the extra ₹/hour and ₹/km if you go over. Extra time is measured from trip start to end.',
            style: TextStyle(fontSize: 11.5.sp, height: 1.35, color: AppColors.textSecondary, fontFamily: 'Poppins'),
          ),
        ],
      ),
    );
  }

  Widget _inclusionsCard() {
    if (_isLocal) return _localInfoCard();
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
    final fare = _fareFor(cat);
    final hasFare = fare > 0;
    final (loFare, hiFare) = _fareRange(cat);
    final (loRaw, hiRaw) = _rawFareRange(cat);
    final disc = _discountPct(cat);
    final img = (cat['imageUrl'] ?? '').toString();
    final seats = (cat['seats'] as num?)?.toInt() ?? 4;
    final bags = (cat['bags'] ?? '').toString();
    final vclass = (cat['vehicleClass'] ?? '').toString().trim();
    final extraKm = (cat['extraKmPrice'] as num?)?.toInt() ?? 0;
    final isLowest = hasFare && fare == _minFare;
    final kmLabel = _isLocal ? '${_localIncludedKm(cat)} km' : '${_billableKmFor(cat).round()} km';

    return Container(
      margin: EdgeInsets.only(bottom: 14.h),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16.r), border: Border.all(color: AppColors.border), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3))]),
      child: Padding(
        padding: EdgeInsets.all(14.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image on the left, name/class/rating + price on the right.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12.r),
                  child: SizedBox(
                    width: 96.r,
                    child: AspectRatio(
                      aspectRatio: 4 / 3,
                      child: img.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: img,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Icon(Icons.directions_car_filled_rounded, size: 36.sp, color: AppColors.primary.withValues(alpha: 0.5)),
                              errorWidget: (_, __, ___) => Icon(Icons.directions_car_filled_rounded, size: 40.sp, color: AppColors.primary.withValues(alpha: 0.7)),
                            )
                          : Icon(Icons.directions_car_filled_rounded, size: 40.sp, color: AppColors.primary.withValues(alpha: 0.7)),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                          child: Text('${cat['name'] ?? 'Cab'}  or similar',
                              maxLines: 2, overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 14.5.sp, fontWeight: FontWeight.w800, color: AppColors.textPrimary, fontFamily: 'Poppins')),
                        ),
                        if (isLowest)
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.h),
                            decoration: BoxDecoration(color: AppColors.warning, borderRadius: BorderRadius.circular(5.r)),
                            child: Text('Lowest', style: TextStyle(fontSize: 9.sp, fontWeight: FontWeight.w800, color: Colors.white, fontFamily: 'Poppins')),
                          ),
                      ]),
                      SizedBox(height: 3.h),
                      Text('$seats seater ${vclass.isEmpty ? '' : '$vclass '}AC Cab',
                          style: TextStyle(fontSize: 11.5.sp, color: AppColors.primary, fontWeight: FontWeight.w600, fontFamily: 'Poppins')),
                      SizedBox(height: 8.h),
                      if (hasFare) ...[
                        if (disc > 0) ...[
                          Row(children: [
                            Flexible(
                              child: Text(loRaw == hiRaw ? '₹$loRaw' : '₹$loRaw – ₹$hiRaw',
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: AppColors.textSecondary, decoration: TextDecoration.lineThrough, fontFamily: 'Poppins')),
                            ),
                            SizedBox(width: 6.w),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.h),
                              decoration: BoxDecoration(color: AppColors.success, borderRadius: BorderRadius.circular(4.r)),
                              child: Text('${disc.round()}% OFF', style: TextStyle(fontSize: 8.5.sp, fontWeight: FontWeight.w800, color: Colors.white, fontFamily: 'Poppins')),
                            ),
                          ]),
                          SizedBox(height: 2.h),
                        ],
                        Text(loFare == hiFare ? '₹$loFare' : '₹$loFare – ₹$hiFare',
                            style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w900, color: AppColors.textPrimary, fontFamily: 'Poppins')),
                      ] else
                        Text('On request', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800, color: AppColors.textSecondary, fontFamily: 'Poppins')),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            // Quick-fact chips.
            Wrap(spacing: 8.w, runSpacing: 8.h, children: [
              _chip(Icons.event_seat_rounded, '$seats Seats'),
              if (bags.isNotEmpty) _chip(Icons.luggage_rounded, bags),
              _chip(Icons.speed_rounded, _isLocal ? '$_localHours hrs · $kmLabel' : '$kmLabel included'),
              if (extraKm > 0) _chip(Icons.trending_up_rounded, 'Then ₹$extraKm/km'),
            ]),
            SizedBox(height: 10.h),
            // Fare-mode badges — same capsule style as the fact chips.
            Wrap(spacing: 8.w, runSpacing: 8.h, children: [
              _greenChip(_isBestPrice ? 'Best Price' : 'All inclusive fare'),
              _greenChip('No hidden charges'),
            ]),
            if (!_isLocal && _isMinAppliedFor(cat))
              Padding(
                padding: EdgeInsets.only(top: 8.h),
                child: Text('Minimum ${_minKmFor(cat).round()} km billed (your trip is ${_distanceKm.round()} km).',
                    style: TextStyle(fontSize: 10.5.sp, color: AppColors.warning, fontWeight: FontWeight.w700, fontFamily: 'Poppins')),
              ),
            if (hasFare) ...[
              Padding(
                padding: EdgeInsets.symmetric(vertical: 10.h),
                child: Divider(height: 1, color: AppColors.border),
              ),
              // Fare breakup toggle (left) + Book Now (right) — the breakup
              // expands INLINE inside the card (no popup sheet).
              Row(
                children: [
                  InkWell(
                    onTap: () => setState(() {
                      final id = _catId(cat);
                      _expandedFare.contains(id) ? _expandedFare.remove(id) : _expandedFare.add(id);
                    }),
                    borderRadius: BorderRadius.circular(8.r),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 6.h),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text('Fare breakup', style: TextStyle(fontSize: 12.5.sp, fontWeight: FontWeight.w700, color: AppColors.primary, fontFamily: 'Poppins')),
                        SizedBox(width: 2.w),
                        Icon(_expandedFare.contains(_catId(cat)) ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, size: 18.sp, color: AppColors.primary),
                      ]),
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () => _openDetails(cat),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, padding: EdgeInsets.symmetric(horizontal: 22.w, vertical: 11.h), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r))),
                    child: Text(_isEdit ? 'Save' : 'Book Now', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w800, letterSpacing: 0.2, fontFamily: 'Poppins')),
                  ),
                ],
              ),
              if (_expandedFare.contains(_catId(cat))) _fareBreakupInline(cat, loFare, hiFare),
            ] else
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: null,
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, disabledBackgroundColor: AppColors.textHint, padding: EdgeInsets.symmetric(horizontal: 22.w, vertical: 11.h), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r))),
                  child: Text(_isEdit ? 'Save' : 'Book Now', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w800, letterSpacing: 0.2, fontFamily: 'Poppins')),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Inline fare breakup shown inside the card when "Fare breakup" is expanded.
  // Uses the card's default fuel for the line items; the total shows the same
  // range as the card headline.
  Widget _fareBreakupInline(Map<String, dynamic> cat, int loFare, int hiFare) {
    final fuel = _fuelOf(cat);
    final base = _netBaseForFuel(cat, fuel);
    final gst = _gstForFuel(cat, fuel);
    final allowance = _allowanceFor(cat);
    final totalLabel = loFare == hiFare ? '₹$loFare' : '₹$loFare – ₹$hiFare';
    return Container(
      margin: EdgeInsets.only(top: 6.h),
      padding: EdgeInsets.fromLTRB(12.w, 10.h, 12.w, 12.h),
      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12.r), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _bkRow('Base fare', '₹$base'),
          if (allowance > 0) _bkRow('Driver allowance', '₹$allowance'),
          if (!_isBestPrice && _toll > 0) _bkRow('Toll & state tax', 'Included', valueColor: AppColors.success),
          if (gst > 0) _bkRow('GST (${_gstPercent.round()}%)', '₹$gst'),
          Padding(padding: EdgeInsets.symmetric(vertical: 8.h), child: Divider(height: 1, color: AppColors.border)),
          Row(children: [
            Expanded(child: Text('Estimated total fare', style: TextStyle(fontSize: 13.5.sp, fontWeight: FontWeight.w800, color: AppColors.textPrimary, fontFamily: 'Poppins'))),
            Text(totalLabel, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w900, color: AppColors.primary, fontFamily: 'Poppins')),
          ]),
          SizedBox(height: 6.h),
          Text(_isBestPrice ? 'Best Price — toll, state tax & parking paid directly to the driver.' : 'All Inclusive — toll & state tax included.',
              style: TextStyle(fontSize: 9.5.sp, color: AppColors.textSecondary, fontFamily: 'Poppins')),
        ],
      ),
    );
  }

  // One line of the inline fare breakup (label + optional ₹/km subtitle, value).
  Widget _bkRow(String label, String value, {String? subtitle, Color? valueColor}) => Padding(
        padding: EdgeInsets.symmetric(vertical: 5.h),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: TextStyle(fontSize: 12.5.sp, fontWeight: FontWeight.w600, color: AppColors.textSecondary, fontFamily: 'Poppins')),
              if (subtitle != null)
                Text(subtitle, style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w500, color: AppColors.textHint, fontFamily: 'Poppins')),
            ]),
          ),
          Text(value, style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, color: valueColor ?? AppColors.textPrimary, fontFamily: 'Poppins')),
        ]),
      );

  Widget _chip(IconData icon, String text) => Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
        decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(20.r)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14.sp, color: AppColors.textSecondary),
          SizedBox(width: 5.w),
          Text(text, style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontFamily: 'Poppins')),
        ]),
      );

  // Capsule chip (same style as _chip) with a green check — for the fare-mode badges.
  Widget _greenChip(String text) => Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
        decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(20.r)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.check_circle_rounded, size: 14.sp, color: AppColors.success),
          SizedBox(width: 5.w),
          Text(text, style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontFamily: 'Poppins')),
        ]),
      );
}
