import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:dio/dio.dart';
import '../../../../core/theme/app_theme.dart';

class LocationPickerResult {
  final String address;
  final double lat;
  final double lng;
  const LocationPickerResult({required this.address, required this.lat, required this.lng});
}

class LocationPickerPage extends StatefulWidget {
  final String title;
  final double? initialLat;
  final double? initialLng;

  const LocationPickerPage({
    super.key,
    required this.title,
    this.initialLat,
    this.initialLng,
  });

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  static const _defaultLat = 23.0225;
  static const _defaultLng = 72.5714; // Ahmedabad

  GoogleMapController? _mapCtrl;
  late LatLng _center;
  String _address = 'Move the map to select location';
  bool _loading = false;
  bool _pinMoving = false;
  Timer? _debounce;
  final _dio = Dio();

  @override
  void initState() {
    super.initState();
    _center = LatLng(
      widget.initialLat ?? _defaultLat,
      widget.initialLng ?? _defaultLng,
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _mapCtrl?.dispose();
    _dio.close();
    super.dispose();
  }

  Future<void> _reverseGeocode(LatLng pos) async {
    setState(() => _loading = true);
    try {
      final res = await _dio.get(
        'https://nominatim.openstreetmap.org/reverse',
        queryParameters: {
          'format': 'json',
          'lat': pos.latitude.toStringAsFixed(6),
          'lon': pos.longitude.toStringAsFixed(6),
        },
        options: Options(
          headers: {'Accept-Language': 'en', 'User-Agent': 'GoraCabs/1.0'},
          receiveTimeout: const Duration(seconds: 6),
        ),
      );
      final data = res.data as Map<String, dynamic>;
      final addrObj = data['address'] as Map<String, dynamic>? ?? {};
      final parts = <String>[
        if ((addrObj['road'] ?? addrObj['suburb'] ?? '') != '') (addrObj['road'] ?? addrObj['suburb'] ?? '') as String,
        if ((addrObj['city'] ?? addrObj['town'] ?? addrObj['village'] ?? addrObj['county'] ?? '') != '')
          (addrObj['city'] ?? addrObj['town'] ?? addrObj['village'] ?? addrObj['county'] ?? '') as String,
        if ((addrObj['state'] ?? '') != '') (addrObj['state'] ?? '') as String,
      ];
      setState(() {
        _address = parts.isNotEmpty ? parts.join(', ') : (data['display_name'] as String? ?? 'Unknown location');
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _address = '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';
        _loading = false;
      });
    }
  }

  void _onCameraMove(CameraPosition pos) {
    _center = pos.target;
    if (!_pinMoving) setState(() => _pinMoving = true);
    _debounce?.cancel();
  }

  void _onCameraIdle() {
    setState(() => _pinMoving = false);
    _debounce = Timer(const Duration(milliseconds: 300), () => _reverseGeocode(_center));
  }

  void _confirm() {
    if (_loading) return;
    Navigator.of(context).pop(LocationPickerResult(
      address: _address,
      lat: _center.latitude,
      lng: _center.longitude,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, style: TextStyle(fontFamily: 'Poppins', fontSize: 16.sp, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Map
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _center, zoom: 14),
            onMapCreated: (ctrl) {
              _mapCtrl = ctrl;
              _reverseGeocode(_center);
            },
            onCameraMove: _onCameraMove,
            onCameraIdle: _onCameraIdle,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),

          // Center pin — tip of the icon sits exactly at map center
          Positioned.fill(
            child: IgnorePointer(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    transform: Matrix4.translationValues(0, _pinMoving ? -8 : 0, 0),
                    child: Icon(
                      Icons.location_on,
                      color: AppColors.primary,
                      size: 52.sp,
                    ),
                  ),
                  // Drop shadow dot at tip
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: _pinMoving ? 10.w : 6.w,
                    height: _pinMoving ? 4.h : 3.h,
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(4.r),
                    ),
                  ),
                  // spacer = same height as icon so the column center == icon tip
                  SizedBox(height: 52.sp + 4.h),
                ],
              ),
            ),
          ),

          // Bottom sheet
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 28.h),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 12, offset: const Offset(0, -4))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36.w, height: 4.h,
                      margin: EdgeInsets.only(bottom: 12.h),
                      decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2.r)),
                    ),
                  ),
                  Text('Selected Location', style: TextStyle(fontFamily: 'Poppins', fontSize: 11.sp, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                  SizedBox(height: 8.h),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.location_on, color: AppColors.primary, size: 20.sp),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: _loading
                            ? Row(children: [
                                SizedBox(width: 14.w, height: 14.h, child: const CircularProgressIndicator(strokeWidth: 2)),
                                SizedBox(width: 8.w),
                                Text('Finding location...', style: TextStyle(fontFamily: 'Poppins', fontSize: 13.sp, color: AppColors.textHint)),
                              ])
                            : Text(_address, style: TextStyle(fontFamily: 'Poppins', fontSize: 14.sp, fontWeight: FontWeight.w600, color: AppColors.textPrimary, height: 1.4)),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _confirm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                        elevation: 0,
                      ),
                      child: Text('Confirm Location', style: TextStyle(fontFamily: 'Poppins', fontSize: 15.sp, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Haversine distance between two lat/lng points → returns km
double haversineDistanceKm(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371.0;
  final dLat = (lat2 - lat1) * pi / 180;
  final dLon = (lon2 - lon1) * pi / 180;
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(lat1 * pi / 180) * cos(lat2 * pi / 180) * sin(dLon / 2) * sin(dLon / 2);
  return r * 2 * atan2(sqrt(a), sqrt(1 - a));
}
