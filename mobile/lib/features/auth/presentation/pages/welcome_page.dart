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

          // Dark scrim behind the copy — the road underneath is light in places,
          // and white text on it would be unreadable.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.center,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xCC000B1F)],
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
                    // "Welcome to ———"
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Welcome to',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 10.w),
                        _rule(width: 16.w, color: Colors.white70),
                      ],
                    ),
                    SizedBox(height: 4.h),

                    // "——▶  Gora Taxi Partner  ◀——" : arrows point in at the title.
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _arrowRule(pointsRight: true),
                        SizedBox(width: 10.w),
                        // "Gora Taxi" white + "Partner" orange, as in the artwork.
                        Flexible(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                const TextSpan(text: 'Gora Taxi '),
                                TextSpan(
                                  text: 'Partner',
                                  style: TextStyle(color: Colors.orange.shade600),
                                ),
                              ],
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 20.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: 10.w),
                        _arrowRule(pointsRight: false),
                      ],
                    ),
                    SizedBox(height: 20.h),

                    // The ONLY tappable thing on this screen.
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => context.go('/auth/login'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade700,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 16.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14.r),
                          ),
                          elevation: 6,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Get Started',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 18.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: 10.w),
                            Icon(Icons.arrow_forward, size: 20.sp),
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

  /// Decorative line ending in an arrowhead that points at the title.
  Widget _arrowRule({required bool pointsRight}) {
    final head = Icon(
      pointsRight ? Icons.arrow_right_alt : Icons.keyboard_backspace,
      size: 16.sp,
      color: Colors.white70,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: pointsRight
          ? [_rule(width: 20.w, color: Colors.white70), head]
          : [head, _rule(width: 20.w, color: Colors.white70)],
    );
  }
}
