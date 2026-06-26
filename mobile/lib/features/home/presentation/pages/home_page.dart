import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/contact_launcher.dart';
import '../../../../core/widgets/app_logo.dart';
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
  // TODO: replace with your real support number.
  static const _supportNumber = '+919876543210';

  bool _alertsOn = true;

  @override
  void initState() {
    super.initState();
    context.read<HomeBloc>().add(LoadHomeDataEvent());
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _toggleAlerts(bool value) async {
    setState(() => _alertsOn = value);
    try {
      await getIt<ApiClient>().put('/users/notifications', data: {'enabled': value});
    } catch (_) {
      if (mounted) setState(() => _alertsOn = !value); // revert on failure
    }
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
                AppLogo(size: 34.w, radius: 8.r),
                SizedBox(width: 10.w),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Gora Cabs', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    Text('Taxi Partner', style: TextStyle(fontSize: 10.sp, color: AppColors.textSecondary)),
                  ],
                ),
              ],
            ),
            titleSpacing: 12,
            actions: [
              // Alerts toggle
              Text('Alerts', style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
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
              // WhatsApp
              IconButton(
                onPressed: () => openWhatsApp(_supportNumber, message: 'Hello, I need help with Gora Cabs'),
                icon: const FaIcon(FontAwesomeIcons.whatsapp, color: Color(0xFF25D366)),
                iconSize: 22.sp,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'WhatsApp',
              ),
              SizedBox(width: 8.w),
              // Help
              IconButton(
                onPressed: () => callNumber(_supportNumber),
                icon: Icon(Icons.headset_mic, color: AppColors.primary),
                iconSize: 22.sp,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Help',
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
                      const QuickActionGridWidget(),
                      SizedBox(height: 24.h),
                    ],
                  ),
                ),

                // Brand footer
                _buildBrandFooter(),
                SizedBox(height: 24.h),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandFooter() {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Gora Cabs',
            style: TextStyle(
              fontSize: 26.sp,
              fontWeight: FontWeight.w800,
              color: AppColors.textHint.withValues(alpha: 0.5),
            ),
          ),
          SizedBox(height: 8.h),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.favorite, color: Colors.red, size: 14),
              SizedBox(width: 6.w),
              Text('Made in India', style: TextStyle(fontSize: 12.sp, color: AppColors.textSecondary)),
            ],
          ),
          SizedBox(height: 4.h),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.location_on, color: AppColors.primary, size: 14),
              SizedBox(width: 6.w),
              Text('Crafted in Rajasthan', style: TextStyle(fontSize: 12.sp, color: AppColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}
