import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    // The welcome artwork (with its baked-in "Get Started" button) is shown fully
    // on every device using BoxFit.contain — no cropping on tablets/foldables.
    // The whole screen is tappable, so the "Get Started" button always works.
    return Scaffold(
      // Background matches the artwork's dark tone so any letterbox blends in.
      backgroundColor: const Color(0xFF0B1B3A),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => context.go('/auth/login'),
        // cover = full-bleed (no side/top bars); bottomCenter keeps the lower part
        // (Welcome text + "Get Started" button) always visible, cropping only the
        // top on very tall/short screens.
        child: const SizedBox.expand(
          child: Image(
            image: AssetImage('assets/images/welcome.png'),
            fit: BoxFit.cover,
            alignment: Alignment.bottomCenter,
          ),
        ),
      ),
    );
  }
}
