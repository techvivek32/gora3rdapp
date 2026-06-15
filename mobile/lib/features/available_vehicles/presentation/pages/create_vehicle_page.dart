import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../bloc/vehicles_bloc.dart';

class CreateVehiclePage extends StatefulWidget {
  const CreateVehiclePage({super.key});

  @override
  State<CreateVehiclePage> createState() => _CreateVehiclePageState();
}

class _CreateVehiclePageState extends State<CreateVehiclePage> {
  final _formKey = GlobalKey<FormState>();
  final _currentCityCtrl = TextEditingController();
  final _currentStateCtrl = TextEditingController();
  final _destCityCtrl = TextEditingController();
  final _vehicleNumberCtrl = TextEditingController();
  final _driverNameCtrl = TextEditingController();
  final _driverMobileCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _vehicleType = 'sedan';
  DateTime? _availableDate;
  TimeOfDay? _availableTime;

  final _vehicleTypes = ['hatchback', 'sedan', 'suv', 'muv', 'traveller', 'tempo_traveller', 'mini_bus', 'bus'];

  @override
  void dispose() {
    _currentCityCtrl.dispose(); _currentStateCtrl.dispose(); _destCityCtrl.dispose();
    _vehicleNumberCtrl.dispose(); _driverNameCtrl.dispose();
    _driverMobileCtrl.dispose(); _notesCtrl.dispose();
    super.dispose();
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
    context.read<VehiclesBloc>().add(CreateVehicleEvent({
      'currentCity': _currentCityCtrl.text.trim(),
      'currentState': _currentStateCtrl.text.trim(),
      'destinationCity': _destCityCtrl.text.trim().isEmpty ? null : _destCityCtrl.text.trim(),
      'vehicleType': _vehicleType,
      'vehicleNumber': _vehicleNumberCtrl.text.trim().toUpperCase(),
      'driverName': _driverNameCtrl.text.trim(),
      'driverMobile': _driverMobileCtrl.text.trim(),
      'availableDate': _availableDate!.toIso8601String().split('T').first,
      'availableTime': _availableTime != null ? '${_availableTime!.hour.toString().padLeft(2, '0')}:${_availableTime!.minute.toString().padLeft(2, '0')}' : '00:00',
      'notes': _notesCtrl.text.trim(),
    }));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text('Post Available Cab', style: TextStyle(fontFamily: 'Poppins')), centerTitle: true),
      body: BlocListener<VehiclesBloc, VehiclesState>(
        listener: (context, state) {
          if (state is VehicleCreated) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Vehicle listed!'), backgroundColor: AppColors.success));
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Location', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp, fontFamily: 'Poppins', color: AppColors.textPrimary)),
                    SizedBox(height: 12.h),
                    TextFormField(
                      controller: _currentCityCtrl,
                      decoration: InputDecoration(
                        labelText: 'Current City *',
                        prefixIcon: Icon(Icons.my_location_outlined, color: AppColors.primary),
                        filled: true,
                        fillColor: Colors.grey[50],
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide(color: AppColors.border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide(color: AppColors.primary.withOpacity(0.7))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide(color: AppColors.primary, width: 2)),
                      ),
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                    SizedBox(height: 12.h),
                    TextFormField(
                      controller: _currentStateCtrl,
                      decoration: InputDecoration(
                        labelText: 'Current State *',
                        prefixIcon: Icon(Icons.map_outlined, color: AppColors.primary),
                        filled: true,
                        fillColor: Colors.grey[50],
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide(color: AppColors.border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide(color: AppColors.primary.withOpacity(0.7))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide(color: AppColors.primary, width: 2)),
                      ),
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                    SizedBox(height: 12.h),
                    TextFormField(
                      controller: _destCityCtrl,
                      decoration: InputDecoration(
                        labelText: 'Available For (Destination City)',
                        prefixIcon: Icon(Icons.location_on_outlined, color: AppColors.primary),
                        filled: true,
                        fillColor: Colors.grey[50],
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide(color: AppColors.border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide(color: AppColors.primary.withOpacity(0.7))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide(color: AppColors.primary, width: 2)),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20.h),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                      items: _vehicleTypes.map((v) => DropdownMenuItem(value: v, child: Text(v.replaceAll('_', ' ').toUpperCase(), style: TextStyle(fontFamily: 'Poppins')))).toList(),
                      onChanged: (v) => setState(() => _vehicleType = v!),
                    ),
                    SizedBox(height: 12.h),
                    TextFormField(
                      controller: _vehicleNumberCtrl,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        labelText: 'Vehicle Number *',
                        prefixIcon: Icon(Icons.badge_outlined, color: AppColors.primary),
                        filled: true,
                        fillColor: Colors.grey[50],
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide(color: AppColors.border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide(color: AppColors.primary.withOpacity(0.7))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide(color: AppColors.primary, width: 2)),
                      ),
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                  ],
                ),
                SizedBox(height: 20.h),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Driver Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp, fontFamily: 'Poppins', color: AppColors.textPrimary)),
                    SizedBox(height: 12.h),
                    TextFormField(
                      controller: _driverNameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Driver Name *',
                        prefixIcon: Icon(Icons.person_outline, color: AppColors.primary),
                        filled: true,
                        fillColor: Colors.grey[50],
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide(color: AppColors.border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide(color: AppColors.primary.withOpacity(0.7))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide(color: AppColors.primary, width: 2)),
                      ),
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                    SizedBox(height: 12.h),
                    TextFormField(
                      controller: _driverMobileCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Driver Mobile *',
                        prefixIcon: Icon(Icons.phone_outlined, color: AppColors.primary),
                        filled: true,
                        fillColor: Colors.grey[50],
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide(color: AppColors.border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide(color: AppColors.primary.withOpacity(0.7))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide(color: AppColors.primary, width: 2)),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        if (v.length != 10) return 'Enter 10 digit number';
                        return null;
                      },
                    ),
                  ],
                ),
                SizedBox(height: 20.h),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Availability', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp, fontFamily: 'Poppins', color: AppColors.textPrimary)),
                    SizedBox(height: 12.h),
                    GestureDetector(
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
                        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(color: AppColors.primary.withOpacity(0.7), width: 1.5),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today_outlined, color: AppColors.primary, size: 24.sp),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: Text(
                                _availableDate != null
                                    ? '${_availableDate!.day}-${_availableDate!.month}-${_availableDate!.year}'
                                    : 'Select Available Date *',
                                style: TextStyle(fontFamily: 'Poppins', fontSize: 15.sp, color: _availableDate != null ? AppColors.textPrimary : AppColors.textHint),
                              ),
                            ),
                            Icon(Icons.chevron_right, color: AppColors.primary, size: 24.sp),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 12.h),
                    GestureDetector(
                      onTap: () async {
                        final t = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                        if (t != null) setState(() => _availableTime = t);
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(color: AppColors.primary.withOpacity(0.7), width: 1.5),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.access_time, color: AppColors.primary, size: 24.sp),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: Text(
                                _availableTime != null ? _formatTime(_availableTime!) : 'Select Available Time',
                                style: TextStyle(fontFamily: 'Poppins', fontSize: 15.sp, color: _availableTime != null ? AppColors.textPrimary : AppColors.textHint),
                              ),
                            ),
                            Icon(Icons.chevron_right, color: AppColors.primary, size: 24.sp),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20.h),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                  ],
                ),
                SizedBox(height: 24.h),
                BlocBuilder<VehiclesBloc, VehiclesState>(
                  builder: (context, state) => ElevatedButton(
                    onPressed: state is VehiclesLoading ? null : _submit,
                    child: state is VehiclesLoading
                        ? SizedBox(width: 20.w, height: 20.h, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text('Post Available Cab', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600, fontFamily: 'Poppins')),
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
