import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/vehicle_types.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/api_error.dart';

/// Set to true once an RC / DL verification vendor is configured in the admin
/// panel. While false the garage forms are plain manual entry: the Fetch
/// buttons are hidden, because without API keys they can only report that the
/// lookup is not set up. Nothing else about the fetch flow is removed.
const bool kVerificationEnabled = false;

/// The user's garage: two tabs — saved Vehicles and saved Drivers, each reusable
/// when posting/assigning so details don't have to be retyped.
class MyGaragePage extends StatefulWidget {
  const MyGaragePage({super.key});

  @override
  State<MyGaragePage> createState() => _MyGaragePageState();
}

class _MyGaragePageState extends State<MyGaragePage> {
  final _api = getIt<ApiClient>();
  // Live counts shown next to each tab's icon (null until first load).
  final _vehicleCount = ValueNotifier<int?>(null);
  final _driverCount = ValueNotifier<int?>(null);

  @override
  void initState() {
    super.initState();
    // Fetch BOTH counts up front so each tab shows its number immediately —
    // the Drivers tab is lazy-built, so without this its count only appeared
    // after the user opened that tab.
    _prefetchCounts();
  }

  Future<void> _prefetchCounts() async {
    try {
      final v = await _api.get('/garage');
      _vehicleCount.value = ((v.data['data'] as List?)?.length) ?? 0;
    } catch (_) {}
    try {
      final d = await _api.get('/garage/drivers');
      _driverCount.value = ((d.data['data'] as List?)?.length) ?? 0;
    } catch (_) {}
  }

  @override
  void dispose() {
    _vehicleCount.dispose();
    _driverCount.dispose();
    super.dispose();
  }

  Widget _tab(IconData icon, String label, ValueNotifier<int?> count) => Tab(
        icon: Icon(icon),
        child: ValueListenableBuilder<int?>(
          valueListenable: count,
          builder: (_, c, __) => Text(c == null ? label : '$label ($c)'),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text('My Vehicles & Drivers'.tr,
              style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 18.sp)),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          bottom: TabBar(
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            labelStyle: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 14.sp),
            tabs: [
              _tab(Icons.directions_car_outlined, 'Vehicles'.tr, _vehicleCount),
              _tab(Icons.person_outline, 'Drivers'.tr, _driverCount),
            ],
          ),
        ),
        body: TabBarView(
          children: [_VehiclesTab(count: _vehicleCount), _DriversTab(count: _driverCount)],
        ),
      ),
    );
  }
}

// ══════════════════════════════ VEHICLES TAB ══════════════════════════════

class _VehiclesTab extends StatefulWidget {
  final ValueNotifier<int?> count;
  const _VehiclesTab({required this.count});
  @override
  State<_VehiclesTab> createState() => _VehiclesTabState();
}

class _VehiclesTabState extends State<_VehiclesTab> with AutomaticKeepAliveClientMixin {
  final _api = getIt<ApiClient>();
  bool _loading = true;
  List<Map<String, dynamic>> _vehicles = [];

