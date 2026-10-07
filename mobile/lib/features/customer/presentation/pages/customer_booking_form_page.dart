import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/action_url.dart';
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
      subTypes: ['One Way', 'Round Trip', 'Local'], vehicles: ['Sedan', 'SUV', 'Hatchback', 'Any']),
  'hire_driver': _ServiceMeta('Hire a Driver', 'A driver for your own car', Icons.badge_rounded,
      needsDrop: false, needsDuration: false, needsPassengers: false, subTypes: ['6 Hours', '8 Hours', '12 Hours']),
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
  int _localHours = 8; // Local (hourly rental) package length
  String? _subType;
  String? _vehicle;
  DateTime? _endDate; // trip end (round-trip return / general trip end)
  TimeOfDay? _endTime;
  bool _busy = false;

  // Cab page extras: admin-managed promo banners + the support number to call.
  String _supportPhone = '';
  List<Map<String, dynamic>> _offers = [];
  // Representative Local package km-per-hour (for the "X km included" chip hint).
  double _localKmPerHour = 0;

  // Accent colour for the cab layout (orange to match the app brand).
  static const _teal = AppColors.primary;

  _ServiceMeta get _m => _meta[widget.serviceType] ?? const _ServiceMeta('Booking', '', Icons.directions_car_rounded);

  bool get _isEdit => widget.bookingId != null;

  @override
  void initState() {
    super.initState();
    if (_m.subTypes.isNotEmpty) _subType = _m.subTypes.first;
    if (_m.vehicles.isNotEmpty) _vehicle = _m.vehicles.first;
    // Cab page only: load the promo banners + support number for the help card,
    // and auto-fill the last search the customer ran (new bookings only).
    if (widget.serviceType == 'cab' && !_isEdit) {
      _loadExtras();
      if (widget.existing == null) _restoreLastSearch();
    }
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
      final ed = tripDate(e['tripEndDate']);
      if (ed != null) _endDate = ed;
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

  /// Fetch the admin-managed promo banners (home "offers") and the support
  /// number (per-city franchise, else global) for the cab page's help card.
  Future<void> _loadExtras() async {
    try {
      final res = await getIt<ApiClient>().get('/settings/support-contact');
      final d = (res.data['data'] as Map?) ?? const {};
      final phone = (d['phone'] ?? '').toString().trim();
      if (mounted && phone.isNotEmpty) setState(() => _supportPhone = phone);
    } catch (_) {}
    try {
      final d = await getIt<CustomerRepository>().homeContent(null);
      final list = (d['offers'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? <Map<String, dynamic>>[];
      if (mounted) setState(() => _offers = list);
    } catch (_) {}
    // Representative Local package km/hour — the most common value among the
    // active cabs that offer a Local package, used to show "X km included".
    try {
      final res = await getIt<ApiClient>().get('/home-content/cab-categories');
      final cats = (res.data['data'] as List?) ?? const [];
      final perHrs = cats
          .map((e) => ((e as Map)['packageKmPerHour'] as num?)?.toDouble() ?? 0)
          .where((v) => v > 0)
          .toList();
      if (perHrs.isNotEmpty) {
        // mode (most frequent); ties → the first seen
        final counts = <double, int>{};
        for (final v in perHrs) {
          counts[v] = (counts[v] ?? 0) + 1;
        }
        final mode = counts.entries.reduce((a, b) => b.value > a.value ? b : a).key;
        if (mounted) setState(() => _localKmPerHour = mode);
      }
    } catch (_) {}
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

  Future<void> _pickEndDateTime() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _date.add(const Duration(days: 1)),
      firstDate: _date,
      lastDate: DateTime.now().add(const Duration(days: 180)),
    );
    if (d == null) return;
    if (!mounted) return;
    final t = await showTimePicker(context: context, initialTime: _endTime ?? _time);
    setState(() {
      _endDate = d;
      if (t != null) _endTime = t;
    });
  }

  // Cab "Explore Cabs": validate the route, then open the fare-estimate results
  // screen (the booking is created there when the customer picks a cab + Book Now).
  void _exploreCabs() {
    // Local (hourly package) has no destination — the fare comes from the chosen
    // cab's package (hours × per-km rate). It still goes through the results screen
    // so the customer sees each cab's package price, included km and extra rates.
    if (_subType == 'Local') {
      if (_pickupCtrl.text.trim().isEmpty) {
        _snack('Please select a pickup location');
        return;
      }
      final localTrip = <String, dynamic>{
        'subType': 'Local',
        'pickup': {'address': _pickupCtrl.text.trim(), 'lat': _pickupLat ?? 0, 'lng': _pickupLng ?? 0},
        'pickupCity': _pickupCity,
        'travelDate': ymdString(_date),
        'travelTime': _time.format(context),
        'passengers': _passengers,
        'durationHours': _localHours,
        if (_isEdit) 'bookingId': widget.bookingId,
        if (_isEdit && _vehicle != null) 'currentVehicle': _vehicle,
      };
      context.push('/customer/cab-results', extra: localTrip);
      return;
    }
    if (_pickupCtrl.text.trim().isEmpty || _dropCtrl.text.trim().isEmpty) {
      _snack('Please select From and To locations');
      return;
    }
    // Trip end is required only for Round Trip (needed to count the days for the
    // per-day minimum included-km). One Way and Local use only the start date.
    if (_subType == 'Round Trip' && _endDate == null) {
      _snack('Please select the trip end (return) date');
      return;
    }
    // Intermediate stops (with coords) so the route/distance goes THROUGH them.
    final stops = _stops
        .where((s) => s.ctrl.text.trim().isNotEmpty)
        .map((s) => {'address': s.ctrl.text.trim(), 'lat': s.lat ?? 0, 'lng': s.lng ?? 0, if (s.city != null) 'city': s.city})
        .toList();
    final trip = <String, dynamic>{
      'subType': _subType,
      'pickup': {'address': _pickupCtrl.text.trim(), 'lat': _pickupLat ?? 0, 'lng': _pickupLng ?? 0},
      'pickupCity': _pickupCity,
      'drop': {'address': _dropCtrl.text.trim(), 'lat': _dropLat ?? 0, 'lng': _dropLng ?? 0},
      'dropCity': _dropCity,
      if (stops.isNotEmpty) 'stops': stops,
      'travelDate': ymdString(_date),
      'travelTime': _time.format(context),
      'passengers': _passengers,
      // Trip end (saved to DB). For Round Trip it is the return; optional otherwise.
      if (_endDate != null) 'tripEndDate': ymdString(_endDate!),
      if (_endDate != null && _endTime != null) 'tripEndTime': _endTime!.format(context),
      if (_subType == 'Round Trip' && _endDate != null) 'returnDate': ymdString(_endDate!),
      if (_subType == 'Round Trip' && _endDate != null) 'notes': 'Return date: ${DateFormat('dd-MM-yyyy').format(_endDate!)}',
      // Editing an existing booking: cab-results will UPDATE instead of create.
      if (_isEdit) 'bookingId': widget.bookingId,
      if (_isEdit && _vehicle != null) 'currentVehicle': _vehicle,
    };
    if (!_isEdit) _saveLastSearch();
    context.push('/customer/cab-results', extra: trip);
  }

  static const _kLastCabSearch = 'last_cab_search';

  // Persist the current cab search so it auto-fills when the app is reopened.
  void _saveLastSearch() {
    try {
      final data = {
        'subType': _subType,
        'pickup': _pickupCtrl.text.trim(),
        'pickupLat': _pickupLat,
        'pickupLng': _pickupLng,
        'pickupCity': _pickupCity,
        'drop': _dropCtrl.text.trim(),
        'dropLat': _dropLat,
        'dropLng': _dropLng,
        'dropCity': _dropCity,
        'stops': _stops
            .where((s) => s.ctrl.text.trim().isNotEmpty)
            .map((s) => {'address': s.ctrl.text.trim(), 'lat': s.lat, 'lng': s.lng, 'city': s.city})
            .toList(),
        'date': _date.toIso8601String(),
        'timeH': _time.hour,
        'timeM': _time.minute,
        'endDate': _endDate?.toIso8601String(),
        'endH': _endTime?.hour,
        'endM': _endTime?.minute,
        'passengers': _passengers,
        'localHours': _localHours,
      };
      getIt<SharedPreferences>().setString(_kLastCabSearch, jsonEncode(data));
    } catch (_) {}
  }

  // Restore the last cab search (controllers + state) on a fresh form open.
  void _restoreLastSearch() {
    try {
      final raw = getIt<SharedPreferences>().getString(_kLastCabSearch);
      if (raw == null || raw.isEmpty) return;
      final d = jsonDecode(raw) as Map<String, dynamic>;
      final st = (d['subType'] ?? '').toString();
      if (st.isNotEmpty && _m.subTypes.contains(st)) _subType = st;
      _pickupCtrl.text = (d['pickup'] ?? '').toString();
      _pickupLat = (d['pickupLat'] as num?)?.toDouble();
      _pickupLng = (d['pickupLng'] as num?)?.toDouble();
      _pickupCity = (d['pickupCity'])?.toString();
      _dropCtrl.text = (d['drop'] ?? '').toString();
      _dropLat = (d['dropLat'] as num?)?.toDouble();
      _dropLng = (d['dropLng'] as num?)?.toDouble();
      _dropCity = (d['dropCity'])?.toString();
      for (final s in (d['stops'] as List? ?? [])) {
        final m = Map<String, dynamic>.from(s as Map);
        final f = _StopField()
          ..lat = (m['lat'] as num?)?.toDouble()
          ..lng = (m['lng'] as num?)?.toDouble()
          ..city = m['city']?.toString();
        f.ctrl.text = (m['address'] ?? '').toString();
        _stops.add(f);
      }
      final dt = DateTime.tryParse((d['date'] ?? '').toString());
      if (dt != null && dt.isAfter(DateTime.now().subtract(const Duration(days: 1)))) {
        _date = dt;
        if (d['timeH'] is int) _time = TimeOfDay(hour: d['timeH'] as int, minute: (d['timeM'] as int?) ?? 0);
      }
      final edt = DateTime.tryParse((d['endDate'] ?? '').toString());
      if (edt != null && edt.isAfter(DateTime.now().subtract(const Duration(days: 1)))) {
        _endDate = edt;
        if (d['endH'] is int) _endTime = TimeOfDay(hour: d['endH'] as int, minute: (d['endM'] as int?) ?? 0);
      }
      _passengers = (d['passengers'] as num?)?.toInt() ?? _passengers;
      _localHours = (d['localHours'] as num?)?.toInt() ?? _localHours;
    } catch (_) {}
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
    if (_subType == 'Round Trip' && _endDate == null) {
      _snack('Please select the trip end (return) date');
      return;
    }
    setState(() => _busy = true);
    final notes = <String>[];
    if (_notesCtrl.text.trim().isNotEmpty) notes.add(_notesCtrl.text.trim());
    final stopTexts = _stops.map((s) => s.ctrl.text.trim()).where((t) => t.isNotEmpty).toList();
    if (stopTexts.isNotEmpty) notes.add('Via: ${stopTexts.join(', ')}');
    if (_subType == 'Round Trip' && _endDate != null) {
      notes.add('Return date: ${DateFormat('dd-MM-yyyy').format(_endDate!)}');
    }
    final body = <String, dynamic>{
      // serviceType is fixed on edit (backend rejects it in the update DTO).
      if (!_isEdit) 'serviceType': widget.serviceType,
      if (_subType != null) 'subType': _subType,
      if (_vehicle != null) 'vehicleType': _vehicle,
      'pickup': {'address': _pickupCtrl.text.trim(), 'lat': _pickupLat ?? 0, 'lng': _pickupLng ?? 0},
      'pickupCity': _pickupCity,
      if (_m.needsDrop) 'drop': {'address': _dropCtrl.text.trim(), 'lat': _dropLat ?? 0, 'lng': _dropLng ?? 0},
      if (_m.needsDrop) 'dropCity': _dropCity,
      'travelDate': ymdString(_date),
      'travelTime': _time.format(context),
      if (_endDate != null) 'tripEndDate': ymdString(_endDate!),
      if (_endDate != null && _endTime != null) 'tripEndTime': _endTime!.format(context),
      if (_m.needsPassengers) 'passengers': _passengers,
      if (_m.needsDuration) 'durationHours': _durationHours,
      // Hire a Driver: duration comes from the selected "6/8/12 Hours" chip.
      if (widget.serviceType == 'hire_driver' && _subType != null)
        'durationHours': int.tryParse(_subType!.split(' ').first) ?? 0,
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
      _snack(_isEdit ? 'Booking updated' : 'Request posted — waiting for a driver to accept', ok: true);
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
    if (widget.serviceType == 'cab') return _buildCab();
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
            if (_m.subTypes.isNotEmpty)
              _card(widget.serviceType == 'hire_driver' ? 'Duration' : 'Trip Type', Icons.tune_rounded, _chips(_m.subTypes, _subType, (v) => setState(() => _subType = v))),

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
              Text('A nearby driver accepts your booking directly. No upfront payment.',
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
        title: Text(_isEdit ? 'Edit Booking' : 'Cab Booking', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 18.sp)),
      ),
      bottomNavigationBar: _isEdit ? null : _homeBottomNav(),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.fromLTRB(14.w, 14.h, 14.w, 20.h),
          children: [
            _cabCard(isRound),
            if (!_isEdit) ...[
              _offersBanner(),
              _supportCard(),
            ],
          ],
        ),
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
            // Local hourly-package picker sits ABOVE the pickup (no destination).
            if (_subType == 'Local') ...[
              _localDurationChips(),
              SizedBox(height: 14.h),
            ],
            // FROM → TO / stops (Local = pickup only).
            if (_subType == 'Local')
              _fromField()
            else if (_stops.isEmpty)
              // From + To share ONE Stack so the swap button can straddle the gap
              // (half over From, half over To) AND still be tappable. A widget drawn
              // outside its parent's bounds (the old `top: -25` overlay) is visible
              // but never receives taps; here the border sits INSIDE the Stack, so
              // centre-right lands exactly on the From↔To gap and works.
              Stack(
                alignment: Alignment.centerRight,
                children: [
                  Column(
                    children: [
                      _fromField(),
                      SizedBox(height: 18.h),
                      _toField(),
                    ],
                  ),
                  Padding(
                    padding: EdgeInsets.only(right: 6.w),
                    child: _swapButton(),
                  ),
                ],
              )
            else
              Column(
                children: [
                  _fromField(),
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
                            prefixWidget: _stopNumberBadge(i + 1),
                            hintText: 'Enter stop city',
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
                  _toField(),
                ],
              ),
            // Add Stops only for point-to-point trips (not Local).
            if (_subType != 'Local') ...[
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
            ],
            SizedBox(height: 14.h),
            // Only Round Trip has a trip end (return) date — used to count days for
            // the per-day minimum km. One Way and Local show just the Trip Start.
            if (isRound)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _dtBoxCompact(
                      'TRIP START',
                      Icons.calendar_today_rounded,
                      DateFormat('dd-MM-yyyy').format(_date),
                      _time.format(context),
                      _pickDateTime,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: _dtBoxCompact(
                      'TRIP END *',
                      Icons.event_available_rounded,
                      _endDate == null ? 'Select date' : DateFormat('dd-MM-yyyy').format(_endDate!),
                      _endTime?.format(context),
                      _pickEndDateTime,
                    ),
                  ),
                ],
              )
            else
              _dtBoxCompact(
                'TRIP START',
                Icons.calendar_today_rounded,
                DateFormat('dd-MM-yyyy').format(_date),
                _time.format(context),
                _pickDateTime,
              ),
            SizedBox(height: 16.h),
            SizedBox(
              width: double.infinity,
              height: 52.h,
              child: ElevatedButton(
                onPressed: _busy ? null : _exploreCabs,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.textHint,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                ),
                child: _busy
                    ? SizedBox(width: 22.w, height: 22.w, child: const CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                    : Text(_isEdit ? 'CHOOSE VEHICLE' : 'EXPLORE CABS', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800, letterSpacing: 0.5, fontFamily: 'Poppins')),
              ),
            ),
          ],
        ),
      );

  // Trip-type selector at the TOP of the card: title + short description, no icon.
  Widget _tripTypeTabs() {
    const types = [
      ('One Way', 'Drop off only'),
      ('Round Trip', 'Return in same cab'),
      ('Local', 'Hourly rental'),
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
                // Default the return/trip-end to the next day so it isn't blank.
                if (t.$1 == 'Round Trip' && _endDate == null) {
                  _endDate = _date.add(const Duration(days: 1));
                  _endTime ??= _time;
                }
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                height: 46.h,
                alignment: Alignment.center,
                padding: EdgeInsets.symmetric(horizontal: 3.w),
                decoration: BoxDecoration(color: sel ? _teal : Colors.transparent, borderRadius: BorderRadius.circular(10.r)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(t.$1, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w800, color: sel ? Colors.white : AppColors.textPrimary, fontFamily: 'Poppins')),
                    SizedBox(height: 2.h),
                    Text(t.$2, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 8.sp, height: 1.1, fontWeight: FontWeight.w500, color: sel ? Colors.white.withValues(alpha: 0.9) : AppColors.textSecondary, fontFamily: 'Poppins')),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // Admin-managed promotional banners (reuses home "offers") shown below the card.
  Widget _offersBanner() {
    if (_offers.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(top: 16.h),
      child: SizedBox(
        height: 120.h,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _offers.length,
          separatorBuilder: (_, __) => SizedBox(width: 10.w),
          itemBuilder: (_, i) {
            final it = _offers[i];
            final img = (it['imageUrl'] ?? '').toString();
            final title = (it['title'] ?? '').toString();
            return GestureDetector(
              onTap: () {
                final url = (it['actionUrl'] ?? '').toString().trim();
                if (url.isNotEmpty) openActionUrl(context, url);
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16.r),
                child: SizedBox(
                  width: 240.w,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (img.isNotEmpty)
                        Image.network(img, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: _teal))
                      else
                        Container(color: _teal),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Color(0xB3000000)]),
                        ),
                      ),
                      if (title.isNotEmpty)
                        Positioned(
                          left: 12.w,
                          right: 12.w,
                          bottom: 10.h,
                          child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w800, color: Colors.white, fontFamily: 'Poppins', shadows: const [Shadow(color: Colors.black54, blurRadius: 4)])),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // 24×7 "Your Travel Expert" help card — dials the admin-configured number.
  Widget _supportCard() {
    if (_supportPhone.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(top: 16.h),
      child: Container(
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: const Color(0xFFEAF4FF),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: const Color(0xFFBFDCFF)),
        ),
        child: Row(
          children: [
            Container(
              width: 46.w,
              height: 46.w,
              decoration: const BoxDecoration(color: Color(0xFF1E88E5), shape: BoxShape.circle),
              child: Icon(Icons.headset_mic_rounded, color: Colors.white, size: 24.sp),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Your Travel Expert', style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w800, color: AppColors.textPrimary, fontFamily: 'Poppins')),
                  SizedBox(height: 2.h),
                  Text('Get expert advice for smarter travel plans', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10.sp, color: AppColors.textSecondary, fontFamily: 'Poppins')),
                ],
              ),
            ),
            SizedBox(width: 10.w),
            GestureDetector(
              onTap: () => callNumber(_supportPhone),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 9.h),
                decoration: BoxDecoration(color: const Color(0xFF1E88E5), borderRadius: BorderRadius.circular(24.r)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.call_rounded, color: Colors.white, size: 14.sp),
                    SizedBox(width: 5.w),
                    Text('Call 24×7', style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w800, color: Colors.white, fontFamily: 'Poppins')),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Numbered circle badge used as the prefix for each stop field.
  Widget _stopNumberBadge(int n) => Center(
        widthFactor: 1,
        child: Container(
          width: 24.w,
          height: 24.w,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary.withValues(alpha: 0.08),
            border: Border.all(color: AppColors.primary, width: 1.6),
          ),
          child: Text('$n', style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w800, color: AppColors.primary)),
        ),
      );

  Widget _fromField() => AddressAutocompleteField(
        controller: _pickupCtrl,
        label: 'From',
        prefixIcon: Icons.location_on_rounded,
        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
        onSelected: (a, lat, lng, city) { _pickupLat = lat; _pickupLng = lng; _pickupCity = city; },
      );

  Widget _toField() => AddressAutocompleteField(
        controller: _dropCtrl,
        label: 'To',
        prefixIcon: Icons.location_on_rounded,
        onSelected: (a, lat, lng, city) { _dropLat = lat; _dropLng = lng; _dropCity = city; },
      );

  /// Swap the From and To locations (address + coords + city).
  void _swapFromTo() {
    setState(() {
      final t = _pickupCtrl.text; _pickupCtrl.text = _dropCtrl.text; _dropCtrl.text = t;
      final la = _pickupLat; _pickupLat = _dropLat; _dropLat = la;
      final ln = _pickupLng; _pickupLng = _dropLng; _dropLng = ln;
      final c = _pickupCity; _pickupCity = _dropCity; _dropCity = c;
    });
  }

  /// Round swap button that sits in the gap between From and To.
  Widget _swapButton() => Material(
        color: Colors.white,
        shape: const CircleBorder(side: BorderSide(color: _teal, width: 1.3)),
        elevation: 1.5,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: _swapFromTo,
          child: Padding(
            padding: EdgeInsets.all(7.w),
            child: Icon(Icons.swap_vert_rounded, size: 20.sp, color: _teal),
          ),
        ),
      );

  // Local (hourly rental) package chips — shown only for the "Local" trip type.
  Widget _localDurationChips() {
    const hours = [6, 8, 10, 12];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('PACKAGE', style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 0.4, fontFamily: 'Poppins')),
        SizedBox(height: 8.h),
        Row(
          children: hours.map((h) {
            final sel = _localHours == h;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: h == hours.last ? 0 : 8.w),
                child: GestureDetector(
                  onTap: () => setState(() => _localHours = h),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: sel ? AppColors.primary : const Color(0xFFEFF3F6),
                      borderRadius: BorderRadius.circular(10.r),
                      border: Border.all(color: sel ? AppColors.primary : AppColors.border),
                    ),
                    child: Column(
                      children: [
                        Text('$h hrs', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w800, color: sel ? Colors.white : AppColors.textPrimary, fontFamily: 'Poppins')),
                        if (_localKmPerHour > 0) ...[
                          SizedBox(height: 3.h),
                          Text('${(_localKmPerHour * h).round()} km', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 8.5.sp, fontWeight: FontWeight.w700, color: sel ? Colors.white : AppColors.primary, fontFamily: 'Poppins')),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // Compact date/time box used two-per-row (Trip Start | Trip End). Label + icon
  // on top, date below, time under it — fits in half the card width.
  Widget _dtBoxCompact(String label, IconData icon, String value, String? sub, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.r),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
          decoration: BoxDecoration(color: const Color(0xFFEAF6FC), borderRadius: BorderRadius.circular(12.r), border: Border.all(color: _teal.withValues(alpha: 0.3))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(icon, color: _teal, size: 15.sp),
                  SizedBox(width: 6.w),
                  Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 9.5.sp, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.3, fontFamily: 'Poppins'))),
                ],
              ),
              SizedBox(height: 6.h),
              Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w800, color: AppColors.textPrimary, fontFamily: 'Poppins')),
              SizedBox(height: 1.h),
              Text(
                (sub == null || sub.isEmpty) ? '—' : sub,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600, color: AppColors.textSecondary, fontFamily: 'Poppins'),
              ),
            ],
          ),
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
              item(Icons.settings_rounded, 'Settings', () => context.go('/customer/profile')),
            ],
          ),
        ),
      ),
    );
  }
}
