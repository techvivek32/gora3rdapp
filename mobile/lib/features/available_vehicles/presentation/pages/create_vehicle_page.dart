import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../../../core/config/env.dart';
import '../../../../core/constants/vehicle_types.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../requirements/presentation/pages/location_picker_page.dart';
import '../bloc/vehicles_bloc.dart';

class CreateVehiclePage extends StatefulWidget {
  const CreateVehiclePage({super.key});

  @override
  State<CreateVehiclePage> createState() => _CreateVehiclePageState();
}

class _CreateVehiclePageState extends State<CreateVehiclePage> {
  final _formKey = GlobalKey<FormState>();
  final _currentCityCtrl = TextEditingController();
  final _destCityCtrl = TextEditingController();
  final _vehicleNumberCtrl = TextEditingController();
  final _driverNameCtrl = TextEditingController();
  final _driverMobileCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _vehicleType = 'sedan';
  DateTime? _availableDate;
  TimeOfDay? _availableTime;

  double? _currentLat, _currentLng;
  double? _destLat, _destLng;

  // Fare
  final _customFareCtrl = TextEditingController();
  final _commissionCtrl = TextEditingController(text: '0');
  bool _useCustomFare = false;
  double? _computedDistance;
  bool _loadingDistance = false;
  double _ratePerKm = 20.0;
  bool _settingsLoading = true;