  @override
  bool get wantKeepAlive => true;

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
      widget.count.value = _vehicles.length;
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openForm({Map<String, dynamic>? vehicle}) async {
    final saved = await showDialog<bool>(
      context: context,
      // The form is long; tapping outside by accident would lose it.
      barrierDismissible: false,
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
    super.build(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        // Unique tag so this FAB never shares the default hero tag with the main
        // nav "+" button (that clash made the "+" vanish after visiting here).
        heroTag: 'garageVehicleFab',
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
        SizedBox(height: 0.22.sh),
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
                SizedBox(height: 8.h),
                _approvalBadge(v),
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

// ══════════════════════════════ DRIVERS TAB ══════════════════════════════

class _DriversTab extends StatefulWidget {
  final ValueNotifier<int?> count;
  const _DriversTab({required this.count});
  @override
  State<_DriversTab> createState() => _DriversTabState();
}

class _DriversTabState extends State<_DriversTab> with AutomaticKeepAliveClientMixin {
  final _api = getIt<ApiClient>();
  bool _loading = true;
  List<Map<String, dynamic>> _drivers = [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _api.get('/garage/drivers');
      final list = (res.data['data'] as List?) ?? [];
      if (!mounted) return;
      setState(() {
        _drivers = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _loading = false;
      });
      widget.count.value = _drivers.length;
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openForm({Map<String, dynamic>? driver}) async {
    final saved = await showDialog<bool>(
      context: context,
      // The form is long; tapping outside by accident would lose it.
      barrierDismissible: false,
      builder: (_) => _DriverForm(driver: driver),
    );
    if (saved == true) _load();
  }

  Future<void> _delete(Map<String, dynamic> d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove driver?'),
        content: Text('Remove ${(d['fullName'] ?? 'this driver')} from your drivers?'),
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
      await _api.delete('/garage/drivers/${d['_id']}');
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(serverMessage(e, fallback: 'Could not remove')), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        // Unique tag — see the Vehicles FAB above (avoids the hero-tag clash).
        heroTag: 'garageDriverFab',
        onPressed: () => _openForm(),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text('Add Driver'.tr, style: TextStyle(color: Colors.white, fontFamily: 'Poppins', fontSize: 14.sp)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _drivers.isEmpty
              ? _empty()
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.primary,
                  child: ListView.separated(
                    padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 90.h),
                    itemCount: _drivers.length,
                    separatorBuilder: (_, __) => SizedBox(height: 12.h),
                    itemBuilder: (_, i) => _card(_drivers[i]),
                  ),
                ),
    );
  }

  Widget _empty() {
    return ListView(
      children: [
        SizedBox(height: 0.22.sh),
        Icon(Icons.person_outline, size: 64.sp, color: AppColors.textHint),
        SizedBox(height: 12.h),
        Center(
          child: Text('No drivers yet.\nAdd your drivers to reuse them later.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Poppins', fontSize: 14.sp)),
        ),
      ],
    );
  }

  Widget _card(Map<String, dynamic> d) {
    final photo = (d['photo'] ?? '').toString();
    final chips = <String>[
      if ((d['dlNumber'] ?? '').toString().trim().isNotEmpty) 'DL: ${d['dlNumber']}',
      if ((d['aadharNumber'] ?? '').toString().trim().isNotEmpty) 'Aadhaar: ${d['aadharNumber']}',
    ];
    return Container(
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(30.r),
            child: Container(
              width: 46.w,
              height: 46.w,
              color: AppColors.primary.withValues(alpha: 0.1),
              child: photo.isNotEmpty
                  ? Image.network(photo, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(Icons.person, color: AppColors.primary, size: 24.sp))
                  : Icon(Icons.person, color: AppColors.primary, size: 24.sp),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text((d['fullName'] ?? 'Driver').toString(),
                    style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 15.sp, color: AppColors.textPrimary)),
                if ((d['phone'] ?? '').toString().trim().isNotEmpty) ...[
                  SizedBox(height: 2.h),
                  Text(d['phone'].toString(),
                      style: TextStyle(fontSize: 12.sp, color: AppColors.textSecondary, fontFamily: 'Poppins')),
                ],
                if ((d['address'] ?? '').toString().trim().isNotEmpty) ...[
                  SizedBox(height: 2.h),
                  Text(d['address'].toString(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.5.sp, color: AppColors.textHint, fontFamily: 'Poppins')),
                ],
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
                SizedBox(height: 8.h),
                _approvalBadge(d),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: AppColors.textSecondary, size: 20.sp),
            onSelected: (val) => val == 'edit' ? _openForm(driver: d) : _delete(d),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit')),
              const PopupMenuItem(value: 'delete', child: Text('Remove', style: TextStyle(color: AppColors.error))),
            ],
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════ VEHICLE FORM ══════════════════════════════

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

  // RC lookup state. `_rcOwner`/`_rcNameMatched` stay null until a lookup runs,
  // so a manually-entered vehicle is never shown a match verdict it never got.
  bool _rcFetching = false;
  String? _rcOwner;
  bool? _rcNameMatched;
  String? _rcMessage;
  bool _rcConfigured = true;
  /// Set when the form's details came from a lookup rather than the keyboard.
  bool _rcFilled = false;
  /// Manual entry: every detail field is shown and typed in by hand.
  ///
  /// Starts TRUE because no verification vendor is set up yet - gating the form
  /// behind a Fetch that cannot work would just block people. The Fetch button
  /// stays available, so the moment the API keys are added it fills the form in
  /// and nothing else has to change.
  bool _manualMode = true;

  /// Editing an already-saved vehicle always shows the fields - we are not
  /// going to make someone re-fetch to change a colour.
  bool get _showVehicleFields => _isEdit || _manualMode;

  /// Nothing has been fetched and nothing can be typed, so there is no vehicle
  /// here yet - only a registration number.
  bool get _needsFetch => !_rcFilled && !_showVehicleFields;

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

  /// Pull the vehicle straight from the RC record and fill the form with it.
  /// Nothing here is typed by the user beyond the registration number.
  Future<void> _fetchRc() async {
    final rc = _regCtrl.text.trim();
    if (rc.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').length < 6) {
      _toast('Enter a valid registration number');
      return;
    }
    setState(() {
      _rcFetching = true;
      _rcOwner = null;
      _rcNameMatched = null;
      _rcMessage = null;
      // Whatever is in the form came from the previous registration number.
      // Leaving it there after a failed lookup shows one car's details under
      // another car's number.
      if (_rcFilled) {
        _modelCtrl.clear();
        _seatsCtrl.clear();
        _colorCtrl.clear();
        _rcFilled = false;
      }
    });
    try {
      final res = await _api.post('/verification/rc', data: {'registrationNumber': rc});
      final d = Map<String, dynamic>.from(res.data['data'] as Map);
      if (!mounted) return;

      if (d['configured'] == false) {
        setState(() {
          _rcConfigured = false;
          _manualMode = true;
          _rcMessage = (d['message'] ?? '').toString();
        });
        return;
      }
      if (d['found'] != true) {
        setState(() {
          _manualMode = true;
          _rcMessage = (d['message'] ?? 'No record found').toString();
        });
        return;
      }

      final v = Map<String, dynamic>.from(d['vehicle'] as Map);
      final nm = d['nameMatch'] is Map ? Map<String, dynamic>.from(d['nameMatch'] as Map) : null;
      setState(() {
        _modelCtrl.text = (v['modelName'] ?? '').toString();
        final seats = (v['seatingCapacity'] as num?)?.toInt() ?? 0;
        if (seats > 0) _seatsCtrl.text = '$seats';
        final color = (v['color'] ?? '').toString();
        if (color.isNotEmpty) _colorCtrl.text = color;
        final fuel = _closestOption((v['fuelType'] ?? '').toString(), _fuelTypes);
        if (fuel != null) _fuelType = fuel;
        final type = _closestOption((v['vehicleType'] ?? '').toString(), kVehicleTypes);
        if (type != null) _vehicleType = type;
        _rcFilled = true;
        _manualMode = false;
        _rcOwner = (v['ownerName'] ?? '').toString();
        _rcNameMatched = nm?['matched'] as bool?;
        _rcMessage = (d['message'] ?? '').toString();
      });
    } catch (e) {
      // The vendor is down or refused. Don't strand them on a form with one
      // field and no way forward - let them type it in.
      if (mounted) {
        setState(() {
          _manualMode = true;
          _rcMessage = _clean(e);
        });
      }
    } finally {
      if (mounted) setState(() => _rcFetching = false);
    }
  }

  /// The RC's wording rarely matches our dropdown exactly ("PETROL/CNG",
  /// "LMV-CAR"), so pick the option whose label or value appears in it rather
  /// than dropping the value entirely.
  String? _closestOption(String raw, List<Map<String, String>> options) {
    final v = raw.toLowerCase();
    if (v.isEmpty) return null;
    for (final o in options) {
      final val = (o['value'] ?? '').toLowerCase();
      final lab = (o['label'] ?? '').toLowerCase();
      if (val.isNotEmpty && val != 'any' && v.contains(val)) return o['value'];
      if (lab.isNotEmpty && lab != 'any fuel' && v.contains(lab)) return o['value'];
    }
    return null;
  }

  String _clean(Object e) {
    final m = e.toString();
    final i = m.indexOf('message: ');
    return i >= 0 ? m.substring(i + 9).replaceAll(RegExp(r'[}\]]+$'), '') : 'Could not fetch RC details';
  }

  /// What came back from the RC, shown as plain text. These are facts from the
  /// government record, so there is nothing here to edit.
  Widget _fetchedSummary() {
    final rows = <List<String>>[
      ['Type', _labelFor(kVehicleTypes, _vehicleType)],
      ['Model', _modelCtrl.text],
      ['Fuel', _labelFor(_fuelTypes, _fuelType)],
      ['Seats', _seatsCtrl.text],
      ['Colour', _colorCtrl.text],
    ].where((r) => r[1].trim().isNotEmpty).toList();
    if (rows.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final r in rows)
            Padding(
              padding: EdgeInsets.only(bottom: r == rows.last ? 0 : 8.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 64.w,
                    child: Text(r[0].tr,
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 12.sp, color: AppColors.textSecondary)),
                  ),
                  Expanded(
                    child: Text(r[1],
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 13.sp, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  ),
                ],
              ),
            ),
          SizedBox(height: 10.h),
          GestureDetector(
            onTap: () => setState(() => _manualMode = true),
            child: Text('Something wrong? Edit manually'.tr,
                style: TextStyle(fontFamily: 'Poppins', fontSize: 12.sp, fontWeight: FontWeight.w600, color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  /// Turn a stored dropdown value back into the label people read.
  String _labelFor(List<Map<String, String>> options, String value) {
    for (final o in options) {
      if (o['value'] == value) return o['label'] ?? value;
    }
    return value;
  }

  /// True once a lookup has told us the vehicle belongs to somebody else.
  bool get _rcBlocked => _rcNameMatched == false;

  /// What the RC lookup came back with. Null until a lookup runs, so a vehicle
  /// typed in by hand never shows a verdict it was never given.
  Widget? get _rcBanner {
    if (_rcMessage == null && _rcOwner == null) return null;

    // No vendor keys yet: say so plainly and let them fill the form by hand.
    final bool ok = _rcNameMatched == true;
    final bool bad = _rcNameMatched == false;
    final Color tone = !_rcConfigured
        ? AppColors.textSecondary
        : bad
            ? AppColors.error
            : ok
                ? AppColors.success
                : AppColors.textSecondary;
    final IconData icon = !_rcConfigured
        ? Icons.info_outline
        : bad
            ? Icons.cancel_outlined
            : ok
                ? Icons.verified_outlined
                : Icons.info_outline;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.08),
        border: Border.all(color: tone.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18.sp, color: tone),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if ((_rcOwner ?? '').isNotEmpty)
                  Text('RC owner: ${_rcOwner!}',
                      style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 13.sp, color: AppColors.textPrimary)),
                if ((_rcMessage ?? '').isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: (_rcOwner ?? '').isNotEmpty ? 2.h : 0),
                    child: Text(_rcMessage!,
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 12.sp, color: tone)),
                  ),
                if (bad)
                  Padding(
                    padding: EdgeInsets.only(top: 4.h),
                    child: Text('You can only add a vehicle registered in your own name.'.tr,
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 11.sp, color: AppColors.textSecondary)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    // A lookup that came back with someone else's name is a hard stop - the
    // vehicle has to be registered to the person adding it.
    if (_rcNameMatched == false) {
      _toast('RC owner name does not match your account - cannot add this vehicle');
      return;
    }
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
    final size = MediaQuery.of(context).size;
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 28.h),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
      child: ConstrainedBox(
        // Grows with the content but never past the screen, so a short form is
        // a small box and a long one scrolls inside the dialog.
        constraints: BoxConstraints(maxHeight: size.height * 0.85, maxWidth: 520.w),
        child: Form(
          key: _formKey,
          child: ListView(
            shrinkWrap: true,
            padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 24.h),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(_isEdit ? 'Edit Vehicle'.tr : 'Add Vehicle'.tr,
                        style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 18.sp, color: AppColors.textPrimary)),
                  ),
                  IconButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    icon: Icon(Icons.close, size: 22.sp, color: AppColors.textSecondary),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Close',
                  ),
                ],
              ),
              SizedBox(height: 16.h),

              _label('Registration Number *'),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _regCtrl,
                      textCapitalization: TextCapitalization.characters,
                      decoration: _dec(Icons.confirmation_number_outlined, hint: 'e.g. GJ01AB1234'),
                    ),
                  ),
                  if (kVerificationEnabled) ...[
                  SizedBox(width: 10.w),
                  SizedBox(
                    height: 48.h,
                    child: ElevatedButton(
                      onPressed: _rcFetching ? null : _fetchRc,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 18.w),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                      ),
                      child: _rcFetching
                          ? SizedBox(width: 18.w, height: 18.w, child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text('Fetch'.tr, style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 14.sp)),
                    ),
                  ),
                  ],
                ],
              ),
              if (_rcBanner != null) ...[SizedBox(height: 10.h), _rcBanner!],
              if (_needsFetch) ...[
                SizedBox(height: 8.h),
                GestureDetector(
                  onTap: () => setState(() => _manualMode = true),
                  child: Text('Skip and enter details manually'.tr,
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 12.sp, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                ),
              ],
              SizedBox(height: 14.h),

              // Everything below came back from the RC - shown, not typed.
              if (_rcFilled && !_showVehicleFields) ...[
                _fetchedSummary(),
                SizedBox(height: 14.h),
              ],

              if (_showVehicleFields) ...[
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
              ],

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
                  _imageSlot(busy: _uploadingSlot == 'car0', onPick: () => _pick('car0'), onClear: () => _clearSlot('car0'), caption: 'Photo 1', url: _carPhotos[0]),
                  SizedBox(width: 10.w),
                  _imageSlot(busy: _uploadingSlot == 'car1', onPick: () => _pick('car1'), onClear: () => _clearSlot('car1'), caption: 'Photo 2', url: _carPhotos[1]),
                ],
              ),
              SizedBox(height: 14.h),

              _label('RC (Registration Certificate)'),
              Row(
                children: [
                  _imageSlot(busy: _uploadingSlot == 'rcFront', onPick: () => _pick('rcFront'), onClear: () => _clearSlot('rcFront'), caption: 'RC Front', url: _rcFront),
                  SizedBox(width: 10.w),
                  _imageSlot(busy: _uploadingSlot == 'rcBack', onPick: () => _pick('rcBack'), onClear: () => _clearSlot('rcBack'), caption: 'RC Back', url: _rcBack),
                ],
              ),
              SizedBox(height: 22.h),

              // The mismatch banner is far up the form; by the time they reach
              // the button it is off screen, so say it again right here.
              if (_rcBlocked)
                Padding(
                  padding: EdgeInsets.only(bottom: 10.h),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.block, size: 16.sp, color: AppColors.error),
                      SizedBox(width: 6.w),
                      Expanded(
                        child: Text(
                          'This vehicle is registered to ${_rcOwner ?? "someone else"} - you can only add a vehicle registered in your own name.'.tr,
                          style: TextStyle(fontFamily: 'Poppins', fontSize: 12.sp, color: AppColors.error, height: 1.35),
                        ),
                      ),
                    ],
                  ),
                )
              else if (_needsFetch)
                Padding(
                  padding: EdgeInsets.only(bottom: 10.h),
                  child: Text('Enter the registration number and tap Fetch.'.tr,
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 12.sp, color: AppColors.textSecondary)),
                ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_saving || _rcBlocked || _needsFetch) ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.border,
                    disabledForegroundColor: AppColors.textSecondary,
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

  Widget _label(String t) => _fieldLabel(t);

  InputDecoration _dec(IconData icon, {String? hint}) => _fieldDec(icon, hint: hint);
}

