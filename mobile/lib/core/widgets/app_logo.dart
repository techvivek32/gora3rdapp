import 'package:flutter/material.dart';

/// The app brand logo, rendered from the bundled image asset.
class AppLogo extends StatelessWidget {
  final double size;
  final double radius;
  const AppLogo({super.key, this.size = 48, this.radius = 12});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.asset(
        'assets/images/Gora_texi.jpeg',
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );
  }
}
