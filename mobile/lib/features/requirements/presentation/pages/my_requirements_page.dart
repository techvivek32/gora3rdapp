import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/api_error.dart';
import '../../../../core/widgets/otp_input.dart';
import '../bloc/requirements_bloc.dart';
import '../widgets/requirement_card_widget.dart';

class MyRequirementsPage extends StatefulWidget {
  /// Which tab to open on: 0 Running, 1 Booked, 2 Assigned. An assignment push
  /// deep-links straight to Assigned.
  final int initialTab;

  const MyRequirementsPage({super.key, this.initialTab = 0});

  @override
  State<MyRequirementsPage> createState() => _MyRequirementsPageState();
}

class _MyRequirementsPageState extends State<MyRequirementsPage> {
  @override
  void initState() {
    super.initState();
    // Always refetch when deep-linked from a push: the assignment that triggered
    // it won't be in whatever list the bloc is already holding.
    if (widget.initialTab != 0 ||
        context.read<RequirementsBloc>().state is! MyRequirementsLoaded) {
      context.read<RequirementsBloc>().add(const LoadMyRequirementsEvent());
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      initialIndex: widget.initialTab,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(
            'My Bookings'.tr,
            style: TextStyle(fontFamily: 'Poppins', fontSize: 17.sp, fontWeight: FontWeight.bold),
          ),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: Container(
              color: Colors.white,
              child: TabBar(
                indicatorColor: AppColors.primary,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textHint,
                labelStyle: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold),
                tabs: [
                  Tab(text: 'Running'.tr),
                  Tab(text: 'Booked'.tr),
                  Tab(text: 'Assigned'.tr),
                ],
              ),
            ),
          ),
        ),
        body: BlocConsumer<RequirementsBloc, RequirementsState>(
          listener: (context, state) {
            if (state is RequirementCancelled) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Booking cancelled'), backgroundColor: AppColors.success),
              );
              context.read<RequirementsBloc>().add(const LoadMyRequirementsEvent());
            }
            if (state is RequirementUpdated) {
              context.read<RequirementsBloc>().add(const LoadMyRequirementsEvent());
            }
            if (state is DriverAssigned) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Driver assigned & booking confirmed'), backgroundColor: AppColors.success),
              );
            }
            if (state is RequirementsError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.message), backgroundColor: AppColors.error),
              );
            }
          },
          buildWhen: (prev, curr) =>
              curr is RequirementsLoading ||
              curr is MyRequirementsLoaded ||
              curr is RequirementsError,
          builder: (context, state) {
            if (state is RequirementsLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state is RequirementsError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 48.sp, color: AppColors.error),
                    SizedBox(height: 12.h),
                    Text(state.message, style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Poppins', fontSize: 14.sp)),
                    SizedBox(height: 16.h),
                    ElevatedButton(
                      onPressed: () => context.read<RequirementsBloc>().add(const LoadMyRequirementsEvent()),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }

            if (state is MyRequirementsLoaded) {
              // Booked holds everything that's no longer live: booked, cancelled,
              // and completed (the driver finished the trip). Anything else — open,
              // on hold — is still Running. Listing these explicitly rather than
              // "not accepted/cancelled", so a new status can't silently land in
              // Running the way 'completed' did.
              const settled = {'accepted', 'cancelled', 'completed'};
              final running = state.requirements
                  .where((r) => !settled.contains(r['status']))
                  .toList();
              final booked = state.requirements
                  .where((r) => settled.contains(r['status']))
                  .toList();
              return TabBarView(
                children: [
                  _buildList(context, running, 'No running bookings'.tr, showMenu: true),
                  _buildList(context, booked, 'No booked bookings'.tr),
                  // Requirements OTHER people assigned to me — I'm the driver here,
                  // so no owner menu, and no BOOKED stamp obscuring a live job.
                  _buildList(context, state.assignedToMe, 'No bookings assigned to you'.tr, isAssignedTab: true),
                ],
              );
            }

            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    List<Map<String, dynamic>> items,
    String emptyText, {
    bool showMenu = false,
    bool isAssignedTab = false,
  }) {
    return RefreshIndicator(
      onRefresh: () async {
        context.read<RequirementsBloc>().add(const LoadMyRequirementsEvent());
        await Future.delayed(const Duration(milliseconds: 500));
      },
      child: items.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(height: 0.3.sh),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.post_add_outlined, size: 64.sp, color: AppColors.textHint),
                      SizedBox(height: 12.h),
                      Text(emptyText, style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Poppins', fontSize: 15.sp)),
                    ],
                  ),
                ),
              ],
            )
          : ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final req = items[index];
                // Actions menu lives inside the card (Running tab; not for cancelled).
                final menu = (showMenu && req['status'] != 'cancelled') ? _buildMenu(context, req) : null;

                final trip = (req['tripStatus'] ?? 'pending').toString();
                // On the Assigned tab the stamp stays hidden while the job is live,
                // and comes back once the trip is done.
                final showStamp = !isAssignedTab || trip == 'completed';

                return Padding(
                  padding: EdgeInsets.only(bottom: 12.h),
                  child: Column(
                    children: [
                      // Cards are display-only — no navigation to the detail screen.
                      RequirementCardWidget(requirement: req, menu: menu, showStamp: showStamp),
                      if (isAssignedTab && trip != 'completed') ...[
                        SizedBox(height: 8.h),
                        _tripButton(context, req, trip),
                      ],
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildMenu(BuildContext context, Map<String, dynamic> req) {
    final isHeld = req['status'] == 'on_hold';
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
      padding: EdgeInsets.zero,
      tooltip: 'Options',
      constraints: BoxConstraints(minWidth: 160.w),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
      onSelected: (value) => _onMenuAction(context, value, req),
      itemBuilder: (_) => [
        _menuItem('edit', Icons.edit_outlined, 'Edit'),
        _menuItem('assign', Icons.person_add_alt_1_outlined, 'Assign Driver'),
        _menuItem('booked', Icons.check_circle_outline, 'Booked'),
        _menuItem(isHeld ? 'unhold' : 'hold', isHeld ? Icons.play_circle_outline : Icons.pause_circle_outline, isHeld ? 'Unhold' : 'Hold'),
        _menuItem('cancel', Icons.cancel_outlined, 'Cancel', color: AppColors.error),
      ],
    );
  }

  PopupMenuItem<String> _menuItem(String value, IconData icon, String label, {Color? color}) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 20.sp, color: color ?? AppColors.textSecondary),
          SizedBox(width: 10.w),
          Text(label.tr, style: TextStyle(fontFamily: 'Poppins', fontSize: 14.sp, color: color ?? AppColors.textPrimary)),
        ],
      ),
    );
  }

  void _onMenuAction(BuildContext context, String action, Map<String, dynamic> req) {
    final id = req['_id'] as String;
    final bloc = context.read<RequirementsBloc>();
    switch (action) {
      case 'edit':
        context.push('/requirements/$id/edit', extra: req);
        break;
      case 'assign':
        _openAssignSheet(context, req);
        break;
      case 'booked':
        bloc.add(SetRequirementStatusEvent(id: id, status: 'accepted'));
        break;
      case 'hold':
        bloc.add(SetRequirementStatusEvent(id: id, status: 'on_hold'));
        break;
      case 'unhold':
        bloc.add(SetRequirementStatusEvent(id: id, status: 'active'));
        break;
      case 'cancel':
        bloc.add(CancelRequirementEvent(id: id, reason: ''));
        break;
    }
  }

  /// Assigned tab: Start (trip pending) or End (trip started).
  Widget _tripButton(BuildContext context, Map<String, dynamic> req, String trip) {
    final starting = trip == 'pending';
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _runTripFlow(context, req, starting ? 'start' : 'end'),
        icon: Icon(starting ? Icons.play_arrow_rounded : Icons.stop_rounded, size: 20.sp),
        label: Text(
          starting ? 'Start Trip'.tr : 'End Trip'.tr,
          style: TextStyle(fontSize: 15.sp, fontFamily: 'Poppins', fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: starting ? AppColors.success : AppColors.error,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 13.h),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
        ),
      ),
    );
  }

  /// Ask the backend for an OTP (it goes to the *owner*, not to us), then collect
  /// it from the driver — the owner has to read it out, which is the point.
  Future<void> _runTripFlow(BuildContext context, Map<String, dynamic> req, String action) async {
    final id = req['_id'] as String;
    final messenger = ScaffoldMessenger.of(context);
    final bloc = context.read<RequirementsBloc>();

    final sent = await _requestOtp(id, action);
    if (!context.mounted) return;
    if (sent != null) {
      messenger.showSnackBar(SnackBar(content: Text(sent), backgroundColor: AppColors.error));
      return;
    }

    final done = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _TripOtpDialog(
        requirementId: id,
        action: action,
        onResend: () => _requestOtp(id, action),
      ),
    );

    if (done == true) {
      messenger.showSnackBar(SnackBar(
        content: Text(action == 'start' ? 'Trip started' : 'Trip completed'),
        backgroundColor: AppColors.success,
      ));
      bloc.add(const LoadMyRequirementsEvent());
    }
  }

  /// Returns null on success, or the server's message on failure.
  Future<String?> _requestOtp(String id, String action) async {
    try {
      await getIt<ApiClient>().post('/requirements/$id/trip/request-otp', data: {'action': action});
      return null;
    } catch (e) {
      return serverMessage(e, fallback: 'Could not send OTP');
    }
  }

  void _openAssignSheet(BuildContext context, Map<String, dynamic> req) {
    final bloc = context.read<RequirementsBloc>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AssignDriverSheet(
        requirement: req,
        onConfirm: (driverId) => bloc.add(AssignDriverEvent(id: req['_id'] as String, driverId: driverId)),
      ),
    );
  }
}