// ══════════════════════════════ DRIVER FORM ══════════════════════════════

class _DriverForm extends StatefulWidget {
  final Map<String, dynamic>? driver;
  const _DriverForm({this.driver});

  @override
  State<_DriverForm> createState() => _DriverFormState();
}

class _DriverFormState extends State<_DriverForm> {
  final _api = getIt<ApiClient>();
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _dlCtrl = TextEditingController();
  final _aadharCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();

  // Licence verification against the RTO record. Nothing is asked of the driver
  // - no app, no OTP - so it works for every driver, not only the ones who
  // happen to have a DigiLocker account.
  bool _dlBusy = false;
  bool _dlVerified = false;
  String? _dlMessage;
  /// What the RTO record said about the licence itself.
  String _dlValidUpto = '';
  List<String> _dlClasses = const [];
  String _dlRto = '';
  bool _dlExpired = false;

  /// What the Aadhaar photo turned out to say. Null until one is uploaded.
  bool _ocrBusy = false;
  String? _ocrMessage;
  bool? _ocrNameMatched;
  bool _ocrSuspect = false;
  /// Manual entry for the driver, for the same reason as the vehicle form:
  /// no verification vendor is configured yet. Fetch still works once it is.
  bool _dlManual = true;

  /// Editing a saved driver always shows the fields.
  bool get _showDriverFields => _isEdit || _dlManual;

