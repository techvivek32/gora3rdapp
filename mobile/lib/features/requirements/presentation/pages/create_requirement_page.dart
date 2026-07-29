import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../../../core/config/env.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../../core/constants/vehicle_types.dart';
import '../../../../core/theme/app_theme.dart';
import '../bloc/requirements_bloc.dart';
import '../../../../core/widgets/address_autocomplete_field.dart';
import 'location_picker_page.dart' show haversineDistanceKm;

class CreateRequirementPage extends StatefulWidget {
  // When [existing] is provided the page acts as an edit form for that requirement.
  final Map<String, dynamic>? existing;
  final String? requirementId;
  const CreateRequirementPage({super.key, this.existing, this.requirementId});

  @override
  State<CreateRequirementPage> createState() => _CreateRequirementPageState();
}

class _CreateRequirementPageState extends State<CreateRequirementPage> {
  final _formKey = GlobalKey<FormState>();
  final _pickupCtrl = TextEditingController();
  final _dropCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _customFareCtrl = TextEditingController();
  final _commissionCtrl = TextEditingController(text: '0');
  String _vehicleType = 'sedan';
  String _tripType = 'one_way';
  String _fuelType = 'any';
  final List<_Stop> _stops = [];
  DateTime? _travelDate;
  TimeOfDay? _travelTime;
  DateTime? _returnDate;
  TimeOfDay? _returnTime;
  bool _useCustomFare = false;

  // Location lat/lng from map picker
  double? _pickupLat, _pickupLng;
  double? _dropLat, _dropLng;
  String? _pickupCity, _dropCity; // clean city names for filtering
  double? _computedDistance;
  bool _loadingDistance = false;

  // Platform settings (fetched from backend)
  double _ratePerKm = 20.0;
  Map<String, double> _vehiclePrices = {};
  bool _settingsLoading = true;

  double get _distance => _computedDistance ?? 0.0;
  
  // Rate for the currently selected vehicle type
  double get _rateForVehicle {
    if (_vehiclePrices.containsKey(_vehicleType)) return _vehiclePrices[_vehicleType]!;
    return _ratePerKm; // fallback to global rate
  }
  
  final _vehicleTypes = kVehicleTypes;
  final _tripTypes = ['one_way', 'round_trip', 'airport_transfer', 'local'];
  final _fuelTypes = const [
    {'value': 'any', 'label': 'Any Fuel'},
    {'value': 'diesel', 'label': 'Diesel'},
    {'value': 'petrol', 'label': 'Petrol'},
    {'value': 'cng', 'label': 'CNG'},
  ];

  // Calculate total suggested fare
  double get _suggestedFare => _distance * _rateForVehicle;
  
  // Get fare to use
  double get _currentFare {
    if (_useCustomFare && _customFareCtrl.text.isNotEmpty) {
      return double.tryParse(_customFareCtrl.text) ?? _suggestedFare;
    }
    return _suggestedFare;
  }
  
  double get _commission => double.tryParse(_commissionCtrl.text) ?? 0;
  
  // Calculate total
  double get _total => _currentFare + _commission;