/// Search a driver by phone number, review them, then confirm the assignment.
/// A StatefulWidget (not an inline builder) so its controller is owned by — and
/// disposed with — the sheet's own element.
class _AssignDriverSheet extends StatefulWidget {
  final Map<String, dynamic> requirement;
  final void Function(String driverId) onConfirm;

  const _AssignDriverSheet({required this.requirement, required this.onConfirm});

  @override
  State<_AssignDriverSheet> createState() => _AssignDriverSheetState();
}

class _AssignDriverSheetState extends State<_AssignDriverSheet> {
  final _phoneCtrl = TextEditingController();
  final _api = getIt<ApiClient>();

  Map<String, dynamic>? _driver;
  bool _searching = false;
  String? _error;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.length < 10) {
      setState(() => _error = 'Enter a valid 10-digit number');
      return;
    }
    setState(() {
      _searching = true;
      _error = null;
      _driver = null;
    });
    try {
      final res = await _api.get('/users/lookup', params: {'mobile': phone});
      final user = res.data['data'] as Map<String, dynamic>?;
      if (!mounted) return;
      setState(() => _driver = user);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'No user found with this number');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _confirm() {
    final id = _driver?['_id']?.toString();
    if (id == null) return;
    widget.onConfirm(id);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final d = _driver;
    final name = (d?['agencyName'] ?? d?['fullName'] ?? '').toString();

    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 20.h + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
          ),
          SizedBox(height: 16.h),
          Text(
            'Assign Driver',
            style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold, fontFamily: 'Poppins', color: AppColors.textPrimary),
          ),
          SizedBox(height: 4.h),
          Text(
            'Booking #${widget.requirement['bookingId'] ?? ''}',
            style: TextStyle(fontSize: 12.sp, color: AppColors.textHint, fontFamily: 'Poppins'),
          ),
          SizedBox(height: 16.h),

          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
            onSubmitted: (_) => _search(),
            decoration: InputDecoration(
              labelText: 'Driver mobile number',
              prefixIcon: const Icon(Icons.phone_outlined),
              errorText: _error,
              suffixIcon: _searching
                  ? Padding(
                      padding: EdgeInsets.all(12.r),
                      child: const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : IconButton(icon: const Icon(Icons.search), onPressed: _search),
            ),
          ),

          if (d != null) ...[
            SizedBox(height: 16.h),
            Container(
              padding: EdgeInsets.all(12.r),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22.r,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                    backgroundImage: (d['profileImage'] ?? '').toString().isNotEmpty
                        ? NetworkImage(d['profileImage'].toString())
                        : null,
                    child: (d['profileImage'] ?? '').toString().isEmpty
                        ? Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 16.sp),
                          )
                        : null,
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold, fontFamily: 'Poppins', color: AppColors.textPrimary),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          '${d['mobile'] ?? ''}${(d['city'] ?? '').toString().isNotEmpty ? ' · ${d['city']}' : ''}',
                          style: TextStyle(fontSize: 12.sp, color: AppColors.textSecondary, fontFamily: 'Poppins'),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.check_circle, color: AppColors.success),
                ],
              ),
            ),
          ],

          SizedBox(height: 20.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: d == null ? null : _confirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.border,
                padding: EdgeInsets.symmetric(vertical: 14.h),
              ),
              child: Text(
                'Confirm & Book',
                style: TextStyle(fontSize: 15.sp, fontFamily: 'Poppins', fontWeight: FontWeight.w600),
              ),
            ),
          ),
          SizedBox(height: 8.h),
          Center(
            child: Text(
              'Assigning a driver marks this booking as booked',
              style: TextStyle(fontSize: 11.sp, color: AppColors.textHint, fontFamily: 'Poppins'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Collects the OTP the requirement owner received and read out to the driver.
/// Pops `true` once the trip has actually been started / ended.
class _TripOtpDialog extends StatefulWidget {
  final String requirementId;
  final String action; // 'start' | 'end'
  /// Re-sends the OTP to the owner. Returns null on success, else the error text.
  final Future<String?> Function() onResend;

  const _TripOtpDialog({
    required this.requirementId,
    required this.action,
    required this.onResend,
  });

  @override
  State<_TripOtpDialog> createState() => _TripOtpDialogState();
}

class _TripOtpDialogState extends State<_TripOtpDialog> {
  static const _cooldown = 30; // seconds before Resend is allowed again

  final _api = getIt<ApiClient>();

  String _code = '';
  bool _busy = false;
  String? _error;
  int _secondsLeft = _cooldown;
  Timer? _timer;

  bool get _isStart => widget.action == 'start';

  @override
  void initState() {
    super.initState();
    _startCountdown(); // the OTP was already sent before this dialog opened
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _secondsLeft = _cooldown);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      if (_secondsLeft <= 1) {
        t.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  Future<void> _verify() async {
    if (_code.length != 6 || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _api.post(
        '/requirements/${widget.requirementId}/trip/verify-otp',
        data: {'action': widget.action, 'otp': _code},
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = serverMessage(e, fallback: 'Could not verify OTP');
        _busy = false;
      });
    }
  }

  Future<void> _resend() async {
    if (_busy || _secondsLeft > 0) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await widget.onResend();
    if (!mounted) return;
    setState(() {
      _error = err;
      _busy = false;
    });
    if (err == null) {
      _startCountdown(); // only restart the clock if a new OTP actually went out
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New OTP sent to the owner')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isStart ? 'Start Trip'.tr : 'End Trip'.tr),
      contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'We sent a 6-digit OTP to the booking owner.\nAsk them for it to ${_isStart ? 'start' : 'end'} this trip.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 18),
            OtpInput(
              onChanged: (v) => setState(() => _code = v),
              onCompleted: (_) => _verify(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.error, fontSize: 12),
              ),
            ],
            const SizedBox(height: 6),
            TextButton(
              onPressed: (_busy || _secondsLeft > 0) ? null : _resend,
              child: Text(
                _secondsLeft > 0 ? 'Resend OTP in ${_secondsLeft}s' : 'Resend OTP',
                style: TextStyle(
                  color: _secondsLeft > 0 ? AppColors.textHint : AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: (_code.length == 6 && !_busy) ? _verify : null,
          child: _busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(_isStart ? 'Start' : 'End'),
        ),
      ],
    );
  }
}