  /// Nothing verified and nothing typed - there is no driver here yet.
  bool get _needsVerify => !_dlVerified && !_showDriverFields;

  bool _saving = false;
  // Server-side error for the phone field (e.g. "not registered as driver/vendor"),
  // shown inline under the field instead of a snackbar the user might miss.
  String? _phoneServerError;
  String? _photo;
  String? _dlFront;
  String? _dlBack;
  String? _aadharFront;
  String? _aadharBack;
  String? _uploadingSlot;

  bool get _isEdit => widget.driver != null;

  @override
  void initState() {
    super.initState();
    final d = widget.driver;
    _nameCtrl.text = (d?['fullName'] ?? '').toString();
    _phoneCtrl.text = (d?['phone'] ?? '').toString();
    _dlCtrl.text = (d?['dlNumber'] ?? '').toString();
    _aadharCtrl.text = (d?['aadharNumber'] ?? '').toString();
    _addressCtrl.text = (d?['address'] ?? '').toString();
    _photo = d?['photo'] as String?;
    _dlFront = d?['dlFrontImage'] as String?;
    _dlBack = d?['dlBackImage'] as String?;
    _aadharFront = d?['aadharFrontImage'] as String?;
    _aadharBack = d?['aadharBackImage'] as String?;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _dlCtrl.dispose();
    _aadharCtrl.dispose();
    _addressCtrl.dispose();
    _dobCtrl.dispose();
    super.dispose();
  }

