import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../bloc/home_bloc.dart';
import '../widgets/banner_slider_widget.dart';
import '../widgets/quick_action_grid_widget.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final PageController _pageController = PageController(initialPage: 0);
  final List<Map<String, String>> _closers = [
    {
      'name': 'Thakar Choudhary',
      'phone': '+91 8003092907',
      'email': 'thakarchoudhary51@gmail.com',
      'location': 'Jodhpur, Rajasthan',
      'role': 'Owner in Jodhpur, Rajasthan',
      'initials': 'T',
    },
    {
      'name': 'Rahul Sharma',
      'phone': '+91 9876543210',
      'email': 'rahul.sharma@gmail.com',
      'location': 'Mumbai, Maharashtra',
      'role': 'Partner in Mumbai, Maharashtra',
      'initials': 'R',
    },
    {
      'name': 'Priya Singh',
      'phone': '+91 9123456789',
      'email': 'priya.singh@gmail.com',
      'location': 'Delhi, Delhi',
      'role': 'Driver in Delhi, Delhi',
      'initials': 'P',
    },
  ];
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    context.read<HomeBloc>().add(LoadHomeDataEvent());
    // Auto scroll every 3 seconds
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 3));
      if (mounted) {
        _currentPage = (_currentPage + 1) % _closers.length;
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
      return mounted;
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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
                Container(
                  width: 32.w,
                  height: 32.w,
                  decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(8.r)),
                  child: Icon(Icons.directions_car_rounded, color: Colors.white, size: 18.sp),
                ),
                SizedBox(width: 10.w),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Gora Cabs', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    Text('Taxi Network', style: TextStyle(fontSize: 10.sp, color: AppColors.textSecondary)),
                  ],
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: Stack(
                  children: [
                    Icon(Icons.notifications_outlined, color: AppColors.textPrimary, size: 24.sp),
                    Positioned(
                      right: 0, top: 0,
                      child: Container(
                        width: 8.w, height: 8.w,
                        decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                      ),
                    ),
                  ],
                ),
                onPressed: () => context.push('/notifications'),
              ),
              SizedBox(width: 8.w),
            ],
          ),

          // Content
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Banner Slider
                BlocBuilder<HomeBloc, HomeState>(
                  builder: (context, state) => BannerSliderWidget(
                    banners: state is HomeLoaded ? state.banners : [],
                  ),
                ),
                SizedBox(height: 20.h),

                // Top Closers Section
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 220.h,
                        child: PageView.builder(
                          controller: _pageController,
                          onPageChanged: (index) {
                            setState(() {
                              _currentPage = index;
                            });
                          },
                          itemCount: _closers.length,
                          itemBuilder: (context, index) {
                            final closer = _closers[index];
                            return Container(
                              width: double.infinity,
                              margin: EdgeInsets.only(right: index < _closers.length - 1 ? 8.w : 0),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [AppColors.primary, Color(0xFFFF6B35)],
                                ),
                                borderRadius: BorderRadius.circular(20.r),
                              ),
                              padding: EdgeInsets.all(20.r),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 36.r,
                                        backgroundColor: Colors.white.withOpacity(0.2),
                                        child: Text(
                                          closer['initials']!, 
                                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 28.sp),
                                        ),
                                      ),
                                      SizedBox(width: 16.w),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              closer['name']!, 
                                              style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w700, color: Colors.white, fontFamily: 'Poppins'),
                                            ),
                                            SizedBox(height: 4.h),
                                            Text(
                                              closer['phone']!, 
                                              style: TextStyle(fontSize: 13.sp, color: Colors.white.withOpacity(0.87), fontFamily: 'Poppins'),
                                            ),
                                            SizedBox(height: 4.h),
                                            Text(
                                              closer['email']!, 
                                              style: TextStyle(fontSize: 12.sp, color: Colors.white70, fontFamily: 'Poppins'),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 16.h),
                                  Row(
                                    children: [
                                      Icon(Icons.location_on_outlined, color: Colors.white, size: 16.sp),
                                      SizedBox(width: 4.w),
                                      Text(closer['location']!, style: TextStyle(fontSize: 13.sp, color: Colors.white.withOpacity(0.87), fontFamily: 'Poppins')),
                                    ],
                                  ),
                                  SizedBox(height: 8.h),
                                  Row(
                                    children: [
                                      Icon(Icons.work_outline, color: Colors.white, size: 16.sp),
                                      SizedBox(width: 4.w),
                                      Text(closer['role']!, style: TextStyle(fontSize: 13.sp, color: Colors.white.withOpacity(0.87), fontFamily: 'Poppins')),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      SizedBox(height: 12.h),
                      // Page dots
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _closers.length,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: index == _currentPage ? 24.w : 8.w,
                            height: 8.h,
                            margin: EdgeInsets.symmetric(horizontal: 4.w),
                            decoration: BoxDecoration(
                              color: index == _currentPage ? AppColors.primary : AppColors.border,
                              borderRadius: BorderRadius.circular(4.r),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 24.h),

                      // Quick Actions
                      Text('Quick Actions', style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      SizedBox(height: 12.h),
                      const QuickActionGridWidget(),
                      SizedBox(height: 100.h),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

      // WhatsApp + Helpline bottom buttons
      bottomSheet: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        color: Colors.white,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.chat, color: Color(0xFF25D366), size: 18),
                label: Text('WhatsApp', style: TextStyle(fontSize: 13.sp, color: AppColors.textPrimary)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.border),
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                ),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {},
                icon: Icon(Icons.phone, color: AppColors.primary, size: 18),
                label: Text('Helpline', style: TextStyle(fontSize: 13.sp, color: AppColors.textPrimary)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.border),
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
