import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/vehicle_types.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/city_autocomplete_field.dart';
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
  final _notesCtrl = TextEditingController();
  String _vehicleType = 'sedan';
  String _tripType = 'one_way';
  DateTime? _availableDate;
  TimeOfDay? _availableTime;

  // City + state captured from the autocomplete fields.
  String _currentCity = '';
  String? _currentState;
  String _destCity = '';
  String? _destState;
  String? _currentInitial;
  String? _destInitial;

  bool get _isEdit => widget.existing != null;

  final _vehicleTypes = kVehicleTypes;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) _populateFromExisting(widget.existing!);
  }

  void _populateFromExisting(Map<String, dynamic> v) {
    _notesCtrl.text = (v['notes'] ?? '') as String;
    _vehicleType = (v['vehicleType'] as String?) ?? 'sedan';
    _tripType = (v['tripType'] as String?) ?? 'one_way';

    _currentCity = (v['currentCity'] ?? '') as String;
    _currentState = v['currentState'] as String?;
    _destCity = (v['destinationCity'] ?? '') as String;
    _destState = v['destinationState'] as String?;
    _currentInitial = [_currentCity, _currentState].where((e) => e != null && e.isNotEmpty).join(', ');
    _destInitial = [_destCity, _destState].where((e) => e != null && e.isNotEmpty).join(', ');

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
    _notesCtrl.dispose();
    super.dispose();
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_availableDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please select available date'), backgroundColor: AppColors.error));
      return;
    }
    final data = <String, dynamic>{
      'currentCity': _currentCity.trim(),
      if (_currentState != null && _currentState!.isNotEmpty) 'currentState': _currentState,
      'destinationCity': _destCity.trim().isEmpty ? null : _destCity.trim(),
      if (_destState != null && _destState!.isNotEmpty) 'destinationState': _destState,
      'vehicleType': _vehicleType,
      'tripType': _tripType,
      'availableDate': _availableDate!.toIso8601String().split('T').first,
      'availableTime': _availableTime != null ? '${_availableTime!.hour.toString().padLeft(2, '0')}:${_availableTime!.minute.toString().padLeft(2, '0')}' : '00:00',
      'notes': _notesCtrl.text.trim(),
    };

    final bloc = context.read<VehiclesBloc>();
    if (_isEdit) {
      bloc.add(UpdateVehicleEvent(id: widget.vehicleId!, data: data));
      return;
    }
    bloc.add(CreateVehicleEvent(data));
  }

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
                CityAutocompleteField(
                  label: 'Current City *',
                  icon: Icons.my_location_outlined,
                  required: true,
                  initialText: _currentInitial,
                  onChanged: (city, state) {
                    _currentCity = city;
                    _currentState = state;
                  },
                ),
                SizedBox(height: 12.h),
                CityAutocompleteField(
                  label: 'Available For (Destination City)',
                  icon: Icons.location_on_outlined,
                  initialText: _destInitial,
                  onChanged: (city, state) {
                    _destCity = city;
                    _destState = state;
                  },
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
                SizedBox(height: 12.h),
                DropdownButtonFormField<String>(
                  value: _tripType,
                  decoration: InputDecoration(
                    labelText: 'Trip Type',
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide(color: AppColors.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide(color: AppColors.primary.withOpacity(0.7))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide(color: AppColors.primary, width: 2)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'one_way', child: Text('One Way', style: TextStyle(fontFamily: 'Poppins'))),
                    DropdownMenuItem(value: 'round_trip', child: Text('Round Trip', style: TextStyle(fontFamily: 'Poppins'))),
                  ],
                  onChanged: (v) => setState(() => _tripType = v!),
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
