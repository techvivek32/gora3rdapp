import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../../core/utils/contact_launcher.dart';
import '../../../../core/widgets/app_logo.dart';
import '../../../../core/widgets/marquee_text.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../home/presentation/widgets/ad_popup.dart';
import '../../../home/presentation/widgets/banner_slider_widget.dart';

/// Customer landing — mirrors the driver home's look (brand header, banner
/// slider, caution marquee, and the orange/navy action cards) so the two modes
/// feel like one app. The tiles launch the 4 modular services.
class CustomerHomePage extends StatefulWidget {
  const CustomerHomePage({super.key});

  @override
  State<CustomerHomePage> createState() => _CustomerHomePageState();
}

class _CustomerHomePageState extends State<CustomerHomePage> {
  final _api = getIt<ApiClient>();
  List<Map<String, dynamic>> _banners = [];
  String _supportPhone = '+919587090620';
  String _supportWhatsapp = '+919587090620';

  @override
  void initState() {
    super.initState();
    _loadBanners();
    _fetchSupportContacts();
    // Same admin popup ad as the driver home — once per app launch.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) maybeShowAdPopup(context, _api);
    });
  }

  Future<void> _loadBanners() async {
    try {
      final res = await _api.get('/banners');
      if (!mounted) return;
      setState(() => _banners = List<Map<String, dynamic>>.from(res.data['data'] ?? []));
    } catch (_) {}
  }

  Future<void> _fetchSupportContacts() async {
    try {
      final res = await _api.get('/settings/support-contact');
      final d = (res.data['data'] as Map<String, dynamic>?) ?? {};
      if (!mounted) return;
      setState(() {
        final phone = (d['phone'] ?? '').toString().trim();
        final whatsapp = (d['whatsapp'] ?? '').toString().trim();
        if (phone.isNotEmpty) _supportPhone = phone;
        if (whatsapp.isNotEmpty) _supportWhatsapp = whatsapp;
      });
    } catch (_) {}
  }

  Widget _searchRow(IconData icon, String hint, Color color) => Row(
        children: [
          Icon(icon, size: 18.sp, color: color),
          SizedBox(width: 10.w),
          Text(hint, style: TextStyle(fontSize: 13.5.sp, color: AppColors.textHint, fontFamily: 'Poppins')),
        ],
      );

  static const _services = [
    _Service('cab', 'Cabs Booking', 'One way • round trip • local • airport', Icons.local_taxi_rounded),
    _Service('hire_driver', 'Hire a Driver', 'Hourly • full day • outstation', Icons.badge_rounded),
    _Service('luxury', 'Luxury Car', 'Premium sedans • SUVs • events', Icons.workspace_premium_rounded),
    _Service('car_pool', 'Car Pooling', 'Share a ride on your route', Icons.groups_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthBloc>().state;
    final user = auth is AuthAuthenticated ? auth.user as Map<String, dynamic>? : null;
    final name = (user?['fullName'] ?? '').toString().split(' ').first;

    const navy = Color(0xFF111827);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Brand header — logo + stacked "Gora Taxi / Partner" + help.
            SliverAppBar(
              floating: true,
              snap: true,
              backgroundColor: Colors.white,
              elevation: 0,
              automaticallyImplyLeading: false,
              titleSpacing: 12,
              title: Row(
                children: [
                  AppLogo(size: 34.w, radius: 8.r),
                  SizedBox(width: 10.w),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Gora Taxi',
                          style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700, color: AppColors.textPrimary, height: 1.0, fontFamily: 'Poppins')),
                      Text('Customer',
                          style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: AppColors.primary, height: 1.2, fontFamily: 'Poppins')),
                    ],
                  ),
                ],
              ),
              actions: [
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
                    PopupMenuItem(value: 'whatsapp', child: Row(children: [const FaIcon(FontAwesomeIcons.whatsapp, color: Color(0xFF25D366), size: 18), SizedBox(width: 10.w), Text('WhatsApp', style: TextStyle(fontFamily: 'Poppins', fontSize: 14.sp))])),
                    PopupMenuItem(value: 'chat', child: Row(children: [Icon(Icons.chat_bubble_outline, color: AppColors.primary, size: 18.sp), SizedBox(width: 10.w), Text('Chat', style: TextStyle(fontFamily: 'Poppins', fontSize: 14.sp))])),
                    PopupMenuItem(value: 'help', child: Row(children: [Icon(Icons.call, color: AppColors.primary, size: 18.sp), SizedBox(width: 10.w), Text('Help', style: TextStyle(fontFamily: 'Poppins', fontSize: 14.sp))])),
                  ],
                ),
                SizedBox(width: 8.w),
              ],
            ),

            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Greeting
                  Padding(
                    padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 10.h),
                    child: Text(
                      name.isEmpty ? 'Where would you like to go?' : 'Hi $name, where to?',
                      style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w800, color: AppColors.textPrimary, fontFamily: 'Poppins'),
                    ),
                  ),

                  // Banner slider (same widget the driver home uses)
                  BannerSliderWidget(banners: _banners),

                  // Caution marquee — same brand pattern as the driver home.
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 6.h),
                    child: SizedBox(
                      height: 26.h,
                      child: MarqueeText(
                        text:
                            'सुरक्षित यात्रा करें — भुगतान ड्राइवर को सीधे करें।   Travel safe — pay the driver directly after your trip.',
                        style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700, color: AppColors.error),
                      ),
                    ),
                  ),

                  // Pickup → Drop quick search card (tap opens the cab booking form)
                  Padding(
                    padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 6.h),
                    child: GestureDetector(
                      onTap: () => context.push('/customer/book/cab'),
                      child: Container(
                        padding: EdgeInsets.all(14.w),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16.r),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 3))],
                        ),
                        child: Column(
                          children: [
                            _searchRow(Icons.my_location_rounded, 'Pickup location', AppColors.primary),
                            Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.h),
                              child: Row(children: [
                                SizedBox(width: 4.w),
                                Container(width: 1.5, height: 16.h, color: AppColors.border),
                                const Spacer(),
                              ]),
                            ),
                            _searchRow(Icons.location_on_rounded, 'Drop location', AppColors.error),
                            SizedBox(height: 12.h),
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.symmetric(vertical: 12.h),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                Icon(Icons.search_rounded, color: Colors.white, size: 20.sp),
                                SizedBox(width: 8.w),
                                Text('Search Rides', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14.sp, fontFamily: 'Poppins')),
                              ]),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  Padding(
                    padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 8.h),
                    child: Text('Our Services'.tr, style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontFamily: 'Poppins')),
                  ),

                  // Service cards — the orange/navy glowing-ring style from the
                  // driver's Quick Actions grid.
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    child: GridView.count(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      mainAxisSpacing: 12.w,
                      crossAxisSpacing: 12.w,
                      childAspectRatio: 1.05,
                      children: List.generate(_services.length, (i) {
                        final even = i.isEven;
                        return _ServiceCard(
                          service: _services[i],
                          bgColor: even ? AppColors.primary : navy,
                          textColor: even ? Colors.white : AppColors.primary,
                          onTap: () => context.push('/customer/book/${_services[i].type}'),
                        );
                      }),
                    ),
                  ),
                  SizedBox(height: 20.h),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Service {
  final String type, title, subtitle;
  final IconData icon;
  const _Service(this.type, this.title, this.subtitle, this.icon);
}

class _ServiceCard extends StatelessWidget {
  final _Service service;
  final Color bgColor;
  final Color textColor;
  final VoidCallback onTap;
  const _ServiceCard({required this.service, required this.bgColor, required this.textColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 16.r, horizontal: 12.r),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(18.r),
          boxShadow: [BoxShadow(color: bgColor.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60.r,
              height: 60.r,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: textColor.withValues(alpha: 0.08),
                border: Border.all(color: textColor.withValues(alpha: 0.4), width: 1.5),
                boxShadow: [BoxShadow(color: textColor.withValues(alpha: 0.15), blurRadius: 8, spreadRadius: 1)],
              ),
              child: Icon(service.icon, color: textColor, size: 34.sp),
            ),
            SizedBox(height: 12.h),
            Text(service.title, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, color: textColor, fontFamily: 'Poppins')),
            SizedBox(height: 4.h),
            Text(service.subtitle, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w500, color: textColor.withValues(alpha: 0.85), fontFamily: 'Poppins')),
          ],
        ),
      ),
    );
  }
}
