import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/action_url.dart';
import '../../../../core/utils/contact_launcher.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../data/customer_repository.dart';
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

  // Default hero fallback when a city has no admin-set image yet.
  static const _imgHero =
      'https://images.unsplash.com/photo-1599661046289-e31897846e41?auto=format&fit=crop&w=800&q=70';

  static const _navy = Color(0xFF12213D);

  // Admin-managed dynamic home content (per-city hero + travel/offers/explore).
  Map<String, dynamic>? _home;

  @override
  void initState() {
    super.initState();
    _fetchSupportContacts();
    _loadHome();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) maybeShowAdPopup(context, _api);
    });
  }

  Future<void> _loadHome() async {
    try {
      final auth = context.read<AuthBloc>().state;
      final user = auth is AuthAuthenticated ? auth.user as Map<String, dynamic>? : null;
      final city = (user?['city'] ?? '').toString();
      final d = await getIt<CustomerRepository>().homeContent(city);
      if (mounted) setState(() => _home = d);
    } catch (_) {}
  }

  List<Map<String, dynamic>> _section(String key) {
    final v = _home?[key];
    return v is List ? v.map((e) => Map<String, dynamic>.from(e as Map)).toList() : <Map<String, dynamic>>[];
  }

  void _openItem(Map<String, dynamic> item) {
    final url = (item['actionUrl'] ?? '').toString().trim();
    if (url.isEmpty) {
      _soon((item['title'] ?? 'This').toString());
      return;
    }
    // Internal route → push; external URL → open via the shared action-url helper.
    if (url.startsWith('/')) {
      context.push(url);
    } else {
      openActionUrl(context, url);
    }
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
        content: Text('$feature — coming soon! 🚧', style: const TextStyle(fontFamily: 'Poppins')),
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
                  SizedBox(height: 8.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12.w),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _serviceCard('Cab Booking', 'Book a Cab', 'assets/images/cab-booking.png', AppColors.info, () => context.push('/customer/book/cab'), iconSize: 74)),
                        SizedBox(width: 10.w),
                        Expanded(child: _serviceCard('Car Pooling', 'Share a Ride', 'assets/images/car-pooling.png', AppColors.primary, () => context.push('/car-pool/search'))),
                        SizedBox(width: 10.w),
                        Expanded(child: _serviceCard('Hire a Driver', 'Hourly • Full Day', 'assets/images/hire-a-driver.png', _navy, () => context.push('/customer/book/hire_driver'))),
                      ],
                    ),
                  ),
                  SizedBox(height: 18.h),
                  ..._exploreSection(),
                  ..._travelSection(),
                  ..._offersSection(),
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
      height: 268.h,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Hero image — no rounded corners; it fades into the page below.
          _netImg(
            (_home?['heroImage'] ?? '').toString().isNotEmpty ? _home!['heroImage'].toString() : _imgHero,
            fallback: _navy,
          ),
          // Dark overlay for text readability.
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black.withValues(alpha: 0.45), Colors.black.withValues(alpha: 0.10), Colors.black.withValues(alpha: 0.25)],
              ),
            ),
          ),
          // Bottom fade — only the lower strip blends into the page background,
          // so most of the image stays clearly visible.
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: 55.h,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00F6F7F9), Color(0xFFF6F7F9)],
                  stops: [0.0, 0.9],
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
                  // Top bar: menu · brand · bell
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

  Widget _locationPill(String name) {
    final city = _cityName();
    return GestureDetector(
      onTap: () => _soon('City select'),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 7.h),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20.r), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 6)]),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.location_on, color: AppColors.primary, size: 15.sp),
          SizedBox(width: 4.w),
          Text(city.isEmpty ? 'Set city' : city, style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontFamily: 'Poppins')),
          Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary, size: 18.sp),
        ]),
      ),
    );
  }

  Widget _circleBtn(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36.r,
          height: 36.r,
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), shape: BoxShape.circle, border: Border.all(color: Colors.white24)),
          child: Icon(icon, color: Colors.white, size: 20.sp),
        ),
      );

  // ─── Service cards (colored card + brand image as the icon) ──────────────────
  Widget _serviceCard(String title, String subtitle, String asset, Color color, VoidCallback onTap, {double iconSize = 60}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 168.h,
        padding: EdgeInsets.symmetric(vertical: 12.h),
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [color, Color.lerp(color, Colors.black, 0.22)!]),
          borderRadius: BorderRadius.circular(18.r),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 6))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Brand illustration as the icon (no white background, no round clip).
            Image.asset(asset, width: iconSize.r, height: iconSize.r, fit: BoxFit.contain, errorBuilder: (_, __, ___) => Icon(Icons.directions_car_rounded, color: Colors.white, size: 30.sp)),
            Column(
              children: [
                Text(title, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.2, fontFamily: 'Poppins')),
                SizedBox(height: 2.h),
                Text(subtitle, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 8.5.sp, fontWeight: FontWeight.w500, color: Colors.white.withValues(alpha: 0.9), fontFamily: 'Poppins')),
              ],
            ),
            // ">" button.
            Container(
              width: 26.r,
              height: 26.r,
              decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4)]),
              child: Icon(Icons.chevron_right_rounded, color: color, size: 20.sp),
            ),
          ],
        ),
      ),
    );
  }

  String _cityName() {
    final auth = context.read<AuthBloc>().state;
    final user = auth is AuthAuthenticated ? auth.user as Map<String, dynamic>? : null;
    final c = (user?['city'] ?? '').toString().trim();
    return c.isEmpty ? '' : (c[0].toUpperCase() + c.substring(1));
  }

  // ─── Explore <city> — admin-managed category chips ───────────────────────────
  List<Widget> _exploreSection() {
    final items = _section('explore');
    if (items.isEmpty) return [];
    final city = _cityName();
    return [
      _sectionHeader(city.isEmpty ? 'Explore' : 'Explore $city'),
      SizedBox(height: 10.h),
      SizedBox(
        height: 88.h,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: 14.w),
          itemCount: items.length,
          separatorBuilder: (_, __) => SizedBox(width: 12.w),
          itemBuilder: (_, i) {
            final it = items[i];
            return GestureDetector(
              onTap: () => _openItem(it),
              child: SizedBox(
                width: 72.w,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64.r,
                      height: 64.r,
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.primary.withValues(alpha: 0.4), width: 2)),
                      child: ClipOval(child: _netImg((it['imageUrl'] ?? '').toString(), fit: BoxFit.cover, fallback: AppColors.primary.withValues(alpha: 0.3))),
                    ),
                    SizedBox(height: 6.h),
                    Text((it['category'] ?? it['title'] ?? '').toString(), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: TextStyle(fontSize: 10.5.sp, fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontFamily: 'Poppins')),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      SizedBox(height: 12.h),
    ];
  }

  // ─── Travel Made Better — admin-managed cards ────────────────────────────────
  List<Widget> _travelSection() {
    final items = _section('travel');
    if (items.isEmpty) return [];
    return [
      _sectionHeader('Travel Made Better'),
      SizedBox(height: 10.h),
      SizedBox(
        height: 120.h,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: 14.w),
          itemCount: items.length,
          separatorBuilder: (_, __) => SizedBox(width: 10.w),
          itemBuilder: (_, i) => _showcaseCard(items[i], width: 150.w),
        ),
      ),
      SizedBox(height: 12.h),
    ];
  }

  // ─── Special Offers — admin-managed cards ────────────────────────────────────
  List<Widget> _offersSection() {
    final items = _section('offers');
    if (items.isEmpty) return [];
    return [
      _sectionHeader('Special Offers'),
      SizedBox(height: 10.h),
      SizedBox(
        height: 130.h,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: 14.w),
          itemCount: items.length,
          separatorBuilder: (_, __) => SizedBox(width: 10.w),
          itemBuilder: (_, i) => _showcaseCard(items[i], width: 240.w, showTag: true),
        ),
      ),
      SizedBox(height: 12.h),
    ];
  }

  // Shared image card for travel + offers showcase items.
  Widget _showcaseCard(Map<String, dynamic> it, {required double width, bool showTag = false}) {
    final title = (it['title'] ?? '').toString();
    final subtitle = (it['subtitle'] ?? '').toString();
    final category = (it['category'] ?? '').toString();
    return GestureDetector(
      onTap: () => _openItem(it),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14.r),
        child: SizedBox(
          width: width,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _netImg((it['imageUrl'] ?? '').toString(), fallback: _navy),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black.withValues(alpha: 0.72), Colors.black.withValues(alpha: 0.12)]),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(10.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showTag)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                        decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(6.r)),
                        child: Text(category.isEmpty ? 'OFFER' : category.toUpperCase(), style: TextStyle(fontSize: 8.5.sp, fontWeight: FontWeight.w800, color: Colors.white, fontFamily: 'Poppins')),
                      )
                    else if (category.isNotEmpty)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(6.r)),
                        child: Text(category, style: TextStyle(fontSize: 8.5.sp, fontWeight: FontWeight.w700, color: AppColors.primaryDark, fontFamily: 'Poppins')),
                      ),
                    const Spacer(),
                    Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w800, color: Colors.white, height: 1.1, fontFamily: 'Poppins')),
                    if (subtitle.isNotEmpty) ...[
                      SizedBox(height: 2.h),
                      Row(children: [
                        Flexible(child: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w500, color: Colors.white.withValues(alpha: 0.9), fontFamily: 'Poppins'))),
                        SizedBox(width: 4.w),
                        Icon(Icons.chevron_right_rounded, color: Colors.white, size: 16.sp),
                      ]),
                    ],
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
  Widget _sectionHeader(String title) => Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        child: Text(title, style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w800, color: AppColors.textPrimary, fontFamily: 'Poppins')),
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
