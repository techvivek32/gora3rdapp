import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../../../core/theme/app_theme.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _controller = PageController();
  int _current = 0;

  final _pages = [
    _OnboardingData(
      icon: Icons.directions_car_outlined,
      title: 'Post Vehicle Requirements',
      subtitle: 'Instantly share your cab needs with hundreds of verified operators across India.',
      color: AppColors.primary,
    ),
    _OnboardingData(
      icon: Icons.local_taxi_outlined,
      title: 'List Your Available Cabs',
      subtitle: 'Have empty cabs? Post your available fleet and connect with travel agencies instantly.',
      color: AppColors.info,
    ),
    _OnboardingData(
      icon: Icons.verified_outlined,
      title: 'Verified Network',
      subtitle: 'All users are verified. Premium members get contact access for seamless coordination.',
      color: AppColors.success,
    ),
  ];

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    if (mounted) context.go('/auth/login');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _current == _pages.length - 1;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: EdgeInsets.all(16.r),
                child: TextButton(onPressed: _finish, child: Text('Skip', style: TextStyle(color: AppColors.primary, fontFamily: 'Poppins'))),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (i) => setState(() => _current = i),
                itemCount: _pages.length,
                itemBuilder: (_, i) => _OnboardingSlide(data: _pages[i]),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 32.h),
              child: Column(
                children: [
                  SmoothPageIndicator(
                    controller: _controller,
                    count: _pages.length,
                    effect: WormEffect(
                      dotHeight: 10.h,
                      dotWidth: 10.w,
                      activeDotColor: AppColors.primary,
                      dotColor: AppColors.border,
                    ),
                  ),
                  SizedBox(height: 32.h),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isLast
                          ? _finish
                          : () => _controller.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
                      child: Text(isLast ? 'Get Started' : 'Next', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600, fontFamily: 'Poppins')),
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
}

class _OnboardingData {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  const _OnboardingData({required this.icon, required this.title, required this.subtitle, required this.color});
}

class _OnboardingSlide extends StatelessWidget {
  final _OnboardingData data;
  const _OnboardingSlide({required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 32.w),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 140.w,
            height: 140.h,
            decoration: BoxDecoration(color: data.color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(data.icon, size: 72.sp, color: data.color),
          ),
          SizedBox(height: 40.h),
          Text(data.title, style: TextStyle(fontSize: 24.sp, fontWeight: FontWeight.bold, fontFamily: 'Poppins', color: AppColors.textPrimary), textAlign: TextAlign.center),
          SizedBox(height: 16.h),
          Text(data.subtitle, style: TextStyle(fontSize: 16.sp, color: AppColors.textSecondary, height: 1.6, fontFamily: 'Poppins'), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
