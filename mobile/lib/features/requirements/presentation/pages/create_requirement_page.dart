import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../bloc/requirements_bloc.dart';

class CreateRequirementPage extends StatefulWidget {
  const CreateRequirementPage({super.key});

  @override
  State<CreateRequirementPage> createState() => _CreateRequirementPageState();
}

class _CreateRequirementPageState extends State<CreateRequirementPage> {
  final _formKey = GlobalKey<FormState>();
  final _pickupCtrl = TextEditingController();
  final _dropCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _vehicleType = 'sedan';
  String _tripType = 'one_way';
  int _numberOfVehicles = 1;
  DateTime? _travelDate;
  TimeOfDay? _travelTime;
  DateTime? _returnDate;
  TimeOfDay? _returnTime;

  final _vehicleTypes = ['hatchback', 'sedan', 'suv', 'muv', 'traveller', 'tempo_traveller', 'mini_bus', 'bus'];
  final _tripTypes = ['one_way', 'round_trip', 'airport_transfer', 'local', 'outstation'];

  @override
  void dispose() {
    _pickupCtrl.dispose();
    _dropCtrl.dispose();
    _notesCtrl.dispose();
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
    if (_travelDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please select travel date'), backgroundColor: AppColors.error));
      return;
    }
    context.read<RequirementsBloc>().add(CreateRequirementEvent(data: {
      'pickupCity': _pickupCtrl.text.trim(),
      'dropCity': _dropCtrl.text.trim(),
      'vehicleType': _vehicleType,
      'tripType': _tripType,
      'numberOfVehicles': _numberOfVehicles,
      'travelDate': _travelDate!.toIso8601String().split('T').first,
      'travelTime': _travelTime != null ? '${_travelTime!.hour.toString().padLeft(2, '0')}:${_travelTime!.minute.toString().padLeft(2, '0')}' : '00:00',
      'notes': _notesCtrl.text.trim(),
    }));
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text('Post Requirement', style: TextStyle(fontFamily: 'Poppins')), centerTitle: true),
      body: BlocListener<RequirementsBloc, RequirementsState>(
        listener: (context, state) {
          if (state is RequirementCreated) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Requirement posted!'), backgroundColor: AppColors.success));
            context.pop();
          }
          if (state is RequirementsError) {
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
                    Text('Route Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp, fontFamily: 'Poppins', color: AppColors.textPrimary)),
                    SizedBox(height: 12.h),
                    TextFormField(
                      controller: _pickupCtrl,
                      decoration: InputDecoration(
                        labelText: 'Pickup City *',
                        prefixIcon: Icon(Icons.location_on_outlined, color: AppColors.primary),
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
                      controller: _dropCtrl,
                      decoration: InputDecoration(
                        labelText: 'Drop City *',
                        prefixIcon: Icon(Icons.location_off_outlined, color: AppColors.primary),
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
                    Text('Vehicle Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp, fontFamily: 'Poppins', color: AppColors.textPrimary)),
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
                      items: _tripTypes.map((t) => DropdownMenuItem(value: t, child: Text(t.replaceAll('_', ' ').toUpperCase(), style: TextStyle(fontFamily: 'Poppins')))).toList(),
                      onChanged: (v) => setState(() => _tripType = v!),
                    ),
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
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text('Number of Vehicles: ', style: TextStyle(fontSize: 15.sp, fontFamily: 'Poppins', color: AppColors.textPrimary)),
                        ),
                        Expanded(
                          flex: 3,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Container(
                                width: 40.w,
                                height: 40.h,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8.r),
                                ),
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  onPressed: () => setState(() => _numberOfVehicles = (_numberOfVehicles - 1).clamp(1, 50)),
                                  icon: Icon(Icons.remove, color: AppColors.primary, size: 20.sp),
                                ),
                              ),
                              SizedBox(width: 8.w),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                                decoration: BoxDecoration(
                                  border: Border.all(color: AppColors.primary, width: 2),
                                  borderRadius: BorderRadius.circular(8.r),
                                ),
                                child: Text('$_numberOfVehicles', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, fontFamily: 'Poppins', color: AppColors.textPrimary)),
                              ),
                              SizedBox(width: 8.w),
                              Container(
                                width: 40.w,
                                height: 40.h,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(8.r),
                                ),
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  onPressed: () => setState(() => _numberOfVehicles = (_numberOfVehicles + 1).clamp(1, 50)),
                                  icon: Icon(Icons.add, color: Colors.white, size: 20.sp),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 20.h),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Date & Time', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp, fontFamily: 'Poppins', color: AppColors.textPrimary)),
                    SizedBox(height: 12.h),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now().add(const Duration(days: 1)),
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                              );
                              if (picked != null) setState(() => _travelDate = picked);
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
                                      _travelDate != null
                                          ? '${_travelDate!.day}-${_travelDate!.month}-${_travelDate!.year}'
                                          : 'Date *',
                                      style: TextStyle(fontFamily: 'Poppins', fontSize: 13.sp, color: _travelDate != null ? AppColors.textPrimary : AppColors.textHint),
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
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay.now(),
                              );
                              if (picked != null) setState(() => _travelTime = picked);
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
                                      _travelTime != null ? _formatTime(_travelTime!) : 'Time',
                                      style: TextStyle(fontFamily: 'Poppins', fontSize: 13.sp, color: _travelTime != null ? AppColors.textPrimary : AppColors.textHint),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_tripType == 'round_trip') ...[
                      SizedBox(height: 12.h),
                      Text('Return Date & Time', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.sp, fontFamily: 'Poppins', color: AppColors.textPrimary)),
                      SizedBox(height: 12.h),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: (_travelDate ?? DateTime.now()).add(const Duration(days: 1)),
                                  firstDate: _travelDate ?? DateTime.now(),
                                  lastDate: DateTime.now().add(const Duration(days: 365)),
                                );
                                if (picked != null) setState(() => _returnDate = picked);
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
                                        _returnDate != null
                                            ? '${_returnDate!.day}-${_returnDate!.month}-${_returnDate!.year}'
                                            : 'Return Date',
                                        style: TextStyle(fontFamily: 'Poppins', fontSize: 13.sp, color: _returnDate != null ? AppColors.textPrimary : AppColors.textHint),
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
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime: TimeOfDay.now(),
                                );
                                if (picked != null) setState(() => _returnTime = picked);
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
                                        _returnTime != null ? _formatTime(_returnTime!) : 'Return Time',
                                        style: TextStyle(fontFamily: 'Poppins', fontSize: 13.sp, color: _returnTime != null ? AppColors.textPrimary : AppColors.textHint),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
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
                BlocBuilder<RequirementsBloc, RequirementsState>(
                  builder: (context, state) => ElevatedButton(
                    onPressed: state is RequirementsLoading ? null : _submit,
                    child: state is RequirementsLoading
                        ? SizedBox(width: 20.w, height: 20.h, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text('Post Requirement', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600, fontFamily: 'Poppins')),
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
