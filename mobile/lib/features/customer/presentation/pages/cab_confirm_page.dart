import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/api_error.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../data/customer_repository.dart';

/// Booking review / confirmation screen ("Review Your Booking"). Shown after the
/// customer picks a cab on the results screen — it summarises the trip, cab,
/// inclusions/exclusions and T&C, and only posts the booking on Confirm.
class CabConfirmPage extends StatefulWidget {
  final Map<String, dynamic> data;
  const CabConfirmPage({super.key, required this.data});

  @override
  State<CabConfirmPage> createState() => _CabConfirmPageState();
}

class _CabConfirmPageState extends State<CabConfirmPage> {
  bool _busy = false;
  bool _tcOpen = false;

  // Advance payment: 0 = book now / pay later, 10 = 10% advance, 100 = full.
  int _payPercent = 0;
  Razorpay? _razorpay;
  String? _pendingBookingId; // booking created, awaiting advance payment
  String _pendingHumanId = ''; // the human CB… id, for the confirmation screen

  // Contact details (pre-filled from the signed-in user). Editable.
  final _nameCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  // Pickup / drop come from the chosen trip and are shown READ-ONLY here.
  String get _pickupAddr {
    final a = ((_trip['pickup'] as Map?)?['address'] ?? '').toString().trim();
    return a.isNotEmpty ? a : (_trip['pickupCity'] ?? '—').toString();
  }

  String get _dropAddr {
    final a = ((_trip['drop'] as Map?)?['address'] ?? '').toString().trim();
    return a.isNotEmpty ? a : (_trip['dropCity'] ?? '—').toString();
  }

