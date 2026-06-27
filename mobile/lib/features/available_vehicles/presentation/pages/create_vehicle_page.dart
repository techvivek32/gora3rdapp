import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/vehicle_types.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../requirements/presentation/pages/location_picker_page.dart';
import '../bloc/vehicles_bloc.dart';

class CreateVehiclePage extends StatefulWidget {
  // When [existing] is provided the page acts as an edit form.
  final Map<String, dynamic>? existing;
  final String? vehicleId;
  const CreateVehiclePage({super.key, this.existing, this.vehicleId});

  @override
  State<CreateVehiclePage> createState() => _CreateVehiclePageState();
}

class _CreateVehiclePageState extends State<CreateVehiclePage> {
  final _formKey = GlobalKey<FormState>();
  final _currentCityCtrl = TextEditingController();
  final _destCityCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _vehicleType = 'sedan';
  DateTime? _availableDate;
  TimeOfDay? _availableTime;

  double? _currentLat, _currentLng;
  double? _destLat, _destLng;

  bool get _isEdit => widget.existing != null;

  final _vehicleTypes = kVehicleTypes;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) _populateFromExisting(widget.existing!);
  }

  void _populateFromExisting(Map<String, dynamic> v) {
    _currentCityCtrl.text = (v['currentCity'] ?? '') as String;
    _destCityCtrl.text = (v['destinationCity'] ?? '') as String;
    _notesCtrl.text = (v['notes'] ?? '') as String;
    _vehicleType = (v['vehicleType'] as String?) ?? 'sedan';

    final cc = v['currentCoordinates'] as Map?;
    if (cc != null) {
      _currentLat = (cc['lat'] as num?)?.toDouble();
      _currentLng = (cc['lng'] as num?)?.toDouble();
    }
    final dc = v['destinationCoordinates'] as Map?;
    if (dc != null) {
      _destLat = (dc['lat'] as num?)?.toDouble();
      _destLng = (dc['lng'] as num?)?.toDouble();
    }

    if (v['availableDate'] != null) {
      try {
        _availableDate = DateTime.parse(v['availableDate'].toString());
      } catch (_) {}
    }
    if (v['availableTime'] != null) {
      try {
        final p = (v['availableTime'] as String).split(':');
        _availableTime = TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _currentCityCtrl.dispose();
    _destCityCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _openCurrentCity() async {
    final result = await Navigator.of(context).push<LocationPickerResult>(
      MaterialPageRoute(
        builder: (_) => LocationPickerPage(title: 'Pick Current Location', initialLat: _currentLat, initialLng: _currentLng),
      ),
    );
    if (result != null) {
      setState(() {
        _currentCityCtrl.text = result.address;
        _currentLat = result.lat;
        _currentLng = result.lng;
      });
    }
  }

  Future<void> _openDestCity() async {
    final result = await Navigator.of(context).push<LocationPickerResult>(
      MaterialPageRoute(
        builder: (_) => LocationPickerPage(title: 'Pick Destination', initialLat: _destLat, initialLng: _destLng),
      ),
    );
    if (result != null) {
      setState(() {
        _destCityCtrl.text = result.address;
        _destLat = result.lat;
        _destLng = result.lng;
      });
    }
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_availableDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please select available date'), backgroundColor: AppColors.error));
      return;
    }
    final data = <String, dynamic>{
      'currentCity': _currentCityCtrl.text.trim(),
      'destinationCity': _destCityCtrl.text.trim().isEmpty ? null : _destCityCtrl.text.trim(),
      if (_currentLat != null && _currentLng != null)
        'currentCoordinates': {'lat': _currentLat, 'lng': _currentLng, 'address': _currentCityCtrl.text.trim()},
      if (_destLat != null && _destLng != null)
        'destinationCoordinates': {'lat': _destLat, 'lng': _destLng, 'address': _destCityCtrl.text.trim()},
      'vehicleType': _vehicleType,
      'availableDate': _availableDate!.toIso8601String().split('T').first,
      'availableTime': _availableTime != null ? '${_availableTime!.hour.toString().padLeft(2, '0')}:${_availableTime!.minute.toString().padLeft(2, '0')}' : '00:00',
      'notes': _notesCtrl.text.trim(),
    };

    final bloc = context.read<VehiclesBloc>();
    if (_isEdit) {
      bloc.add(UpdateVehicleEvent(id: widget.vehicleId!, data: data));
    } else {
      bloc.add(CreateVehicleEvent(data));
    }
  }

  InputDecoration _dec(String label, IconData icon, {Widget? suffix}) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.primary),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide(color: AppColors.primary.withOpacity(0.7))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide(color: AppColors.primary, width: 2)),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(_isEdit ? 'Edit Cab' : 'Post Available Cab', style: TextStyle(fontFamily: 'Poppins')), centerTitle: true),
      body: BlocListener<VehiclesBloc, VehiclesState>(
        listener: (context, state) {
          if (state is VehicleCreated || state is VehicleUpdated) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isEdit ? 'Cab updated!' : 'Vehicle listed!'), backgroundColor: AppColors.success));
            context.pop();
          }
          if (state is VehiclesError) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message), backgroundColor: AppColors.error));
          }
        },
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16.r),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Location', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp, fontFamily: 'Poppins', color: AppColors.textPrimary)),
                SizedBox(height: 12.h),
                TextFormField(
                  controller: _currentCityCtrl,
                  readOnly: true,
                  onTap: _openCurrentCity,
                  decoration: _dec('Current City *', Icons.my_location_outlined, suffix: Icon(Icons.map_outlined, color: AppColors.primary, size: 20.sp)),
                  validator: (v) => v == null || v.isEmpty ? 'Tap to pick current location' : null,
                ),
                SizedBox(height: 12.h),
                TextFormField(
                  controller: _destCityCtrl,
                  readOnly: true,
                  onTap: _openDestCity,
                  decoration: _dec('Available For (Destination City)', Icons.location_on_outlined, suffix: Icon(Icons.map_outlined, color: AppColors.primary, size: 20.sp)),
                ),
                SizedBox(height: 20.h),

                Text('Vehicle Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp, fontFamily: 'Poppins', color: AppColors.textPrimary)),
                SizedBox(height: 12.h),
                DropdownButtonFormField<String>(
                  value: _vehicleType,
                  decoration: InputDecoration(
                    labelText: 'Vehicle Type',
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide(color: AppColors.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide(color: AppColors.primary.withOpacity(0.7))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide(color: AppColors.primary, width: 2)),
                  ),
                  items: _vehicleTypes.map((v) => DropdownMenuItem(value: v['value'], child: Text(v['label']!, style: TextStyle(fontFamily: 'Poppins')))).toList(),
                  onChanged: (v) => setState(() => _vehicleType = v!),
                ),
                SizedBox(height: 20.h),

                Text('Availability', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp, fontFamily: 'Poppins', color: AppColors.textPrimary)),
                SizedBox(height: 12.h),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final d = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 90)),
                          );
                          if (d != null) setState(() => _availableDate = d);
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 14.h),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(color: AppColors.primary.withOpacity(0.7), width: 1.5),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today_outlined, color: AppColors.primary, size: 20.sp),
                              SizedBox(width: 8.w),
                              Expanded(
                                child: Text(
                                  _availableDate != null ? '${_availableDate!.day}-${_availableDate!.month}-${_availableDate!.year}' : 'Date *',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontFamily: 'Poppins', fontSize: 13.sp, color: _availableDate != null ? AppColors.textPrimary : AppColors.textHint),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final t = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                          if (t != null) setState(() => _availableTime = t);
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 14.h),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(color: AppColors.primary.withOpacity(0.7), width: 1.5),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.access_time, color: AppColors.primary, size: 20.sp),
                              SizedBox(width: 8.w),
                              Expanded(
                                child: Text(
                                  _availableTime != null ? _formatTime(_availableTime!) : 'Time',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontFamily: 'Poppins', fontSize: 13.sp, color: _availableTime != null ? AppColors.textPrimary : AppColors.textHint),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20.h),

                Text('Additional Notes (Optional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp, fontFamily: 'Poppins', color: AppColors.textPrimary)),
                SizedBox(height: 12.h),
                TextFormField(
                  controller: _notesCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Add any additional notes here...',
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide(color: AppColors.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide(color: AppColors.primary.withOpacity(0.7))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide(color: AppColors.primary, width: 2)),
                  ),
                ),
                SizedBox(height: 24.h),

                BlocBuilder<VehiclesBloc, VehiclesState>(
                  builder: (context, state) => ElevatedButton(
                    onPressed: state is VehiclesLoading ? null : _submit,
                    child: state is VehiclesLoading
                        ? SizedBox(width: 20.w, height: 20.h, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(_isEdit ? 'Save Changes' : 'Post Available Cab', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600, fontFamily: 'Poppins')),
                  ),
                ),
                SizedBox(height: 32.h),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