  double get _distance => _computedDistance ?? 0.0;
  double get _suggestedFare => _distance * _ratePerKm;
  double get _currentFare {
    if (_useCustomFare && _customFareCtrl.text.isNotEmpty) {
      return double.tryParse(_customFareCtrl.text) ?? _suggestedFare;
    }
    return _suggestedFare;
  }
  double get _commission => double.tryParse(_commissionCtrl.text) ?? 0;
  double get _total => _currentFare + _commission;
  bool get _isCustomFareBelowMin {
    if (!_useCustomFare) return false;
    final entered = double.tryParse(_customFareCtrl.text);
    if (entered == null || _suggestedFare <= 0) return false;
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
      final s = (body?['data'] as Map<String, dynamic>?) ?? body;
      if (s != null && mounted) {
        setState(() => _ratePerKm = (s['pricePerKm'] as num?)?.toDouble() ?? _ratePerKm);
      }
    } catch (_) {
      // keep defaults
    } finally {
      if (mounted) setState(() => _settingsLoading = false);
    }
  }

  Future<void> _updateDistance() async {
    if (_currentLat == null || _destLat == null) {
      setState(() => _computedDistance = null);
      return;
    }
    setState(() => _loadingDistance = true);
    double? routeKm;
    try {
      final res = await Dio().get(
        'http://router.project-osrm.org/route/v1/driving/$_currentLng,$_currentLat;$_destLng,$_destLat',
        queryParameters: {'overview': 'false'},
        options: Options(receiveTimeout: const Duration(seconds: 8)),
      );
      final data = res.data as Map<String, dynamic>;
      if (data['code'] == 'Ok') {
        final routes = data['routes'] as List;
        if (routes.isNotEmpty) routeKm = (routes[0]['distance'] as num).toDouble() / 1000.0;
      }
    } catch (_) {}
    setState(() {
      _computedDistance = routeKm ?? haversineDistanceKm(_currentLat!, _currentLng!, _destLat!, _destLng!);
      _loadingDistance = false;
    });
  }

  final _vehicleTypes = kVehicleTypes;

  @override
  void dispose() {
    _currentCityCtrl.dispose(); _destCityCtrl.dispose();
    _vehicleNumberCtrl.dispose(); _driverNameCtrl.dispose();
    _driverMobileCtrl.dispose(); _notesCtrl.dispose();
    _customFareCtrl.dispose(); _commissionCtrl.dispose();
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
      _updateDistance();
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
      _updateDistance();
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
    context.read<VehiclesBloc>().add(CreateVehicleEvent({
      'currentCity': _currentCityCtrl.text.trim(),
      'destinationCity': _destCityCtrl.text.trim().isEmpty ? null : _destCityCtrl.text.trim(),
      if (_currentLat != null && _currentLng != null)
        'currentCoordinates': {'lat': _currentLat, 'lng': _currentLng, 'address': _currentCityCtrl.text.trim()},
      if (_destLat != null && _destLng != null)
        'destinationCoordinates': {'lat': _destLat, 'lng': _destLng, 'address': _destCityCtrl.text.trim()},
      'vehicleType': _vehicleType,
      'vehicleNumber': _vehicleNumberCtrl.text.trim().toUpperCase(),
      'driverName': _driverNameCtrl.text.trim(),
      'driverMobile': _driverMobileCtrl.text.trim(),
      'availableDate': _availableDate!.toIso8601String().split('T').first,
      'availableTime': _availableTime != null ? '${_availableTime!.hour.toString().padLeft(2, '0')}:${_availableTime!.minute.toString().padLeft(2, '0')}' : '00:00',
      'notes': _notesCtrl.text.trim(),
      if (_computedDistance != null) 'estimatedDistance': _computedDistance!.round(),
      'fare': _currentFare.round(),
      'commission': _commission.round(),
      'totalAmount': _total.round(),
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
                      readOnly: true,
                      onTap: _openCurrentCity,
                      decoration: InputDecoration(
                        labelText: 'Current City *',
                        prefixIcon: Icon(Icons.my_location_outlined, color: AppColors.primary),
                        suffixIcon: Icon(Icons.map_outlined, color: AppColors.primary, size: 20.sp),
                        filled: true,
                        fillColor: Colors.grey[50],
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide(color: AppColors.border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide(color: AppColors.primary.withOpacity(0.7))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide(color: AppColors.primary, width: 2)),
                      ),
                      validator: (v) => v == null || v.isEmpty ? 'Tap to pick current location' : null,
                    ),
                    SizedBox(height: 12.h),
                    TextFormField(
                      controller: _destCityCtrl,
                      readOnly: true,
                      onTap: _openDestCity,
                      decoration: InputDecoration(
                        labelText: 'Available For (Destination City)',
                        prefixIcon: Icon(Icons.location_on_outlined, color: AppColors.primary),
                        suffixIcon: Icon(Icons.map_outlined, color: AppColors.primary, size: 20.sp),
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
                      items: _vehicleTypes.map((v) => DropdownMenuItem(value: v['value'], child: Text(v['label']!, style: TextStyle(fontFamily: 'Poppins')))).toList(),
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
                                      _availableDate != null
                                          ? '${_availableDate!.day}-${_availableDate!.month}-${_availableDate!.year}'
                                          : 'Date *',
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
                _buildFareSection(),
                SizedBox(height: 24.h),
                BlocBuilder<VehiclesBloc, VehiclesState>(
                  builder: (context, state) => ElevatedButton(
                    onPressed: (state is VehiclesLoading || _isCustomFareBelowMin) ? null : _submit,
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

  Widget _buildFareSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Fare', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp, fontFamily: 'Poppins', color: AppColors.textPrimary)),
        SizedBox(height: 12.h),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _useCustomFare = false),
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  decoration: BoxDecoration(
                    color: _useCustomFare ? Colors.grey[100] : AppColors.primary,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: _useCustomFare ? AppColors.border : AppColors.primary, width: 2),
                  ),
                  child: Center(
                    child: Text('App Suggested',
                        style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, color: _useCustomFare ? AppColors.textHint : Colors.white, fontSize: 14.sp)),
                  ),
                ),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _useCustomFare = true),
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  decoration: BoxDecoration(
                    color: !_useCustomFare ? Colors.grey[100] : AppColors.primary,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: !_useCustomFare ? AppColors.border : AppColors.primary, width: 2),
                  ),
                  child: Center(
                    child: Text('Enter Your Own',
                        style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, color: !_useCustomFare ? AppColors.textHint : Colors.white, fontSize: 14.sp)),
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 16.h),
        Container(
          padding: EdgeInsets.all(16.r),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: AppColors.primary.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _loadingDistance
                      ? Row(mainAxisSize: MainAxisSize.min, children: [
                          SizedBox(width: 14.w, height: 14.h, child: const CircularProgressIndicator(strokeWidth: 2)),
                          SizedBox(width: 8.w),
                          Text('Calculating route...', style: TextStyle(fontFamily: 'Poppins', fontSize: 13.sp, color: AppColors.textHint)),
                        ])
                      : Text(
                          _computedDistance != null ? 'Route = ${_computedDistance!.toStringAsFixed(1)} KM' : 'Route = — (pick locations)',
                          style: TextStyle(fontFamily: 'Poppins', fontSize: 14.sp, color: _computedDistance != null ? AppColors.textPrimary : AppColors.textHint),
                        ),
                  Text(
                    _settingsLoading ? 'Rate = loading...' : 'Rate = ₹${_ratePerKm.toStringAsFixed(0)}/km',
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 14.sp, color: _settingsLoading ? AppColors.textHint : AppColors.textPrimary),
                  ),
                ],
              ),
              SizedBox(height: 8.h),
              if (!_useCustomFare)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Suggested Fare', style: TextStyle(fontFamily: 'Poppins', fontSize: 15.sp, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    Text('₹${_suggestedFare.toStringAsFixed(0)}', style: TextStyle(fontFamily: 'Poppins', fontSize: 15.sp, fontWeight: FontWeight.w600, color: AppColors.primary)),
                  ],
                ),
              if (_useCustomFare)
                TextFormField(
                  controller: _customFareCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Enter Your Fare (₹)',
                    hintText: _suggestedFare > 0 ? 'Minimum ₹${_suggestedFare.toStringAsFixed(0)}' : 'Enter your fare',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r), borderSide: BorderSide(color: AppColors.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r), borderSide: BorderSide(color: AppColors.primary.withOpacity(0.7))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r), borderSide: BorderSide(color: AppColors.primary, width: 2)),
                  ),
                  validator: (v) {
                    if (!_useCustomFare) return null;
                    if (v == null || v.isEmpty) return 'Please enter your fare';
                    final entered = double.tryParse(v);
                    if (entered == null) return 'Please enter valid number';
                    if (_suggestedFare > 0 && entered < _suggestedFare) return 'Minimum fare is ₹${_suggestedFare.toStringAsFixed(0)}';
                    return null;
                  },
                ),
              SizedBox(height: 16.h),
              Divider(color: AppColors.primary.withOpacity(0.2)),
              SizedBox(height: 12.h),
              Row(
                children: [
                  Expanded(child: Text('Commission (₹)', style: TextStyle(fontFamily: 'Poppins', fontSize: 14.sp, color: AppColors.textSecondary))),
                  SizedBox(
                    width: 110.w,
                    child: TextFormField(
                      controller: _commissionCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.right,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        isDense: true,
                        prefixText: '₹ ',
                        contentPadding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r), borderSide: BorderSide(color: AppColors.border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r), borderSide: BorderSide(color: AppColors.primary.withOpacity(0.7))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r), borderSide: BorderSide(color: AppColors.primary, width: 2)),
                      ),
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
                  Text('Total Amount', style: TextStyle(fontFamily: 'Poppins', fontSize: 16.sp, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  Text('₹${_total.toStringAsFixed(0)}', style: TextStyle(fontFamily: 'Poppins', fontSize: 18.sp, fontWeight: FontWeight.w700, color: AppColors.primary)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
