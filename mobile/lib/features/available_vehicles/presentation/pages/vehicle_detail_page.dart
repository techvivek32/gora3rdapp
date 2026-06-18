import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../bloc/vehicles_bloc.dart';

class VehicleDetailPage extends StatefulWidget {
  final String vehicleId;
  final Map<String, dynamic>? vehicle;
  const VehicleDetailPage({super.key, required this.vehicleId, this.vehicle});

  @override
  State<VehicleDetailPage> createState() => _VehicleDetailPageState();
}

class _VehicleDetailPageState extends State<VehicleDetailPage> {
  Map<String, dynamic>? _vehicle;
  bool _isEditing = false;
  final _formKey = GlobalKey<FormState>();

  // Edit controllers
  late TextEditingController _currentCityCtrl;
  late TextEditingController _currentStateCtrl;
  late TextEditingController _destCityCtrl;
  late TextEditingController _vehicleNumberCtrl;
  late TextEditingController _driverNameCtrl;
  late TextEditingController _driverMobileCtrl;
  late TextEditingController _notesCtrl;
  String _vehicleType = 'sedan';
  DateTime? _availableDate;
  TimeOfDay? _availableTime;

  final _vehicleTypes = ['hatchback', 'sedan', 'suv', 'muv', 'traveller', 'tempo_traveller', 'mini_bus', 'bus'];

  @override
  void initState() {
    super.initState();
    _currentCityCtrl = TextEditingController();
    _currentStateCtrl = TextEditingController();
    _destCityCtrl = TextEditingController();
    _vehicleNumberCtrl = TextEditingController();
    _driverNameCtrl = TextEditingController();
    _driverMobileCtrl = TextEditingController();
    _notesCtrl = TextEditingController();
    if (widget.vehicle != null) {
      _vehicle = widget.vehicle;
      _populateControllers();
    }
    context.read<VehiclesBloc>().add(LoadVehicleDetailEvent(widget.vehicleId));
  }

