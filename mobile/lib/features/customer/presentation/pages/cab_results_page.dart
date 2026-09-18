import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/customer_repository.dart';

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
  bool _booking = false;
  double _distanceKm = 0;
  List<Map<String, dynamic>> _cats = [];
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

  Future<void> _load() async {
    double dist = (widget.trip['distanceKm'] as num?)?.toDouble() ?? 0;
    List<Map<String, dynamic>> cats = [];
    try {
      final pk = widget.trip['pickup'] as Map?;
      final dp = widget.trip['drop'] as Map?;
      final pLat = (pk?['lat'] as num?)?.toDouble() ?? 0;
      final pLng = (pk?['lng'] as num?)?.toDouble() ?? 0;
      final dLat = (dp?['lat'] as num?)?.toDouble() ?? 0;
      final dLng = (dp?['lng'] as num?)?.toDouble() ?? 0;
      if (dist <= 0 && pLat != 0 && dLat != 0) {
        final res = await _api.get('/places/route', params: {'points': '$pLat,$pLng;$dLat,$dLng'});
        dist = ((res.data['data']?['distanceKm']) as num?)?.toDouble() ?? 0;
      }
    } catch (_) {}
    try {
      final res = await _api.get('/home-content/cab-categories');
      final list = (res.data['data'] as List?) ?? [];
      cats = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {}
    if (cats.isEmpty) cats = _defaultCats.map((e) => Map<String, dynamic>.from(e)).toList();
    if (!mounted) return;
    setState(() {
      _distanceKm = _isRound ? dist * 2 : dist;
      _cats = cats;
      _loading = false;
    });
  }

  int _baseFare(Map<String, dynamic> cat) {
    final rate = (cat['pricePerKm'] as num?)?.toDouble() ?? 0;
    return (_distanceKm * rate).round();
  }

  Future<void> _book(Map<String, dynamic> cat) async {
    if (_booking) return;
    setState(() => _booking = true);
    final t = widget.trip;
    final base = _baseFare(cat);
    final body = <String, dynamic>{
      'serviceType': 'cab',
      if (t['subType'] != null) 'subType': t['subType'],
      'vehicleType': (cat['name'] ?? 'Cab').toString(),
      'pickup': t['pickup'],
      'pickupCity': t['pickupCity'],
      'drop': t['drop'],
      'dropCity': t['dropCity'],
      'travelDate': t['travelDate'],
      'travelTime': t['travelTime'],
      'passengers': t['passengers'] ?? 1,
      if (base > 0) 'estimatedFare': base,
      if (t['notes'] != null && (t['notes'] as String).isNotEmpty) 'notes': t['notes'],
    };
    try {
      final booking = await getIt<CustomerRepository>().createBooking(body);
      if (!mounted) return;
      final id = (booking['_id'] ?? booking['id'] ?? '').toString();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Booking posted — drivers will send offers'), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating));
      context.go('/customer/bookings/$id');
    } catch (e) {
      if (mounted) {
        setState(() => _booking = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not book: ${e.toString().replaceFirst('Exception: ', '')}'), backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.trip;
    final from = (t['pickupCity'] ?? (t['pickup'] as Map?)?['address'] ?? 'From').toString();
    final to = (t['dropCity'] ?? (t['drop'] as Map?)?['address'] ?? 'To').toString();
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
                Container(
                  padding: EdgeInsets.all(14.w),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14.r), border: Border.all(color: AppColors.border)),
                  child: Row(children: [
                    Icon(Icons.tune_rounded, color: AppColors.primary, size: 22.sp),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Choose your ride', style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w800, fontFamily: 'Poppins')),
                        Text(_distanceKm > 0 ? 'Approx ${_distanceKm.round()} km${_isRound ? ' (round trip)' : ''} • all-inclusive estimate' : 'Pick a cab class that fits your trip', style: TextStyle(fontSize: 11.5.sp, color: AppColors.textSecondary, fontFamily: 'Poppins')),
                      ]),
                    ),
                  ]),
                ),
                SizedBox(height: 12.h),
                ..._cats.map(_cabCard),
              ],
            ),
    );
  }

  Widget _cabCard(Map<String, dynamic> cat) {
    final id = (cat['_id'] ?? cat['name'] ?? '').toString();
    final base = _baseFare(cat);
    final high = (base * 1.15).round();
    final hasFare = base > 0;
    final kms = _distanceKm > 0 ? '${_distanceKm.round()} Kms' : '—';
    final expanded = _expanded.contains(id);
    final taxes = (base * 0.05).round();
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
                  child: Container(
                    width: 92.w,
                    height: 74.h,
                    color: const Color(0xFFF3F4F6),
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
                    Text(hasFare ? '₹$base - ₹$high' : 'On request', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w800, color: AppColors.textPrimary, fontFamily: 'Poppins')),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w),
            child: Wrap(spacing: 8.w, runSpacing: 8.h, children: [
              _chip(Icons.event_seat_rounded, '$seats Seats'),
              if (bags.isNotEmpty) _chip(Icons.luggage_rounded, bags),
              _chip(Icons.speed_rounded, kms),
            ]),
          ),
          SizedBox(height: 8.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w),
            child: Row(children: [
              _tag('All inclusive fare'),
              SizedBox(width: 8.w),
              _tag('No hidden charges'),
            ]),
          ),
          if (expanded && hasFare)
            Padding(
              padding: EdgeInsets.fromLTRB(12.w, 10.h, 12.w, 0),
              child: Container(
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(10.r)),
                child: Column(children: [
                  _fareRow('Base fare (${_distanceKm.round()} km)', '₹$base'),
                  _fareRow('Taxes & fees (est.)', '₹$taxes'),
                  const Divider(height: 14),
                  _fareRow('Estimated total', '₹${base + taxes}', bold: true),
                  SizedBox(height: 4.h),
                  Text('Final fare is confirmed by the driver offer. Pay the driver directly.', style: TextStyle(fontSize: 10.sp, color: AppColors.textSecondary, fontFamily: 'Poppins')),
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
                  onPressed: _booking ? null : () => _book(cat),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, padding: EdgeInsets.symmetric(horizontal: 22.w, vertical: 11.h), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r))),
                  child: Text('Book Now', style: TextStyle(fontSize: 13.5.sp, fontWeight: FontWeight.w700, fontFamily: 'Poppins')),
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

  Widget _tag(String text) => Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
        decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(20.r), border: Border.all(color: AppColors.success.withValues(alpha: 0.4))),
        child: Text(text, style: TextStyle(fontSize: 10.5.sp, fontWeight: FontWeight.w600, color: AppColors.success, fontFamily: 'Poppins')),
      );

  Widget _fareRow(String k, String v, {bool bold = false}) => Padding(
        padding: EdgeInsets.symmetric(vertical: 2.h),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(k, style: TextStyle(fontSize: 12.sp, fontWeight: bold ? FontWeight.w800 : FontWeight.w500, fontFamily: 'Poppins')),
          Text(v, style: TextStyle(fontSize: 12.sp, fontWeight: bold ? FontWeight.w800 : FontWeight.w600, color: bold ? AppColors.primary : AppColors.textPrimary, fontFamily: 'Poppins')),
        ]),
      );
}
