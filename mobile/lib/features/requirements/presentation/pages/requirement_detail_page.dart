import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../bloc/requirements_bloc.dart';

class RequirementDetailPage extends StatefulWidget {
  final String requirementId;
  final Map<String, dynamic>? requirement;
  final bool startEditing;
  const RequirementDetailPage({super.key, required this.requirementId, this.requirement, this.startEditing = false});

  @override
  State<RequirementDetailPage> createState() => _RequirementDetailPageState();
}

class _RequirementDetailPageState extends State<RequirementDetailPage> {
  Map<String, dynamic>? _requirement;
  bool _isEditing = false;
  bool _detailLoaded = false;
  final _formKey = GlobalKey<FormState>();

  // Edit controllers
  late TextEditingController _pickupCtrl;
  late TextEditingController _dropCtrl;
  late TextEditingController _notesCtrl;
  String _vehicleType = 'sedan';
  String _tripType = 'one_way';
  final List<TextEditingController> _stopCtrls = [];
  DateTime? _travelDate;
  TimeOfDay? _travelTime;

  final _vehicleTypes = ['hatchback', 'sedan', 'suv', 'muv', 'traveller', 'tempo_traveller', 'mini_bus', 'bus'];
  final _tripTypes = ['one_way', 'round_trip', 'airport_transfer', 'local', 'outstation'];

  @override
  void initState() {
    super.initState();
    _pickupCtrl = TextEditingController();
    _dropCtrl = TextEditingController();
    _notesCtrl = TextEditingController();
    if (widget.requirement != null) {
      _requirement = widget.requirement;
      _populateControllers();
    }
    _isEditing = widget.startEditing;
    // Always load full detail from API so acceptedBy and other fields are fully populated
    context.read<RequirementsBloc>().add(LoadRequirementDetailEvent(widget.requirementId));
  }