  void _populateControllers() {
    _currentCityCtrl.text = _vehicle?['currentCity'] as String? ?? '';
    _currentStateCtrl.text = _vehicle?['currentState'] as String? ?? '';
    _destCityCtrl.text = _vehicle?['destinationCity'] as String? ?? '';
    _vehicleNumberCtrl.text = _vehicle?['vehicleNumber'] as String? ?? '';
    _driverNameCtrl.text = _vehicle?['driverName'] as String? ?? '';
    _driverMobileCtrl.text = _vehicle?['driverMobile'] as String? ?? '';
    _notesCtrl.text = _vehicle?['notes'] as String? ?? '';
    _vehicleType = _vehicle?['vehicleType'] as String? ?? 'sedan';
    if (_vehicle?['availableDate'] != null) {
      try {
        _availableDate = DateTime.parse(_vehicle!['availableDate'].toString());
      } catch (_) {}
    }
    if (_vehicle?['availableTime'] != null) {
      try {
        final parts = (_vehicle!['availableTime'] as String).split(':');
        _availableTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _currentCityCtrl.dispose();
    _currentStateCtrl.dispose();
    _destCityCtrl.dispose();
    _vehicleNumberCtrl.dispose();
    _driverNameCtrl.dispose();
    _driverMobileCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  bool _isMyVehicle(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return false;
    final userId = authState.user['_id'] as String? ?? authState.user['id'] as String?;
    final postedBy = _vehicle?['postedBy'];
    final posterId = postedBy is Map 
      ? (postedBy['_id'] as String? ?? postedBy['id'] as String?) 
      : (postedBy is String ? postedBy : _vehicle?['userId'] as String?);
    return userId != null && userId == posterId;
  }

  String _formatDate(dynamic date) {
    if (date == null) return '-';
    try {
      final d = DateTime.parse(date.toString());
      const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${d.day} ${months[d.month]} ${d.year}';
    } catch (_) {
      return date.toString();
    }
  }

  String _formatVehicleType(String? type) {
    if (type == null) return '';
    return type.split('_').map((w) => w[0].toUpperCase() + w.substring(1)).join(' ') + ' Car';
  }

  void _showCancelDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      isDismissible: true,
      enableDrag: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (sheetContext) => _CancelReasonSheet(
        onConfirm: (reason) {
          // Close the sheet first
          Navigator.of(sheetContext).pop();
          // Then show confirmation
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) {
              _showCancelConfirmation(reason);
            }
          });
        },
      ),
    );
  }

  void _showCancelConfirmation(String reason) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isDismissible: true,
      enableDrag: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (confirmContext) => Container(
        padding: EdgeInsets.all(20.r),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber_rounded, size: 48.sp, color: AppColors.error),
            SizedBox(height: 16.h),
            Text('Confirm Cancel', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 18.sp)),
            SizedBox(height: 12.h),
            Text('Are you sure you want to cancel this vehicle listing?', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Poppins', fontSize: 14.sp)),
            SizedBox(height: 8.h),
            Container(
              padding: EdgeInsets.all(12.r),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16.sp, color: AppColors.textSecondary),
                  SizedBox(width: 8.w),
                  Expanded(child: Text('Reason: $reason', style: TextStyle(fontFamily: 'Poppins', fontSize: 13.sp, color: AppColors.textSecondary))),
                ],
              ),
            ),
            SizedBox(height: 20.h),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(confirmContext).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      side: BorderSide(color: Colors.grey[400]!),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                    ),
                    child: const Text('No', style: TextStyle(fontFamily: 'Poppins')),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(confirmContext).pop();
                      if (mounted) {
                        context.read<VehiclesBloc>().add(
                          CancelVehicleEvent(id: widget.vehicleId, reason: reason),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                    ),
                    child: Text('Yes, Cancel', style: TextStyle(color: Colors.white, fontFamily: 'Poppins')),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),
          ],
        ),
      ),
    );
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  void _saveEdit() {
    if (!_formKey.currentState!.validate()) return;
    if (_availableDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please select available date'), backgroundColor: AppColors.error));
      return;
    }

    final data = <String, dynamic>{
      'currentCity': _currentCityCtrl.text.trim(),
      'currentState': _currentStateCtrl.text.trim(),
      'destinationCity': _destCityCtrl.text.trim().isEmpty ? null : _destCityCtrl.text.trim(),
      'vehicleType': _vehicleType,
      'vehicleNumber': _vehicleNumberCtrl.text.trim().toUpperCase(),
      'driverName': _driverNameCtrl.text.trim(),
      'driverMobile': _driverMobileCtrl.text.trim(),
      'availableDate': _availableDate!.toIso8601String().split('T').first,
      'availableTime': _availableTime != null ? '${_availableTime!.hour.toString().padLeft(2, '0')}:${_availableTime!.minute.toString().padLeft(2, '0')}' : '00:00',
    };

    if (_notesCtrl.text.trim().isNotEmpty) {
      data['notes'] = _notesCtrl.text.trim();
    }

    context.read<VehiclesBloc>().add(UpdateVehicleEvent(
      id: widget.vehicleId,
      data: data,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<VehiclesBloc, VehiclesState>(
      listener: (ctx, state) {
        if (state is VehicleDetailLoaded && mounted) {
          setState(() {
            _vehicle = state.vehicle;
            _populateControllers();
          });
        }
        if (state is VehicleUpdated && mounted) {
          setState(() {
            _vehicle = state.vehicle;
            _isEditing = false;
            _populateControllers();
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Vehicle listing updated!'), backgroundColor: AppColors.success),
              );
            }
          });
        }
        if (state is VehicleCancelled) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Vehicle listing cancelled.'), backgroundColor: AppColors.error),
              );
              Future.delayed(const Duration(milliseconds: 500), () {
                if (mounted && Navigator.canPop(context)) {
                  Navigator.pop(context, true);
                }
              });
            }
          });
        }
        if (state is VehicleAccepted && mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Vehicle accepted successfully!'), backgroundColor: AppColors.success),
              );
            }
          });
        }
        if (state is VehiclesError && mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.message), backgroundColor: AppColors.error),
              );
            }
          });
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.primary,
            elevation: 4,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => context.pop(),
            ),
            title: _vehicle != null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_formatDate(_vehicle!['availableDate']), style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, color: Colors.white)),
                      Text(_vehicle!['availableTime'] as String? ?? '', style: TextStyle(fontSize: 12.sp, color: Colors.white70)),
                    ],
                  )
                : Text('Vehicle Detail', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
          body: _vehicle == null
              ? const Center(child: CircularProgressIndicator())
              : _isEditing
                  ? _buildEditForm()
                  : _buildBody(_vehicle!),
          bottomNavigationBar: _vehicle != null ? _buildBottomBar() : null,
        );
      },
    );
  }

  Widget _buildBottomBar() {
    final isMine = _isMyVehicle(context);
    if (isMine) {
      if (_isEditing) {
        return BlocBuilder<VehiclesBloc, VehiclesState>(
          builder: (context, state) {
            final loading = state is VehiclesLoading;
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: loading ? null : () {
                          if (mounted) {
                            setState(() {
                              _isEditing = false;
                              _populateControllers();
                            });
                          }
                        },
                        icon: Icon(Icons.close, color: loading ? Colors.grey : Colors.grey[700]),
                        label: Text('Cancel', style: TextStyle(color: loading ? Colors.grey : Colors.grey[700], fontSize: 14.sp)),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 13.h),
                          side: BorderSide(color: loading ? Colors.grey[300]! : Colors.grey[400]!),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: loading ? null : _saveEdit,
                        icon: loading
                            ? SizedBox(width: 18.w, height: 18.h, child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.save_outlined, color: Colors.white),
                        label: Text('Save Changes', style: TextStyle(color: Colors.white, fontSize: 14.sp)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: loading ? AppColors.primary.withOpacity(0.6) : AppColors.primary,
                          padding: EdgeInsets.symmetric(vertical: 13.h),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }
      final isVehicleBooked = (_vehicle?['status'] as String? ?? '') == 'booked';
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _showCancelDialog,
                  icon: Icon(Icons.cancel_outlined, color: AppColors.error),
                  label: Text('Cancel', style: TextStyle(color: AppColors.error, fontSize: 14.sp)),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 13.h),
                    side: BorderSide(color: AppColors.error),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                  ),
                ),
              ),
              if (!isVehicleBooked) ...[
                SizedBox(width: 12.w),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => setState(() => _isEditing = true),
                    icon: const Icon(Icons.edit_outlined, color: Colors.white),
                    label: Text('Edit', style: TextStyle(color: Colors.white, fontSize: 14.sp)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: EdgeInsets.symmetric(vertical: 13.h),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }
    // Non-owner bottom bar
    final authState = context.read<AuthBloc>().state;
    final currentUserId = authState is AuthAuthenticated ? authState.user['_id'] as String? : null;
    final acceptorsList = (_vehicle?['acceptedBy'] as List? ?? []);
    final hasCurrentUserAccepted = currentUserId != null && acceptorsList.any((a) {
      if (a is Map) return a['_id']?.toString() == currentUserId;
      return a?.toString() == currentUserId;
    });
    final vehicleStatus = (_vehicle?['status'] as String? ?? 'available');
    final isBooked = vehicleStatus == 'booked';

    if (hasCurrentUserAccepted) {
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16.r),
          child: ElevatedButton.icon(
            onPressed: null,
            icon: const Icon(Icons.check_circle_outline, color: Colors.white),
            label: const Text('Already Accepted', style: TextStyle(color: Colors.white, fontSize: 15)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[700],
              disabledBackgroundColor: Colors.green[700],
              disabledForegroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 14.h),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
            ),
          ),
        ),
      );
    }
    if (isBooked) {
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16.r),
          child: ElevatedButton.icon(
            onPressed: null,
            icon: const Icon(Icons.block, color: Colors.white),
            label: const Text('Vehicle Already Booked', style: TextStyle(color: Colors.white, fontSize: 15)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[700],
              disabledBackgroundColor: Colors.red[700],
              disabledForegroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 14.h),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
            ),
          ),
        ),
      );
    }
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(16.r),
        child: ElevatedButton.icon(
          onPressed: () => context.read<VehiclesBloc>().add(AcceptVehicleEvent(widget.vehicleId)),
          icon: const Icon(Icons.handshake_outlined, color: Colors.white),
          label: const Text('Accept Cab', style: TextStyle(color: Colors.white, fontSize: 15)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            padding: EdgeInsets.symmetric(vertical: 14.h),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
          ),
        ),
      ),
    );
  }

  Widget _buildEditForm() {
    return SingleChildScrollView(
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
                      initialDate: _availableDate ?? DateTime.now(),
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
                    final t = await showTimePicker(context: context, initialTime: _availableTime ?? TimeOfDay.now());
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
            SizedBox(height: 32.h),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(Map<String, dynamic> vehicle) {
    final isMine = _isMyVehicle(context);
    final postedBy = vehicle['postedBy'];
    final postedByMap = postedBy is Map ? postedBy : null;

    final acceptors = (vehicle['acceptedBy'] as List? ?? [])
        .where((a) => a is Map)
        .map((a) => Map<String, dynamic>.from(a as Map))
        .toList();

    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        bool isCurrentUserPremium = false;
        if (authState is AuthAuthenticated) {
          final user = authState.user;
          isCurrentUserPremium = (user['isPremium'] == true) || (user['isGolden'] == true) || (['active', 'verified', 'premium', 'golden'].contains(user['membershipType']));
        }

        final posterMemberType = postedByMap?['membershipType'] as String? ?? 'new';
        String? posterBadgeText;
        Color posterBadgeColor;
        Color posterBadgeBg;
        if (posterMemberType == 'golden' || postedByMap?['isGolden'] == true) {
          posterBadgeText = 'GOLDEN USER';
          posterBadgeColor = AppColors.memberGolden;
          posterBadgeBg = AppColors.memberGolden.withOpacity(0.12);
        } else if (posterMemberType == 'premium' || postedByMap?['isPremium'] == true) {
          posterBadgeText = 'PREMIUM USER';
          posterBadgeColor = AppColors.memberPremium;
          posterBadgeBg = AppColors.memberPremium.withOpacity(0.12);
        } else if (posterMemberType == 'active' || posterMemberType == 'verified') {
          posterBadgeText = 'ACTIVE USER';
          posterBadgeColor = AppColors.memberActive;
          posterBadgeBg = AppColors.memberActive.withOpacity(0.1);
        } else {
          posterBadgeText = null;
          posterBadgeColor = Colors.grey;
          posterBadgeBg = Colors.grey[100]!;
        }

        return SingleChildScrollView(
          padding: EdgeInsets.all(16.r),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Route card
              _card(
                title: 'Location',
                child: Row(
                  children: [
                    Column(
                      children: [
                        Container(width: 12.w, height: 12.h, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                        Container(width: 2.w, height: 30.h, color: Colors.grey[400]),
                        Container(width: 12.w, height: 12.h, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
                      ],
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(vehicle['currentCity'] as String? ?? '', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, color: Colors.black)),
                          if (vehicle['currentState'] != null)
                            Text(vehicle['currentState'] as String, style: TextStyle(fontSize: 12.sp, color: Colors.grey[600])),
                          SizedBox(height: 16.h),
                          Text(vehicle['destinationCity'] as String? ?? 'Any', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, color: Colors.black)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 12.h),

              // Vehicle info card
              _card(
                title: 'Vehicle Info',
                child: Column(
                  children: [
                    _infoRow(Icons.directions_car, 'Vehicle Type', _formatVehicleType(vehicle['vehicleType'])),
                    _infoRow(Icons.badge_outlined, 'Vehicle Number', vehicle['vehicleNumber'] as String? ?? '-'),
                    _infoRow(Icons.person_outline, 'Driver Name', vehicle['driverName'] as String? ?? '-'),
                    _infoRow(Icons.calendar_today_outlined, 'Available Date', _formatDate(vehicle['availableDate'])),
                    _infoRow(Icons.access_time, 'Available Time', vehicle['availableTime'] as String? ?? '-'),
                    if (vehicle['notes'] != null && (vehicle['notes'] as String).isNotEmpty)
                      _infoRow(Icons.notes, 'Notes', vehicle['notes'] as String),
                  ],
                ),
              ),
              SizedBox(height: 12.h),

              // Contact card
              _card(
                title: 'Posted By',
                child: isMine
                    ? Row(
                        children: [
                          CircleAvatar(
                            radius: 24.r,
                            backgroundColor: AppColors.primary.withOpacity(0.1),
                            backgroundImage: postedByMap?['profileImage'] != null ? NetworkImage(postedByMap!['profileImage'] as String) : null,
                            child: postedByMap?['profileImage'] == null ? Icon(Icons.person, color: AppColors.primary) : null,
                          ),
                          SizedBox(width: 12.w),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Me', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp, color: AppColors.primary)),
                              if (postedByMap?['agencyName'] != null)
                                Text(postedByMap!['agencyName'] as String, style: TextStyle(fontSize: 12.sp, color: Colors.grey[600])),
                            ],
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 24.r,
                                backgroundColor: AppColors.primary.withOpacity(0.1),
                                backgroundImage: postedByMap?['profileImage'] != null ? NetworkImage(postedByMap!['profileImage'] as String) : null,
                                child: postedByMap?['profileImage'] == null ? Icon(Icons.person, color: AppColors.primary) : null,
                              ),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(postedByMap?['fullName'] as String? ?? 'Hidden', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp, color: Colors.black)),
                                    if (postedByMap?['agencyName'] != null)
                                      Text(postedByMap!['agencyName'] as String, style: TextStyle(fontSize: 12.sp, color: Colors.grey[600])),
                                  ],
                                ),
                              ),
                              if (posterBadgeText != null)
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                                  decoration: BoxDecoration(
                                    color: posterBadgeBg,
                                    borderRadius: BorderRadius.circular(4.r),
                                    border: Border.all(color: posterBadgeColor),
                                  ),
                                  child: Text(posterBadgeText, style: TextStyle(fontSize: 10.sp, color: posterBadgeColor, fontWeight: FontWeight.w600)),
                                ),
                            ],
                          ),
                          if (!isCurrentUserPremium) ...[
                            SizedBox(height: 12.h),
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(12.r),
                              decoration: BoxDecoration(
                                color: Colors.amber[50],
                                borderRadius: BorderRadius.circular(8.r),
                                border: Border.all(color: Colors.amber.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.lock_outline, color: Colors.amber[700]),
                                  SizedBox(width: 8.w),
                                  Expanded(child: Text('Upgrade to Premium to view contact details', style: TextStyle(fontSize: 12.sp, color: Colors.amber[800]))),
                                ],
                              ),
                            ),
                            SizedBox(height: 8.h),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () => context.push('/subscriptions'),
                                icon: const Icon(Icons.star, color: Colors.amber),
                                label: const Text('Upgrade to Premium'),
                              ),
                            ),
                          ] else ...[
                            SizedBox(height: 12.h),
                            if (postedByMap?['mobile'] != null || postedByMap?['phone'] != null) ...[
                              Container(
                                width: double.infinity,
                                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                                decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  borderRadius: BorderRadius.circular(8.r),
                                  border: Border.all(color: Colors.blue.shade200, width: 1),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.phone, color: Colors.blue[700], size: 16.sp),
                                    SizedBox(width: 8.w),
                                    Text(
                                      postedByMap?['mobile'] as String? ?? postedByMap?['phone'] as String? ?? '',
                                      style: TextStyle(fontSize: 14.sp, color: Colors.blue[800], fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 8.h),
                            ],
                            if (postedByMap?['email'] != null) ...[
                              Container(
                                width: double.infinity,
                                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                                decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  borderRadius: BorderRadius.circular(8.r),
                                  border: Border.all(color: Colors.blue.shade200, width: 1),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.email_outlined, color: Colors.blue[700], size: 16.sp),
                                    SizedBox(width: 8.w),
                                    Expanded(
                                      child: Text(
                                        postedByMap!['email'] as String,
                                        style: TextStyle(fontSize: 13.sp, color: Colors.blue[800], fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 8.h),
                            ],
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                                    onPressed: () {},
                                    icon: const Icon(Icons.call, color: Colors.white),
                                    label: Text(
                                      postedByMap?['mobile'] != null ? 'Call ${postedByMap!['mobile']}' : 'Call',
                                      style: const TextStyle(color: Colors.white),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 10.w),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () {},
                                    icon: Icon(Icons.chat, color: Colors.green, size: 16.sp),
                                    label: Text('WhatsApp', style: TextStyle(fontSize: 13.sp, color: Colors.green)),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: Colors.green, width: 1.5),
                                      padding: EdgeInsets.symmetric(vertical: 10.h),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
              ),
              if (isMine && acceptors.isNotEmpty) ...[
                SizedBox(height: 12.h),
                _card(
                  title: 'Accepted By',
                  child: Column(
                    children: [
                      for (int i = 0; i < acceptors.length; i++) ...[
                        _buildAcceptorRow(acceptors[i]),
                        if (i < acceptors.length - 1)
                          Divider(height: 16.h, thickness: 1, color: Colors.grey[200]),
                      ],
                    ],
                  ),
                ),
              ],
              SizedBox(height: 32.h),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAcceptorRow(Map<String, dynamic> acceptor) {
    final memberType = acceptor['membershipType'] as String? ?? 'new';
    Color badgeColor;
    Color badgeBg;
    String? badgeText;
    if (memberType == 'golden') {
      badgeColor = AppColors.memberGolden;
      badgeBg = AppColors.memberGolden.withOpacity(0.12);
      badgeText = 'GOLDEN';
    } else if (memberType == 'premium') {
      badgeColor = AppColors.memberPremium;
      badgeBg = AppColors.memberPremium.withOpacity(0.12);
      badgeText = 'PREMIUM';
    } else if (memberType == 'active' || memberType == 'verified') {
      badgeColor = AppColors.memberActive;
      badgeBg = AppColors.memberActive.withOpacity(0.1);
      badgeText = 'ACTIVE';
    } else {
      badgeColor = Colors.grey;
      badgeBg = Colors.grey[100]!;
      badgeText = null;
    }

    return Row(
      children: [
        CircleAvatar(
          radius: 20.r,
          backgroundColor: AppColors.primary.withOpacity(0.1),
          backgroundImage: acceptor['profileImage'] != null ? NetworkImage(acceptor['profileImage'] as String) : null,
          child: acceptor['profileImage'] == null ? Icon(Icons.person, color: AppColors.primary, size: 20.sp) : null,
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(acceptor['fullName'] as String? ?? 'Unknown', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp)),
              if (acceptor['agencyName'] != null)
                Text(acceptor['agencyName'] as String, style: TextStyle(fontSize: 11.sp, color: Colors.grey[600])),
              if (acceptor['mobile'] != null)
                Text(acceptor['mobile'] as String, style: TextStyle(fontSize: 11.sp, color: Colors.blue[700])),
            ],
          ),
        ),
        if (badgeText != null)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 3.h),
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(4.r),
              border: Border.all(color: badgeColor),
            ),
            child: Text(badgeText, style: TextStyle(fontSize: 9.sp, color: badgeColor, fontWeight: FontWeight.w600)),
          ),
      ],
    );
  }

  Widget _card({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: Colors.black26, width: 1),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 1))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 4.h,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.only(topLeft: Radius.circular(8.r), topRight: Radius.circular(8.r)),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(14.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold, color: AppColors.primary)),
                Divider(height: 12.h, thickness: 1, color: Colors.black26),
                child,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 5.h),
      child: Row(
        children: [
          Icon(icon, size: 16.sp, color: AppColors.primary),
          SizedBox(width: 10.w),
          Text('$label: ', style: TextStyle(fontSize: 13.sp, color: Colors.grey[600])),
          Expanded(child: Text(value, style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold, color: Colors.black))),
        ],
      ),
    );
  }
}

