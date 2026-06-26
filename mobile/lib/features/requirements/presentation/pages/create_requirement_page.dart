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
  final List<_Stop> _stops = [];
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
  
  double get _commission => double.tryParse(_commissionCtrl.text) ?? 0;
  
  // Calculate total
  double get _total => _currentFare + _commission;

  bool get _isCustomFareBelowMin {
    if (!_useCustomFare) return false;
    final entered = double.tryParse(_customFareCtrl.text);
    if (entered == null) return false;
    if (_suggestedFare <= 0) return false;
    return entered < _suggestedFare;
  }

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
    // Recompute distance through the route if we have coordinates.
    if (_pickupLat != null && _dropLat != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _updateDistance());
    }
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
    try {
      // OSRM returns the total distance through all waypoints in order.
      final coordStr = points.map((p) => '${p[1]},${p[0]}').join(';');
      final res = await Dio().get(
        'http://router.project-osrm.org/route/v1/driving/$coordStr',
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

  Future<void> _openStop(_Stop stop) async {
    final result = await Navigator.of(context).push<LocationPickerResult>(
      MaterialPageRoute(
        builder: (_) => LocationPickerPage(
          title: 'Pick Stop Location',
          initialLat: stop.lat,
          initialLng: stop.lng,
        ),
      ),
    );
    if (result != null) {
      setState(() {
        stop.ctrl.text = result.address;
        stop.lat = result.lat;
        stop.lng = result.lng;
      });
      _updateDistance();
    }
  }

  void _addStop() {
    final stop = _Stop();
    setState(() => _stops.add(stop));
    _openStop(stop);
  }

  void _removeStop(int index) {
    setState(() {
      _stops[index].ctrl.dispose();
      _stops.removeAt(index);
    });
    _updateDistance();
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
    final data = <String, dynamic>{
      'pickupCity': _pickupCtrl.text.trim(),
      'dropCity': _dropCtrl.text.trim(),
      'vehicleType': _vehicleType,
      'tripType': _tripType,
      'stops': _stops
          .where((s) => s.ctrl.text.trim().isNotEmpty)
          .map((s) => {'address': s.ctrl.text.trim(), 'lat': s.lat, 'lng': s.lng})
          .toList(),
      'travelDate': _travelDate!.toIso8601String().split('T').first,
      'travelTime': _travelTime != null ? '${_travelTime!.hour.toString().padLeft(2, '0')}:${_travelTime!.minute.toString().padLeft(2, '0')}' : '00:00',
      'notes': _notesCtrl.text.trim(),
      if (_computedDistance != null) 'estimatedDistance': _computedDistance!.round(),
      'fare': _currentFare.round(),
      'commission': _commission.round(),
      'totalAmount': _total.round(),
      if (_pickupLat != null && _pickupLng != null)
        'pickupCoordinates': {'lat': _pickupLat, 'lng': _pickupLng, 'address': _pickupCtrl.text.trim()},
      if (_dropLat != null && _dropLng != null)
        'dropCoordinates': {'lat': _dropLat, 'lng': _dropLng, 'address': _dropCtrl.text.trim()},
    };

    final bloc = context.read<RequirementsBloc>();
    if (_isEdit) {
      bloc.add(UpdateRequirementEvent(id: widget.requirementId!, data: data));
    } else {
      bloc.add(CreateRequirementEvent(data: data));
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(_isEdit ? 'Edit Requirement' : 'Post Requirement', style: TextStyle(fontFamily: 'Poppins')), centerTitle: true),
      body: BlocListener<RequirementsBloc, RequirementsState>(
        listener: (context, state) {
          if (state is RequirementCreated || state is RequirementUpdated) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isEdit ? 'Requirement updated!' : 'Requirement posted!'), backgroundColor: AppColors.success));
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

                    // Intermediate stops
                    ..._stops.asMap().entries.map((e) {
                      final i = e.key;
                      final stop = e.value;
                      return Padding(
                        padding: EdgeInsets.only(bottom: 12.h),
                        child: TextFormField(
                          controller: stop.ctrl,
                          readOnly: true,
                          onTap: () => _openStop(stop),
                          decoration: InputDecoration(
                            labelText: 'Stop ${i + 1}',
                            prefixIcon: Icon(Icons.add_location_alt_outlined, color: AppColors.primary),
                            suffixIcon: IconButton(
                              icon: Icon(Icons.close, color: AppColors.error, size: 20.sp),
                              tooltip: 'Remove stop',
                              onPressed: () => _removeStop(i),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide(color: AppColors.border)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide(color: AppColors.primary.withOpacity(0.7))),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide(color: AppColors.primary, width: 2)),
                          ),
                        ),
                      );
                    }),

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
                    SizedBox(height: 4.h),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: _addStop,
                        icon: Icon(Icons.add_circle_outline, color: AppColors.primary, size: 20.sp),
                        label: Text('Add Stop', style: TextStyle(color: AppColors.primary, fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
                        style: TextButton.styleFrom(padding: EdgeInsets.symmetric(horizontal: 4.w)),
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
                            children: [
                              Expanded(
                                child: Text(
                                  'Commission (₹)',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 14.sp,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
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
                        : Text(_isEdit ? 'Save Changes' : 'Post Requirement', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600, fontFamily: 'Poppins')),
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