  void _populateControllers() {
    _pickupCtrl.text = _requirement?['pickupCity'] as String? ?? '';
    _dropCtrl.text = _requirement?['dropCity'] as String? ?? '';
    _notesCtrl.text = _requirement?['notes'] as String? ?? '';
    _vehicleType = _requirement?['vehicleType'] as String? ?? 'sedan';
    _tripType = _requirement?['tripType'] as String? ?? 'one_way';
    // Populate existing stops (once).
    if (_stopCtrls.isEmpty) {
      final stops = (_requirement?['stops'] as List?) ?? const [];
      for (final s in stops) {
        final addr = (s is Map ? s['address'] : null)?.toString() ?? '';
        _stopCtrls.add(TextEditingController(text: addr));
      }
    }
    if (_requirement?['travelDate'] != null) {
      try {
        _travelDate = DateTime.parse(_requirement!['travelDate'].toString());
      } catch (_) {}
    }
    if (_requirement?['travelTime'] != null) {
      try {
        final parts = (_requirement!['travelTime'] as String).split(':');
        _travelTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _pickupCtrl.dispose();
    _dropCtrl.dispose();
    _notesCtrl.dispose();
    for (final c in _stopCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _addEditStop() => setState(() => _stopCtrls.add(TextEditingController()));

  void _removeEditStop(int index) {
    setState(() {
      _stopCtrls[index].dispose();
      _stopCtrls.removeAt(index);
    });
  }

  bool _isMyRequirement(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return false;
    final userId = authState.user['_id'] as String? ?? authState.user['id'] as String?;
    final postedBy = _requirement?['postedBy'];
    final posterId = postedBy is Map ? (postedBy['_id'] as String? ?? postedBy['id'] as String?) : _requirement?['userId'] as String?;
    return userId != null && userId == posterId;
  }

  IconData _getTripTypeIcon(String? tripType) {
    switch (tripType) {
      case 'one_way': return Icons.arrow_forward;
      case 'round_trip': return Icons.loop;
      case 'airport_transfer': return Icons.flight;
      case 'local': return Icons.location_city;
      case 'outstation': return Icons.map;
      default: return Icons.route;
    }
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

  String _getMemberSince(Map<String, dynamic> user) {
    try {
      final createdAt = user['createdAt'] as String?;
      if (createdAt != null) {
        final date = DateTime.parse(createdAt);
        return date.year.toString();
      }
    } catch (_) {}
    return '2024';
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
            Text('Are you sure you want to cancel this requirement?', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Poppins', fontSize: 14.sp)),
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
                        context.read<RequirementsBloc>().add(
                          CancelRequirementEvent(id: widget.requirementId, reason: reason),
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
    if (_travelDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please select travel date'), backgroundColor: AppColors.error));
      return;
    }
    
    final data = <String, dynamic>{
      'pickupCity': _pickupCtrl.text.trim(),
      'dropCity': _dropCtrl.text.trim(),
      'vehicleType': _vehicleType,
      'tripType': _tripType,
      'stops': _stopCtrls
          .where((c) => c.text.trim().isNotEmpty)
          .map((c) => {'address': c.text.trim()})
          .toList(),
      'travelDate': _travelDate!.toIso8601String().split('T').first,
      'travelTime': _travelTime != null ? '${_travelTime!.hour.toString().padLeft(2, '0')}:${_travelTime!.minute.toString().padLeft(2, '0')}' : '00:00',
    };
    
    if (_notesCtrl.text.trim().isNotEmpty) {
      data['notes'] = _notesCtrl.text.trim();
    }
    
    context.read<RequirementsBloc>().add(UpdateRequirementEvent(
      id: widget.requirementId,
      data: data,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<RequirementsBloc, RequirementsState>(
      listener: (ctx, state) {
        if (state is RequirementDetailLoaded && mounted) {
          setState(() {
            _requirement = state.requirement;
            _detailLoaded = true;
            _populateControllers();
          });
        }
        if (state is RequirementUpdated && mounted) {
          setState(() {
            _requirement = state.requirement;
            _isEditing = false;
            _populateControllers();
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Requirement updated!'), backgroundColor: AppColors.success),
              );
            }
          });
        }
        if (state is RequirementCancelled) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Requirement cancelled.'), backgroundColor: AppColors.error),
              );
              Future.delayed(const Duration(milliseconds: 500), () {
                if (mounted && Navigator.canPop(context)) {
                  Navigator.pop(context, true);
                }
              });
            }
          });
        }
        if (state is RequirementAccepted && mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Requirement accepted successfully!'),
                  backgroundColor: AppColors.success,
                ),
              );
            }
          });
        }
        if (state is RequirementsError && mounted) {
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
            title: _requirement != null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_formatDate(_requirement!['travelDate']), style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, color: Colors.white)),
                      Text(_requirement!['travelTime'] as String? ?? '', style: TextStyle(fontSize: 12.sp, color: Colors.white70)),
                    ],
                  )
                : Text('Requirement Detail', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
          body: _requirement == null
              ? const Center(child: CircularProgressIndicator())
              : _isEditing
                  ? _buildEditForm()
                  : _buildBody(_requirement!),
          bottomNavigationBar: _requirement != null ? _buildBottomBar() : null,
        );
      },
    );
  }

  bool _hasCurrentUserAccepted(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return false;
    final userId = authState.user['_id'] as String? ?? authState.user['id'] as String?;
    final acceptedBy = _requirement?['acceptedBy'] as List?;
    if (acceptedBy == null || userId == null) return false;
    return acceptedBy.any((u) {
      if (u is Map) return (u['_id'] as String?) == userId;
      return u.toString() == userId;
    });
  }

  Widget _buildBottomBar() {
    final isMine = _isMyRequirement(context);
    final isBooked = _requirement?['status'] == 'accepted';
    if (isMine) {
      if (_isEditing) {
        return BlocBuilder<RequirementsBloc, RequirementsState>(
          builder: (context, state) {
            final loading = state is RequirementsLoading;
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
      // Owner bottom bar: show booked badge + optional cancel when before travel time
      if (isBooked) {
        // Determine if travel datetime is still in the future
        bool canCancel = false;
        try {
          final dateStr = _requirement?['travelDate'] as String?;
          final timeStr = _requirement?['travelTime'] as String?;
          if (dateStr != null) {
            final d = DateTime.parse(dateStr).toLocal();
            int hour = 0, minute = 0;
            if (timeStr != null) {
              final parts = timeStr.split(':');
              hour = int.tryParse(parts[0]) ?? 0;
              minute = int.tryParse(parts[1]) ?? 0;
            }
            final travelDt = DateTime(d.year, d.month, d.day, hour, minute);
            canCancel = DateTime.now().isBefore(travelDt);
          }
        } catch (_) {}

        return SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(color: Colors.green),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 20.sp),
                      SizedBox(width: 8.w),
                      Text('Requirement Booked', style: TextStyle(color: Colors.green, fontSize: 14.sp, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                if (canCancel) ...[
                  SizedBox(height: 8.h),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _showCancelDialog,
                      icon: Icon(Icons.cancel_outlined, color: AppColors.error, size: 18.sp),
                      label: Text('Cancel Booking', style: TextStyle(color: AppColors.error, fontSize: 14.sp)),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        side: const BorderSide(color: AppColors.error),
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
          ),
        ),
      );
    }
    // Non-owner: show Already Accepted or Accept button
    final alreadyAccepted = _hasCurrentUserAccepted(context);
    if (alreadyAccepted) {
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16.r),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 14.h),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(color: Colors.green),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 20.sp),
                SizedBox(width: 8.w),
                Text('Already Accepted', style: TextStyle(color: Colors.green, fontSize: 15, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      );
    }
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(16.r),
        child: ElevatedButton.icon(
          onPressed: () => context.read<RequirementsBloc>().add(AcceptRequirementEvent(widget.requirementId)),
          icon: const Icon(Icons.check_circle_outline, color: Colors.white),
          label: const Text('Accept Requirement', style: TextStyle(color: Colors.white, fontSize: 15)),
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

                // Intermediate stops
                ..._stopCtrls.asMap().entries.map((e) {
                  final i = e.key;
                  return Padding(
                    padding: EdgeInsets.only(bottom: 12.h),
                    child: TextFormField(
                      controller: e.value,
                      decoration: InputDecoration(
                        labelText: 'Stop ${i + 1}',
                        prefixIcon: Icon(Icons.add_location_alt_outlined, color: AppColors.primary),
                        suffixIcon: IconButton(
                          icon: Icon(Icons.close, color: AppColors.error, size: 20.sp),
                          tooltip: 'Remove stop',
                          onPressed: () => _removeEditStop(i),
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
                SizedBox(height: 4.h),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _addEditStop,
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
                            initialDate: _travelDate ?? DateTime.now().add(const Duration(days: 1)),
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
                            initialTime: _travelTime ?? TimeOfDay.now(),
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

  Widget _buildBody(Map<String, dynamic> req) {
    final isMine = _isMyRequirement(context);
    final postedBy = req['postedBy'] as Map<String, dynamic>?;
    final acceptors = (req['acceptedBy'] as List? ?? [])
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

        final posterMemberType = postedBy?['membershipType'] as String? ?? 'new';
        String? posterBadgeText;
        Color posterBadgeColor;
        Color posterBadgeBg;
        if (posterMemberType == 'golden' || postedBy?['isGolden'] == true) {
          posterBadgeText = 'GOLDEN USER';
          posterBadgeColor = AppColors.memberGolden;
          posterBadgeBg = AppColors.memberGolden.withOpacity(0.12);
        } else if (posterMemberType == 'premium' || postedBy?['isPremium'] == true) {
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
                title: 'Route',
                child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                        Text(req['pickupCity'] as String? ?? '', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, color: Colors.black)),
                                        if (req['pickupState'] != null)
                                          Text(req['pickupState'] as String, style: TextStyle(fontSize: 12.sp, color: Colors.grey[600])),
                                        SizedBox(height: 16.h),
                                        Text(req['dropCity'] as String? ?? '', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, color: Colors.black)),
                                        if (req['dropState'] != null)
                                          Text(req['dropState'] as String, style: TextStyle(fontSize: 12.sp, color: Colors.grey[600])),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (req['estimatedDistance'] != null)
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text('${req['estimatedDistance']}', style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold, color: Colors.green)),
                                  Text('KM', style: TextStyle(fontSize: 10.sp, color: Colors.grey[600])),
                                ],
                              ),
                          ],
                        ),
                      ),
              ),
              SizedBox(height: 12.h),

              // Trip details card
              _card(
                title: 'Trip Details',
                child: Column(
                  children: [
                    _infoRow(Icons.directions_car, 'Vehicle', _formatVehicleType(req['vehicleType'])),
                    _infoRow(Icons.confirmation_number_outlined, 'Vehicles Needed', '${req['numberOfVehicles'] ?? 1}'),
                    _infoRow(Icons.calendar_today_outlined, 'Travel Date', _formatDate(req['travelDate'])),
                    _infoRow(Icons.access_time, 'Travel Time', req['travelTime'] as String? ?? '-'),
                    _infoRow(_getTripTypeIcon(req['tripType']), 'Trip Type', (req['tripType'] as String? ?? '').replaceAll('_', ' ').toUpperCase()),
                    if (req['notes'] != null && (req['notes'] as String).isNotEmpty) _infoRow(Icons.notes, 'Notes', req['notes'] as String),
                  ],
                ),
              ),
              SizedBox(height: 12.h),

              // Posted By card
              _card(
                title: 'Posted By',
                child: isMine
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 24.r,
                                backgroundColor: AppColors.primary.withOpacity(0.1),
                                backgroundImage: postedBy?['profileImage'] != null ? NetworkImage(postedBy!['profileImage'] as String) : null,
                                child: postedBy?['profileImage'] == null ? Icon(Icons.person, color: AppColors.primary, size: 20.sp) : null,
                              ),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Me', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp, color: AppColors.primary, fontFamily: 'Poppins')),
                                    if (postedBy?['agencyName'] != null)
                                      Text(postedBy!['agencyName'] as String, style: TextStyle(fontSize: 12.sp, color: Colors.grey[600], fontFamily: 'Poppins')),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12.h),
                          Divider(height: 1, thickness: 1, color: Colors.grey[300]),
                          SizedBox(height: 8.h),
                          // User Details - Only show real data that exists
                          if (postedBy?['agencyName'] != null)
                            _userInfoRow(Icons.business, 'Agency', postedBy!['agencyName'] as String),
                          if (postedBy?['mobile'] != null || postedBy?['phone'] != null)
                            _userInfoRow(Icons.phone, 'Phone', postedBy?['mobile'] as String? ?? postedBy?['phone'] as String? ?? ''),
                          if (postedBy?['email'] != null)
                            _userInfoRow(Icons.email, 'Email', postedBy!['email'] as String),
                          if (postedBy?['city'] != null)
                            _userInfoRow(Icons.location_city, 'City', postedBy!['city'] as String),
                          if (postedBy?['state'] != null)
                            _userInfoRow(Icons.map, 'State', postedBy!['state'] as String),
                          SizedBox(height: 8.h),
                          if (postedBy != null) ...[
                            Row(
                              children: [
                                if (postedBy['rating'] != null) ...[
                                  Icon(Icons.star, size: 16.sp, color: Colors.amber),
                                  SizedBox(width: 4.w),
                                  Text('${postedBy['rating']}', style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold, color: Colors.black, fontFamily: 'Poppins')),
                                  SizedBox(width: 8.w),
                                ],
                                if (postedBy['createdAt'] != null) ...[
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 3.h),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      borderRadius: BorderRadius.circular(4.r),
                                    ),
                                    child: Text('Member since ${_getMemberSince(postedBy)}', style: TextStyle(fontSize: 10.sp, color: Colors.grey[600], fontFamily: 'Poppins')),
                                  ),
                                ],
                              ],
                            ),
                          ],
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
                                backgroundImage: postedBy?['profileImage'] != null ? NetworkImage(postedBy!['profileImage'] as String) : null,
                                child: postedBy?['profileImage'] == null ? Icon(Icons.person, color: AppColors.primary, size: 20.sp) : null,
                              ),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(postedBy?['fullName'] as String? ?? postedBy?['name'] as String? ?? 'User', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp, color: Colors.black, fontFamily: 'Poppins')),
                                    if (postedBy?['agencyName'] != null)
                                      Text(postedBy!['agencyName'] as String, style: TextStyle(fontSize: 12.sp, color: Colors.grey[600], fontFamily: 'Poppins')),
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
                                  child: Text(posterBadgeText, style: TextStyle(fontSize: 10.sp, color: posterBadgeColor, fontWeight: FontWeight.w600, fontFamily: 'Poppins')),
                                ),
                            ],
                          ),
                          SizedBox(height: 12.h),
                          Divider(height: 1, thickness: 1, color: Colors.grey[300]),
                          SizedBox(height: 8.h),
                          // User Details
                          if (postedBy?['agencyName'] != null)
                            _userInfoRow(Icons.business, 'Agency', postedBy!['agencyName'] as String),
                          if (postedBy?['mobile'] != null || postedBy?['phone'] != null)
                            _userInfoRow(Icons.phone, 'Phone', postedBy?['mobile'] as String? ?? postedBy?['phone'] as String? ?? ''),
                          if (postedBy?['email'] != null)
                            _userInfoRow(Icons.email, 'Email', postedBy!['email'] as String),
                          if (postedBy?['city'] != null)
                            _userInfoRow(Icons.location_city, 'City', postedBy!['city'] as String),
                          if (postedBy?['state'] != null)
                            _userInfoRow(Icons.map, 'State', postedBy!['state'] as String),

                          // Rating and member info
                          SizedBox(height: 8.h),
                          Row(
                            children: [
                              if (postedBy?['rating'] != null) ...[
                                Icon(Icons.star, size: 16.sp, color: Colors.amber),
                                SizedBox(width: 4.w),
                                Text('${postedBy!['rating']}', style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold, color: Colors.black, fontFamily: 'Poppins')),
                                SizedBox(width: 8.w),
                              ],
                              if (postedBy?['createdAt'] != null) ...[
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 3.h),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(4.r),
                                  ),
                                  child: Text('Member since ${_getMemberSince(postedBy!)}', style: TextStyle(fontSize: 10.sp, color: Colors.grey[600], fontFamily: 'Poppins')),
                                ),
                              ],
                              const Spacer(),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 3.h),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(4.r),
                                ),
                                child: Text('Report', style: TextStyle(fontSize: 10.sp, color: Colors.red, fontWeight: FontWeight.w600, fontFamily: 'Poppins')),
                              ),
                            ],
                          ),
                          SizedBox(height: 12.h),
                          
                          // Contact buttons
                          if (isCurrentUserPremium) ...[
                            if (postedBy?['mobile'] != null || postedBy?['phone'] != null) ...[
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
                                      postedBy?['mobile'] as String? ?? postedBy?['phone'] as String? ?? '',
                                      style: TextStyle(fontSize: 14.sp, color: Colors.blue[800], fontWeight: FontWeight.w600, fontFamily: 'Poppins'),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 8.h),
                            ],
                            if (postedBy?['email'] != null) ...[
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
                                        postedBy!['email'] as String,
                                        style: TextStyle(fontSize: 13.sp, color: Colors.blue[800], fontWeight: FontWeight.w500, fontFamily: 'Poppins'),
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
                                    onPressed: () {},
                                    icon: Icon(Icons.phone, color: Colors.white, size: 16.sp),
                                    label: Text(
                                      postedBy?['mobile'] != null ? 'Call ${postedBy!['mobile']}' : 'Call',
                                      style: TextStyle(fontSize: 13.sp, color: Colors.white, fontFamily: 'Poppins'),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      padding: EdgeInsets.symmetric(vertical: 10.h),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 10.w),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () {},
                                    icon: Icon(Icons.chat, color: Colors.green, size: 16.sp),
                                    label: Text('WhatsApp', style: TextStyle(fontSize: 13.sp, color: Colors.green, fontFamily: 'Poppins')),
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(color: Colors.green, width: 1.5),
                                      padding: EdgeInsets.symmetric(vertical: 10.h),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 12.h),
                          ],
                          
                          if (!isCurrentUserPremium) ...[
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
                                  Icon(Icons.lock_outline, color: Colors.amber[700], size: 16.sp),
                                  SizedBox(width: 8.w),
                                  Expanded(child: Text('Upgrade to Premium to contact directly', style: TextStyle(fontSize: 12.sp, color: Colors.amber[800], fontFamily: 'Poppins'))),
                                ],
                              ),
                            ),
                            SizedBox(height: 8.h),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () => context.push('/subscriptions'),
                                icon: Icon(Icons.star, color: Colors.amber, size: 16.sp),
                                label: Text('Upgrade to Premium', style: TextStyle(fontFamily: 'Poppins')),
                              ),
                            ),
                            SizedBox(height: 8.h),
                          ],
                          
                          // Safety warning
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                            decoration: BoxDecoration(
                              color: Colors.amber[50],
                              borderRadius: BorderRadius.circular(8.r),
                              border: Border.all(color: Colors.amber.shade200, width: 1),
                            ),
                            child: Text(
                              '⚠️ Don\'t pay without reference & proper verification.',
                              style: TextStyle(fontSize: 11.sp, color: Colors.amber[800], fontWeight: FontWeight.w500, fontFamily: 'Poppins'),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
              ),

              // Accepted By section — shown to the poster when requirement is booked
              if (isMine && _requirement?['status'] == 'accepted') ...[
                SizedBox(height: 12.h),
                _card(
                  title: 'Accepted By',
                  child: acceptors.isEmpty
                      ? _detailLoaded
                          ? Row(
                              children: [
                                Icon(Icons.check_circle_outline, color: Colors.green, size: 18.sp),
                                SizedBox(width: 8.w),
                                Expanded(child: Text('Booking confirmed. Acceptor will contact you soon.', style: TextStyle(fontSize: 12.sp, color: AppColors.textSecondary, fontFamily: 'Poppins'))),
                              ],
                            )
                          : Row(
                              children: [
                                SizedBox(width: 16.w, height: 16.w, child: const CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
                                SizedBox(width: 12.w),
                                Expanded(child: Text('Loading acceptor details...', style: TextStyle(fontSize: 13.sp, color: AppColors.textSecondary, fontFamily: 'Poppins'))),
                              ],
                            )
                      : Column(
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
    String? badgeText;
    if (memberType == 'golden' || acceptor['isGolden'] == true) {
      badgeColor = AppColors.memberGolden; badgeText = 'GOLDEN';
    } else if (memberType == 'premium' || acceptor['isPremium'] == true) {
      badgeColor = AppColors.memberPremium; badgeText = 'PREMIUM';
    } else if (memberType == 'active' || memberType == 'verified') {
      badgeColor = AppColors.memberActive; badgeText = 'ACTIVE';
    } else {
      badgeColor = Colors.grey; badgeText = null;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 22.r,
              backgroundColor: AppColors.primary.withOpacity(0.1),
              backgroundImage: acceptor['profileImage'] != null ? NetworkImage(acceptor['profileImage'] as String) : null,
              child: acceptor['profileImage'] == null ? Icon(Icons.person, color: AppColors.primary, size: 18.sp) : null,
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(acceptor['fullName'] as String? ?? 'User', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp, fontFamily: 'Poppins')),
                  if (acceptor['agencyName'] != null)
                    Text(acceptor['agencyName'] as String, style: TextStyle(fontSize: 11.sp, color: Colors.grey[600], fontFamily: 'Poppins')),
                ],
              ),
            ),
            if (badgeText != null)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(4.r),
                  border: Border.all(color: badgeColor),
                ),
                child: Text(badgeText, style: TextStyle(fontSize: 10.sp, color: badgeColor, fontWeight: FontWeight.w700)),
              ),
          ],
        ),
        SizedBox(height: 8.h),
        if (acceptor['mobile'] != null)
          _buildContactRow(Icons.phone, acceptor['mobile'] as String, Colors.blue[700]!),
        if (acceptor['email'] != null)
          _buildContactRow(Icons.email_outlined, acceptor['email'] as String, Colors.blue[700]!),
        if (acceptor['city'] != null)
          _buildContactRow(Icons.location_city, acceptor['city'] as String, Colors.grey[700]!),
      ],
    );
  }

  Widget _buildContactRow(IconData icon, String text, Color color) {
    return Padding(
      padding: EdgeInsets.only(top: 4.h),
      child: Row(
        children: [
          Icon(icon, size: 14.sp, color: color),
          SizedBox(width: 6.w),
          Expanded(child: Text(text, style: TextStyle(fontSize: 13.sp, color: Colors.black87, fontFamily: 'Poppins'))),
        ],
      ),
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

  Widget _userInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        children: [
          Icon(icon, size: 14.sp, color: AppColors.primary),
          SizedBox(width: 8.w),
          Text('$label: ', style: TextStyle(fontSize: 12.sp, color: Colors.grey[600], fontFamily: 'Poppins')),
          Expanded(child: Text(value, style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: Colors.black, fontFamily: 'Poppins'))),
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
    'Found a vehicle already',
    'Trip plan changed',
    'Requirement posted by mistake',
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
                  child: const Text('Back', style: TextStyle(fontFamily: 'Poppins')),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _selected == null ? null : _confirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                  ),
                  child: const Text('Proceed', style: TextStyle(color: Colors.white, fontFamily: 'Poppins')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
