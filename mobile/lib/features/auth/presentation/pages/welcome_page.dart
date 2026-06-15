import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _colorAnimation = ColorTween(
      begin: Colors.white,
      end: AppColors.primary,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    _animationController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Image
          SizedBox.expand(
            child: Image.asset(
              'assets/images/123456123.png',
              fit: BoxFit.cover,
            ),
          ),
          // Gradient Overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.8),
                ],
              ),
            ),
          ),
          // Content
          SafeArea(
            child: Column(
              children: [
                const Spacer(),
                
                // Welcome Text
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 40.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome to',
                        style: TextStyle(
                          fontSize: 24.sp,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      AnimatedBuilder(
                        animation: _colorAnimation,
                        builder: (context, child) {
                          return Text(
                            'Gora Cabs',
                            style: TextStyle(
                              fontSize: 40.sp,
                              fontWeight: FontWeight.w800,
                              color: _colorAnimation.value,
                              fontFamily: 'Poppins',
                            ),
                          );
                        },
                      ),
                      SizedBox(height: 16.h),
                      Text(
                        'Find and connect with reliable taxi partners for your travel needs',
                        style: TextStyle(
                          fontSize: 16.sp,
                          color: Colors.white70,
                          fontFamily: 'Poppins',
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                
                SizedBox(height: 40.h),
                
                // Continue Button
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 40.w),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => context.go('/auth/login'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 16.h),
                      ),
                      child: Text(
                        'Continue to Login',
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ),
                  ),
                ),
                
                SizedBox(height: 40.h),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
