import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/contact_launcher.dart';
import '../../../../core/widgets/address_autocomplete_field.dart';
import '../../data/customer_repository.dart';
import '../widgets/booking_card_ui.dart';

/// One generic booking form that adapts to the chosen service. New services
/// only need an entry in [_meta] — the form fields switch on flags there.
class CustomerBookingFormPage extends StatefulWidget {
  final String serviceType; // cab | hire_driver | luxury | car_pool
  /// When set, the form edits this OPEN booking instead of creating a new one.
  final String? bookingId;
  final Map<String, dynamic>? existing;
  const CustomerBookingFormPage({super.key, required this.serviceType, this.bookingId, this.existing});

  @override
  State<CustomerBookingFormPage> createState() => _CustomerBookingFormPageState();
}

class _ServiceMeta {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool needsDrop; // drop location required
  final bool needsDuration; // hire-a-driver style (hours)
  final bool needsPassengers;
  final List<String> subTypes; // chips; empty = none
  final List<String> vehicles; // vehicle categories; empty = no vehicle picker
  const _ServiceMeta(this.title, this.subtitle, this.icon,
      {this.needsDrop = true, this.needsDuration = false, this.needsPassengers = true, this.subTypes = const [], this.vehicles = const []});
}

const _meta = <String, _ServiceMeta>{
  'cab': _ServiceMeta('Cabs Booking', 'Book a taxi to your destination', Icons.local_taxi_rounded,
      subTypes: ['One Way', 'Round Trip', 'Local', 'Airport'], vehicles: ['Sedan', 'SUV', 'Hatchback', 'Any']),
  'hire_driver': _ServiceMeta('Hire a Driver', 'A driver for your own car', Icons.badge_rounded,
      needsDrop: false, needsDuration: true, needsPassengers: false, subTypes: ['Hourly', 'Full Day', 'Outstation', 'Local']),
  'luxury': _ServiceMeta('Luxury Car', 'Premium cars for every occasion', Icons.workspace_premium_rounded,
      subTypes: ['Sedan', 'SUV', 'Wedding', 'Event'], vehicles: ['Luxury Sedan', 'Luxury SUV', 'Premium', 'Any']),
  'car_pool': _ServiceMeta('Car Pooling', 'Share a ride on your route', Icons.groups_rounded, subTypes: []),
};

/// One intermediate stop on the route (cab layout "Add stops").
class _StopField {
  final TextEditingController ctrl = TextEditingController();
  double? lat, lng;
  String? city;
}

