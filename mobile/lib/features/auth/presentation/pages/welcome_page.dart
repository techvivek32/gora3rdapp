import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    // The artwork is background only — the welcome text, the Get Started button
    // and the trust line below are real widgets, so ONLY the button is tappable.
    return Scaffold(
      // Matches the artwork's dark tone so any letterbox blends in.
      backgroundColor: const Color(0xFF0B1B3A),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Image(
            image: AssetImage('assets/images/welcome.png'),
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),

          // Dark scrim behind the copy — the artwork underneath is busy (man, cars),
          // so we fade to near-solid navy at the bottom to keep the buttons legible.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.35, 0.62, 1.0],
                colors: [Colors.transparent, Color(0x99040C1C), Color(0xF7040C1C)],
              ),
            ),
          ),

          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.fromLTRB(24.w, 0, 24.w, 24.h),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Clean heading — the big logo at the top already carries the
                    // brand, so here we keep one short welcome line + a prompt.
                    Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(text: 'Welcome to '),
                          const TextSpan(text: 'Gora Taxi '),
                          TextSpan(
                            text: 'Partner',
                            style: TextStyle(color: Colors.orange.shade600),
                          ),
                        ],
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 17.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      'Choose how you’d like to continue',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11.5.sp,
                        fontWeight: FontWeight.w400,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                    SizedBox(height: 20.h),

                    // Direct role selection — pick Customer or Driver/Vendor here.
                    _roleButton(
                      context,
                      icon: Icons.person_pin_circle_rounded,
                      title: 'Customer',
                      subtitle: 'Book a cab, hire a driver or car pool',
                      filled: true,
                      onTap: () => context.go('/customer/login'),
                    ),
                    SizedBox(height: 12.h),
                    _roleButton(
                      context,
                      icon: Icons.local_taxi_rounded,
                      title: 'Driver / Vendor',
                      subtitle: 'Post duties, get bookings & leads',
                      filled: false,
                      onTap: () => context.go('/auth/login'),
                    ),
                    SizedBox(height: 16.h),

                    // "——  🛡 Trusted by Taxi Drivers & Travel Agents  ——"
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _rule(width: 20.w, color: const Color(0xFF1E5BC6)),
                        SizedBox(width: 8.w),
                        Icon(Icons.verified_user, size: 15.sp, color: Colors.lightBlueAccent),
                        SizedBox(width: 6.w),
                        Flexible(
                          child: Text(
                            'Trusted by Taxi Drivers & Travel Agents',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 10.sp,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        _rule(width: 20.w, color: const Color(0xFF1E5BC6)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Plain decorative line.
  Widget _rule({required double width, required Color color}) {
    return Container(width: width, height: 1.5.h, color: color);
  }

  /// Role selection button. `filled` → solid orange (primary / Customer);
  /// otherwise a frosted translucent card with an orange icon badge (Driver).
  Widget _roleButton(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool filled,
    required VoidCallback onTap,
  }) {
    final orange = Colors.orange.shade700;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.r),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 13.h),
          decoration: BoxDecoration(
            color: filled ? orange : Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16.r),
            border: filled ? null : Border.all(color: Colors.white.withValues(alpha: 0.35)),
            boxShadow: filled
                ? [BoxShadow(color: orange.withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 8))]
                : null,
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(9.r),
                decoration: BoxDecoration(
                  color: filled ? Colors.white.withValues(alpha: 0.22) : orange,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 22.sp),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 15.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 10.sp,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_rounded, color: Colors.white.withValues(alpha: 0.9), size: 18.sp),
            ],
          ),
        ),
      ),
    );
  }
}
