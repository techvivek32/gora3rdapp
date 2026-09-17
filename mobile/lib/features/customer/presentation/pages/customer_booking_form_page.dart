import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_theme.dart';
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

class _CustomerBookingFormPageState extends State<CustomerBookingFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _pickupCtrl = TextEditingController();
  final _dropCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _fareCtrl = TextEditingController();

  double? _pickupLat, _pickupLng, _dropLat, _dropLng;
  String? _pickupCity, _dropCity;
  DateTime _date = DateTime.now();
  TimeOfDay _time = TimeOfDay.now();
  int _passengers = 1;
  int _durationHours = 4;
  String? _subType;
  String? _vehicle;
  bool _busy = false;

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
    super.dispose();
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
      if (_notesCtrl.text.trim().isNotEmpty) 'notes': _notesCtrl.text.trim(),
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
}
