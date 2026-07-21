import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../../../core/config/env.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/services/push_notification_service.dart';
import '../../../../core/localization/app_translations.dart';
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

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  String _supportPhone = '+919587090620';
  String _supportWhatsapp = '+919587090620';

  bool _alertsOn = false;
  bool _awaitingOverlayGrant = false;
  List<String> _alertVehicles = [];
  List<String> _alertTrips = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    context.read<HomeBloc>().add(LoadHomeDataEvent());
    _fetchSupportContacts();
    final auth = context.read<AuthBloc>().state;
    final user = auth is AuthAuthenticated ? auth.user as Map<String, dynamic>? : null;
    _alertsOn = user?['notificationsEnabled'] == true;
    _alertVehicles = ((user?['alertVehicleTypes'] as List?) ?? []).map((e) => e.toString()).toList();
    _alertTrips = ((user?['alertTripTypes'] as List?) ?? []).map((e) => e.toString()).toList();
    PushNotificationService.instance.registerToken();
  }

  Future<void> _fetchSupportContacts() async {
    try {
      final res = await Dio().get('${Env.apiBaseUrl}/settings');
      final body = res.data as Map<String, dynamic>?;
      final s = (body?['data'] as Map<String, dynamic>?) ?? body;
      if (s != null && mounted) {
        setState(() {
          if ((s['supportPhone'] as String?)?.isNotEmpty == true) _supportPhone = s['supportPhone'];
          if ((s['supportWhatsapp'] as String?)?.isNotEmpty == true) _supportWhatsapp = s['supportWhatsapp'];
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
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
    if (!value) {
      setState(() => _alertsOn = false);
      try {
        await getIt<ApiClient>().put('/users/notifications', data: {'enabled': false});
      } catch (_) {
        if (mounted) setState(() => _alertsOn = true);
      }
      return;
    }

    final filters = await showAlertFilterSheet(context, initialVehicles: _alertVehicles, initialTrips: _alertTrips);
    if (filters == null) return;

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

  Widget _buildBrandTitle() {
    final goraStyle = TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700, color: AppColors.textPrimary, height: 1.0);
    final partnerStyle = TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600, color: AppColors.textPrimary, height: 1.0);
    final gw = _textWidth('Gora Taxi', goraStyle);
    final pw = _textWidth('Partner', partnerStyle);
    final sx = pw > 0 ? gw / pw : 1.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Gora Taxi', style: goraStyle),
        Transform.scale(
          scaleX: sx,
          alignment: Alignment.centerLeft,
          child: Text('Partner', style: partnerStyle),
        ),
      ],
    );
  }

  double _textWidth(String text, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    return tp.width;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        physics: const NeverScrollableScrollPhysics(),
        slivers: [
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
                _buildBrandTitle(),
              ],
            ),
            titleSpacing: 12,
            actions: [
              Text('Alerts'.tr, style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
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
              PopupMenuButton<String>(
                tooltip: 'Help',
                icon: Icon(Icons.headset_mic, color: AppColors.primary, size: 22.sp),
                position: PopupMenuPosition.under,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                onSelected: (value) {
                  if (value == 'whatsapp') {
                    openWhatsApp(_supportWhatsapp, message: 'Hello, I need help with Gora Cabs');
                  } else if (value == 'help') {
                    callNumber(_supportPhone);
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

          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BlocBuilder<HomeBloc, HomeState>(
                  builder: (context, state) => BannerSliderWidget(
                    banners: state is HomeLoaded ? state.banners : [],
                  ),
                ),

                // Fixed-height row so the marquee's footprint is deterministic — the
                // Row inside MarqueeText centres the text, so the tall Devanagari line
                // box can't leave a big empty gap below the text (the bug on phones).
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 4.h),
                  child: SizedBox(
                    height: 26.h,
                    child: MarqueeText(
                      text:
                          'सावधान: बिना रेफरेंस किसी भी अनजान व्यक्ति को एडवांस पेमेंट न करें।   Caution: Do not make advance payments to any unknown person without a trusted reference.',
                      style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700, color: AppColors.error),
                    ),
                  ),
                ),

                Padding(
                  padding: EdgeInsets.symmetric(vertical: 6.h),
                  child: const UserSearchWidget(),
                ),

                Padding(
                  padding: EdgeInsets.only(top: 4.h),
                  child: SizedBox(
                    height: 26.h,
                    child: MarqueeText(
                      text:
                          'बुकिंग लेने या देने से पहले अकाउंट अवश्य वेरिफाई कर लें।   Please verify account before accepting or posting a booking.',
                      style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700, color: AppColors.error),
                    ),
                  ),
                ),

                const QuickActionGridWidget(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
