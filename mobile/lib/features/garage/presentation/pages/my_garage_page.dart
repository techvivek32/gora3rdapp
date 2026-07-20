import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/vehicle_types.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/api_error.dart';

/// The user's "My Vehicles" garage: saved cars they can add, edit and delete.
class MyGaragePage extends StatefulWidget {
  const MyGaragePage({super.key});

  @override
  State<MyGaragePage> createState() => _MyGaragePageState();
}

class _MyGaragePageState extends State<MyGaragePage> {
  final _api = getIt<ApiClient>();
  bool _loading = true;
  List<Map<String, dynamic>> _vehicles = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _api.get('/garage');
      final list = (res.data['data'] as List?) ?? [];
      if (!mounted) return;
      setState(() {
        _vehicles = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openForm({Map<String, dynamic>? vehicle}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20.r))),
      builder: (_) => _VehicleForm(vehicle: vehicle),
    );
    if (saved == true) _load();
  }

  Future<void> _delete(Map<String, dynamic> v) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove vehicle?'),
        content: Text('Remove ${_title(v)} from your vehicles?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.delete('/garage/${v['_id']}');
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(serverMessage(e, fallback: 'Could not remove')), backgroundColor: AppColors.error),
        );
      }
    }
  }

  String _title(Map<String, dynamic> v) {
    final model = (v['modelName'] ?? '').toString().trim();
    return model.isNotEmpty ? model : vehicleTypeLabel(v['vehicleType'] as String?);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('My Vehicles'.tr, style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 18.sp)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text('Add Vehicle'.tr, style: TextStyle(color: Colors.white, fontFamily: 'Poppins', fontSize: 14.sp)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _vehicles.isEmpty
              ? _empty()
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.primary,
                  child: ListView.separated(
                    padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 90.h),
                    itemCount: _vehicles.length,
                    separatorBuilder: (_, __) => SizedBox(height: 12.h),
                    itemBuilder: (_, i) => _card(_vehicles[i]),
                  ),
                ),
    );
  }

  Widget _empty() {
    return ListView(
      children: [
        SizedBox(height: 0.25.sh),
        Icon(Icons.directions_car_outlined, size: 64.sp, color: AppColors.textHint),
        SizedBox(height: 12.h),
        Center(
          child: Text('No vehicles yet.\nAdd your cars to reuse them later.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Poppins', fontSize: 14.sp)),
        ),
      ],
    );
  }

  Widget _card(Map<String, dynamic> v) {
    final chips = <String>[
      if ((v['registrationNumber'] ?? '').toString().trim().isNotEmpty) v['registrationNumber'].toString(),
      if ((v['fuelType'] ?? 'any').toString() != 'any') _cap(v['fuelType'].toString()),
      if (v['seatingCapacity'] != null) '${v['seatingCapacity']} seats',
      if ((v['color'] ?? '').toString().trim().isNotEmpty) v['color'].toString(),
    ];
    final photos = (v['carPhotos'] as List?)?.whereType<String>().where((s) => s.isNotEmpty).toList() ?? [];
    final firstPhoto = photos.isNotEmpty ? photos.first : null;
    return Container(
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12.r),
            child: Container(
              width: 46.w,
              height: 46.w,
              color: AppColors.primary.withValues(alpha: 0.1),
              child: firstPhoto != null
                  ? Image.network(firstPhoto, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(Icons.directions_car, color: AppColors.primary, size: 24.sp))
                  : Icon(Icons.directions_car, color: AppColors.primary, size: 24.sp),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_title(v), style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 15.sp, color: AppColors.textPrimary)),
                SizedBox(height: 2.h),
                Text(vehicleTypeLabel(v['vehicleType'] as String?),
                    style: TextStyle(fontSize: 12.sp, color: AppColors.textSecondary, fontFamily: 'Poppins')),
                if (chips.isNotEmpty) ...[
                  SizedBox(height: 8.h),
                  Wrap(
                    spacing: 6.w,
                    runSpacing: 6.h,
                    children: chips.map((c) => Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(6.r), border: Border.all(color: AppColors.border)),
                      child: Text(c, style: TextStyle(fontSize: 11.sp, color: AppColors.textSecondary, fontFamily: 'Poppins')),
                    )).toList(),
                  ),
                ],
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: AppColors.textSecondary, size: 20.sp),
            onSelected: (val) => val == 'edit' ? _openForm(vehicle: v) : _delete(v),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit')),
              const PopupMenuItem(value: 'delete', child: Text('Remove', style: TextStyle(color: AppColors.error))),
            ],
          ),
        ],
      ),
    );
  }

  String _cap(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}

