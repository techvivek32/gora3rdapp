import 'dart:async';
import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_logo.dart';
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
  final _explorePage = PageController();
  final _travelCtrl = ScrollController();
  final _offersCtrl = ScrollController();
  int _exploreIndex = 0;
  // Shuffled once on load so the first item shown is random each time, then the
  // carousels auto-advance on a timer.
  List<Map<String, dynamic>> _exploreItems = [];
  List<Map<String, dynamic>> _travelItems = [];
  List<Map<String, dynamic>> _offersItems = [];
  Timer? _autoTimer;

  @override
  void dispose() {
    _autoTimer?.cancel();
    _explorePage.dispose();
    _travelCtrl.dispose();
    _offersCtrl.dispose();
    super.dispose();
  }

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
      if (!mounted) return;
      List<Map<String, dynamic>> pick(String key) {
        final v = d[key];
        final list = v is List ? v.map((e) => Map<String, dynamic>.from(e as Map)).toList() : <Map<String, dynamic>>[];
        list.shuffle(Random()); // random first item each load
        return list;
      }
      setState(() {
        _home = d;
        _exploreItems = pick('explore');
        _travelItems = pick('travel');
        _offersItems = pick('offers');
        _exploreIndex = 0;
      });
      _startAuto();
    } catch (_) {}
  }

  // Auto-advance all three carousels on a timer so the page feels alive.
  void _startAuto() {
    _autoTimer?.cancel();
    if (_exploreItems.length <= 1 && _travelItems.length <= 1 && _offersItems.length <= 1) return;
    _autoTimer = Timer.periodic(const Duration(seconds: 4), (_) => _autoAdvance());
  }

  void _autoAdvance() {
    if (!mounted) return;
    // Explore (full-width PageView) → next page, looping.
    if (_explorePage.hasClients && _exploreItems.length > 1) {
      final next = (_exploreIndex + 1) % _exploreItems.length;
      _explorePage.animateToPage(next, duration: const Duration(milliseconds: 550), curve: Curves.easeInOut);
    }
    // Horizontal lists → scroll forward by one card, snapping back to start at the end.
    _advanceList(_travelCtrl, (150 + 10).w, _travelItems.length);
    _advanceList(_offersCtrl, (240 + 10).w, _offersItems.length);
  }

  void _advanceList(ScrollController c, double step, int count) {
    if (!c.hasClients || count <= 1) return;
    final max = c.position.maxScrollExtent;
    if (max <= 0) return; // content fits — nothing to scroll
    // Already at (or near) the end → loop back to the start. Otherwise advance by
    // one card, but never past the end. (When a short list's step is larger than
    // the whole scroll extent we scroll straight to the end, then loop.)
    final atEnd = c.offset >= max - 2;
    final double next = atEnd ? 0 : (c.offset + step).clamp(0, max).toDouble();
    c.animateTo(
      next,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
    );
  }

  void _openItem(Map<String, dynamic> item) {
    final url = (item['actionUrl'] ?? '').toString().trim();
    // No link → not clickable (do nothing). Only redirect when a link is set.
    if (url.isEmpty) return;
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
                  _serviceGrid(),
                  SizedBox(height: 14.h),
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
      height: 296.h,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Hero image — no rounded corners; it fades into the page below.
          _netImg(
            (_home?['heroImage'] ?? '').toString().isNotEmpty ? _home!['heroImage'].toString() : _imgHero,
            fallback: _navy,
          ),
          // Dark overlay for text readability — darker at top (brand) and bottom
          // (tagline) so both read cleanly while the middle image stays visible.
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black.withValues(alpha: 0.50), Colors.black.withValues(alpha: 0.06), Colors.black.withValues(alpha: 0.62)],
                stops: const [0.0, 0.4, 1.0],
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
                  // Top bar: logo + brand (left) · bell (right).
                  // Tap the logo for the support menu (My Rides / WhatsApp / Call).
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _openMenu,
                        child: const AppLogo(size: 42, radius: 11),
                      ),
                      SizedBox(width: 10.w),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('GORA TAXI',
                              style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1, fontFamily: 'Poppins', shadows: const [Shadow(color: Colors.black45, blurRadius: 6)])),
                          SizedBox(height: 2.h),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(width: 12.w, height: 1.2.h, color: AppColors.primary),
                              SizedBox(width: 5.w),
                              Text('India Ka Apna App',
                                  style: TextStyle(fontSize: 9.sp, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.5, fontFamily: 'Poppins')),
                              SizedBox(width: 5.w),
                              Container(width: 12.w, height: 1.2.h, color: AppColors.primary),
                            ],
                          ),
                        ],
                      ),
                      const Spacer(),
                      _circleBtn(Icons.notifications_none_rounded, () => context.push('/notifications')),
                    ],
                  ),
                  const Spacer(),
                  // Tagline and the city pill on one line, bottom-aligned so
                  // "Gora Ke Saath" lines up with the Rajkot pill.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(child: _tagline()),
                      SizedBox(width: 10.w),
                      Padding(
                        padding: EdgeInsets.only(bottom: 4.h),
                        child: _locationPill(name),
                      ),
                    ],
                  ),
                  SizedBox(height: 26.h),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Bold two-line tagline with an orange "Gora" and a hand-drawn swoosh under it.
  Widget _tagline() {
    final base = TextStyle(
      fontSize: 30.sp,
      fontWeight: FontWeight.w900,
      height: 1.06,
      color: Colors.white,
      fontFamily: 'Poppins',
      shadows: const [Shadow(color: Colors.black87, blurRadius: 12, offset: Offset(0, 2))],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Har Safar,', style: base),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.bottomLeft,
              children: [
                Text('Gora', style: base.copyWith(color: AppColors.primary)),
                Positioned(
                  bottom: -7.h,
                  left: 0,
                  right: -2.w,
                  child: CustomPaint(size: Size(60.w, 9.h), painter: _SwooshPainter()),
                ),
              ],
            ),
            Text(' Ke Saath', style: base),
          ],
        ),
      ],
    );
  }

  Widget _locationPill(String name) {
    final city = _cityName();
    // Display-only — the city comes from the user's profile, so no tap action.
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 7.h),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20.r), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 6)]),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.location_on, color: AppColors.primary, size: 15.sp),
        SizedBox(width: 4.w),
        Text(city.isEmpty ? 'Set city' : city, style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontFamily: 'Poppins')),
      ]),
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

  // ─── Services: a clean light-card grid (big Cab tile + two stacked tiles) ────
  Widget _serviceGrid() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      child: SizedBox(
        height: 172.h,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Big primary tile — Cab Booking.
            Expanded(
              child: _lightCard(
                title: 'Cab Booking',
                subtitle: 'One Way · Round · Local',
                asset: 'assets/images/cab-booking.png',
                bg: const Color(0xFFEAF1FF),
                onTap: () => context.push('/customer/book/cab'),
                big: true,
              ),
            ),
            SizedBox(width: 8.w),
            // Right column — Car Pool + Book a Driver.
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: _lightCard(
                      title: 'Car Pool',
                      subtitle: 'Share & save',
                      asset: 'assets/images/car-pooling.png',
                      bg: const Color(0xFFFFF1E6),
                      onTap: () => context.push('/car-pool/search'),
                      horizontal: true,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Expanded(
                    child: _lightCard(
                      title: 'Book a Driver',
                      subtitle: 'Hourly · Full day',
                      asset: 'assets/images/hire-a-driver.png',
                      bg: const Color(0xFFF1ECFF),
                      onTap: () => context.push('/customer/book/hire_driver'),
                      horizontal: true,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Clean, light service tile: soft-tinted background, bold dark title, grey
  // subtitle and a colourful illustration tucked into the bottom-right corner.
  Widget _lightCard({
    required String title,
    required String subtitle,
    required String asset,
    required Color bg,
    required VoidCallback onTap,
    bool big = false,
    bool horizontal = false,
  }) {
    final decoration = BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(20.r),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 6))],
    );

    // Horizontal variant: text on the left, illustration on the right.
    if (horizontal) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: decoration,
          child: Row(
            children: [
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w800, color: _navy, height: 1.1, fontFamily: 'Poppins')),
                    SizedBox(height: 2.h),
                    Text(subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 9.sp, fontWeight: FontWeight.w500, color: Colors.black.withValues(alpha: 0.45), fontFamily: 'Poppins')),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.only(right: 10.w, left: 6.w),
                child: Image.asset(
                  asset,
                  width: 56.r,
                  height: 52.r,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: decoration,
        child: Stack(
          children: [
            // Illustration in the bottom-right corner.
            Positioned(
              right: big ? 10.w : -2.w,
              bottom: big ? 6.h : -2.h,
              child: Image.asset(
                asset,
                width: big ? 128.r : 56.r,
                height: big ? 128.r : 56.r,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(big ? 14.w : 10.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: big ? 18.sp : 12.5.sp, fontWeight: FontWeight.w800, color: _navy, height: 1.1, fontFamily: 'Poppins')),
                  SizedBox(height: 3.h),
                  Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: big ? 11.sp : 8.5.sp, fontWeight: FontWeight.w500, color: Colors.black.withValues(alpha: 0.45), fontFamily: 'Poppins')),
                ],
              ),
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

  // ─── Explore — admin-managed clickable banner carousel (per city) ────────────
  List<Widget> _exploreSection() {
    final items = _exploreItems;
    if (items.isEmpty) return [];
    if (_exploreIndex >= items.length) _exploreIndex = 0;
    return [
      SizedBox(
        height: 132.h,
        child: PageView.builder(
          controller: _explorePage,
          itemCount: items.length,
          onPageChanged: (i) => setState(() => _exploreIndex = i),
          itemBuilder: (_, i) {
            final it = items[i];
            final title = (it['title'] ?? '').toString();
            final subtitle = (it['subtitle'] ?? '').toString();
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: 14.w),
              child: GestureDetector(
                onTap: () => _openItem(it),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18.r),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _netImg((it['imageUrl'] ?? '').toString(), fallback: _navy),
                      if (title.isNotEmpty || subtitle.isNotEmpty)
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight, colors: [Colors.black.withValues(alpha: 0.55), Colors.black.withValues(alpha: 0.05)]),
                          ),
                        ),
                      if (title.isNotEmpty || subtitle.isNotEmpty)
                        Padding(
                          padding: EdgeInsets.all(16.w),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (title.isNotEmpty)
                                Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w900, color: Colors.white, height: 1.1, fontFamily: 'Poppins', shadows: const [Shadow(color: Colors.black54, blurRadius: 6)])),
                              if (subtitle.isNotEmpty) ...[
                                SizedBox(height: 4.h),
                                Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.95), fontFamily: 'Poppins')),
                              ],
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
      if (items.length > 1) ...[
        SizedBox(height: 8.h),
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(items.length, (i) {
              final active = i == _exploreIndex;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: EdgeInsets.symmetric(horizontal: 3.w),
                width: active ? 18.w : 7.w,
                height: 7.h,
                decoration: BoxDecoration(color: active ? AppColors.primary : AppColors.border, borderRadius: BorderRadius.circular(4.r)),
              );
            }),
          ),
        ),
      ],
      SizedBox(height: 16.h),
    ];
  }

  // ─── Travel Made Better — admin-managed cards ────────────────────────────────
  List<Widget> _travelSection() {
    final items = _travelItems;
    if (items.isEmpty) return [];
    return [
      _sectionHeader('Travel Made Better'),
      SizedBox(height: 10.h),
      SizedBox(
        height: 120.h,
        child: ListView.separated(
          controller: _travelCtrl,
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
    final items = _offersItems;
    if (items.isEmpty) return [];
    return [
      _sectionHeader('Special Offers'),
      SizedBox(height: 10.h),
      SizedBox(
        height: 130.h,
        child: ListView.separated(
          controller: _offersCtrl,
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w800, color: AppColors.textPrimary, fontFamily: 'Poppins')),
            SizedBox(height: 4.h),
            // Orange accent underline.
            Container(
              width: 32.w,
              height: 3.h,
              decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(2)),
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

/// Hand-drawn upward "swoosh" underline (orange) drawn under the word "Gora".
class _SwooshPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(0, size.height * 0.7)
      ..quadraticBezierTo(size.width * 0.45, size.height * 1.5, size.width, size.height * 0.15);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