  Future<void> _pick(String slot) async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1400, imageQuality: 80);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() => _uploadingSlot = slot);
    try {
      final res = await _api.dio.post('/storage/upload', data: FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: '$slot.jpg'),
        'folder': 'drivers',
      }));
      final url = res.data['data'] as String?;
      if (!mounted) return;
      setState(() => _setSlot(slot, url));
      // The Aadhaar photo is the only one worth reading - the rest are just
      // documents for the admin to eyeball.
      if (slot == 'aadharFront') await _ocrAadhaar(bytes);
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

  /// Read the uploaded Aadhaar and check it against the name on the licence.
  ///
  /// This is the only Aadhaar route open to an app like this - no eKYC licence,
  /// no portal visit, no OTP. We are reading a document the user handed over,
  /// and we keep only the last 4 digits of the number.
  Future<void> _ocrAadhaar(Uint8List bytes) async {
    setState(() {
      _ocrBusy = true;
      _ocrMessage = null;
      _ocrNameMatched = null;
      _ocrSuspect = false;
    });
    try {
      final res = await _api.dio.post('/verification/ocr', data: FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: 'aadhaar.jpg'),
        'documentType': 'aadhaar',
        // Compare against the licence holder's name, which is already on screen.
        'compareName': _nameCtrl.text.trim(),
      }));
      final d = Map<String, dynamic>.from(res.data['data'] as Map);
      if (!mounted) return;

      if (d['configured'] == false || d['found'] != true) {
        setState(() => _ocrMessage = (d['message'] ?? '').toString());
        return;
      }

      final doc = Map<String, dynamic>.from((d['document'] ?? {}) as Map);
      final q = Map<String, dynamic>.from((d['quality'] ?? {}) as Map);
      final nm = d['nameMatch'] is Map ? Map<String, dynamic>.from(d['nameMatch'] as Map) : null;
      setState(() {
        final last4 = (doc['aadhaarLast4'] ?? '').toString();
        if (last4.isNotEmpty) _aadharCtrl.text = 'XXXX XXXX $last4';
        _ocrNameMatched = nm?['matched'] as bool?;
        _ocrSuspect = q['tampered'] == true || q['screenshot'] == true;
        _ocrMessage = (d['message'] ?? '').toString();
      });
    } catch (e) {
      if (mounted) setState(() => _ocrMessage = serverMessage(e, fallback: 'Could not read the Aadhaar photo'));
    } finally {
      if (mounted) setState(() => _ocrBusy = false);
    }
  }

  void _setSlot(String slot, String? url) {
    switch (slot) {
      case 'photo':
        _photo = url;
      case 'dlFront':
        _dlFront = url;
      case 'dlBack':
        _dlBack = url;
      case 'aadharFront':
        _aadharFront = url;
      case 'aadharBack':
        _aadharBack = url;
    }
  }

  /// Pull the licence straight from the RTO record.
  ///
  /// Date of birth is required by the lookup itself - licence number alone would
  /// let anyone pull a stranger's details, so the government keys on both.
  Future<void> _fetchDl() async {
    final dl = _dlCtrl.text.trim();
    final dob = _dobCtrl.text.trim();
    if (dl.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').length < 8) {
      _driverToast('Enter a valid driving licence number');
      return;
    }
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(dob)) {
      // Ask once, inline, instead of putting a second field on the form.
      await _pickDob();
      final picked = _dobCtrl.text.trim();
      if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(picked)) return;
      return _fetchDl();
    }
    setState(() {
      _dlBusy = true;
      _dlMessage = null;
      _dlExpired = false;
    });
    try {
      final res = await _api.post('/verification/dl', data: {'dlNumber': dl, 'dob': dob});
      final d = Map<String, dynamic>.from(res.data['data'] as Map);
      if (!mounted) return;

      if (d['configured'] == false || d['found'] != true) {
        setState(() {
          _dlManual = true;
          _dlMessage = (d['message'] ?? 'No record found').toString();
        });
        return;
      }

      final l = Map<String, dynamic>.from(d['licence'] as Map);
      setState(() {
        _dlVerified = true;
        _dlManual = false;
        _nameCtrl.text = (l['holderName'] ?? '').toString();
        final addr = (l['address'] ?? '').toString();
        if (addr.isNotEmpty) _addressCtrl.text = addr;
        _dlValidUpto = (l['validUpto'] ?? '').toString();
        _dlClasses = ((l['vehicleClasses'] as List?) ?? const [])
            .map((e) => e.toString())
            .where((e) => e.isNotEmpty)
            .toList();
        _dlRto = (l['rto'] ?? '').toString();
        _dlExpired = l['expired'] == true;
        _dlMessage = (d['message'] ?? '').toString();
      });
    } catch (e) {
      // Vendor down or refused - let them type it in rather than strand them.
      if (mounted) {
        setState(() {
          _dlManual = true;
          _dlMessage = serverMessage(e, fallback: 'Could not fetch licence details');
        });
      }
    } finally {
      if (mounted) setState(() => _dlBusy = false);
    }
  }

  void _driverToast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  /// What the uploaded Aadhaar turned out to be. A forged or screen-captured
  /// image is the loudest thing here - a name mismatch is next.
  Widget? get _ocrBanner {
    if ((_ocrMessage ?? '').isEmpty) return null;
    final bad = _ocrSuspect || _ocrNameMatched == false;
    final tone = bad
        ? AppColors.error
        : _ocrNameMatched == true
            ? AppColors.success
            : AppColors.textSecondary;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.08),
        border: Border.all(color: tone.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _ocrSuspect
                ? Icons.report_gmailerrorred
                : bad
                    ? Icons.cancel_outlined
                    : _ocrNameMatched == true
                        ? Icons.verified_outlined
                        : Icons.info_outline,
            size: 18.sp,
            color: tone,
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(_ocrMessage!,
                style: TextStyle(fontFamily: 'Poppins', fontSize: 12.sp, color: tone, height: 1.35)),
          ),
        ],
      ),
    );
  }

  /// What the RTO record returned. Facts, so nothing here is editable.
  Widget _verifiedSummary() {
    final rows = <List<String>>[
      ['Name', _nameCtrl.text],
      ['Valid till', _dlValidUpto],
      ['Can drive', _dlClasses.join(', ')],
      ['RTO', _dlRto],
      ['Address', _addressCtrl.text],
    ].where((r) => r[1].trim().isNotEmpty).toList();
    if (rows.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final r in rows)
            Padding(
              padding: EdgeInsets.only(bottom: r == rows.last ? 0 : 8.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 68.w,
                    child: Text(r[0].tr,
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 12.sp, color: AppColors.textSecondary)),
                  ),
                  Expanded(
                    child: Text(r[1],
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 13.sp, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  ),
                ],
              ),
            ),
          SizedBox(height: 10.h),
          GestureDetector(
            onTap: () => setState(() => _dlManual = true),
            child: Text('Something wrong? Edit manually'.tr,
                style: TextStyle(fontFamily: 'Poppins', fontSize: 12.sp, fontWeight: FontWeight.w600, color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  /// The licence lookup, which is now the whole identity step: a number, a date
  /// of birth, and the RTO record fills in the rest.
  Widget _licenceCard() {
    // No verification vendor configured: this is just a licence-number field,
    // so drop the card chrome and the talk of fetching from the RTO record.
    if (!kVerificationEnabled) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel('Driving Licence (DL) Number'),
          TextFormField(
            controller: _dlCtrl,
            textCapitalization: TextCapitalization.characters,
            decoration: _fieldDec(Icons.badge_outlined, hint: 'e.g. GJ0120210001234'),
          ),
        ],
      );
    }

    final tone = _dlExpired
        ? AppColors.error
        : _dlVerified
            ? AppColors.success
            : AppColors.primary;
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.06),
        border: Border.all(color: tone.withValues(alpha: 0.30)),
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_dlVerified && !_dlExpired ? Icons.verified_user : Icons.badge_outlined, size: 20.sp, color: tone),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  _dlVerified && !_dlExpired ? 'Licence verified'.tr : 'Verify driving licence'.tr,
                  style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 14.sp, color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
          SizedBox(height: 4.h),
          Text(
            _dlMessage ??
                "Enter the licence number. Their name, address and licence validity come from the RTO record.",
            style: TextStyle(fontFamily: 'Poppins', fontSize: 11.5.sp, color: _dlExpired ? tone : AppColors.textSecondary, height: 1.35),
          ),
          SizedBox(height: 12.h),

          _fieldLabel('Driving Licence (DL) Number *'),
          TextFormField(
            controller: _dlCtrl,
            textCapitalization: TextCapitalization.characters,
            decoration: _fieldDec(Icons.badge_outlined, hint: 'e.g. GJ0120210001234'),
          ),
          // The date of birth is collected by the picker on Fetch, not as a
          // second field - but once we have it, show what is being used.
          if (_dobCtrl.text.isNotEmpty) ...[
            SizedBox(height: 8.h),
            GestureDetector(
              onTap: _pickDob,
              child: Row(
                children: [
                  Icon(Icons.cake_outlined, size: 14.sp, color: AppColors.textSecondary),
                  SizedBox(width: 6.w),
                  Text('Date of birth: ${_dobCtrl.text}',
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 11.5.sp, color: AppColors.textSecondary)),
                  SizedBox(width: 6.w),
                  Text('Change'.tr,
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 11.5.sp, fontWeight: FontWeight.w600, color: AppColors.primary)),
                ],
              ),
            ),
          ],
          if (kVerificationEnabled) ...[
          SizedBox(height: 12.h),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _dlBusy ? null : _fetchDl,
              style: ElevatedButton.styleFrom(
                backgroundColor: tone,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 12.h),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
              ),
              child: _dlBusy
                  ? SizedBox(width: 16.w, height: 16.w, child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(_dlVerified ? 'Fetch again'.tr : 'Fetch'.tr,
                      style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 13.sp)),
            ),
          ),
          ],

          // Nobody gets stuck on a form they cannot finish.
          if (!_showDriverFields && !_dlVerified) ...[
            SizedBox(height: 8.h),
            GestureDetector(
              onTap: () => setState(() => _dlManual = true),
              child: Text('Skip and enter details manually'.tr,
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 12.sp, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            ),
          ],
        ],
      ),
    );
  }

  /// A licence holder is an adult with a licence, so the picker opens on a
  /// plausible year rather than today.
  Future<void> _pickDob() async {
    final now = DateTime.now();
    final current = DateTime.tryParse(_dobCtrl.text.trim());
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime(now.year - 30),
      firstDate: DateTime(now.year - 80),
      lastDate: DateTime(now.year - 18),
      helpText: "Driver's date of birth",
      // The RTO looks up the licence by number AND date of birth together.
      fieldHintText: 'YYYY-MM-DD',
    );
    if (picked == null) return;
    String two(int n) => n.toString().padLeft(2, '0');
    setState(() => _dobCtrl.text = '${picked.year}-${two(picked.month)}-${two(picked.day)}');
  }

  Future<void> _save() async {
    // Clear any stale server error so validation reflects the latest input.
    _phoneServerError = null;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final body = {
      'fullName': _nameCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'dlNumber': _dlCtrl.text.trim(),
      'aadharNumber': _aadharCtrl.text.trim(),
      'address': _addressCtrl.text.trim(),
      'photo': _photo ?? '',
      'dlFrontImage': _dlFront ?? '',
      'dlBackImage': _dlBack ?? '',
      'aadharFrontImage': _aadharFront ?? '',
      'aadharBackImage': _aadharBack ?? '',
    };
    try {
      if (_isEdit) {
        await _api.put('/garage/drivers/${widget.driver!['_id']}', data: body);
      } else {
        await _api.post('/garage/drivers', data: body);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      final msg = serverMessage(e, fallback: 'Could not save driver');
      final lower = msg.toLowerCase();
      // Number-related rejections show inline under the Phone field so they don't
      // disappear with a snackbar; other errors keep the snackbar.
      final isPhoneError = lower.contains('number') || lower.contains('mobile') || lower.contains('driver/vendor');
      setState(() {
        _saving = false;
        _phoneServerError = isPhoneError ? msg : null;
      });
      if (isPhoneError) {
        _formKey.currentState?.validate(); // surface it on the field
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 28.h),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
      child: ConstrainedBox(
        // Grows with the content but never past the screen, so a short form is
        // a small box and a long one scrolls inside the dialog.
        constraints: BoxConstraints(maxHeight: size.height * 0.85, maxWidth: 520.w),
        child: Form(
          key: _formKey,
          child: ListView(
            shrinkWrap: true,
            padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 24.h),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(_isEdit ? 'Edit Driver'.tr : 'Add Driver'.tr,
                        style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 18.sp, color: AppColors.textPrimary)),
                  ),
                  IconButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    icon: Icon(Icons.close, size: 22.sp, color: AppColors.textSecondary),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Close',
                  ),
                ],
              ),
              SizedBox(height: 16.h),

              // Driver photo (centered avatar picker)
              Center(
                child: GestureDetector(
                  onTap: _uploadingSlot == 'photo' ? null : () => _pick('photo'),
                  child: Container(
                    width: 92.w,
                    height: 92.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.background,
                      border: Border.all(color: AppColors.border),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _uploadingSlot == 'photo'
                        ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                        : (_photo != null && _photo!.isNotEmpty)
                            ? Image.network(_photo!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Icon(Icons.person, size: 34.sp, color: AppColors.textHint))
                            : Icon(Icons.add_a_photo_outlined, size: 28.sp, color: AppColors.textHint),
                  ),
                ),
              ),
              SizedBox(height: 6.h),
              Center(child: Text('Driver Photo', style: TextStyle(fontSize: 11.sp, color: AppColors.textHint, fontFamily: 'Poppins'))),
              SizedBox(height: 16.h),

              _licenceCard(),
              SizedBox(height: 14.h),

              // Everything the RTO record returned - shown, not typed.
              if (_dlVerified && !_showDriverFields) ...[
                _verifiedSummary(),
                SizedBox(height: 14.h),
              ],

              if (_showDriverFields) ...[
                _fieldLabel('Full Name *'),
                TextFormField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: _fieldDec(Icons.person_outline, hint: 'e.g. Suresh Kumar'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                SizedBox(height: 14.h),
              ],

              // The phone always stays: a licence record does not carry one, and
              // this is what matches the driver to the trips assigned to them.
              _fieldLabel('Phone *'),
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                decoration: _fieldDec(Icons.phone_outlined, hint: 'e.g. 9876543210'),
                autovalidateMode: AutovalidateMode.onUserInteraction,
                onChanged: (_) {
                  if (_phoneServerError != null) setState(() => _phoneServerError = null);
                },
                validator: (v) {
                  final t = (v ?? '').trim();
                  // Any valid 10-digit number works — the driver need not have an
                  // account yet. They'll see assigned trips after signing in with it.
                  if (t.isEmpty) return 'Mobile number is required';
                  if (!RegExp(r'^[6-9]\d{9}$').hasMatch(t)) return 'Enter a valid 10-digit mobile';
                  if (_phoneServerError != null) return _phoneServerError;
                  return null;
                },
              ),
              SizedBox(height: 6.h),
              Text(
                'The driver doesn\'t need an account yet. After you assign them a trip, they\'ll see it in their own app once they sign in with this number.',
                style: TextStyle(fontSize: 11.sp, color: AppColors.textSecondary, height: 1.3, fontFamily: 'Poppins'),
              ),
              SizedBox(height: 14.h),

              if (_showDriverFields) ...[
              _fieldLabel('Aadhaar Number'),
              TextFormField(
                controller: _aadharCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [_AadhaarInputFormatter()],
                decoration: _fieldDec(Icons.credit_card_outlined, hint: 'e.g. 1234 5678 9012'),
                validator: (v) {
                  final t = (v ?? '').replaceAll(' ', '');
                  if (t.isEmpty) return null; // aadhaar optional
                  if (t.length != 12) return 'Aadhaar must be 12 digits';
                  return null;
                },
              ),
              SizedBox(height: 14.h),

              _fieldLabel('Address'),
              TextFormField(
                controller: _addressCtrl,
                maxLines: 2,
                decoration: _fieldDec(Icons.location_on_outlined, hint: 'e.g. 12 Green Park, Rajkot'),
              ),
              SizedBox(height: 16.h),
              ],

              _fieldLabel('Driving Licence (front & back)'),
              Row(
                children: [
                  _imageSlot(busy: _uploadingSlot == 'dlFront', onPick: () => _pick('dlFront'), onClear: () => _clearSlot('dlFront'), caption: 'DL Front', url: _dlFront),
                  SizedBox(width: 10.w),
                  _imageSlot(busy: _uploadingSlot == 'dlBack', onPick: () => _pick('dlBack'), onClear: () => _clearSlot('dlBack'), caption: 'DL Back', url: _dlBack),
                ],
              ),
              SizedBox(height: 14.h),

              _fieldLabel('Aadhaar (front & back)'),
              Row(
                children: [
                  _imageSlot(busy: _uploadingSlot == 'aadharFront', onPick: () => _pick('aadharFront'), onClear: () => _clearSlot('aadharFront'), caption: 'Aadhaar Front', url: _aadharFront),
                  SizedBox(width: 10.w),
                  _imageSlot(busy: _uploadingSlot == 'aadharBack', onPick: () => _pick('aadharBack'), onClear: () => _clearSlot('aadharBack'), caption: 'Aadhaar Back', url: _aadharBack),
                ],
              ),
              if (_ocrBusy || _ocrBanner != null) ...[
                SizedBox(height: 10.h),
                if (_ocrBusy)
                  Row(
                    children: [
                      SizedBox(width: 14.w, height: 14.w, child: const CircularProgressIndicator(strokeWidth: 2)),
                      SizedBox(width: 8.w),
                      Text('Reading the Aadhaar photo...'.tr,
                          style: TextStyle(fontFamily: 'Poppins', fontSize: 12.sp, color: AppColors.textSecondary)),
                    ],
                  )
                else
                  _ocrBanner!,
              ],
              SizedBox(height: 22.h),

              if (_needsVerify)
                Padding(
                  padding: EdgeInsets.only(bottom: 10.h),
                  child: Text('Fetch the licence details first, or enter them manually.'.tr,
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 12.sp, color: AppColors.textSecondary)),
                ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_saving || _needsVerify) ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.border,
                    disabledForegroundColor: AppColors.textSecondary,
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                  ),
                  child: _saving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(_isEdit ? 'Save Changes'.tr : 'Add Driver'.tr, style: TextStyle(fontSize: 15.sp, fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _clearSlot(String slot) => setState(() => _setSlot(slot, null));
}

// ══════════════════════ shared form helpers (both forms) ══════════════════════

/// Formats an Aadhaar entry as digits-only, max 12, grouped "1234 5678 9012".
class _AadhaarInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 12) digits = digits.substring(0, 12);
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i != 0 && i % 4 == 0) buf.write(' ');
      buf.write(digits[i]);
    }
    final text = buf.toString();
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}