/// Add / edit form shown in a bottom sheet. Pops `true` on a successful save.
class _VehicleForm extends StatefulWidget {
  final Map<String, dynamic>? vehicle;
  const _VehicleForm({this.vehicle});

  @override
  State<_VehicleForm> createState() => _VehicleFormState();
}

class _VehicleFormState extends State<_VehicleForm> {
  final _api = getIt<ApiClient>();
  final _formKey = GlobalKey<FormState>();

  final _modelCtrl = TextEditingController();
  final _regCtrl = TextEditingController();
  final _seatsCtrl = TextEditingController();
  final _colorCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _picker = ImagePicker();

  late String _vehicleType;
  late String _fuelType;
  bool _saving = false;

  // Uploaded image URLs. Two car photos + RC front/back.
  final List<String?> _carPhotos = [null, null];
  String? _rcFront;
  String? _rcBack;
  String? _uploadingSlot; // which slot is uploading right now

  static const _fuelTypes = [
    {'value': 'any', 'label': 'Any Fuel'},
    {'value': 'petrol', 'label': 'Petrol'},
    {'value': 'diesel', 'label': 'Diesel'},
    {'value': 'cng', 'label': 'CNG'},
    {'value': 'electric', 'label': 'Electric'},
  ];

  bool get _isEdit => widget.vehicle != null;

  @override
  void initState() {
    super.initState();
    final v = widget.vehicle;
    _vehicleType = (v?['vehicleType'] as String?) ?? kVehicleTypes.first['value']!;
    _fuelType = (v?['fuelType'] as String?) ?? 'any';
    _modelCtrl.text = (v?['modelName'] ?? '').toString();
    _regCtrl.text = (v?['registrationNumber'] ?? '').toString();
    _seatsCtrl.text = v?['seatingCapacity'] != null ? '${v!['seatingCapacity']}' : '';
    _colorCtrl.text = (v?['color'] ?? '').toString();
    _notesCtrl.text = (v?['notes'] ?? '').toString();
    final cp = (v?['carPhotos'] as List?) ?? [];
    if (cp.isNotEmpty) _carPhotos[0] = cp[0] as String?;
    if (cp.length > 1) _carPhotos[1] = cp[1] as String?;
    _rcFront = v?['rcFrontImage'] as String?;
    _rcBack = v?['rcBackImage'] as String?;
  }