class _CustomerBookingFormPageState extends State<CustomerBookingFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _pickupCtrl = TextEditingController();
  final _dropCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _fareCtrl = TextEditingController();
  final List<_StopField> _stops = [];

  double? _pickupLat, _pickupLng, _dropLat, _dropLng;
  String? _pickupCity, _dropCity;
  DateTime _date = DateTime.now();
  TimeOfDay _time = TimeOfDay.now();
  int _passengers = 1;
  int _durationHours = 4;
  String? _subType;
  String? _vehicle;
  DateTime? _returnDate; // round-trip return (cab layout)
  bool _busy = false;

  // Accent colour for the cab layout (orange to match the app brand).
  static const _teal = AppColors.primary;

  _ServiceMeta get _m => _meta[widget.serviceType] ?? const _ServiceMeta('Booking', '', Icons.directions_car_rounded);

  bool get _isEdit => widget.bookingId != null;

  @override
  void initState() {
    super.initState();
    if (_m.subTypes.isNotEmpty) _subType = _m.subTypes.first;
    if (_m.vehicles.isNotEmpty) _vehicle = _m.vehicles.first;
    // Pre-fill from the existing booking when editing.
    final e = widget.existing;
    if (e != null) {
      _pickupCtrl.text = ((e['pickup'] as Map?)?['address'] ?? '').toString();
      _pickupLat = ((e['pickup'] as Map?)?['lat'] as num?)?.toDouble();
      _pickupLng = ((e['pickup'] as Map?)?['lng'] as num?)?.toDouble();
      _pickupCity = (e['pickupCity'] ?? '').toString();
      _dropCtrl.text = ((e['drop'] as Map?)?['address'] ?? '').toString();
      _dropLat = ((e['drop'] as Map?)?['lat'] as num?)?.toDouble();
      _dropLng = ((e['drop'] as Map?)?['lng'] as num?)?.toDouble();
      _dropCity = (e['dropCity'] ?? '').toString();
      final st = (e['subType'] ?? '').toString();
      if (st.isNotEmpty && _m.subTypes.contains(st)) _subType = st;
      final vt = (e['vehicleType'] ?? '').toString();
      if (vt.isNotEmpty && _m.vehicles.contains(vt)) _vehicle = vt;
      _passengers = (e['passengers'] as num?)?.toInt() ?? _passengers;
      _durationHours = (e['durationHours'] as num?)?.toInt() ?? _durationHours;
      if ((e['estimatedFare'] ?? 0) != 0) _fareCtrl.text = e['estimatedFare'].toString();
      _notesCtrl.text = (e['notes'] ?? '').toString();
      final d = tripDate(e['travelDate']);
      if (d != null) _date = d;
    }
  }

  @override
  void dispose() {
    _pickupCtrl.dispose();
    _dropCtrl.dispose();
    _notesCtrl.dispose();
    _fareCtrl.dispose();
    for (final s in _stops) {
      s.ctrl.dispose();
    }
    super.dispose();
  }

  void _addStop() {
    if (_stops.length >= 3) {
      _snack('You can add up to 3 stops');
      return;
    }
    setState(() => _stops.add(_StopField()));
  }

  void _removeStop(int i) {
    final s = _stops[i];
    setState(() => _stops.removeAt(i));
    WidgetsBinding.instance.addPostFrameCallback((_) => s.ctrl.dispose());
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 180)),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: _time);
    if (t != null) setState(() => _time = t);
  }

  /// Trip-start picker used by the cab layout — date then time in one flow.
  Future<void> _pickDateTime() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 180)),
    );
    if (d == null) return;
    if (!mounted) return;
    final t = await showTimePicker(context: context, initialTime: _time);
    setState(() {
      _date = d;
      if (t != null) _time = t;
    });
  }

  Future<void> _pickReturnDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _returnDate ?? _date.add(const Duration(days: 1)),
      firstDate: _date,
      lastDate: DateTime.now().add(const Duration(days: 180)),
    );
    if (d != null) setState(() => _returnDate = d);
  }

  // Cab "Explore Cabs": validate the route, then open the fare-estimate results
  // screen (the booking is created there when the customer picks a cab + Book Now).
  void _exploreCabs() {
    if (_pickupCtrl.text.trim().isEmpty || _dropCtrl.text.trim().isEmpty) {
      _snack('Please select From and To locations');
      return;
    }
    final trip = <String, dynamic>{
      'subType': _subType,
      'pickup': {'address': _pickupCtrl.text.trim(), 'lat': _pickupLat ?? 0, 'lng': _pickupLng ?? 0},
      'pickupCity': _pickupCity,
      'drop': {'address': _dropCtrl.text.trim(), 'lat': _dropLat ?? 0, 'lng': _dropLng ?? 0},
      'dropCity': _dropCity,
      'travelDate': ymdString(_date),
      'travelTime': _time.format(context),
      'passengers': _passengers,
      if (_subType == 'Round Trip' && _returnDate != null) 'notes': 'Return date: ${DateFormat('dd-MM-yyyy').format(_returnDate!)}',
    };
    context.push('/customer/cab-results', extra: trip);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_pickupCtrl.text.trim().isEmpty) {
      _snack('Please select a pickup location');
      return;
    }
    if (_m.needsDrop && _dropCtrl.text.trim().isEmpty) {
      _snack('Please select a drop location');
      return;
    }
    setState(() => _busy = true);
    // Round-trip return date is carried in notes so it works without a backend
    // schema change (notes is already whitelisted server-side).
    final notes = <String>[];
    if (_notesCtrl.text.trim().isNotEmpty) notes.add(_notesCtrl.text.trim());
    final stopTexts = _stops.map((s) => s.ctrl.text.trim()).where((t) => t.isNotEmpty).toList();
    if (stopTexts.isNotEmpty) notes.add('Via: ${stopTexts.join(', ')}');
    if (_subType == 'Round Trip' && _returnDate != null) {
      notes.add('Return date: ${DateFormat('dd-MM-yyyy').format(_returnDate!)}');
    }
    final body = <String, dynamic>{
      'serviceType': widget.serviceType,
      if (_subType != null) 'subType': _subType,
      if (_vehicle != null) 'vehicleType': _vehicle,
      'pickup': {'address': _pickupCtrl.text.trim(), 'lat': _pickupLat ?? 0, 'lng': _pickupLng ?? 0},
      'pickupCity': _pickupCity,
      if (_m.needsDrop) 'drop': {'address': _dropCtrl.text.trim(), 'lat': _dropLat ?? 0, 'lng': _dropLng ?? 0},
      if (_m.needsDrop) 'dropCity': _dropCity,
      'travelDate': ymdString(_date),
      'travelTime': _time.format(context),
      if (_m.needsPassengers) 'passengers': _passengers,
      if (_m.needsDuration) 'durationHours': _durationHours,
      if (_fareCtrl.text.trim().isNotEmpty) 'estimatedFare': num.tryParse(_fareCtrl.text.trim()),
      if (notes.isNotEmpty) 'notes': notes.join(' • '),
    };
    try {
      final repo = getIt<CustomerRepository>();
      final booking = _isEdit
          ? await repo.updateBooking(widget.bookingId!, body)
          : await repo.createBooking(body);
      if (!mounted) return;
      final id = (booking['_id'] ?? booking['id'] ?? widget.bookingId ?? '').toString();
      _snack(_isEdit ? 'Booking updated — drivers will re-send offers' : 'Request posted — drivers will start sending offers', ok: true);
      context.go('/customer/bookings/$id');
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _snack(_isEdit ? 'Could not update: $e' : 'Could not post request: $e');
      }
    }
  }

  void _snack(String m, {bool ok = false}) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m), backgroundColor: ok ? AppColors.success : AppColors.error, behavior: SnackBarBehavior.floating));

  @override
  Widget build(BuildContext context) {
    // The cab service uses the dedicated "Outstation Cabs" layout for new bookings.
    if (widget.serviceType == 'cab' && !_isEdit) return _buildCab();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Booking' : _m.title, style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 17.sp)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      bottomNavigationBar: _bottomBar(),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 20.h),
          children: [
            _hero(),
            SizedBox(height: 16.h),

            if (_m.subTypes.isNotEmpty)
              _card('Trip Type', Icons.tune_rounded, _chips(_m.subTypes, _subType, (v) => setState(() => _subType = v))),

            if (_m.vehicles.isNotEmpty)
              _card('Vehicle', Icons.directions_car_rounded, _chips(_m.vehicles, _vehicle, (v) => setState(() => _vehicle = v))),

            _card(
              'Route',
              Icons.route_rounded,
              Column(
                children: [
                  AddressAutocompleteField(
                    controller: _pickupCtrl,
                    label: 'Pickup location',
                    prefixIcon: Icons.my_location_rounded,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    onSelected: (a, lat, lng, city) { _pickupLat = lat; _pickupLng = lng; _pickupCity = city; },
                  ),
                  if (_m.needsDrop) ...[
                    SizedBox(height: 12.h),
                    AddressAutocompleteField(
                      controller: _dropCtrl,
                      label: 'Drop location',
                      prefixIcon: Icons.location_on_rounded,
                      onSelected: (a, lat, lng, city) { _dropLat = lat; _dropLng = lng; _dropCity = city; },
                    ),
                  ],
                ],
              ),
            ),

            _card(
              'When',
              Icons.schedule_rounded,
              Row(
                children: [
                  Expanded(child: _tile(Icons.calendar_today_rounded, 'Date', DateFormat('EEE, d MMM').format(_date), _pickDate)),
                  SizedBox(width: 12.w),
                  Expanded(child: _tile(Icons.access_time_rounded, 'Time', _time.format(context), _pickTime)),
                ],
              ),
            ),

            _card(
              'Details',
              Icons.list_alt_rounded,
              Column(
                children: [
                  if (_m.needsPassengers) _stepper('Passengers', Icons.people_rounded, _passengers, (v) => setState(() => _passengers = v), min: 1, max: 10),
                  if (_m.needsDuration) _stepper('Duration (hours)', Icons.timelapse_rounded, _durationHours, (v) => setState(() => _durationHours = v), min: 1, max: 24),
                  if (_m.needsPassengers || _m.needsDuration) SizedBox(height: 12.h),
                  TextFormField(
                    controller: _fareCtrl,
                    keyboardType: TextInputType.number,
                    style: TextStyle(fontSize: 14.sp),
                    decoration: _dec('Your budget / offer fare (optional)', Icons.currency_rupee_rounded),
                  ),
                  SizedBox(height: 12.h),
                  TextFormField(
                    controller: _notesCtrl,
                    maxLines: 3,
                    style: TextStyle(fontSize: 14.sp),
                    decoration: _dec('Notes for the driver (optional)', Icons.notes_rounded),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Building blocks ──────────────────────────────────────────────────────

  Widget _hero() => Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Container(
              width: 46.w, height: 46.w,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), shape: BoxShape.circle),
              child: Icon(_m.icon, color: Colors.white, size: 26.sp),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_m.title, style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.w800, fontFamily: 'Poppins')),
                  SizedBox(height: 2.h),
                  Text(_m.subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12.sp, fontFamily: 'Poppins')),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _card(String title, IconData icon, Widget child) => Container(
        margin: EdgeInsets.only(bottom: 14.h),
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: AppColors.border),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 16.sp, color: AppColors.primary),
              SizedBox(width: 6.w),
              Text(title, style: TextStyle(fontSize: 13.5.sp, fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontFamily: 'Poppins')),
            ]),
            SizedBox(height: 12.h),
            child,
          ],
        ),
      );

  Widget _chips(List<String> options, String? selected, ValueChanged<String> onTap) => Wrap(
        spacing: 8.w,
        runSpacing: 8.h,
        children: options.map((o) {
          final sel = selected == o;
          return GestureDetector(
            onTap: () => onTap(o),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 9.h),
              decoration: BoxDecoration(
                color: sel ? AppColors.primary : AppColors.background,
                borderRadius: BorderRadius.circular(30.r),
                border: Border.all(color: sel ? AppColors.primary : AppColors.border, width: 1.3),
              ),
              child: Text(o, style: TextStyle(
                fontSize: 13.sp,
                fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                color: sel ? Colors.white : AppColors.textSecondary,
                fontFamily: 'Poppins',
              )),
            ),
          );
        }).toList(),
      );

  Widget _tile(IconData icon, String label, String value, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.r),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18.sp, color: AppColors.primary),
              SizedBox(width: 8.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: TextStyle(fontSize: 10.5.sp, color: AppColors.textHint, fontFamily: 'Poppins')),
                    SizedBox(height: 1.h),
                    Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, fontFamily: 'Poppins')),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  Widget _stepper(String label, IconData icon, int value, ValueChanged<int> onChanged, {required int min, required int max}) => Container(
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18.sp, color: AppColors.primary),
            SizedBox(width: 8.w),
            Expanded(child: Text(label, style: TextStyle(fontSize: 13.5.sp, fontWeight: FontWeight.w600, fontFamily: 'Poppins'))),
            _roundBtn(Icons.remove_rounded, value > min ? () => onChanged(value - 1) : null),
            Container(
              width: 34.w,
              alignment: Alignment.center,
              child: Text('$value', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800, fontFamily: 'Poppins')),
            ),
            _roundBtn(Icons.add_rounded, value < max ? () => onChanged(value + 1) : null),
          ],
        ),
      );

  Widget _roundBtn(IconData icon, VoidCallback? onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20.r),
        child: Container(
          width: 30.w, height: 30.w,
          decoration: BoxDecoration(
            color: onTap == null ? AppColors.border.withValues(alpha: 0.4) : AppColors.primary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18.sp, color: onTap == null ? AppColors.textHint : AppColors.primary),
        ),
      );

  InputDecoration _dec(String label, IconData icon) => InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: 13.sp, color: AppColors.textSecondary),
        prefixIcon: Icon(icon, color: AppColors.primary, size: 20.sp),
        filled: true,
        fillColor: AppColors.background,
        contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: const BorderSide(color: AppColors.primary, width: 1.6)),
      );

  Widget _bottomBar() => Container(
        padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 12.h),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: const Border(top: BorderSide(color: AppColors.border)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -2))],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                height: 52.h,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: _busy ? null : const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
                    color: _busy ? AppColors.textHint : null,
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                  child: ElevatedButton.icon(
                    onPressed: _busy ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
                    ),
                    icon: _busy ? const SizedBox.shrink() : Icon(Icons.send_rounded, size: 18.sp),
                    label: _busy
                        ? SizedBox(width: 22.w, height: 22.w, child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(_isEdit ? 'Save Changes' : 'Post Request', style: TextStyle(fontSize: 15.5.sp, fontWeight: FontWeight.w700, fontFamily: 'Poppins')),
                  ),
                ),
              ),
              SizedBox(height: 6.h),
              Text('Drivers near you send offers — you pick one. No upfront payment.',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 11.sp, color: AppColors.textSecondary, fontFamily: 'Poppins')),
            ],
          ),
        ),
      );

  // ══════════════════════════════════════════════════════════════════════════
  // Dedicated "Outstation Cabs" layout (cab service, new bookings)
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildCab() {
    final isRound = _subType == 'Round Trip';
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0.5,
        centerTitle: true,
        title: Text('Cab Booking', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 18.sp)),
      ),
      bottomNavigationBar: _homeBottomNav(),
      body: ListView(
        padding: EdgeInsets.fromLTRB(14.w, 14.h, 14.w, 20.h),
        children: [
          _cabCard(isRound),
          SizedBox(height: 16.h),
          _promoRow(),
          SizedBox(height: 14.h),
          _travelExpert(),
        ],
      ),
    );
  }

  Widget _cabCard(bool isRound) => Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(color: AppColors.border),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(width: 26.w, height: 2, color: _teal),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.w),
                  child: Text("INDIA'S PREMIER INTERCITY CABS",
                      style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w700, color: _teal, letterSpacing: 0.3, fontFamily: 'Poppins')),
                ),
                Container(width: 26.w, height: 2, color: _teal),
              ],
            ),
            SizedBox(height: 14.h),
            _tripTypeTabs(),
            SizedBox(height: 14.h),
            // FROM / TO
            Column(
              children: [
                AddressAutocompleteField(
                  controller: _pickupCtrl,
                  label: 'From',
                  prefixIcon: Icons.location_on_rounded,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  onSelected: (a, lat, lng, city) { _pickupLat = lat; _pickupLng = lng; _pickupCity = city; },
                ),
                for (int i = 0; i < _stops.length; i++) ...[
                  SizedBox(height: 10.h),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: AddressAutocompleteField(
                          controller: _stops[i].ctrl,
                          label: 'Stop ${i + 1}',
                          prefixIcon: Icons.more_vert_rounded,
                          onSelected: (a, lat, lng, city) { _stops[i].lat = lat; _stops[i].lng = lng; _stops[i].city = city; },
                        ),
                      ),
                      IconButton(
                        onPressed: () => _removeStop(i),
                        icon: Icon(Icons.close_rounded, color: AppColors.error, size: 20.sp),
                        tooltip: 'Remove stop',
                      ),
                    ],
                  ),
                ],
                SizedBox(height: 10.h),
                AddressAutocompleteField(
                  controller: _dropCtrl,
                  label: 'To',
                  prefixIcon: Icons.location_on_rounded,
                  onSelected: (a, lat, lng, city) { _dropLat = lat; _dropLng = lng; _dropCity = city; },
                ),
              ],
            ),
            SizedBox(height: 14.h),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _addStop,
                icon: Icon(Icons.add, size: 16.sp, color: _teal),
                label: Text('ADD STOPS', style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700, color: _teal, fontFamily: 'Poppins')),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: _teal, width: 1.3), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)), padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h)),
              ),
            ),
            SizedBox(height: 14.h),
            _dtBox('TRIP START', Icons.calendar_today_rounded, DateFormat('dd-MM-yyyy').format(_date), _time.format(context), _pickDateTime),
            if (isRound) ...[
              SizedBox(height: 12.h),
              _dtBox('RETURN', Icons.event_repeat_rounded, _returnDate == null ? 'Select return date' : DateFormat('dd-MM-yyyy').format(_returnDate!), null, _pickReturnDate),
            ],
            SizedBox(height: 16.h),
            SizedBox(
              width: double.infinity,
              height: 52.h,
              child: ElevatedButton(
                onPressed: _exploreCabs,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.textHint,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                ),
                child: Text('EXPLORE CABS', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800, letterSpacing: 0.5, fontFamily: 'Poppins')),
              ),
            ),
          ],
        ),
      );

  // Trip-type selector at the TOP of the card (One Way / Round Trip / Local / Airport).
  Widget _tripTypeTabs() {
    const types = [
      ('One Way', Icons.trending_flat_rounded),
      ('Round Trip', Icons.sync_rounded),
      ('Local', Icons.location_city_rounded),
    ];
    return Container(
      padding: EdgeInsets.all(4.r),
      decoration: BoxDecoration(color: const Color(0xFFEFF3F6), borderRadius: BorderRadius.circular(12.r), border: Border.all(color: AppColors.border)),
      child: Row(
        children: types.map((t) {
          final sel = _subType == t.$1;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() {
                _subType = t.$1;
                if (t.$1 != 'Round Trip') _returnDate = null;
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 2.w),
                decoration: BoxDecoration(color: sel ? _teal : Colors.transparent, borderRadius: BorderRadius.circular(10.r)),
                child: Column(
                  children: [
                    Icon(t.$2, size: 18.sp, color: sel ? Colors.white : AppColors.textSecondary),
                    SizedBox(height: 3.h),
                    Text(t.$1, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10.sp, fontWeight: sel ? FontWeight.w800 : FontWeight.w600, color: sel ? Colors.white : AppColors.textPrimary, fontFamily: 'Poppins')),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _dtBox(String label, IconData icon, String value, String? sub, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.r),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
          decoration: BoxDecoration(color: const Color(0xFFEAF6FC), borderRadius: BorderRadius.circular(12.r), border: Border.all(color: _teal.withValues(alpha: 0.3))),
          child: Row(
            children: [
              Icon(icon, color: _teal, size: 20.sp),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w600, color: AppColors.textSecondary, letterSpacing: 0.3, fontFamily: 'Poppins')),
                    SizedBox(height: 2.h),
                    Row(
                      children: [
                        Text(value, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w800, color: AppColors.textPrimary, fontFamily: 'Poppins')),
                        if (sub != null) ...[
                          SizedBox(width: 8.w),
                          Text(sub, style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: AppColors.textSecondary, fontFamily: 'Poppins')),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppColors.textHint, size: 22.sp),
            ],
          ),
        ),
      );

  Widget _promoRow() => SizedBox(
        height: 130.h,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            _promoCard('CHARDHAM CAB PACKAGES', 'EXCLUSIVE', 'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?auto=format&fit=crop&w=600&q=70', 280.w),
            SizedBox(width: 12.w),
            _promoCard('Beach Getaways', 'OFFERS', 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=600&q=70', 200.w),
          ],
        ),
      );

  Widget _promoCard(String title, String tag, String img, double width) => GestureDetector(
        onTap: () => _snack('Offers — coming soon'),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14.r),
          child: SizedBox(
            width: width,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(imageUrl: img, fit: BoxFit.cover, placeholder: (_, __) => Container(color: _teal.withValues(alpha: 0.2)), errorWidget: (_, __, ___) => Container(color: _teal.withValues(alpha: 0.4))),
                Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomLeft, end: Alignment.topRight, colors: [Colors.black.withValues(alpha: 0.55), Colors.black.withValues(alpha: 0.1)]))),
                Padding(
                  padding: EdgeInsets.all(10.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(6.r)),
                        child: Text('★ $tag ★', style: TextStyle(fontSize: 9.sp, fontWeight: FontWeight.w700, color: Colors.white, fontFamily: 'Poppins')),
                      ),
                      const Spacer(),
                      Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w900, color: AppColors.primary, height: 1.1, fontFamily: 'Poppins', shadows: const [Shadow(color: Colors.black54, blurRadius: 6)])),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _travelExpert() => Container(
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(color: const Color(0xFFEAF6FC), borderRadius: BorderRadius.circular(14.r)),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('SAY HELLO TO,', style: TextStyle(fontSize: 9.sp, fontWeight: FontWeight.w600, color: AppColors.textSecondary, fontFamily: 'Poppins')),
                  Text('YOUR TRAVEL EXPERT', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w800, color: AppColors.textPrimary, fontFamily: 'Poppins')),
                  SizedBox(height: 2.h),
                  Text('Get expert advice for smarter travel plans!', style: TextStyle(fontSize: 10.sp, color: AppColors.textSecondary, fontFamily: 'Poppins')),
                ],
              ),
            ),
            SizedBox(width: 10.w),
            ElevatedButton.icon(
              onPressed: () => callNumber('+919587090620'),
              icon: Icon(Icons.call_rounded, size: 16.sp),
              label: Text('Call Expert | 24×7', style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w700, fontFamily: 'Poppins')),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: _teal, elevation: 1, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)), padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h)),
            ),
          ],
        ),
      );

  // Standard customer bottom nav (same as the Home shell): Home / Bookings /
  // Favorites / Profile — so the cab page feels part of the app, not a dead-end.
  Widget _homeBottomNav() {
    Widget item(IconData icon, String label, VoidCallback onTap) => Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white70, size: 24.sp),
                SizedBox(height: 3.h),
                Text(label, style: TextStyle(fontSize: 10.sp, color: Colors.white70, fontWeight: FontWeight.w500, fontFamily: 'Poppins')),
              ],
            ),
          ),
        );
    return Container(
      decoration: BoxDecoration(color: AppColors.primary, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 12, offset: const Offset(0, -2))]),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62.h,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              item(Icons.home_rounded, 'Home', () => context.go('/customer')),
              item(Icons.receipt_long_rounded, 'Bookings', () => context.go('/customer/bookings')),
              item(Icons.favorite_border_rounded, 'Favorites', () => ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(const SnackBar(content: Text('Favorites — coming soon! 🚧', style: TextStyle(fontFamily: 'Poppins')), behavior: SnackBarBehavior.floating, duration: Duration(seconds: 2)))),
              item(Icons.person_rounded, 'Profile', () => context.go('/customer/profile')),
            ],
          ),
        ),
      ),
    );
  }
}
