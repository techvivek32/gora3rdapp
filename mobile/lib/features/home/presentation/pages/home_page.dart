import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/services/push_notification_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/contact_launcher.dart';
import '../../../../core/widgets/app_logo.dart';
import '../../../../core/widgets/marquee_text.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../requirements/presentation/widgets/requirement_overlay.dart';
import '../bloc/home_bloc.dart';
import '../widgets/alert_filter_sheet.dart';
import '../widgets/banner_slider_widget.dart';
import '../widgets/quick_action_grid_widget.dart';
import '../widgets/user_search_widget.dart';
import '../widgets/card_search_widget.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  // TODO: replace with your real support number.
  static const _supportNumber = '+919587090620';

  bool _alertsOn = false;
  bool _awaitingOverlayGrant = false;
  // Remember the user's last-saved alert picks so reopening the sheet shows them.
  List<String> _alertVehicles = [];
  List<String> _alertTrips = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    context.read<HomeBloc>().add(LoadHomeDataEvent());
    // Reflect the user's saved notification setting (defaults off).
    final auth = context.read<AuthBloc>().state;
    final user = auth is AuthAuthenticated ? auth.user as Map<String, dynamic>? : null;
    _alertsOn = user?['notificationsEnabled'] == true;
    _alertVehicles = ((user?['alertVehicleTypes'] as List?) ?? []).map((e) => e.toString()).toList();
    _alertTrips = ((user?['alertTripTypes'] as List?) ?? []).map((e) => e.toString()).toList();
    // Register this device for push notifications (user is authenticated here).
    PushNotificationService.instance.registerToken();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back from the "Display over other apps" settings page — confirm the grant.
    if (state == AppLifecycleState.resumed && _awaitingOverlayGrant) {
      _awaitingOverlayGrant = false;
      isOverlayPermissionGranted().then((granted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(granted
                ? 'On-screen alerts enabled — requirements will pop over other apps.'
                : 'Permission not granted yet. Turn on "Display over other apps" to see pop-ups.'),
            backgroundColor: granted ? Colors.green : Colors.redAccent,
          ),
        );
      });
    }
  }

  Future<void> _toggleAlerts(bool value) async {
    // Turning OFF — just disable, no filter sheet.
    if (!value) {
      setState(() => _alertsOn = false);
      try {
        await getIt<ApiClient>().put('/users/notifications', data: {'enabled': false});
      } catch (_) {
        if (mounted) setState(() => _alertsOn = true);
      }
      return;
    }

    // Turning ON — pre-select the user's last-saved picks so nothing is lost.
    final filters = await showAlertFilterSheet(context, initialVehicles: _alertVehicles, initialTrips: _alertTrips);
    if (filters == null) return; // dismissed → keep the toggle off

    final savedVehicles = filters['vehicles'] ?? [];
    final savedTrips = filters['trips'] ?? [];
    setState(() {
      _alertsOn = true;
      _alertVehicles = savedVehicles;
      _alertTrips = savedTrips;
    });
    try {
      await getIt<ApiClient>().put('/users/notifications', data: {
        'enabled': true,
        'vehicleTypes': savedVehicles,
        'tripTypes': savedTrips,
      });
      // Keep the cached user in sync so reopening the sheet (even after a rebuild)
      // shows the same picks.
      if (!mounted) return;
      final auth = context.read<AuthBloc>().state;
      if (auth is AuthAuthenticated && auth.user is Map) {
        final u = auth.user as Map<String, dynamic>;
        u['notificationsEnabled'] = true;
        u['alertVehicleTypes'] = savedVehicles;
        u['alertTripTypes'] = savedTrips;
      }
    } catch (_) {
      if (mounted) setState(() => _alertsOn = false);
      return;
    }
    // Then ask for the "Display over other apps" permission so requirement cards can
    // float over other apps while the app runs in the background.
    await _ensureOverlayPermission();
  }

  Future<void> _ensureOverlayPermission() async {
    try {
      if (await isOverlayPermissionGranted()) return;
      if (!mounted) return;
      final go = await showDialog<bool>(
        context: context,
        useRootNavigator: true,
        builder: (dialogCtx) => AlertDialog(
          title: const Text('Show alerts over other apps'),
          content: const Text(
            'To pop new ride requirements on your screen even while you are using other '
            'apps or on the home screen, Gora Cabs needs the "Display over other apps" '
            'permission.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogCtx, false), child: const Text('Not now')),
            ElevatedButton(onPressed: () => Navigator.pop(dialogCtx, true), child: const Text('Open settings')),
          ],
        ),
      );
      if (go == true) {
        _awaitingOverlayGrant = true;
        await requestOverlayPermission();
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // App Bar
          SliverAppBar(
            expandedHeight: 0,
            floating: true,
            snap: true,
            backgroundColor: Colors.white,
            elevation: 0,
            title: Row(
              children: [
                AppLogo(size: 34.w, radius: 8.r),
                SizedBox(width: 10.w),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Gora Taxi', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    Text('Partner', style: TextStyle(fontSize: 10.sp, color: AppColors.textSecondary)),
                  ],
                ),
              ],
            ),
            titleSpacing: 12,
            actions: [
              // Alerts toggle
              Text('Alerts', style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              SizedBox(width: 2.w),
              SizedBox(
                width: 38.w,
                height: 26.h,
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: Switch(
                    value: _alertsOn,
                    activeColor: Colors.white,
                    activeTrackColor: AppColors.primary,
                    onChanged: _toggleAlerts,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
              SizedBox(width: 6.w),
              // Help menu — WhatsApp + Call options in a dropdown.
              PopupMenuButton<String>(
                tooltip: 'Help',
                icon: Icon(Icons.headset_mic, color: AppColors.primary, size: 22.sp),
                position: PopupMenuPosition.under,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                onSelected: (value) {
                  if (value == 'whatsapp') {
                    openWhatsApp(_supportNumber, message: 'Hello, I need help with Gora Cabs');
                  } else if (value == 'help') {
                    callNumber(_supportNumber);
                  } else if (value == 'chat') {
                    context.push('/support-chat');
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'whatsapp',
                    child: Row(
                      children: [
                        const FaIcon(FontAwesomeIcons.whatsapp, color: Color(0xFF25D366), size: 18),
                        SizedBox(width: 10.w),
                        Text('WhatsApp', style: TextStyle(fontFamily: 'Poppins', fontSize: 14.sp)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'chat',
                    child: Row(
                      children: [
                        Icon(Icons.chat_bubble_outline, color: AppColors.primary, size: 18.sp),
                        SizedBox(width: 10.w),
                        Text('Chat', style: TextStyle(fontFamily: 'Poppins', fontSize: 14.sp)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'help',
                    child: Row(
                      children: [
                        Icon(Icons.call, color: AppColors.primary, size: 18.sp),
                        SizedBox(width: 10.w),
                        Text('Help', style: TextStyle(fontFamily: 'Poppins', fontSize: 14.sp)),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(width: 8.w),
            ],
          ),

          // Content
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search a posted requirement / available cab by its display ID
                SizedBox(height: 10.h),
                const CardSearchWidget(),
                SizedBox(height: 6.h),

                // Quick access: My Booking, My Vehicles & My Alert (above the banner)
                Padding(
                  padding: EdgeInsets.fromLTRB(12.w, 4.h, 12.w, 6.h),
                  child: Row(
                    children: [
                      _topTile(Icons.event_note_rounded, 'My Booking', () => context.push('/my-requirements')),
                      SizedBox(width: 10.w),
                      _topTile(Icons.directions_car_rounded, 'My Vehicles', () => context.push('/my-vehicles')),
                      SizedBox(width: 10.w),
                      _topTile(Icons.notifications_active_rounded, 'My Alert', () => _toggleAlerts(true)),
                    ],
                  ),
                ),

                // Banner Slider
                BlocBuilder<HomeBloc, HomeState>(
                  builder: (context, state) => BannerSliderWidget(
                    banners: state is HomeLoaded ? state.banners : [],
                  ),
                ),
                SizedBox(height: 12.h),

                // Scrolling caution line
                SizedBox(
                  height: 28.h,
                  child: MarqueeText(
                    text:
                        'सावधान: बिना रेफरेंस किसी भी अनजान व्यक्ति को एडवांस पेमेंट न करें।   Caution: Do not make advance payments to any unknown person without a trusted reference.',
                    style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700, color: AppColors.error),
                  ),
                ),
                SizedBox(height: 10.h),

                // Search a partner by phone number
                const UserSearchWidget(),
                SizedBox(height: 10.h),

                // Scrolling account-verification reminder
                SizedBox(
                  height: 28.h,
                  child: MarqueeText(
                    text:
                        'बुकिंग लेने या देने से पहले अकाउंट अवश्य वेरिफाई कर लें।   Please verify account before accepting or posting a booking.',
                    style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700, color: AppColors.primary),
                  ),
                ),
                SizedBox(height: 2.h),

                // Quick Actions
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const QuickActionGridWidget(),
                      SizedBox(height: 24.h),
                    ],
                  ),
                ),

                // Brand footer
                _buildBrandFooter(),
                SizedBox(height: 24.h),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _topTile(IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 12.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: AppColors.border),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: AppColors.primary, size: 24.sp),
              SizedBox(height: 6.h),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontFamily: 'Poppins'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBrandFooter() {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Gora Cabs',
            style: TextStyle(
              fontSize: 26.sp,
              fontWeight: FontWeight.w800,
              color: AppColors.textHint.withValues(alpha: 0.5),
            ),
          ),
          SizedBox(height: 8.h),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.favorite, color: Colors.red, size: 14),
              SizedBox(width: 6.w),
              Text('Made in India', style: TextStyle(fontSize: 12.sp, color: AppColors.textSecondary)),
            ],
          ),
          SizedBox(height: 4.h),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.location_on, color: AppColors.primary, size: 14),
              SizedBox(width: 6.w),
              Text('Crafted in Rajasthan', style: TextStyle(fontSize: 12.sp, color: AppColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}
