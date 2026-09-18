import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/contact_launcher.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../home/presentation/widgets/ad_popup.dart';

/// Customer landing — a rich Rajasthan travel-app home: a fort hero header,
/// three service cards (Taxi / Pool / Luxury), an Explore Rajasthan banner, and
/// "Travel Made Better" + "Special Offers" showcases. Only the three top service
/// cards are wired to real booking flows; the showcase sections are visual and
/// show a "coming soon" note on tap.
class CustomerHomePage extends StatefulWidget {
  const CustomerHomePage({super.key});

  @override
  State<CustomerHomePage> createState() => _CustomerHomePageState();
}

class _CustomerHomePageState extends State<CustomerHomePage> {
  final _api = getIt<ApiClient>();
  String _supportPhone = '+919587090620';
  String _supportWhatsapp = '+919587090620';

  // ─── Stock imagery (curated Unsplash placeholders; swap for brand assets later) ──
  static const _q = '?auto=format&fit=crop&w=800&q=70';
  static const _imgHero = 'https://images.unsplash.com/photo-1599661046289-e31897846e41$_q';       // Hawa Mahal, Jaipur
  static const _imgExplore = 'https://images.unsplash.com/photo-1477587458883-47145ed94245$_q';    // Jaisalmer / desert road
  static const _imgHotel = 'https://images.unsplash.com/photo-1566073771259-6a8506099945$_q';      // hotel room
  static const _imgRestaurant = 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4$_q'; // restaurant
  static const _imgBusiness = 'https://images.unsplash.com/photo-1497366216548-37526070297c$_q';   // office
  static const _imgOffer1 = 'https://images.unsplash.com/photo-1524492412937-b28074a5d7da$_q';     // Taj / palace
  static const _imgOffer2 = 'https://images.unsplash.com/photo-1509316785289-025f5b846b35$_q';     // desert camel

  static const _navy = Color(0xFF12213D);