Widget _fieldLabel(String t) => Padding(
      padding: EdgeInsets.only(bottom: 6.h),
      child: Text(t, style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: AppColors.textSecondary, fontFamily: 'Poppins')),
    );

/// Admin-approval status chip shown on a garage vehicle/driver card. Pending &
/// rejected items can't be used to accept bookings until an admin approves them.
Widget _approvalBadge(Map<String, dynamic> item) {
  final status = (item['approvalStatus'] ?? 'pending').toString();
  final reason = (item['rejectionReason'] ?? '').toString().trim();
  late final Color color;
  late final IconData icon;
  late final String label;
  switch (status) {
    case 'approved':
      color = AppColors.success;
      icon = Icons.verified_rounded;
      label = 'Approved';
      break;
    case 'rejected':
      color = AppColors.error;
      icon = Icons.cancel_rounded;
      label = 'Rejected';
      break;
    default:
      color = AppColors.warning;
      icon = Icons.hourglass_top_rounded;
      label = 'Pending admin approval';
  }
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6.r),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13.sp, color: color),
          SizedBox(width: 4.w),
          Text(label, style: TextStyle(fontSize: 10.5.sp, fontWeight: FontWeight.w700, color: color, fontFamily: 'Poppins')),
        ]),
      ),
      if (status == 'rejected' && reason.isNotEmpty) ...[
        SizedBox(height: 4.h),
        Text(reason, style: TextStyle(fontSize: 10.5.sp, color: AppColors.error, fontFamily: 'Poppins')),
      ],
    ],
  );
}

InputDecoration _fieldDec(IconData icon, {String? hint}) => InputDecoration(
      prefixIcon: Icon(icon, size: 20.sp),
      hintText: hint,
      hintStyle: TextStyle(fontSize: 13.sp, color: AppColors.textHint, fontFamily: 'Poppins'),
      isDense: true,
    );

/// One tappable image box shared by both forms.
Widget _imageSlot({
  required bool busy,
  required VoidCallback onPick,
  required VoidCallback onClear,
  required String caption,
  required String? url,
}) {
  return Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(caption, style: TextStyle(fontSize: 11.sp, color: AppColors.textHint, fontFamily: 'Poppins')),
        SizedBox(height: 4.h),
        GestureDetector(
          onTap: busy ? null : onPick,
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
                          onTap: onClear,
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
