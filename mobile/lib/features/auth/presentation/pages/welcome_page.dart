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
                      'Book rides or grow your taxi business',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11.5.sp,
                        fontWeight: FontWeight.w400,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                    SizedBox(height: 22.h),

                    // Single "Get Started" CTA → the role-selection screen, where
                    // the user picks Customer or Driver / Vendor.
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => context.go('/role-select'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade700,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: EdgeInsets.symmetric(vertical: 15.h),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Get Started',
                              style: TextStyle(fontFamily: 'Poppins', fontSize: 15.sp, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(width: 8.w),
                            Icon(Icons.arrow_forward_rounded, size: 19.sp),
                          ],
                        ),
                      ),
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
}