  @override
  void initState() {
    super.initState();
    final st = context.read<AuthBloc>().state;
    final user = st is AuthAuthenticated ? st.user as Map<String, dynamic>? : null;
    _nameCtrl.text = (user?['fullName'] ?? '').toString();
    _mobileCtrl.text = (user?['mobile'] ?? user?['phone'] ?? '').toString();
    _emailCtrl.text = (user?['email'] ?? '').toString();
    if (!kIsWeb) {
      _razorpay = Razorpay();
      _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaymentSuccess);
      _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, _onPaymentError);
    }
  }

  @override
  void dispose() {
    _razorpay?.clear();
    // If the user leaves while an advance booking is still awaiting payment,
    // cancel that pending booking so no unpaid (0-advance) booking is left live.
    final pending = _pendingBookingId;
    if (pending != null && !_isEdit) {
      getIt<CustomerRepository>().cancelBooking(pending, reason: 'Advance payment not completed').catchError((_) {});
    }
    _nameCtrl.dispose();
    _mobileCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  /// Cancel the just-created booking that is still awaiting its advance payment,
  /// so an abandoned/cancelled payment never leaves a live 0-advance booking.
  Future<void> _cancelPendingBooking() async {
    final id = _pendingBookingId;
    if (id == null || _isEdit) return;
    _pendingBookingId = null;
    _pendingHumanId = '';
    try {
      await getIt<CustomerRepository>().cancelBooking(id, reason: 'Advance payment not completed');
    } catch (_) {/* best-effort */}
  }

  Map<String, dynamic> get _trip => Map<String, dynamic>.from(widget.data['trip'] as Map? ?? {});
  Map<String, dynamic> get _cat => Map<String, dynamic>.from(widget.data['cat'] as Map? ?? {});
  String get _fuel => (widget.data['fuel'] ?? 'Petrol').toString();
  double get _distanceKm => (widget.data['distanceKm'] as num?)?.toDouble() ?? 0;
  double get _billedKm => (widget.data['billedKm'] as num?)?.toDouble() ?? _distanceKm;
  int get _fare => (widget.data['fare'] as num?)?.toInt() ?? 0;
  bool get _isRound => widget.data['isRound'] == true;
  // Local hourly package.
  bool get _isLocal => widget.data['isLocal'] == true;
  int get _packageHours => (widget.data['packageHours'] as num?)?.toInt() ?? 0;
  int get _extraHourPrice => (widget.data['extraHourPrice'] as num?)?.toInt() ?? 0;
  String get _editId => (widget.data['bookingId'] ?? '').toString();
  bool get _isEdit => _editId.isNotEmpty;
  List<String> get _inclusions => ((widget.data['inclusions'] as List?) ?? []).map((e) => e.toString()).toList();
  int get _toll => (widget.data['toll'] as num?)?.toInt() ?? 0;
  // Fare breakdown parts (from the details screen).
  int get _driverAllowance => (widget.data['driverAllowance'] as num?)?.toInt() ?? 0;
  int get _gstAmount => (widget.data['gstAmount'] as num?)?.toInt() ?? 0;
  double get _gstPercent => (widget.data['gstPercent'] as num?)?.toDouble() ?? 0;
  String get _gstLabel => _gstPercent > 0 ? 'GST (${_gstPercent.round()}%)' : 'GST';
  int get _baseFarePart => (widget.data['baseFare'] as num?)?.toInt() ?? (_fare - _driverAllowance - _gstAmount);
  String get _incMode => (widget.data['incMode'] ?? 'All Inclusive').toString();
  bool get _isBestPrice => _incMode == 'Best Price';
  int get _extraKm => (_cat['extraKmPrice'] as num?)?.toInt() ?? 0;
  List<String> get _terms => ((_cat['terms'] as List?) ?? []).map((e) => e.toString()).toList();

  // Shown when the admin hasn't set custom T&C for this cab category.
  static const List<String> _defaultTerms = [
    'Your trip has a KM limit. If your usage exceeds this limit, you will be charged for the extra KM used at the per-km rate shown.',
    'The fare includes one pick-up in the pickup city and one drop in the destination city. It does not include within-city travel.',
    'Airport entry / parking charges, if applicable, are not included in the fare and are charged extra.',
    'On a Best Price fare, toll, state tax & parking are paid directly to the driver by you. On All Inclusive they are already included.',
    'If your trip has hill climbs, the cab AC may be switched off during such climbs.',
  ];

  List<String> get _effectiveTerms => _terms.isNotEmpty ? _terms : _defaultTerms;

  String _cityOf(String cityKey, String addrKey) {
    final t = _trip;
    final city = (t[cityKey] ?? '').toString().trim();
    if (city.isNotEmpty) return city.split(',').first.trim();
    final addr = ((t[addrKey] as Map?)?['address'] ?? '').toString().trim();
    return addr.isEmpty ? '—' : addr.split(',').first.trim();
  }

  int _advanceRupees(int percent) => (_fare * percent / 100).round();

  // Fare-breakdown sheet opened from the "Total Fare (i)" row.
  void _showFareBreakdown() {
    final advance = _advanceRupees(_payPercent);
    final payToDriver = (_fare - advance).clamp(0, _fare);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20.r))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(18.w, 12.h, 18.w, 18.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40.w, height: 4.h, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
              SizedBox(height: 14.h),
              Text('Fare Breakdown', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800, color: AppColors.textPrimary, fontFamily: 'Poppins')),
              SizedBox(height: 12.h),
              _bdRow('Base Fare', _baseFarePart),
              if (_driverAllowance > 0) _bdRow('Driver Allowance', _driverAllowance),
              if (_gstAmount > 0) _bdRow(_gstLabel, _gstAmount),
              Padding(padding: EdgeInsets.symmetric(vertical: 6.h), child: Divider(height: 1, color: AppColors.border)),
              _bdRow('Total Fare', _fare, bold: true),
              SizedBox(height: 14.h),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                decoration: BoxDecoration(color: AppColors.info.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12.r)),
                child: Column(children: [
                  _bdRow('Pay Now', advance, accent: true),
                  _bdRow('Pay to Driver', payToDriver.toInt(), accent: true),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bdRow(String label, int amount, {bool bold = false, bool accent = false}) => Padding(
        padding: EdgeInsets.symmetric(vertical: 4.h),
        child: Row(children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: bold ? 14.sp : 12.5.sp, fontWeight: bold ? FontWeight.w800 : FontWeight.w600, color: accent ? AppColors.textPrimary : (bold ? AppColors.textPrimary : AppColors.textSecondary), fontFamily: 'Poppins'))),
          Text('₹$amount', style: TextStyle(fontSize: bold ? 15.sp : 13.sp, fontWeight: bold ? FontWeight.w900 : FontWeight.w700, color: (bold || accent) ? AppColors.primary : AppColors.textPrimary, fontFamily: 'Poppins')),
        ]),
      );

  void _err(String m) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m), backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating));

  /// Builds + posts (or updates) the booking. Returns its id, or null on failure.
  Future<String?> _createBooking() async {
    if (_nameCtrl.text.trim().isEmpty || _mobileCtrl.text.trim().isEmpty) {
      _err('Please enter your name and mobile number');
      return null;
    }
    final t = _trip;
    final notes = <String>[];
    if (t['notes'] != null && (t['notes'] as String).isNotEmpty) notes.add(t['notes'].toString());
    notes.add('Fuel: $_fuel');
    final contact = [_nameCtrl.text.trim(), _mobileCtrl.text.trim(), _emailCtrl.text.trim()].where((s) => s.isNotEmpty).join(', ');
    if (contact.isNotEmpty) notes.add('Contact: $contact');
    if (_isLocal) {
      notes.add('Local $_packageHours-hour package');
    } else if (_isBestPrice) {
      notes.add('Best Price — toll/tax/parking paid directly by rider');
    } else {
      if (_toll > 0) notes.add('Toll included (auto): ₹$_toll');
      if (_inclusions.isNotEmpty) notes.add('All Inclusive: ${_inclusions.join(', ')}');
    }
    // Snapshot the extra-km rate + the included allowance so the driver's GPS km
    // can be billed at trip end. The rider is shown "<billedKm> kms included ·
    // Pay ₹X/km after <billedKm> km" and pays a fare for exactly that distance,
    // so the included allowance IS that billed distance — one-way and round trip
    // alike. (For round trip _billedKm already covers both legs, e.g. 2× the road
    // distance.) Previously this stored `dailyKmLimit × days`, which decoupled the
    // billing baseline from what the rider actually saw and paid for.
    final dailyKm = (_cat['dailyKmLimit'] as num?)?.toInt() ?? 0;
    final extraKmP = (_cat['extraKmPrice'] as num?)?.toInt() ?? 0;
    final includedKm = (extraKmP > 0 && _billedKm > 0) ? _billedKm.round() : 0;
    final body = <String, dynamic>{
      if (!_isEdit) 'serviceType': 'cab',
      if (t['subType'] != null) 'subType': t['subType'],
      'vehicleType': (_cat['name'] ?? 'Cab').toString(),
      'pickup': t['pickup'],
      'pickupCity': t['pickupCity'],
      // Local has no destination.
      if (!_isLocal) 'drop': t['drop'],
      if (!_isLocal) 'dropCity': t['dropCity'],
      if (!_isLocal && t['stops'] is List && (t['stops'] as List).isNotEmpty) 'stops': t['stops'],
      'travelDate': t['travelDate'],
      'travelTime': t['travelTime'],
      if (t['tripEndDate'] != null) 'tripEndDate': t['tripEndDate'],
      if (t['tripEndTime'] != null) 'tripEndTime': t['tripEndTime'],
      'passengers': t['passengers'] ?? 1,
      if (_fare > 0) 'estimatedFare': _fare,
      // Snapshot the breakdown so the driver side can show the fare without GST.
      if (_baseFarePart > 0) 'baseFare': _baseFarePart,
      if (_driverAllowance > 0) 'driverAllowance': _driverAllowance,
      if (_gstAmount > 0) 'gstAmount': _gstAmount,
      // For Local, estimatedDistance holds the package's included km (billedKm).
      if (_distanceKm > 0) 'estimatedDistance': _distanceKm.round()
      else if (_isLocal && _billedKm > 0) 'estimatedDistance': _billedKm.round(),
      if (dailyKm > 0) 'dailyKmLimit': dailyKm,
      if (extraKmP > 0) 'extraKmPrice': extraKmP,
      if (includedKm > 0) 'includedKm': includedKm,
      // Local hourly-package snapshot.
      if (_isLocal) 'durationHours': _packageHours,
      if (_isLocal && _packageHours > 0) 'packageHours': _packageHours,
      if (_isLocal && _extraHourPrice > 0) 'extraHourPrice': _extraHourPrice,
      'notes': notes.join(' • '),
    };
    try {
      final repo = getIt<CustomerRepository>();
      final booking = _isEdit ? await repo.updateBooking(_editId, body) : await repo.createBooking(body);
      final id = (booking['_id'] ?? booking['id'] ?? _editId).toString();
      _pendingHumanId = (booking['bookingId'] ?? '').toString();
      return id.isEmpty ? null : id;
    } catch (e) {
      if (mounted) _err('Could not ${_isEdit ? 'update' : 'book'}: ${serverMessage(e, fallback: 'please try again')}');
      return null;
    }
  }

  /// After confirm/payment: show the "Booking Confirmation" (Thank You) screen
  /// with the full summary — not the raw booking-details page.
  void _goToBooking(String id, String msg) {
    if (!mounted) return;
    final t = _trip;
    final date = (t['travelDate'] ?? '').toString();
    final time = (t['travelTime'] ?? '').toString();
    final exclusions = <String>[
      if (_extraKm > 0) 'Pay ₹$_extraKm/km after ${_billedKm.round()} km',
      if (_isBestPrice) 'Toll, state tax & parking (pay the driver directly)',
      'Multiple pickups / drops',
    ];
    context.go('/customer/cab-confirmed', extra: {
      'name': _nameCtrl.text.trim(),
      'humanId': _pendingHumanId,
      'bookingObjId': id,
      'pickupCity': _cityOf('pickupCity', 'pickup'),
      'totalFare': _fare,
      'tripType': (t['subType'] ?? 'One Way').toString(),
      'dateTime': [if (date.isNotEmpty) _prettyDate(date), if (time.isNotEmpty) time].join(' | '),
      'carType': (_cat['name'] ?? 'Cab').toString(),
      'amountPaid': _payPercent == 0 ? 0 : _advanceRupees(_payPercent),
      'inclusions': _inclusions.isNotEmpty ? _inclusions : const ['Fuel Charges', 'Driver Allowance'],
      'exclusions': exclusions,
      'terms': _effectiveTerms,
    });
  }

  /// Bottom action: create the booking, then navigate (pay later) or take the advance.
  Future<void> _onPayNow() async {
    if (_busy) return;
    setState(() => _busy = true);
    final id = _pendingBookingId ?? await _createBooking();
    if (id == null) { if (mounted) setState(() => _busy = false); return; }
    if (_payPercent == 0) {
      // Pay later: the booking is committed right away — nothing is pending payment.
      _pendingBookingId = null;
      _goToBooking(id, 'Booking confirmed — waiting for a driver to accept');
      return;
    }
    // Advance flow: keep the id so retries reuse it, but it's "pending payment" —
    // if the user cancels/abandons the payment it gets cancelled (see cleanup).
    _pendingBookingId = id;
    if (kIsWeb) {
      if (mounted) setState(() => _busy = false);
      _err('Payments are only supported on the mobile app.');
      return;
    }
    if (mounted) setState(() => _busy = false);
    _showPaymentMethodSheet(id);
  }

  /// Choose how to pay the advance: in-app checkout or a scannable UPI QR.
  Future<void> _showPaymentMethodSheet(String bookingId) async {
    var chosen = false;
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Row(children: [
              Text('Pay ₹${_advanceRupees(_payPercent)} advance', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, fontFamily: 'Poppins')),
              const Spacer(),
              IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
            ]),
          ),
          ListTile(
            leading: CircleAvatar(backgroundColor: AppColors.primary.withValues(alpha: 0.15), child: const Icon(Icons.account_balance_wallet_rounded, color: AppColors.primary)),
            title: const Text('Pay in App', style: TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Poppins')),
            subtitle: const Text('UPI apps, Cards, Netbanking', style: TextStyle(fontSize: 12, fontFamily: 'Poppins')),
            onTap: () { chosen = true; Navigator.pop(ctx); _payInApp(bookingId); },
          ),
          ListTile(
            leading: const CircleAvatar(backgroundColor: Color(0xFFE8F5E9), child: Icon(Icons.qr_code_2_rounded, color: Color(0xFF25D366))),
            title: const Text('Pay by QR', style: TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Poppins')),
            subtitle: const Text('Scan & pay with any UPI app', style: TextStyle(fontSize: 12, fontFamily: 'Poppins')),
            onTap: () { chosen = true; Navigator.pop(ctx); _startQrPayment(bookingId); },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    // Dismissed without picking a method → the user backed out of paying the
    // advance, so cancel the pending booking instead of leaving it live.
    if (!chosen) await _cancelPendingBooking();
  }

  Future<void> _payInApp(String bookingId) async {
    try {
      final res = await getIt<ApiClient>().post('/customer-bookings/$bookingId/advance/order', data: {'percent': _payPercent});
      _openRazorpay(Map<String, dynamic>.from(res.data['data'] as Map));
    } catch (e) {
      // The payment couldn't even start → don't leave a live 0-advance booking.
      await _cancelPendingBooking();
      if (mounted) _err('${serverMessage(e, fallback: 'Could not start payment')}. Booking not placed — tap Pay Now to try again.');
    }
  }

  void _openRazorpay(Map<String, dynamic> order) {
    if (_razorpay == null) return;
    _razorpay!.open({
      'key': order['keyId'] ?? '',
      'amount': order['amount'],
      'currency': order['currency'] ?? 'INR',
      'order_id': order['orderId'],
      'name': 'Gora Cabs',
      'description': 'Booking advance ($_payPercent%)',
      'prefill': {'contact': _mobileCtrl.text.trim(), 'email': _emailCtrl.text.trim(), 'name': _nameCtrl.text.trim()},
      'theme': {'color': '#F97316'},
    });
  }

  Future<void> _onPaymentSuccess(PaymentSuccessResponse r) async {
    // Paid — clear the pending id so the dispose cleanup never cancels a paid booking.
    final id = _pendingBookingId;
    _pendingBookingId = null;
    try {
      await getIt<ApiClient>().post('/customer-bookings/advance/verify', data: {
        'razorpayOrderId': r.orderId, 'razorpayPaymentId': r.paymentId, 'razorpaySignature': r.signature,
      });
    } catch (_) {/* falls back to the Razorpay webhook */}
    if (id != null) _goToBooking(id, '✅ Advance paid — booking confirmed');
  }

  void _onPaymentError(PaymentFailureResponse r) {
    // Payment cancelled/failed → cancel the pending booking so no 0-advance
    // booking is left live. The user can tap Pay Now again to retry.
    _cancelPendingBooking();
    if (mounted) _err('Payment cancelled — booking not placed. Tap Pay Now to try again.');
  }

  Future<void> _startQrPayment(String bookingId) async {
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator(color: AppColors.primary)));
    Map<String, dynamic> data;
    try {
      final res = await getIt<ApiClient>().post('/customer-bookings/$bookingId/advance/qr', data: {'percent': _payPercent});
      data = Map<String, dynamic>.from(res.data['data'] as Map);
    } catch (e) {
      if (mounted) Navigator.pop(context);
      await _cancelPendingBooking(); // QR couldn't be created → don't leave a live booking
      if (mounted) _err('Could not create QR. Booking not placed — tap Pay Now to try again.');
      return;
    }
    if (!mounted) return;
    Navigator.pop(context);
    final paid = await Navigator.of(context).push<bool>(
      MaterialPageRoute(fullscreenDialog: true, builder: (_) => _AdvanceQrPage(data: data)),
    );
    if (paid == true) {
      final id = _pendingBookingId;
      _pendingBookingId = null; // paid — don't let cleanup cancel it
      if (id != null) _goToBooking(id, '✅ Advance paid — booking confirmed');
    } else {
      // QR screen closed without paying → cancel the pending booking.
      await _cancelPendingBooking();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _trip;
    final img = (_cat['imageUrl'] ?? '').toString();
    final from = _cityOf('pickupCity', 'pickup');
    final to = _cityOf('dropCity', 'drop');
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
        centerTitle: true,
        title: Text('Review Your Booking', style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w800, fontFamily: 'Poppins')),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(14.w, 14.h, 14.w, 20.h),
        children: [
          _summaryCard(from, to, sub, img, date, time, returnDate),
          SizedBox(height: 12.h),
          _cancelBanner(),
          SizedBox(height: 12.h),
          _contactCard(),
          SizedBox(height: 12.h),
          _incExcCard(),
          SizedBox(height: 12.h),
          _tcCard(),
        ],
      ),
      bottomNavigationBar: _bottomBar(),
    );
  }

  // ── Trip + cab summary ──────────────────────────────────────────────────────
  Widget _summaryCard(String from, String to, String sub, String img, String date, String time, String returnDate) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16.r), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800, color: AppColors.textPrimary, fontFamily: 'Poppins'),
                    children: [
                      TextSpan(text: _isLocal ? from : (_isRound ? '$from → $to → $from' : '$from → $to')),
                      TextSpan(text: '  (${_titleCase(sub)})', style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ),
              if (img.isNotEmpty) ...[
                SizedBox(width: 8.w),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8.r),
                  child: SizedBox(
                    width: 74.r,
                    child: AspectRatio(
                      aspectRatio: 4 / 3,
                      child: CachedNetworkImage(imageUrl: img, fit: BoxFit.cover, errorWidget: (_, __, ___) => Icon(Icons.directions_car_filled_rounded, size: 30.sp, color: AppColors.primary.withValues(alpha: 0.6))),
                    ),
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: 10.h),
          Divider(height: 1, color: AppColors.border),
          SizedBox(height: 10.h),
          _kv('Car Type', (_cat['name'] ?? 'Cab').toString(), suffix: ' or similar'),
          _kv('Fuel Type', _fuel),
          _kv('Pickup Date', '${_prettyDate(date)}${time.isNotEmpty ? ', $time' : ''}'),
          if (_isLocal) ...[
            _kv('Package', '$_packageHours hours'),
            _kv('Kms included', '${_billedKm.round()} kms'),
            if (_extraHourPrice > 0) _kv('Extra hours', '₹$_extraHourPrice/hr beyond package'),
            if (_extraKm > 0) _kv('Extra km', '₹$_extraKm/km beyond included'),
          ] else ...[
            _kv('Kms included', '${_billedKm.round()} kms'),
            if (_isRound && returnDate.isNotEmpty) _kv('Return', _prettyDate(returnDate)),
          ],
        ],
      ),
    );
  }

  Widget _kv(String label, String value, {String? suffix}) => Padding(
        padding: EdgeInsets.symmetric(vertical: 4.h),
        child: RichText(
          text: TextSpan(
            style: TextStyle(fontSize: 13.sp, fontFamily: 'Poppins', color: AppColors.textPrimary),
            children: [
              TextSpan(text: '$label: ', style: TextStyle(fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
              TextSpan(text: value, style: const TextStyle(fontWeight: FontWeight.w800)),
              if (suffix != null) TextSpan(text: suffix, style: TextStyle(fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
            ],
          ),
        ),
      );

  // ── Contact & pickup details ────────────────────────────────────────────────
  Widget _contactCard() => Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16.r), border: Border.all(color: AppColors.border)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Contact & Pickup Details', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w800, fontFamily: 'Poppins')),
            SizedBox(height: 12.h),
            _field(_nameCtrl, 'Full Name', Icons.person_rounded),
            SizedBox(height: 12.h),
            _field(_mobileCtrl, 'Mobile No.', Icons.phone_rounded, keyboard: TextInputType.phone),
            SizedBox(height: 12.h),
            _field(_emailCtrl, 'Email ID (optional)', Icons.email_rounded, keyboard: TextInputType.emailAddress),
            SizedBox(height: 14.h),
            _readonlyLoc('Pickup Location', Icons.my_location_rounded, AppColors.success, _pickupAddr),
            // Local (in-city hourly) has no fixed drop.
            if (!_isLocal) ...[
              SizedBox(height: 10.h),
              _readonlyLoc('Drop Location', Icons.location_on_rounded, AppColors.error, _dropAddr),
            ],
          ],
        ),
      );

  // Read-only pickup/drop row (locations are fixed from the chosen trip).
  Widget _readonlyLoc(String label, IconData icon, Color color, String value) => Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12.r), border: Border.all(color: AppColors.border)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18.sp, color: color),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 10.5.sp, fontWeight: FontWeight.w600, color: AppColors.textSecondary, fontFamily: 'Poppins')),
                  SizedBox(height: 2.h),
                  Text(value, style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontFamily: 'Poppins')),
                ],
              ),
            ),
            Icon(Icons.lock_outline_rounded, size: 14.sp, color: AppColors.textHint),
          ],
        ),
      );

  Widget _field(TextEditingController c, String label, IconData icon, {TextInputType? keyboard, int maxLines = 1}) => TextField(
        controller: c,
        keyboardType: keyboard,
        maxLines: maxLines,
        style: TextStyle(fontSize: 13.sp, fontFamily: 'Poppins'),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 18.sp, color: AppColors.primary),
          isDense: true,
          filled: true,
          fillColor: Colors.grey[50],
          contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide(color: AppColors.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide(color: AppColors.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: const BorderSide(color: AppColors.primary, width: 1.6)),
        ),
      );

  // ── Free cancellation banner ────────────────────────────────────────────────
  Widget _cancelBanner() => Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
        ),
        child: Row(children: [
          Icon(Icons.access_time_rounded, size: 18.sp, color: AppColors.warning),
          SizedBox(width: 10.w),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 12.5.sp, color: AppColors.textPrimary, fontFamily: 'Poppins'),
                children: const [
                  TextSpan(text: 'Free cancellation till '),
                  TextSpan(text: '1 hour', style: TextStyle(fontWeight: FontWeight.w800)),
                  TextSpan(text: ' before departure.'),
                ],
              ),
            ),
          ),
        ]),
      );

  // ── Inclusions / Exclusions ─────────────────────────────────────────────────
  Widget _incExcCard() {
    final inclusions = _inclusions.isNotEmpty ? _inclusions : const ['Fuel Charges', 'Driver Allowance'];
    final exclusions = <String>[
      if (_extraKm > 0) 'Pay ₹$_extraKm/km after ${_billedKm.round()} km',
      if (_isBestPrice) 'Toll, state tax & parking (pay the driver directly)',
      'Multiple pickups / drops',
    ];
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16.r), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Inclusions / Exclusions', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w800, fontFamily: 'Poppins')),
          SizedBox(height: 10.h),
          Row(children: [
            Icon(Icons.circle, size: 8.sp, color: AppColors.success),
            SizedBox(width: 6.w),
            Text('Inclusions', style: TextStyle(fontSize: 12.5.sp, fontWeight: FontWeight.w800, color: AppColors.success, fontFamily: 'Poppins')),
          ]),
          SizedBox(height: 6.h),
          ...inclusions.map((e) => _bulletLine(Icons.check_circle_rounded, AppColors.success, e)),
          SizedBox(height: 10.h),
          Row(children: [
            Icon(Icons.circle, size: 8.sp, color: AppColors.primary),
            SizedBox(width: 6.w),
            Text('Exclusions', style: TextStyle(fontSize: 12.5.sp, fontWeight: FontWeight.w800, color: AppColors.primary, fontFamily: 'Poppins')),
          ]),
          SizedBox(height: 6.h),
          ...exclusions.map((e) => _bulletLine(Icons.cancel_rounded, AppColors.primary, e)),
        ],
      ),
    );
  }

  Widget _bulletLine(IconData icon, Color color, String text) => Padding(
        padding: EdgeInsets.symmetric(vertical: 4.h),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 15.sp, color: color),
          SizedBox(width: 8.w),
          Expanded(child: Text(text, style: TextStyle(fontSize: 12.5.sp, color: AppColors.textPrimary, fontFamily: 'Poppins'))),
        ]),
      );

  // ── Terms & Conditions (expandable) ─────────────────────────────────────────
  Widget _tcCard() => Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16.r), border: Border.all(color: AppColors.border)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => setState(() => _tcOpen = !_tcOpen),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 10.h),
                child: Row(children: [
                  Icon(Icons.description_rounded, size: 18.sp, color: AppColors.primary),
                  SizedBox(width: 8.w),
                  Expanded(child: Text('Terms & Conditions', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w800, fontFamily: 'Poppins'))),
                  Icon(_tcOpen ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: AppColors.info, size: 22.sp),
                ]),
              ),
            ),
            if (_tcOpen) ...[
              Divider(height: 1, color: AppColors.border),
              SizedBox(height: 8.h),
              ..._effectiveTerms.map((e) => Padding(
                    padding: EdgeInsets.only(bottom: 8.h),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('•  ', style: TextStyle(fontSize: 13.sp, color: AppColors.textSecondary, fontFamily: 'Poppins')),
                      Expanded(child: Text(e, style: TextStyle(fontSize: 12.5.sp, height: 1.4, color: AppColors.textPrimary, fontFamily: 'Poppins'))),
                    ]),
                  )),
              SizedBox(height: 6.h),
            ],
          ],
        ),
      );

  // ── Bottom: Total Fare row on top, then options + Pay Now below ─────────────
  Widget _bottomBar() {
    final due = _payPercent == 0 ? 0 : _advanceRupees(_payPercent);
    final showOptions = !_isEdit && _fare > 0;
    return Container(
      decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: AppColors.border))),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Total Fare — tap the label/info to see the full breakdown.
            InkWell(
              onTap: _fare > 0 ? _showFareBreakdown : null,
              child: Padding(
                padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 10.h),
                child: Row(
                  children: [
                    Text('Total Fare', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontFamily: 'Poppins')),
                    SizedBox(width: 5.w),
                    Icon(Icons.info_outline_rounded, size: 15.sp, color: AppColors.primary),
                    const Spacer(),
                    Text(_fare > 0 ? '₹$_fare' : 'On request', style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w800, color: AppColors.textPrimary, fontFamily: 'Poppins')),
                  ],
                ),
              ),
            ),
            Divider(height: 1, color: AppColors.border),
            // Options (Book at ₹0 / Pay 10% / Pay 100%) + the Pay Now button.
            Padding(
              padding: EdgeInsets.fromLTRB(10.w, 10.h, 10.w, 10.h),
              child: Row(
                children: [
                  if (showOptions) ...[
                    Expanded(flex: 3, child: _payChip(0, 'Book at ₹0', 'Pay later')),
                    SizedBox(width: 6.w),
                    Expanded(flex: 3, child: _payChip(10, 'Pay 10%', '₹${_advanceRupees(10)} now')),
                    SizedBox(width: 6.w),
                    Expanded(flex: 3, child: _payChip(100, 'Pay 100%', '₹$_fare')),
                    SizedBox(width: 8.w),
                  ],
                  Expanded(
                    flex: showOptions ? 4 : 1,
                    child: SizedBox(
                      height: 54.h,
                      child: ElevatedButton(
                        onPressed: _busy ? null : _onPayNow,
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, disabledBackgroundColor: AppColors.textHint, elevation: 0, padding: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r))),
                        child: _busy
                            ? SizedBox(width: 20.w, height: 20.w, child: const CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                            : Column(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _isEdit ? 'SAVE' : (_payPercent == 0 ? 'CONFIRM' : 'Pay Now'),
                                    style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w800, letterSpacing: 0.3, fontFamily: 'Poppins'),
                                  ),
                                  if (showOptions && _payPercent != 0)
                                    Text('₹$due', style: TextStyle(fontSize: 11.5.sp, fontWeight: FontWeight.w700, fontFamily: 'Poppins')),
                                ],
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// One advance-payment option card (Book at ₹0 / Pay 10% / Pay 100%).
  Widget _payChip(int percent, String title, String sub) {
    final sel = _payPercent == percent;
    return GestureDetector(
      onTap: () => setState(() => _payPercent = percent),
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 54.h,
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(horizontal: 3.w),
        decoration: BoxDecoration(
          color: sel ? AppColors.primary.withValues(alpha: 0.10) : Colors.white,
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(color: sel ? AppColors.primary : AppColors.border, width: sel ? 1.5 : 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w800, color: sel ? AppColors.primary : AppColors.textPrimary, fontFamily: 'Poppins')),
            SizedBox(height: 2.h),
            Text(sub, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 8.5.sp, fontWeight: FontWeight.w600, color: sel ? AppColors.primary : AppColors.textSecondary, fontFamily: 'Poppins')),
          ],
        ),
      ),
    );
  }

  String _titleCase(String s) => s.isEmpty ? s : s;

  /// "2026-09-25" → "25 Sep"; falls back to the raw string if unexpected.
  String _prettyDate(String d) {
    final p = d.split('-');
    if (p.length == 3) {
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final m = int.tryParse(p[1]) ?? 0;
      if (m >= 1 && m <= 12) return '${p[2]} ${months[m - 1]}';
    }
    return d;
  }
}

