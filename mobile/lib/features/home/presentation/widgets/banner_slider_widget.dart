import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/banner_popup.dart';

class BannerSliderWidget extends StatefulWidget {
  final List<Map<String, dynamic>> banners;
  const BannerSliderWidget({super.key, required this.banners});

  @override
  State<BannerSliderWidget> createState() => _BannerSliderWidgetState();
}

class _BannerSliderWidgetState extends State<BannerSliderWidget> {
  final _controller = PageController();
  int _current = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _randomStart();
    _startAutoScroll();
  }

  // Start on a random banner instead of always the first one.
  void _randomStart() {
    if (widget.banners.length <= 1) {
      _current = 0;
      return;
    }
    _current = Random().nextInt(widget.banners.length);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _controller.hasClients) _controller.jumpToPage(_current);
    });
  }

  void _startAutoScroll() {
    _timer?.cancel();
    if (widget.banners.length <= 1) return;
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      _current = (_current + 1) % widget.banners.length;
      _controller.animateToPage(
        _current,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void didUpdateWidget(BannerSliderWidget old) {
    super.didUpdateWidget(old);
    if (old.banners.length != widget.banners.length) {
      _randomStart();
      _startAutoScroll();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.banners.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        SizedBox(
          height: 175.h,
          child: PageView.builder(
            controller: _controller,
            onPageChanged: (i) => setState(() => _current = i),
            itemCount: widget.banners.length,
            itemBuilder: (_, i) => _BannerItem(banner: widget.banners[i]),
          ),
        ),
        if (widget.banners.length > 1) ...[
          SizedBox(height: 10.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.banners.length, (i) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: i == _current ? 24.w : 8.w,
                height: 8.h,
                margin: EdgeInsets.symmetric(horizontal: 4.w),
                decoration: BoxDecoration(
                  color: i == _current ? AppColors.primary : Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(4.r),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}

class _BannerItem extends StatelessWidget {
  final Map<String, dynamic> banner;
  const _BannerItem({required this.banner});

  @override
  Widget build(BuildContext context) {
    final imageUrl = banner['imageUrl'] as String?;
    final title = banner['title'] as String?;
    final subtitle = banner['subtitle'] as String?;

    return GestureDetector(
      onTap: () => showBannerPopup(context, banner),
      child: Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.r),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background: image or gradient
            if (imageUrl != null && imageUrl.isNotEmpty)
              Image.network(
                imageUrl,
                fit: BoxFit.cover,
                loadingBuilder: (_, child, progress) =>
                    progress == null ? child : Container(color: Colors.orange.shade100),
                errorBuilder: (_, __, ___) => _gradientBg(),
              )
            else
              _gradientBg(),

            // Dark gradient only when there's text to keep readable — an image-only
            // banner shows the artwork with no fade over it.
            if ((title != null && title.isNotEmpty) || (subtitle != null && subtitle.isNotEmpty))
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.fromLTRB(14.w, 24.h, 14.w, 14.h),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Colors.black.withValues(alpha: 0.65), Colors.transparent],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (title != null && title.isNotEmpty)
                        Text(title,
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14.sp,
                                fontFamily: 'Poppins')),
                      if (subtitle != null && subtitle.isNotEmpty)
                        Text(subtitle,
                            style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11.sp,
                                fontFamily: 'Poppins')),
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

  Widget _gradientBg() => const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primary, Color(0xFFFF6B35)],
          ),
        ),
      );
}