  @override
  void initState() {
    super.initState();
    _fetchSupportContacts();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) maybeShowAdPopup(context, _api);
    });
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

  void _soon(String feature) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('$feature — aavi rahyu che! 🚧', style: const TextStyle(fontFamily: 'Poppins')),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthBloc>().state;
    final user = auth is AuthAuthenticated ? auth.user as Map<String, dynamic>? : null;
    final name = (user?['fullName'] ?? '').toString().split(' ').first;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _hero(name),
            // Service cards overlap the hero's rounded base.
            Transform.translate(
              offset: Offset(0, -30.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _searchCard(),
                  SizedBox(height: 16.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14.w),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(child: _serviceCard('Cab Booking', 'One way • airport', Icons.local_taxi_rounded, AppColors.info, () => context.push('/customer/book/cab'))),
                            SizedBox(width: 10.w),
                            Expanded(child: _serviceCard('Hire a Driver', 'Hourly • full day', Icons.airline_seat_recline_normal_rounded, _navy, () => context.push('/customer/book/hire_driver'))),
                          ],
                        ),
                        SizedBox(height: 10.h),
                        Row(
                          children: [
                            Expanded(child: _serviceCard('Car Pooling', 'Share a ride', Icons.groups_rounded, AppColors.primary, () => context.push('/car-pool/search'))),
                            SizedBox(width: 10.w),
                            Expanded(child: _serviceCard('Luxury Car', 'Premium • events', Icons.workspace_premium_rounded, const Color(0xFF7C3AED), () => context.push('/customer/book/luxury'))),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16.h),
                  _exploreBanner(),
                  SizedBox(height: 20.h),
                  _sectionHeader('Travel Made Better', () => _soon('Travel')),
                  SizedBox(height: 10.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14.w),
                    child: Row(
                      children: [
                        Expanded(child: _travelCard('Hotels', Icons.hotel_rounded, AppColors.info, _imgHotel)),
                        SizedBox(width: 10.w),
                        Expanded(child: _travelCard('Restaurants', Icons.restaurant_rounded, AppColors.primary, _imgRestaurant)),
                        SizedBox(width: 10.w),
                        Expanded(child: _travelCard('Business', Icons.business_center_rounded, const Color(0xFF7C3AED), _imgBusiness)),
                      ],
                    ),
                  ),
                  SizedBox(height: 20.h),
                  _sectionHeader('Rajasthan Special Offers', () => _soon('Offers')),
                  SizedBox(height: 10.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14.w),
                    child: Row(
                      children: [
                        Expanded(child: _offerCard('Rajasthan Travel Offers', 'Save More on Your Trips', AppColors.primary, _imgOffer1)),
                        SizedBox(width: 10.w),
                        Expanded(child: _offerCard('Weekend Getaways', 'Explore More', AppColors.info, _imgOffer2)),
                      ],
                    ),
                  ),
                  SizedBox(height: 24.h),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Hero header ────────────────────────────────────────────────────────────
  Widget _hero(String name) {
    return SizedBox(
      height: 250.h,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(28.r)),
            child: _netImg(_imgHero, fallback: _navy),
          ),
          ClipRRect(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(28.r)),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withValues(alpha: 0.45), Colors.black.withValues(alpha: 0.10), Colors.black.withValues(alpha: 0.30)],
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(14.w, 8.h, 14.w, 14.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top bar: menu · brand · bell + avatar
                  Row(
                    children: [
                      _circleBtn(Icons.menu_rounded, _openMenu),
                      const Spacer(),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('GORA TAXI',
                              style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1, fontFamily: 'Poppins', shadows: const [Shadow(color: Colors.black45, blurRadius: 6)])),
                          Text('Rajasthan Ka Apna App',
                              style: TextStyle(fontSize: 9.sp, fontWeight: FontWeight.w600, color: AppColors.primaryLight, fontFamily: 'Poppins')),
                        ],
                      ),
                      const Spacer(),
                      _circleBtn(Icons.notifications_none_rounded, () => context.push('/notifications')),
                      SizedBox(width: 8.w),
                      GestureDetector(
                        onTap: () => context.go('/customer/profile'),
                        child: CircleAvatar(radius: 18.r, backgroundColor: Colors.white, child: Icon(Icons.person, color: AppColors.primary, size: 22.sp)),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text('Har Safar',
                      style: TextStyle(fontSize: 26.sp, fontWeight: FontWeight.w800, color: Colors.white, fontStyle: FontStyle.italic, height: 1.05, fontFamily: 'Poppins', shadows: const [Shadow(color: Colors.black54, blurRadius: 8)])),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Gora Ke Saath',
                          style: TextStyle(fontSize: 26.sp, fontWeight: FontWeight.w800, color: Colors.white, fontStyle: FontStyle.italic, height: 1.05, fontFamily: 'Poppins', shadows: const [Shadow(color: Colors.black54, blurRadius: 8)])),
                      const Spacer(),
                      _locationPill(name),
                    ],
                  ),
                  SizedBox(height: 22.h),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _locationPill(String name) => GestureDetector(
        onTap: () => _soon('City select'),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 7.h),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20.r), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 6)]),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.location_on, color: AppColors.primary, size: 15.sp),
            SizedBox(width: 4.w),
            Text('Jodhpur', style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontFamily: 'Poppins')),
            Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary, size: 18.sp),
          ]),
        ),
      );

  Widget _circleBtn(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36.r,
          height: 36.r,
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), shape: BoxShape.circle, border: Border.all(color: Colors.white24)),
          child: Icon(icon, color: Colors.white, size: 20.sp),
        ),
      );

  // ─── Top search card (pickup / drop / date-time / passengers) ────────────────
  Widget _searchCard() => Padding(
        padding: EdgeInsets.symmetric(horizontal: 14.w),
        child: GestureDetector(
          onTap: () => context.push('/customer/book/cab'),
          child: Container(
            padding: EdgeInsets.all(14.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18.r),
              border: Border.all(color: AppColors.border),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Column(
              children: [
                _searchRow(Icons.my_location_rounded, 'Pickup location', AppColors.primary),
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                  child: Row(children: [SizedBox(width: 4.w), Container(width: 1.5, height: 16.h, color: AppColors.border), const Spacer()]),
                ),
                _searchRow(Icons.location_on_rounded, 'Drop location', AppColors.error),
                SizedBox(height: 12.h),
                Row(
                  children: [
                    Expanded(child: _searchMini(Icons.calendar_today_rounded, 'Date & Time')),
                    SizedBox(width: 10.w),
                    Expanded(child: _searchMini(Icons.people_rounded, 'Passengers')),
                  ],
                ),
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
                    Text('Search Cabs', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14.sp, fontFamily: 'Poppins')),
                  ]),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _searchRow(IconData icon, String hint, Color color) => Row(
        children: [
          Icon(icon, size: 18.sp, color: color),
          SizedBox(width: 10.w),
          Text(hint, style: TextStyle(fontSize: 13.5.sp, color: AppColors.textHint, fontFamily: 'Poppins')),
        ],
      );

  Widget _searchMini(IconData icon, String label) => Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
        decoration: BoxDecoration(color: const Color(0xFFF6F7F9), borderRadius: BorderRadius.circular(10.r), border: Border.all(color: AppColors.border)),
        child: Row(children: [
          Icon(icon, size: 15.sp, color: AppColors.primary),
          SizedBox(width: 6.w),
          Text(label, style: TextStyle(fontSize: 11.5.sp, color: AppColors.textSecondary, fontFamily: 'Poppins')),
        ]),
      );

  // ─── Service cards (clean icon tiles) ────────────────────────────────────────
  Widget _serviceCard(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 158.h,
        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 14.h),
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [color, Color.lerp(color, Colors.black, 0.18)!]),
          borderRadius: BorderRadius.circular(20.r),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 6))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 52.r,
              height: 52.r,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5)),
              child: Container(
                margin: EdgeInsets.all(5.r),
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 24.sp),
              ),
            ),
            Column(
              children: [
                Text(title, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w800, color: Colors.white, fontFamily: 'Poppins')),
                SizedBox(height: 2.h),
                Text(subtitle, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 8.5.sp, fontWeight: FontWeight.w500, color: Colors.white.withValues(alpha: 0.85), fontFamily: 'Poppins')),
              ],
            ),
            Container(
              width: 28.r,
              height: 28.r,
              decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4)]),
              child: Icon(Icons.chevron_right_rounded, color: color, size: 20.sp),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Explore Rajasthan banner ────────────────────────────────────────────────
  Widget _exploreBanner() {
    const items = [
      ('Forts', Icons.castle_rounded),
      ('Temples', Icons.temple_hindu_rounded),
      ('Culture', Icons.diversity_3_rounded),
      ('Hill Stations', Icons.landscape_rounded),
    ];
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 14.w),
      child: GestureDetector(
        onTap: () => _soon('Explore Rajasthan'),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18.r),
          child: Stack(
            children: [
              _netImg(_imgExplore, height: 150.h, width: double.infinity, fallback: _navy),
              Container(
                height: 150.h,
                decoration: BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight, colors: [Colors.black.withValues(alpha: 0.62), Colors.black.withValues(alpha: 0.15)]),
                ),
              ),
              SizedBox(
                height: 150.h,
                child: Padding(
                  padding: EdgeInsets.all(14.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Explore', style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600, color: Colors.white, fontStyle: FontStyle.italic, fontFamily: 'Poppins')),
                      Text('RAJASTHAN', style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.5, fontFamily: 'Poppins')),
                      const Spacer(),
                      Row(
                        children: items
                            .map((e) => Expanded(
                                  child: Column(
                                    children: [
                                      Icon(e.$2, color: Colors.white, size: 20.sp),
                                      SizedBox(height: 3.h),
                                      Text(e.$1, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 9.sp, fontWeight: FontWeight.w600, color: Colors.white, fontFamily: 'Poppins')),
                                    ],
                                  ),
                                ))
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Travel Made Better cards ────────────────────────────────────────────────
  Widget _travelCard(String label, IconData icon, Color color, String img) {
    return GestureDetector(
      onTap: () => _soon(label),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14.r),
        child: SizedBox(
          height: 96.h,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _netImg(img, fallback: color),
              Container(color: Colors.black.withValues(alpha: 0.28)),
              Padding(
                padding: EdgeInsets.all(8.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 30.r,
                      height: 30.r,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                      child: Icon(icon, color: Colors.white, size: 17.sp),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w700, color: Colors.white, fontFamily: 'Poppins'))),
                        Icon(Icons.chevron_right_rounded, color: Colors.white, size: 18.sp),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Special Offers cards ────────────────────────────────────────────────────
  Widget _offerCard(String title, String subtitle, Color tag, String img) {
    return GestureDetector(
      onTap: () => _soon('Offers'),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14.r),
        child: SizedBox(
          height: 120.h,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _netImg(img, fallback: tag),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.bottomLeft, end: Alignment.topRight, colors: [Colors.black.withValues(alpha: 0.7), Colors.black.withValues(alpha: 0.2)]),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(10.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: EdgeInsets.all(6.r),
                      decoration: BoxDecoration(color: tag, borderRadius: BorderRadius.circular(8.r)),
                      child: Icon(Icons.local_offer_rounded, color: Colors.white, size: 14.sp),
                    ),
                    const Spacer(),
                    Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5.sp, fontWeight: FontWeight.w800, color: Colors.white, height: 1.1, fontFamily: 'Poppins')),
                    SizedBox(height: 2.h),
                    Row(
                      children: [
                        Flexible(child: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 9.5.sp, fontWeight: FontWeight.w500, color: Colors.white.withValues(alpha: 0.9), fontFamily: 'Poppins'))),
                        SizedBox(width: 4.w),
                        Icon(Icons.chevron_right_rounded, color: Colors.white, size: 16.sp),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Shared bits ─────────────────────────────────────────────────────────────
  Widget _sectionHeader(String title, VoidCallback onViewAll) => Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w800, color: AppColors.textPrimary, fontFamily: 'Poppins')),
            GestureDetector(
              onTap: onViewAll,
              child: Row(children: [
                Text('View All', style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: AppColors.info, fontFamily: 'Poppins')),
                Icon(Icons.chevron_right_rounded, color: AppColors.info, size: 18.sp),
              ]),
            ),
          ],
        ),
      );

  Widget _netImg(String url, {double? height, double? width, BoxFit fit = BoxFit.cover, Color fallback = AppColors.border}) => CachedNetworkImage(
        imageUrl: url,
        height: height,
        width: width,
        fit: fit,
        placeholder: (_, __) => Container(height: height, width: width, color: fallback.withValues(alpha: 0.4)),
        errorWidget: (_, __, ___) => Container(height: height, width: width, color: fallback),
      );

  void _openMenu() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24.r))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 12.h),
            Container(width: 40.w, height: 4.h, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
            SizedBox(height: 8.h),
            ListTile(leading: const Icon(Icons.receipt_long_rounded, color: AppColors.primary), title: const Text('My Rides', style: TextStyle(fontFamily: 'Poppins')), onTap: () { Navigator.pop(ctx); context.go('/customer/bookings'); }),
            ListTile(leading: const FaIcon(FontAwesomeIcons.whatsapp, color: Color(0xFF25D366)), title: const Text('WhatsApp Support', style: TextStyle(fontFamily: 'Poppins')), onTap: () { Navigator.pop(ctx); openWhatsApp(_supportWhatsapp, message: 'Hello, I need help with Gora Cabs'); }),
            ListTile(leading: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.info), title: const Text('Chat Support', style: TextStyle(fontFamily: 'Poppins')), onTap: () { Navigator.pop(ctx); context.push('/support-chat'); }),
            ListTile(leading: const Icon(Icons.call_rounded, color: AppColors.success), title: const Text('Call Us', style: TextStyle(fontFamily: 'Poppins')), onTap: () { Navigator.pop(ctx); callNumber(_supportPhone); }),
            ListTile(leading: const Icon(Icons.settings_rounded, color: AppColors.textSecondary), title: const Text('Settings', style: TextStyle(fontFamily: 'Poppins')), onTap: () { Navigator.pop(ctx); context.go('/customer/profile'); }),
            SizedBox(height: 8.h),
          ],
        ),
      ),
    );
  }
}
