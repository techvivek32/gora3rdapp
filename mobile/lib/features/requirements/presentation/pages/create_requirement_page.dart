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

  final _vehicleTypes = ['hatchback', 'sedan', 'suv', 'muv', 'traveller', 'tempo_traveller', 'mini_bus', 'bus'];
  final _tripTypes = ['one_way', 'round_trip', 'airport_transfer', 'local', 'outstation'];

  @override
  void dispose() {
    _pickupCtrl.dispose();
    _dropCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
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
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.r),
                    side: BorderSide(color: AppColors.border),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(16.r),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Route Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp, fontFamily: 'Poppins', color: AppColors.textPrimary)),
                        SizedBox(height: 12.h),
                        TextFormField(
                          controller: _pickupCtrl,
                          decoration: InputDecoration(labelText: 'Pickup City *', prefixIcon: Icon(Icons.location_on_outlined)),
                          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                        ),
                        SizedBox(height: 12.h),
                        TextFormField(
                          controller: _dropCtrl,
                          decoration: InputDecoration(labelText: 'Drop City *', prefixIcon: Icon(Icons.location_off_outlined)),
                          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 12.h),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.r),
                    side: BorderSide(color: AppColors.border),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(16.r),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Vehicle Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp, fontFamily: 'Poppins', color: AppColors.textPrimary)),
                        SizedBox(height: 12.h),
                        DropdownButtonFormField<String>(
                          value: _tripType,
                          decoration: InputDecoration(labelText: 'Trip Type'),
                          items: _tripTypes.map((t) => DropdownMenuItem(value: t, child: Text(t.replaceAll('_', ' ').toUpperCase(), style: TextStyle(fontFamily: 'Poppins')))).toList(),
                          onChanged: (v) => setState(() => _tripType = v!),
                        ),
                        SizedBox(height: 12.h),
                        DropdownButtonFormField<String>(
                          value: _vehicleType,
                          decoration: InputDecoration(labelText: 'Vehicle Type'),
                          items: _vehicleTypes.map((v) => DropdownMenuItem(value: v, child: Text(v.replaceAll('_', ' ').toUpperCase(), style: TextStyle(fontFamily: 'Poppins')))).toList(),
                          onChanged: (v) => setState(() => _vehicleType = v!),
                        ),
                        SizedBox(height: 12.h),
                        Row(
                          children: [
                            Text('Number of Vehicles: ', style: TextStyle(fontSize: 16.sp, fontFamily: 'Poppins', color: AppColors.textPrimary)),
                            const Spacer(),
                            IconButton(
                              onPressed: () => setState(() => _numberOfVehicles = (_numberOfVehicles - 1).clamp(1, 50)),
                              icon: Icon(Icons.remove_circle_outline, color: AppColors.textSecondary, size: 24.sp),
                            ),
                            Text('$_numberOfVehicles', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold, fontFamily: 'Poppins', color: AppColors.textPrimary)),
                            IconButton(
                              onPressed: () => setState(() => _numberOfVehicles = (_numberOfVehicles + 1).clamp(1, 50)),
                              icon: Icon(Icons.add_circle_outline, color: AppColors.primary, size: 24.sp),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 12.h),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.r),
                    side: BorderSide(color: AppColors.border),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(16.r),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Date & Time', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp, fontFamily: 'Poppins', color: AppColors.textPrimary)),
                        SizedBox(height: 12.h),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.calendar_today_outlined, color: AppColors.textHint, size: 20.sp),
                          title: Text(_travelDate != null
                              ? '${_travelDate!.day}/${_travelDate!.month}/${_travelDate!.year}'
                              : 'Select Travel Date *', style: TextStyle(fontFamily: 'Poppins')),
                          trailing: Icon(Icons.chevron_right, color: AppColors.textHint),
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now().add(const Duration(days: 1)),
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null) setState(() => _travelDate = picked);
                          },
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.access_time, color: AppColors.textHint, size: 20.sp),
                          title: Text(_travelTime != null ? _travelTime!.format(context) : 'Select Travel Time', style: TextStyle(fontFamily: 'Poppins')),
                          trailing: Icon(Icons.chevron_right, color: AppColors.textHint),
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.now(),
                            );
                            if (picked != null) setState(() => _travelTime = picked);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 12.h),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.r),
                    side: BorderSide(color: AppColors.border),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(16.r),
                    child: TextFormField(
                      controller: _notesCtrl,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Additional Notes (Optional)',
                        alignLabelWithHint: true,
                      ),
                    ),
                  ),
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
