import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/address_autocomplete_field.dart';
import '../../data/car_pool_repository.dart';

/// Driver: post (or edit) a car-pool ride — from/to, date, time, seats, price.
class PostRidePage extends StatefulWidget {
  final String? rideId;
  final Map<String, dynamic>? existing;
  const PostRidePage({super.key, this.rideId, this.existing});

  @override
  State<PostRidePage> createState() => _PostRidePageState();
}

class _PostRidePageState extends State<PostRidePage> {
  final _formKey = GlobalKey<FormState>();
  final _fromCtrl = TextEditingController();
  final _toCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _vehicleCtrl = TextEditingController();
  final _vehicleNoCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  double? _fromLat, _fromLng, _toLat, _toLng;
  String? _fromCity, _toCity;
  DateTime _date = DateTime.now();
  TimeOfDay _time = const TimeOfDay(hour: 7, minute: 0);
  int _seats = 3;
  bool _busy = false;

  bool get _isEdit => widget.rideId != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _fromCtrl.text = ((e['from'] as Map?)?['address'] ?? '').toString();
      _fromLat = ((e['from'] as Map?)?['lat'] as num?)?.toDouble();
      _fromLng = ((e['from'] as Map?)?['lng'] as num?)?.toDouble();
      _fromCity = (e['fromCity'] ?? '').toString();
      _toCtrl.text = ((e['to'] as Map?)?['address'] ?? '').toString();
      _toLat = ((e['to'] as Map?)?['lat'] as num?)?.toDouble();
      _toLng = ((e['to'] as Map?)?['lng'] as num?)?.toDouble();
      _toCity = (e['toCity'] ?? '').toString();
      _priceCtrl.text = ((e['pricePerSeat'] ?? '') == '' ? '' : e['pricePerSeat'].toString());
      _vehicleCtrl.text = (e['vehicle'] ?? '').toString();
      _vehicleNoCtrl.text = (e['vehicleNumber'] ?? '').toString();
      _notesCtrl.text = (e['notes'] ?? '').toString();
      _seats = (e['totalSeats'] as num?)?.toInt() ?? _seats;
      _time = _parseTime(e['departureTime']?.toString()) ?? _time;
      final raw = (e['travelDate'] ?? '').toString();
      if (raw.isNotEmpty) {
        final d = DateTime.tryParse(raw);
        if (d != null) _date = DateTime(d.year, d.month, d.day);
      }
    }
  }

  TimeOfDay? _parseTime(String? s) {
    if (s == null || s.isEmpty) return null;
    try {
      final dt = DateFormat.jm().parseLoose(s);
      return TimeOfDay(hour: dt.hour, minute: dt.minute);
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _fromCtrl.dispose();
    _toCtrl.dispose();
    _priceCtrl.dispose();
    _vehicleCtrl.dispose();
    _vehicleNoCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime.now().subtract(const Duration(days: 1)), lastDate: DateTime.now().add(const Duration(days: 180)));
    if (d != null) setState(() => _date = d);
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: _time);
    if (t != null) setState(() => _time = t);
  }

  void _snack(String m, {bool ok = false}) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: ok ? AppColors.success : AppColors.error, behavior: SnackBarBehavior.floating));

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_fromCtrl.text.trim().isEmpty || _toCtrl.text.trim().isEmpty) {
      _snack('Please select From and To locations');
      return;
    }
    final price = num.tryParse(_priceCtrl.text.trim()) ?? 0;
    if (price <= 0) {
      _snack('Enter a valid price per seat');
      return;
    }
    setState(() => _busy = true);
    final body = <String, dynamic>{
      'from': {'address': _fromCtrl.text.trim(), 'lat': _fromLat ?? 0, 'lng': _fromLng ?? 0},
      'to': {'address': _toCtrl.text.trim(), 'lat': _toLat ?? 0, 'lng': _toLng ?? 0},
      'fromCity': _fromCity ?? '',
      'toCity': _toCity ?? '',
      'travelDate': DateFormat('yyyy-MM-dd').format(_date),
      'departureTime': _time.format(context),
      'totalSeats': _seats,
      'pricePerSeat': price,
      if (_vehicleCtrl.text.trim().isNotEmpty) 'vehicle': _vehicleCtrl.text.trim(),
      if (_vehicleNoCtrl.text.trim().isNotEmpty) 'vehicleNumber': _vehicleNoCtrl.text.trim(),
      if (_notesCtrl.text.trim().isNotEmpty) 'notes': _notesCtrl.text.trim(),
    };
    try {
      final repo = getIt<CarPoolRepository>();
      final ride = _isEdit ? await repo.updateRide(widget.rideId!, body) : await repo.postRide(body);
      if (!mounted) return;
      final id = (ride['_id'] ?? ride['id'] ?? widget.rideId ?? '').toString();
      _snack(_isEdit ? 'Ride updated' : 'Ride posted successfully', ok: true);
      context.go('/car-pool/ride/$id');
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _snack('Could not save: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Ride' : 'Post a Ride', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 17.sp)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 12.h),
        color: AppColors.surface,
        child: SafeArea(
          top: false,
          child: SizedBox(
            width: double.infinity,
            height: 52.h,
            child: ElevatedButton(
              onPressed: _busy ? null : _submit,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r))),
              child: _busy
                  ? SizedBox(width: 22.w, height: 22.w, child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(_isEdit ? 'Save Changes' : 'Post Ride', style: TextStyle(fontSize: 15.5.sp, fontWeight: FontWeight.w700, fontFamily: 'Poppins')),
            ),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 20.h),
          children: [
            _card('Route', Icons.route_rounded, Column(children: [
              AddressAutocompleteField(controller: _fromCtrl, label: 'From', prefixIcon: Icons.my_location_rounded, validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null, onSelected: (a, lat, lng, city) { _fromLat = lat; _fromLng = lng; _fromCity = city; }),
              SizedBox(height: 12.h),
              AddressAutocompleteField(controller: _toCtrl, label: 'To', prefixIcon: Icons.location_on_rounded, validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null, onSelected: (a, lat, lng, city) { _toLat = lat; _toLng = lng; _toCity = city; }),
            ])),
            _card('When', Icons.schedule_rounded, Row(children: [
              Expanded(child: _pickerTile(Icons.calendar_today_rounded, 'Date', DateFormat('EEE, d MMM').format(_date), _pickDate)),
              SizedBox(width: 12.w),
              Expanded(child: _pickerTile(Icons.access_time_rounded, 'Departure', _time.format(context), _pickTime)),
            ])),
            _card('Seats & Price', Icons.event_seat_rounded, Column(children: [
              _stepper('Available Seats', Icons.event_seat_rounded, _seats, (v) => setState(() => _seats = v), min: 1, max: 8),
              SizedBox(height: 12.h),
              TextFormField(controller: _priceCtrl, keyboardType: TextInputType.number, style: TextStyle(fontSize: 14.sp), decoration: _dec('Price per seat (₹)', Icons.currency_rupee_rounded), validator: (v) => (num.tryParse(v?.trim() ?? '') ?? 0) <= 0 ? 'Enter price' : null),
            ])),
            _card('Vehicle', Icons.directions_car_rounded, Column(children: [
              TextFormField(controller: _vehicleCtrl, style: TextStyle(fontSize: 14.sp), decoration: _dec('Vehicle (e.g. Sedan)', Icons.directions_car_rounded)),
              SizedBox(height: 12.h),
              TextFormField(controller: _vehicleNoCtrl, textCapitalization: TextCapitalization.characters, style: TextStyle(fontSize: 14.sp), decoration: _dec('Vehicle number (optional)', Icons.confirmation_number_rounded)),
              SizedBox(height: 12.h),
              TextFormField(controller: _notesCtrl, maxLines: 2, style: TextStyle(fontSize: 14.sp), decoration: _dec('Notes for passengers (optional)', Icons.notes_rounded)),
            ])),
          ],
        ),
      ),
    );
  }

  Widget _card(String title, IconData icon, Widget child) => Container(
        margin: EdgeInsets.only(bottom: 14.h),
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16.r), border: Border.all(color: AppColors.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(icon, size: 16.sp, color: AppColors.primary), SizedBox(width: 6.w), Text(title, style: TextStyle(fontSize: 13.5.sp, fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontFamily: 'Poppins'))]),
          SizedBox(height: 12.h),
          child,
        ]),
      );

  Widget _pickerTile(IconData icon, String label, String value, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.r),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
          decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12.r), border: Border.all(color: AppColors.border)),
          child: Row(children: [
            Icon(icon, size: 18.sp, color: AppColors.primary),
            SizedBox(width: 8.w),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: TextStyle(fontSize: 10.5.sp, color: AppColors.textHint, fontFamily: 'Poppins')),
              Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, fontFamily: 'Poppins')),
            ])),
          ]),
        ),
      );

  Widget _stepper(String label, IconData icon, int value, ValueChanged<int> onChanged, {required int min, required int max}) => Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
        decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12.r), border: Border.all(color: AppColors.border)),
        child: Row(children: [
          Icon(icon, size: 18.sp, color: AppColors.primary),
          SizedBox(width: 8.w),
          Expanded(child: Text(label, style: TextStyle(fontSize: 13.5.sp, fontWeight: FontWeight.w600, fontFamily: 'Poppins'))),
          _rb(Icons.remove_rounded, value > min ? () => onChanged(value - 1) : null),
          Container(width: 34.w, alignment: Alignment.center, child: Text('$value', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800, fontFamily: 'Poppins'))),
          _rb(Icons.add_rounded, value < max ? () => onChanged(value + 1) : null),
        ]),
      );

  Widget _rb(IconData icon, VoidCallback? onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20.r),
        child: Container(width: 30.w, height: 30.w, decoration: BoxDecoration(color: onTap == null ? AppColors.border.withValues(alpha: 0.4) : AppColors.primary.withValues(alpha: 0.12), shape: BoxShape.circle), child: Icon(icon, size: 18.sp, color: onTap == null ? AppColors.textHint : AppColors.primary)),
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
}