class _CancelReasonSheet extends StatefulWidget {
  final void Function(String reason) onConfirm;
  const _CancelReasonSheet({required this.onConfirm});

  @override
  State<_CancelReasonSheet> createState() => _CancelReasonSheetState();
}

class _CancelReasonSheetState extends State<_CancelReasonSheet> {
  static const _reasons = [
    'Found a passenger already',
    'Trip plan changed',
    'Vehicle listed by mistake',
    'Price not matching',
    'Dates changed',
    'Other',
  ];

  String? _selected;
  final _otherCtrl = TextEditingController();

  @override
  void dispose() {
    _otherCtrl.dispose();
    super.dispose();
  }

  void _confirm() {
    final reason = _selected == 'Other' ? _otherCtrl.text.trim() : _selected ?? '';
    if (reason.isEmpty) return;
    widget.onConfirm(reason);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      padding: EdgeInsets.only(
        left: 20.w,
        right: 20.w,
        top: 20.h,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20.h,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Cancel Reason', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 18.sp)),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  ..._reasons.map((r) => RadioListTile<String>(
                    value: r,
                    groupValue: _selected,
                    title: Text(r, style: const TextStyle(fontFamily: 'Poppins', fontSize: 14)),
                    onChanged: (v) => setState(() => _selected = v),
                    activeColor: AppColors.primary,
                    contentPadding: EdgeInsets.zero,
                  )),
                  if (_selected == 'Other') ...[
                    SizedBox(height: 8.h),
                    TextField(
                      controller: _otherCtrl,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Please specify your reason...',
                        hintStyle: const TextStyle(fontFamily: 'Poppins'),
                        filled: true,
                        fillColor: Colors.grey[50],
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.r),
                          borderSide: BorderSide(color: AppColors.primary, width: 2),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    side: BorderSide(color: Colors.grey[400]!),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                  ),
                  child: const Text('Cancel', style: TextStyle(fontFamily: 'Poppins')),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _confirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                  ),
                  child: const Text('Continue', style: TextStyle(color: Colors.white, fontFamily: 'Poppins')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
