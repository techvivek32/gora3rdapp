import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/marquee_text.dart';
import '../bloc/home_bloc.dart';
import '../widgets/banner_slider_widget.dart';
import '../widgets/quick_action_grid_widget.dart';
import '../widgets/user_search_widget.dart';

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
  void dispose() {
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
                SizedBox(height: 20.h),

                // Quick Actions
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
