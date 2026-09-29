import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/injection.dart';
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
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _mobileCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Map<String, dynamic> get _trip => Map<String, dynamic>.from(widget.data['trip'] as Map? ?? {});
  Map<String, dynamic> get _cat => Map<String, dynamic>.from(widget.data['cat'] as Map? ?? {});
  String get _fuel => (widget.data['fuel'] ?? 'Petrol').toString();
  double get _distanceKm => (widget.data['distanceKm'] as num?)?.toDouble() ?? 0;
  double get _billedKm => (widget.data['billedKm'] as num?)?.toDouble() ?? _distanceKm;
  int get _fare => (widget.data['fare'] as num?)?.toInt() ?? 0;
  bool get _isRound => widget.data['isRound'] == true;
  String get _editId => (widget.data['bookingId'] ?? '').toString();
  bool get _isEdit => _editId.isNotEmpty;
  List<String> get _inclusions => ((widget.data['inclusions'] as List?) ?? []).map((e) => e.toString()).toList();
  int get _toll => (widget.data['toll'] as num?)?.toInt() ?? 0;
  String get _incMode => (widget.data['incMode'] ?? 'All Inclusive').toString();
  bool get _isBestPrice => _incMode == 'Best Price';
  int get _extraKm => (_cat['extraKmPrice'] as num?)?.toInt() ?? 0;
  List<String> get _terms => ((_cat['terms'] as List?) ?? []).map((e) => e.toString()).toList();

  String _cityOf(String cityKey, String addrKey) {
    final t = _trip;
    final city = (t[cityKey] ?? '').toString().trim();
    if (city.isNotEmpty) return city.split(',').first.trim();
    final addr = ((t[addrKey] as Map?)?['address'] ?? '').toString().trim();
    return addr.isEmpty ? '—' : addr.split(',').first.trim();
  }

  Future<void> _confirm() async {
    if (_busy) return;
    void err(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating));
    if (_nameCtrl.text.trim().isEmpty || _mobileCtrl.text.trim().isEmpty) {
      err('Please enter your name and mobile number');
      return;
    }
    setState(() => _busy = true);
    final t = _trip;
    final notes = <String>[];
    if (t['notes'] != null && (t['notes'] as String).isNotEmpty) notes.add(t['notes'].toString());
    notes.add('Fuel: $_fuel');
    final contact = [_nameCtrl.text.trim(), _mobileCtrl.text.trim(), _emailCtrl.text.trim()].where((s) => s.isNotEmpty).join(', ');
    if (contact.isNotEmpty) notes.add('Contact: $contact');
    if (_isBestPrice) {
      notes.add('Best Price — toll/tax/parking paid directly by rider');
    } else {
      if (_toll > 0) notes.add('Toll included (auto): ₹$_toll');
      if (_inclusions.isNotEmpty) notes.add('All Inclusive: ${_inclusions.join(', ')}');
    }
    // Round-trip rental: snapshot the cab's per-day km limit + extra ₹/km and the
    // included allowance (km/day × days) so the driver's GPS km can be billed.
    final dailyKm = (_cat['dailyKmLimit'] as num?)?.toInt() ?? 0;
    final extraKmP = (_cat['extraKmPrice'] as num?)?.toInt() ?? 0;
    int days = 1;
    if (_isRound) {
      final rd = DateTime.tryParse((t['returnDate'] ?? '').toString());
      final sd = DateTime.tryParse((t['travelDate'] ?? '').toString());
      if (rd != null && sd != null) {
        days = (DateTime(rd.year, rd.month, rd.day).difference(DateTime(sd.year, sd.month, sd.day)).inDays + 1).clamp(1, 60);
      }
    }
    final includedKm = (_isRound && dailyKm > 0) ? dailyKm * days : 0;
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
      if (dailyKm > 0) 'dailyKmLimit': dailyKm,
      if (extraKmP > 0) 'extraKmPrice': extraKmP,
      if (includedKm > 0) 'includedKm': includedKm,
      'notes': notes.join(' • '),
    };
    try {
      final repo = getIt<CustomerRepository>();
      final booking = _isEdit ? await repo.updateBooking(_editId, body) : await repo.createBooking(body);
      if (!mounted) return;
      final id = (booking['_id'] ?? booking['id'] ?? _editId).toString();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_isEdit ? 'Booking updated' : 'Booking confirmed — waiting for a driver to accept'),
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
          if (_terms.isNotEmpty) ...[
            SizedBox(height: 12.h),
            _tcCard(),
          ],
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
                      TextSpan(text: '$from → $to'),
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
          _kv('Kms included', '${_billedKm.round()} kms'),
          if (_isRound && returnDate.isNotEmpty) _kv('Return', _prettyDate(returnDate)),
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
            SizedBox(height: 10.h),
            _readonlyLoc('Drop Location', Icons.location_on_rounded, AppColors.error, _dropAddr),
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
                  Expanded(child: Text('Read Terms and Conditions', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w800, fontFamily: 'Poppins'))),
                  Icon(_tcOpen ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: AppColors.info, size: 22.sp),
                ]),
              ),
            ),
            if (_tcOpen) ...[
              Divider(height: 1, color: AppColors.border),
              SizedBox(height: 8.h),
              ..._terms.map((e) => Padding(
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

  // ── Bottom: total fare + confirm ────────────────────────────────────────────
  Widget _bottomBar() => Container(
        decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: AppColors.border))),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(14.w, 10.h, 14.w, 10.h),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Total Fare', style: TextStyle(fontSize: 11.sp, color: AppColors.textSecondary, fontFamily: 'Poppins')),
                    Text(_fare > 0 ? '₹$_fare' : 'On request', style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w800, color: AppColors.textPrimary, fontFamily: 'Poppins')),
                  ],
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: SizedBox(
                    height: 50.h,
                    child: ElevatedButton(
                      onPressed: _busy ? null : _confirm,
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, disabledBackgroundColor: AppColors.textHint, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r))),
                      child: _busy
                          ? SizedBox(width: 22.w, height: 22.w, child: const CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                          : Text(_isEdit ? 'SAVE BOOKING' : 'CONFIRM BOOKING', style: TextStyle(fontSize: 14.5.sp, fontWeight: FontWeight.w800, letterSpacing: 0.4, fontFamily: 'Poppins')),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

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