  /// Pick from the gallery and upload to storage; returns the URL slot updates.
  Future<void> _pick(String slot) async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1400, imageQuality: 80);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() => _uploadingSlot = slot);
    try {
      final url = await _upload(bytes, slot);
      if (!mounted) return;
      setState(() => _setSlot(slot, url));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Upload failed'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingSlot = null);
    }
  }

  Future<String?> _upload(Uint8List bytes, String name) async {
    final res = await _api.dio.post('/storage/upload', data: FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: '$name.jpg'),
      'folder': 'garage',
    }));
    return res.data['data'] as String?;
  }

  void _setSlot(String slot, String? url) {
    switch (slot) {
      case 'car0':
        _carPhotos[0] = url;
      case 'car1':
        _carPhotos[1] = url;
      case 'rcFront':
        _rcFront = url;
      case 'rcBack':
        _rcBack = url;
    }
  }

  void _clearSlot(String slot) => setState(() => _setSlot(slot, null));

  @override
  void dispose() {
    _modelCtrl.dispose();
    _regCtrl.dispose();
    _seatsCtrl.dispose();
    _colorCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final body = {
      'vehicleType': _vehicleType,
      'fuelType': _fuelType,
      'modelName': _modelCtrl.text.trim(),
      'registrationNumber': _regCtrl.text.trim(),
      if (_seatsCtrl.text.trim().isNotEmpty) 'seatingCapacity': int.tryParse(_seatsCtrl.text.trim()),
      'color': _colorCtrl.text.trim(),
      'notes': _notesCtrl.text.trim(),
      'carPhotos': _carPhotos.whereType<String>().toList(),
      'rcFrontImage': _rcFront ?? '',
      'rcBackImage': _rcBack ?? '',
    };
    try {
      if (_isEdit) {
        await _api.put('/garage/${widget.vehicle!['_id']}', data: body);
      } else {
        await _api.post('/garage', data: body);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(serverMessage(e, fallback: 'Could not save vehicle')), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, controller) => Form(
          key: _formKey,
          child: ListView(
            controller: controller,
            padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 24.h),
            children: [
              Center(
                child: Container(
                  width: 40.w, height: 4.h,
                  decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2.r)),
                ),
              ),
              SizedBox(height: 16.h),
              Text(_isEdit ? 'Edit Vehicle'.tr : 'Add Vehicle'.tr,
                  style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 18.sp, color: AppColors.textPrimary)),
              SizedBox(height: 16.h),

              _label('Vehicle Type *'),
              DropdownButtonFormField<String>(
                initialValue: _vehicleType,
                decoration: _dec(Icons.directions_car_outlined),
                items: kVehicleTypes.map((v) => DropdownMenuItem(value: v['value'], child: Text(v['label']!, style: TextStyle(fontFamily: 'Poppins', fontSize: 14.sp)))).toList(),
                onChanged: (val) => setState(() => _vehicleType = val ?? _vehicleType),
              ),
              SizedBox(height: 14.h),

              _label('Model Name'),
              TextFormField(controller: _modelCtrl, decoration: _dec(Icons.badge_outlined, hint: 'e.g. Toyota Innova Crysta 2022')),
              SizedBox(height: 14.h),

              _label('Registration Number'),
              TextFormField(
                controller: _regCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: _dec(Icons.confirmation_number_outlined, hint: 'e.g. GJ01AB1234'),
              ),
              SizedBox(height: 14.h),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Fuel Type'),
                        DropdownButtonFormField<String>(
                          initialValue: _fuelType,
                          decoration: _dec(Icons.local_gas_station_outlined),
                          items: _fuelTypes.map((f) => DropdownMenuItem(value: f['value'], child: Text(f['label']!, style: TextStyle(fontFamily: 'Poppins', fontSize: 14.sp)))).toList(),
                          onChanged: (val) => setState(() => _fuelType = val ?? _fuelType),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Seats'),
                        TextFormField(
                          controller: _seatsCtrl,
                          keyboardType: TextInputType.number,
                          decoration: _dec(Icons.event_seat_outlined, hint: 'e.g. 7'),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return null;
                            final n = int.tryParse(v.trim());
                            if (n == null || n < 1 || n > 60) return '1–60';
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 14.h),

              _label('Colour'),
              TextFormField(controller: _colorCtrl, decoration: _dec(Icons.palette_outlined, hint: 'e.g. White')),
              SizedBox(height: 14.h),

              _label('Notes'),
              TextFormField(
                controller: _notesCtrl,
                maxLines: 2,
                decoration: _dec(Icons.notes_outlined, hint: 'e.g. Carrier fitted'),
              ),
              SizedBox(height: 16.h),

              _label('Vehicle Photos'),
              Row(
                children: [
                  _imageSlot('car0', 'Photo 1', _carPhotos[0]),
                  SizedBox(width: 10.w),
                  _imageSlot('car1', 'Photo 2', _carPhotos[1]),
                ],
              ),
              SizedBox(height: 14.h),

              _label('RC (Registration Certificate)'),
              Row(
                children: [
                  _imageSlot('rcFront', 'RC Front', _rcFront),
                  SizedBox(width: 10.w),
                  _imageSlot('rcBack', 'RC Back', _rcBack),
                ],
              ),
              SizedBox(height: 22.h),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                  ),
                  child: _saving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(_isEdit ? 'Save Changes'.tr : 'Add Vehicle'.tr, style: TextStyle(fontSize: 15.sp, fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String t) => Padding(
        padding: EdgeInsets.only(bottom: 6.h),
        child: Text(t, style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: AppColors.textSecondary, fontFamily: 'Poppins')),
      );

  /// One tappable image box: shows the uploaded photo (with a remove ✕) or an
  /// upload placeholder / spinner while uploading.
  Widget _imageSlot(String slot, String caption, String? url) {
    final busy = _uploadingSlot == slot;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(caption, style: TextStyle(fontSize: 11.sp, color: AppColors.textHint, fontFamily: 'Poppins')),
          SizedBox(height: 4.h),
          GestureDetector(
            onTap: busy ? null : () => _pick(slot),
            child: Container(
              height: 92.h,
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(color: AppColors.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: url != null && url.isNotEmpty
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                        Positioned(
                          top: 4.h,
                          right: 4.w,
                          child: GestureDetector(
                            onTap: () => _clearSlot(slot),
                            child: CircleAvatar(
                              radius: 11.r,
                              backgroundColor: Colors.black54,
                              child: Icon(Icons.close, size: 13.sp, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Center(
                      child: busy
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                          : Icon(Icons.add_a_photo_outlined, color: AppColors.textHint, size: 24.sp),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _dec(IconData icon, {String? hint}) => InputDecoration(
        prefixIcon: Icon(icon, size: 20.sp),
        hintText: hint,
        hintStyle: TextStyle(fontSize: 13.sp, color: AppColors.textHint, fontFamily: 'Poppins'),
        isDense: true,
      );
}
