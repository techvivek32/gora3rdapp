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
  @override
  void initState() {
    super.initState();
    context.read<HomeBloc>().add(LoadHomeDataEvent());
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
                      Text('Top Closer', style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      SizedBox(height: 12.h),
                      Container(
                        width: double.infinity,
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
                                  child: Text('T', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 28.sp)),
                                ),
                                SizedBox(width: 16.w),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Thakar Choudhary', style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w700, color: Colors.white, fontFamily: 'Poppins')),
                                      SizedBox(height: 4.h),
                                      Text('+91 8003092907', style: TextStyle(fontSize: 13.sp, color: Colors.white.withOpacity(0.87), fontFamily: 'Poppins')),
                                      SizedBox(height: 4.h),
                                      Text('thakarchoudhary51@gmail.com', style: TextStyle(fontSize: 12.sp, color: Colors.white70, fontFamily: 'Poppins')),
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
                                Text('Jodhpur, Rajasthan', style: TextStyle(fontSize: 13.sp, color: Colors.white.withOpacity(0.87), fontFamily: 'Poppins')),
                              ],
                            ),
                            SizedBox(height: 8.h),
                            Row(
                              children: [
                                Icon(Icons.work_outline, color: Colors.white, size: 16.sp),
                                SizedBox(width: 4.w),
                                Text('Owner in Jodhpur, Rajasthan', style: TextStyle(fontSize: 13.sp, color: Colors.white.withOpacity(0.87), fontFamily: 'Poppins')),
                              ],
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 24.h),

                      // Quick Actions
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
