import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../../../core/config/env.dart';
import '../../../../core/theme/app_theme.dart';
import '../bloc/requirements_bloc.dart';
import 'location_picker_page.dart';

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
  final _customFareCtrl = TextEditingController();
  String _vehicleType = 'sedan';
  String _tripType = 'one_way';
  int _numberOfVehicles = 1;
  DateTime? _travelDate;
  TimeOfDay? _travelTime;
  DateTime? _returnDate;
  TimeOfDay? _returnTime;
  bool _useCustomFare = false;

  // Location lat/lng from map picker
  double? _pickupLat, _pickupLng;
  double? _dropLat, _dropLng;
  double? _computedDistance;
  bool _loadingDistance = false;

  // Platform settings (fetched from backend)
  double _ratePerKm = 20.0;
  double _commissionPercent = 10.0;
  bool _settingsLoading = true;

  double get _distance => _computedDistance ?? 0.0;
  
  final _vehicleTypes = ['hatchback', 'sedan', 'suv', 'muv', 'traveller', 'tempo_traveller', 'mini_bus', 'bus'];
  final _tripTypes = ['one_way', 'round_trip', 'airport_transfer', 'local', 'outstation'];

  // Calculate total suggested fare
  double get _suggestedFare => _distance * _ratePerKm;
  
  // Get fare to use
  double get _currentFare {
    if (_useCustomFare && _customFareCtrl.text.isNotEmpty) {
      return double.tryParse(_customFareCtrl.text) ?? _suggestedFare;
    }
    return _suggestedFare;
  }
  
  double get _commission => _currentFare * (_commissionPercent / 100);
  
  // Calculate total
  double get _total => _currentFare + _commission;

  bool get _isCustomFareBelowMin {
    if (!_useCustomFare) return false;
    final entered = double.tryParse(_customFareCtrl.text);
    if (entered == null) return false;
    if (_suggestedFare <= 0) return false;
    return entered < _suggestedFare;
  }

  @override
  void initState() {
    super.initState();
    _fetchSettings();
  }

  Future<void> _fetchSettings() async {
    try {
      final res = await Dio().get('${Env.apiBaseUrl}/settings');
      final body = res.data as Map<String, dynamic>?;
      // Backend wraps all responses: { success, data: <actual payload> }
      final s = (body?['data'] as Map<String, dynamic>?) ?? body;
      if (s != null && mounted) {
        setState(() {
          _ratePerKm = (s['pricePerKm'] as num?)?.toDouble() ?? _ratePerKm;
          _commissionPercent = (s['commissionPercent'] as num?)?.toDouble() ?? _commissionPercent;
        });
      }
    } catch (_) {
      // keep defaults if backend unreachable
    } finally {
      if (mounted) setState(() => _settingsLoading = false);
    }
  }

  @override
  void dispose() {
    _pickupCtrl.dispose();
    _dropCtrl.dispose();
    _notesCtrl.dispose();
    _customFareCtrl.dispose();
    super.dispose();
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  Future<void> _updateDistance() async {
    if (_pickupLat == null || _dropLat == null) return;
    setState(() => _loadingDistance = true);

    double? routeKm;
    try {
      final res = await Dio().get(
        'http://router.project-osrm.org/route/v1/driving/$_pickupLng,$_pickupLat;$_dropLng,$_dropLat',
        queryParameters: {'overview': 'false'},
        options: Options(receiveTimeout: const Duration(seconds: 8)),
      );
      final data = res.data as Map<String, dynamic>;
      if (data['code'] == 'Ok') {
        final routes = data['routes'] as List;
        if (routes.isNotEmpty) {
          routeKm = (routes[0]['distance'] as num).toDouble() / 1000.0;
        }
      }
    } catch (_) {}

    setState(() {
      // fallback to straight-line if OSRM fails
      _computedDistance = routeKm ?? haversineDistanceKm(_pickupLat!, _pickupLng!, _dropLat!, _dropLng!);
      _loadingDistance = false;
    });
  }

  Future<void> _openPickup() async {
    final result = await Navigator.of(context).push<LocationPickerResult>(
      MaterialPageRoute(
        builder: (_) => LocationPickerPage(
          title: 'Pick Pickup Location',
          initialLat: _pickupLat,
          initialLng: _pickupLng,
        ),
      ),
    );
    if (result != null) {
      setState(() {
        _pickupCtrl.text = result.address;
        _pickupLat = result.lat;
        _pickupLng = result.lng;
      });
      _updateDistance();
    }
  }

  Future<void> _openDrop() async {
    final result = await Navigator.of(context).push<LocationPickerResult>(
      MaterialPageRoute(
        builder: (_) => LocationPickerPage(
          title: 'Pick Drop Location',
          initialLat: _dropLat,
          initialLng: _dropLng,
        ),
      ),
    );
    if (result != null) {
      setState(() {
        _dropCtrl.text = result.address;
        _dropLat = result.lat;
        _dropLng = result.lng;
      });
      _updateDistance();
    }
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
      if (_computedDistance != null) 'estimatedDistance': _computedDistance!.round(),
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
                      readOnly: true,
                      onTap: _openPickup,
                      decoration: InputDecoration(
                        labelText: 'Pickup Location *',
                        prefixIcon: Icon(Icons.location_on_outlined, color: AppColors.primary),
                        suffixIcon: Icon(Icons.map_outlined, color: AppColors.primary, size: 20.sp),
                        filled: true,
                        fillColor: Colors.grey[50],
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide(color: AppColors.border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide(color: AppColors.primary.withOpacity(0.7))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide(color: AppColors.primary, width: 2)),
                      ),
                      validator: (v) => v == null || v.isEmpty ? 'Tap to pick pickup location' : null,
                    ),
                    SizedBox(height: 12.h),
                    TextFormField(
                      controller: _dropCtrl,
                      readOnly: true,
                      onTap: _openDrop,
                      decoration: InputDecoration(
                        labelText: 'Drop Location *',
                        prefixIcon: Icon(Icons.location_off_outlined, color: AppColors.primary),
                        suffixIcon: Icon(Icons.map_outlined, color: AppColors.primary, size: 20.sp),
                        filled: true,
                        fillColor: Colors.grey[50],
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide(color: AppColors.border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide(color: AppColors.primary.withOpacity(0.7))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide(color: AppColors.primary, width: 2)),
                      ),
                      validator: (v) => v == null || v.isEmpty ? 'Tap to pick drop location' : null,
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
                SizedBox(height: 20.h),
                
                // Fare Selection Section
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Fare', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp, fontFamily: 'Poppins', color: AppColors.textPrimary)),
                    SizedBox(height: 12.h),
                    
                    // Suggested vs Custom Option
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _useCustomFare = false;
                              });
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: 12.h),
                              decoration: BoxDecoration(
                                color: _useCustomFare ? Colors.grey[100] : AppColors.primary,
                                borderRadius: BorderRadius.circular(12.r),
                                border: Border.all(
                                  color: _useCustomFare ? AppColors.border : AppColors.primary,
                                  width: 2,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  'App Suggested',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontWeight: FontWeight.w600,
                                    color: _useCustomFare ? AppColors.textHint : Colors.white,
                                    fontSize: 14.sp,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _useCustomFare = true;
                              });
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: 12.h),
                              decoration: BoxDecoration(
                                color: !_useCustomFare ? Colors.grey[100] : AppColors.primary,
                                borderRadius: BorderRadius.circular(12.r),
                                border: Border.all(
                                  color: !_useCustomFare ? AppColors.border : AppColors.primary,
                                  width: 2,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  'Enter Your Own',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontWeight: FontWeight.w600,
                                    color: !_useCustomFare ? AppColors.textHint : Colors.white,
                                    fontSize: 14.sp,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    SizedBox(height: 16.h),
                    
                    // Fare Details
                    Container(
                      padding: EdgeInsets.all(16.r),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                      ),
                      child: Column(
                        children: [
                          // Suggested Fare Details (always visible)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              if (_loadingDistance)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(width: 14.w, height: 14.h, child: const CircularProgressIndicator(strokeWidth: 2)),
                                    SizedBox(width: 8.w),
                                    Text('Calculating route...', style: TextStyle(fontFamily: 'Poppins', fontSize: 13.sp, color: AppColors.textHint)),
                                  ],
                                )
                              else
                                Text(
                                  _computedDistance != null
                                      ? 'Route = ${_computedDistance!.toStringAsFixed(1)} KM'
                                      : 'Route = — (pick locations)',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 14.sp,
                                    color: _computedDistance != null ? AppColors.textPrimary : AppColors.textHint,
                                  ),
                                ),
                              Text(
                                _settingsLoading ? 'Rate = loading...' : 'Rate = ₹${_ratePerKm.toStringAsFixed(0)}/km',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 14.sp,
                                  color: _settingsLoading ? AppColors.textHint : AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8.h),
                          if (!_useCustomFare) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Suggested Fare',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 15.sp,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  '₹${_suggestedFare.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 15.sp,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (_useCustomFare) ...[
                            TextFormField(
                              controller: _customFareCtrl,
                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: 'Enter Your Fare (₹)',
                                hintText: _suggestedFare > 0 ? 'Minimum ₹${_suggestedFare.toStringAsFixed(0)}' : 'Enter your fare',
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r), borderSide: BorderSide(color: AppColors.border)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r), borderSide: BorderSide(color: AppColors.primary.withOpacity(0.7))),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r), borderSide: BorderSide(color: AppColors.primary, width: 2)),
                              ),
                              onChanged: (value) {
                                setState(() {});
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your fare';
                                }
                                final entered = double.tryParse(value);
                                if (entered == null) {
                                  return 'Please enter valid number';
                                }
                                if (entered < _suggestedFare) {
                                  return 'Minimum fare is ₹${_suggestedFare.toStringAsFixed(0)}';
                                }
                                return null;
                              },
                            ),
                            SizedBox(height: 16.h),
                          ],
                          if (!_useCustomFare) SizedBox(height: 16.h),
                          Divider(color: AppColors.primary.withOpacity(0.2)),
                          SizedBox(height: 16.h),
                          
                          // Breakdown
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Base Fare',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 14.sp,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              Text(
                                '₹${_currentFare.toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 14.sp,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8.h),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Commission (${_commissionPercent.toStringAsFixed(0)}%)',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 14.sp,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              Text(
                                '₹${_commission.toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 14.sp,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12.h),
                          Divider(color: AppColors.primary.withOpacity(0.5)),
                          SizedBox(height: 12.h),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Total Amount',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                '₹${_total.toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 18.sp,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 24.h),
                BlocBuilder<RequirementsBloc, RequirementsState>(
                  builder: (context, state) => ElevatedButton(
                    onPressed: (state is RequirementsLoading || _isCustomFareBelowMin) ? null : _submit,
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