/// Full-screen UPI QR for the booking advance. Polls the backend until the
/// payment is credited (out-of-band via the qr_code.credited webhook / reconcile),
/// stops after 15 minutes. Pops `true` when paid; close (✕) = cancel.
class _AdvanceQrPage extends StatefulWidget {
  final Map<String, dynamic> data;
  const _AdvanceQrPage({required this.data});

  @override
  State<_AdvanceQrPage> createState() => _AdvanceQrPageState();
}

class _AdvanceQrPageState extends State<_AdvanceQrPage> {
  Timer? _timer;
  bool _checking = false;
  int _elapsed = 0;
  static const _timeoutSeconds = 15 * 60;

  String get _paymentId => '${widget.data['paymentId']}';

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) => _poll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    if (_checking) return;
    _elapsed += 4;
    if (_elapsed >= _timeoutSeconds) {
      _timer?.cancel();
      return;
    }
    _checking = true;
    try {
      final res = await getIt<ApiClient>().get('/customer-bookings/advance/status/$_paymentId');
      if ((res.data['data']?['paid'] == true) && mounted) {
        _timer?.cancel();
        Navigator.pop(context, true);
        return;
      }
    } catch (_) {
      // transient — keep polling
    } finally {
      _checking = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = widget.data['imageUrl'] as String?;
    final rupees = widget.data['rupees'];
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0.5,
        title: Text('Scan & Pay${rupees != null ? '  ₹$rupees' : ''}', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800, fontFamily: 'Poppins')),
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context, false)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(16.w),
                child: (imageUrl != null && imageUrl.isNotEmpty)
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.contain,
                        loadingBuilder: (c, w, p) => p == null ? w : const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                        errorBuilder: (c, e, s) => const Center(child: Text('Could not load QR')),
                      )
                    : const Center(child: Text('QR unavailable')),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 16.h),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                SizedBox(width: 16.w, height: 16.w, child: const CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
                SizedBox(width: 10.w),
                Text('Waiting for payment…', style: TextStyle(fontSize: 13.sp, color: AppColors.textSecondary, fontFamily: 'Poppins')),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