  // Users may enter any amount now (no minimum enforced against the suggested fare).
  bool get _isCustomFareBelowMin => false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _fetchSettings();
    if (widget.existing != null) _populateFromExisting(widget.existing!);
  }

  void _populateFromExisting(Map<String, dynamic> r) {
    _pickupCtrl.text = (r['pickupCity'] ?? '') as String;
    _dropCtrl.text = (r['dropCity'] ?? '') as String;
    _notesCtrl.text = (r['notes'] ?? '') as String;
    _vehicleType = (r['vehicleType'] as String?) ?? 'sedan';
    _tripType = (r['tripType'] as String?) ?? 'one_way';
    _fuelType = (r['fuelType'] as String?) ?? 'any';

    final pc = r['pickupCoordinates'] as Map?;
    if (pc != null) {
      _pickupLat = (pc['lat'] as num?)?.toDouble();
      _pickupLng = (pc['lng'] as num?)?.toDouble();
    }
    final dc = r['dropCoordinates'] as Map?;
    if (dc != null) {
      _dropLat = (dc['lat'] as num?)?.toDouble();
      _dropLng = (dc['lng'] as num?)?.toDouble();
    }
    for (final s in (r['stops'] as List? ?? const [])) {
      final stop = _Stop();
      stop.ctrl.text = (s is Map ? s['address'] : null)?.toString() ?? '';
      stop.lat = s is Map ? (s['lat'] as num?)?.toDouble() : null;
      stop.lng = s is Map ? (s['lng'] as num?)?.toDouble() : null;
      _stops.add(stop);
    }

    if (r['commission'] != null) _commissionCtrl.text = '${(r['commission'] as num).round()}';
    if (r['fare'] != null) _customFareCtrl.text = '${(r['fare'] as num).round()}';
    if (r['estimatedDistance'] != null) _computedDistance = (r['estimatedDistance'] as num).toDouble();
    if (r['travelDate'] != null) {
      try {
        _travelDate = DateTime.parse(r['travelDate'].toString());
      } catch (_) {}
    }
    if (r['travelTime'] != null) {
      try {
        final p = (r['travelTime'] as String).split(':');
        _travelTime = TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
      } catch (_) {}
    }
    if (r['returnDate'] != null) {
      try {
        _returnDate = DateTime.parse(r['returnDate'].toString());
      } catch (_) {}
    }
    if (r['returnTime'] != null) {
      try {
        final p = (r['returnTime'] as String).split(':');
        _returnTime = TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
      } catch (_) {}
    }
    // Recompute distance through the route if we have coordinates.
    if (_pickupLat != null && _dropLat != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _updateDistance());
    }
  }

  Future<void> _fetchSettings() async {
    try {
      final res = await Dio().get('${Env.apiBaseUrl}/settings');
      final body = res.data as Map<String, dynamic>?;
      final s = (body?['data'] as Map<String, dynamic>?) ?? body;
      if (s != null && mounted) {
        setState(() {
          _ratePerKm = (s['pricePerKm'] as num?)?.toDouble() ?? _ratePerKm;
          final vp = s['vehiclePrices'];
          if (vp is Map) {
            _vehiclePrices = vp.map((k, v) => MapEntry(k.toString(), (v as num).toDouble()));
          }
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
    _commissionCtrl.dispose();
    for (final s in _stops) {
      s.ctrl.dispose();
    }
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

    // Ordered waypoints: pickup -> stops (with a location) -> drop.
    final points = <List<double>>[
      [_pickupLat!, _pickupLng!],
      for (final s in _stops)
        if (s.lat != null && s.lng != null) [s.lat!, s.lng!],
      [_dropLat!, _dropLng!],
    ];

    double? routeKm;

    // 1) Preferred: Google Directions via our backend proxy — this returns the
    // SAME road distance Google Maps shows (OSRM routes a few % shorter, e.g.
    // 214 vs 222 km). Points are sent as "lat,lng;lat,lng;..." in visit order.
    try {
      final pointsStr = points.map((p) => '${p[0]},${p[1]}').join(';');
      final res = await Dio().get(
        '${Env.apiBaseUrl}/places/route',
        queryParameters: {'points': pointsStr},
        options: Options(receiveTimeout: const Duration(seconds: 10)),
      );
      final km = (res.data as Map<String, dynamic>)['data']?['distanceKm'];
      if (km is num && km > 0) routeKm = km.toDouble();
    } catch (_) {}

    // 2) Fallback: OSRM total distance through all waypoints in order.
    if (routeKm == null) {
      try {
        final coordStr = points.map((p) => '${p[1]},${p[0]}').join(';');
        final res = await Dio().get(
          // HTTPS, not HTTP: Android blocks cleartext by default, which silently made
          // this fail and fall back to straight-line distance (e.g. 96 vs 154 km).
          'https://router.project-osrm.org/route/v1/driving/$coordStr',
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
    }

    // Fallback: sum straight-line distance between consecutive waypoints.
    double fallback = 0;
    for (var i = 0; i < points.length - 1; i++) {
      fallback += haversineDistanceKm(points[i][0], points[i][1], points[i + 1][0], points[i + 1][1]);
    }

    setState(() {
      _computedDistance = routeKm ?? fallback;
      _loadingDistance = false;
    });
  }

  void _onPickupSelected(String address, double lat, double lng, String? city) {
    setState(() {
      _pickupLat = lat;
      _pickupLng = lng;
      _pickupCity = (city == null || city.isEmpty) ? address : city;
    });
    _updateDistance();
  }

  void _onDropSelected(String address, double lat, double lng, String? city) {
    setState(() {
      _dropLat = lat;
      _dropLng = lng;
      _dropCity = (city == null || city.isEmpty) ? address : city;
    });
    _updateDistance();
  }

  void _onStopSelected(_Stop stop, String address, double lat, double lng, String? city) {
    setState(() {
      stop.lat = lat;
      stop.lng = lng;
    });
    _updateDistance();
  }

  void _addStop() {
    setState(() => _stops.add(_Stop()));
  }

  void _removeStop(int index) {
    setState(() {
      _stops[index].ctrl.dispose();
      _stops.removeAt(index);
    });
    _updateDistance();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_travelDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please select travel date'.tr), backgroundColor: AppColors.error));
      return;
    }
    if (_travelTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please select travel time'.tr), backgroundColor: AppColors.error));
      return;
    }
    final data = <String, dynamic>{
      'pickupCity': _pickupCtrl.text.trim(),
      'dropCity': _dropCtrl.text.trim(),
      if (_pickupCity != null && _pickupCity!.isNotEmpty) 'pickupCityName': _pickupCity!.trim(),
      if (_dropCity != null && _dropCity!.isNotEmpty) 'dropCityName': _dropCity!.trim(),
      'vehicleType': _vehicleType,
      'tripType': _tripType,
      'fuelType': _fuelType,
      'stops': _stops
          .where((s) => s.ctrl.text.trim().isNotEmpty)
          .map((s) => {'address': s.ctrl.text.trim(), 'lat': s.lat, 'lng': s.lng})
          .toList(),
      'travelDate': _travelDate!.toIso8601String().split('T').first,
      'travelTime': _travelTime != null ? '${_travelTime!.hour.toString().padLeft(2, '0')}:${_travelTime!.minute.toString().padLeft(2, '0')}' : '00:00',
      if (_tripType == 'round_trip' && _returnDate != null)
        'returnDate': _returnDate!.toIso8601String().split('T').first,
      if (_tripType == 'round_trip' && _returnTime != null)
        'returnTime': '${_returnTime!.hour.toString().padLeft(2, '0')}:${_returnTime!.minute.toString().padLeft(2, '0')}',
      'notes': _notesCtrl.text.trim(),
      if (_computedDistance != null) 'estimatedDistance': _computedDistance!.round(),
      'fare': _currentFare.round(),
      'commission': _commission.round(),
      'totalAmount': _total.round(),
      'isAppSuggested': !_useCustomFare,
      if (_pickupLat != null && _pickupLng != null)
        'pickupCoordinates': {'lat': _pickupLat, 'lng': _pickupLng, 'address': _pickupCtrl.text.trim()},
      if (_dropLat != null && _dropLng != null)
        'dropCoordinates': {'lat': _dropLat, 'lng': _dropLng, 'address': _dropCtrl.text.trim()},
    };

    final bloc = context.read<RequirementsBloc>();
    if (_isEdit) {
      bloc.add(UpdateRequirementEvent(id: widget.requirementId!, data: data));
      return;
    }
    bloc.add(CreateRequirementEvent(data: data));
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(_isEdit ? 'Edit Booking' : 'Post Booking'.tr, style: TextStyle(fontFamily: 'Poppins')), centerTitle: true),
      body: BlocListener<RequirementsBloc, RequirementsState>(
        listener: (context, state) {
          if (state is RequirementCreated || state is RequirementUpdated) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isEdit ? 'Booking updated!' : 'Booking posted!'), backgroundColor: AppColors.success));
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
                    Text('Route Details'.tr, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp, fontFamily: 'Poppins', color: AppColors.textPrimary)),
                    SizedBox(height: 12.h),
                    AddressAutocompleteField(
                      controller: _pickupCtrl,
                      label: 'Pickup Location *',
                      prefixIcon: Icons.location_on_outlined,
                      onSelected: _onPickupSelected,
                      validator: (v) => v == null || v.isEmpty ? 'Enter pickup location' : null,
                    ),
                    SizedBox(height: 12.h),

                    // Intermediate stops
                    ..._stops.asMap().entries.map((e) {
                      final i = e.key;
                      final stop = e.value;
                      return Padding(
                        padding: EdgeInsets.only(bottom: 12.h),
                        child: AddressAutocompleteField(
                          controller: stop.ctrl,
                          label: 'Stop ${i + 1}',
                          prefixIcon: Icons.add_location_alt_outlined,
                          onSelected: (a, lat, lng, city) => _onStopSelected(stop, a, lat, lng, city),
                          suffix: IconButton(
                            icon: Icon(Icons.close, color: AppColors.error, size: 20.sp),
                            tooltip: 'Remove stop'.tr,
                            onPressed: () => _removeStop(i),
                          ),
                        ),
                      );
                    }),

                    AddressAutocompleteField(
                      controller: _dropCtrl,
                      label: 'Drop Location *',
                      prefixIcon: Icons.location_off_outlined,
                      onSelected: _onDropSelected,
                      validator: (v) => v == null || v.isEmpty ? 'Enter drop location' : null,
                    ),
                    SizedBox(height: 4.h),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: _addStop,
                        icon: Icon(Icons.add_circle_outline, color: AppColors.primary, size: 20.sp),
                        label: Text('Add Stop'.tr, style: TextStyle(color: AppColors.primary, fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
                        style: TextButton.styleFrom(padding: EdgeInsets.symmetric(horizontal: 4.w)),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20.h),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Vehicle Details'.tr, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp, fontFamily: 'Poppins', color: AppColors.textPrimary)),
                    SizedBox(height: 12.h),
                    DropdownButtonFormField<String>(
                      value: _tripType,
                      decoration: InputDecoration(
                        labelText: 'Trip Type'.tr,
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
                        labelText: 'Vehicle Type'.tr,
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
                      value: _fuelType,
                      decoration: InputDecoration(
                        labelText: 'Fuel Type'.tr,
                        filled: true,
                        fillColor: Colors.grey[50],
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide(color: AppColors.border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide(color: AppColors.primary.withOpacity(0.7))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide(color: AppColors.primary, width: 2)),
                      ),
                      items: _fuelTypes.map((f) => DropdownMenuItem(value: f['value'], child: Text(f['label']!, style: TextStyle(fontFamily: 'Poppins')))).toList(),
                      onChanged: (v) => setState(() => _fuelType = v!),
                    ),
                  ],
                ),
                SizedBox(height: 20.h),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Date & Time'.tr, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp, fontFamily: 'Poppins', color: AppColors.textPrimary)),
                    SizedBox(height: 12.h),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _travelDate ?? DateTime.now(),
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
                                      _travelTime != null ? _formatTime(_travelTime!) : 'Time *',
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
                      Text('Return Date & Time'.tr, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.sp, fontFamily: 'Poppins', color: AppColors.textPrimary)),
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
                                            : 'Return Date'.tr,
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
                                        _returnTime != null ? _formatTime(_returnTime!) : 'Return Time'.tr,
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
                    Text('Additional Notes (Optional)'.tr, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp, fontFamily: 'Poppins', color: AppColors.textPrimary)),
                    SizedBox(height: 12.h),
                    TextFormField(
                      controller: _notesCtrl,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Add any additional notes here...'.tr,
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
                    Text('Fare'.tr, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp, fontFamily: 'Poppins', color: AppColors.textPrimary)),
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
                                  'App Suggested'.tr,
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
                                  'Enter Your Own'.tr,
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
                    
                    if (_useCustomFare) SizedBox(height: 16.h),

                    // Fare details box — only shown when entering your own fare.
                    if (_useCustomFare)
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
                                    Text('Calculating route...'.tr, style: TextStyle(fontFamily: 'Poppins', fontSize: 13.sp, color: AppColors.textHint)),
                                  ],
                                )
                              else
                                Expanded(
                                  child: Text(
                                    _computedDistance != null
                                        ? 'Route = ${_computedDistance!.toStringAsFixed(1)} KM  ·  ₹${_rateForVehicle.toStringAsFixed(0)}/km'
                                        : 'Route = — (pick locations)',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 13.sp,
                                      color: _computedDistance != null ? AppColors.textPrimary : AppColors.textHint,
                                    ),
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
                                  'Suggested Fare'.tr,
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
                          SizedBox(height: 12.h),
                          // Driver Fee (left) + Commission (right) in one row.
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _customFareCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  onChanged: (_) => setState(() {}),
                                  decoration: InputDecoration(
                                    labelText: 'Driver Fee (₹)',
                                    hintText: _suggestedFare > 0 ? '₹${_suggestedFare.toStringAsFixed(0)} (${_rateForVehicle.toStringAsFixed(0)}/km)' : 'Fare'.tr,
                                    prefixText: '₹ ',
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 12.h),
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r), borderSide: BorderSide(color: AppColors.border)),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r), borderSide: BorderSide(color: AppColors.primary.withOpacity(0.7))),
                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r), borderSide: BorderSide(color: AppColors.primary, width: 2)),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) return 'Enter fare';
                                    final entered = double.tryParse(value);
                                    if (entered == null) return 'Invalid';
                                    return null;
                                  },
                                ),
                              ),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: TextFormField(
                                  controller: _commissionCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  onChanged: (_) => setState(() {}),
                                  decoration: InputDecoration(
                                    labelText: 'Commission (₹)',
                                    prefixText: '₹ ',
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 12.h),
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
                        : Text(_isEdit ? 'Save Changes' : 'Post Booking'.tr, style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600, fontFamily: 'Poppins')),
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

class _Stop {
  final TextEditingController ctrl = TextEditingController();
  double? lat;
  double? lng;
}
