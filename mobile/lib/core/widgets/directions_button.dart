import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/app_theme.dart';
import '../utils/map_launcher.dart';

/// Round navigation-arrow button that opens Google Maps on a booking's route.
///
/// Sits beside the FROM → TO timeline on the booking cards, so a driver can go
/// straight from "where is this job" to turn-by-turn without copying addresses
/// anywhere. Renders nothing when the booking has no usable destination, rather
/// than showing a button that cannot work.
///
/// [color] matches the card's accent so the button reads as part of that card.
class DirectionsButton extends StatelessWidget {
  /// Start of the route — the booking's pickup, NOT the device's location, so
  /// the driver sees the actual job route.
  final String? origin;

  /// End of the route. No button is drawn without one.
  final String? destination;

  /// Intermediate stops, in order.
  final List<String> waypoints;

  final Color color;

  const DirectionsButton({
    super.key,
    required this.destination,
    this.origin,
    this.waypoints = const [],
    this.color = AppColors.primary,
  });

  /// Builds one straight from a booking/requirement map, picking the coordinate
  /// and address fields each shape uses.
  factory DirectionsButton.forBooking(
    Map<String, dynamic> booking, {
    Color color = AppColors.primary,
    String fromCoordsKey = 'pickupCoordinates',
    String toCoordsKey = 'dropCoordinates',
    String fromAddressKey = 'pickupCity',
    String toAddressKey = 'dropCity',
  }) {
    return DirectionsButton(
      origin: mapPoint(booking[fromCoordsKey], (booking[fromAddressKey] ?? '').toString()),
      destination: mapPoint(booking[toCoordsKey], (booking[toAddressKey] ?? '').toString()),
      waypoints: mapWaypoints(booking['stops']),
      color: color,
    );
  }

  Future<void> _open(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await openDirections(
      origin: origin,
      destination: destination!,
      waypoints: waypoints,
    );
    if (ok) return;
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Could not open Maps on this device.'),
        backgroundColor: AppColors.error,
      ),
    );
  }

  /// Wraps the button so it sits at the TOP of a route row (level with FROM)
  /// instead of floating in the vertical middle of the A → B line.
  ///
  /// The parent Row must be inside an [IntrinsicHeight] — a Row in a scrolling
  /// list hands its children an unbounded height, which a full-height Column
  /// cannot resolve on its own.
  Widget topAligned() => Column(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [this],
      );

  @override
  Widget build(BuildContext context) {
    if ((destination ?? '').isEmpty) return const SizedBox.shrink();
    return Tooltip(
      message: 'Navigate',
      child: InkWell(
        onTap: () => _open(context),
        borderRadius: BorderRadius.circular(22.r),
        child: Container(
          width: 28.r,
          height: 28.r,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: 0.45)),
          ),
          // Tilted up-right like the Maps navigation cursor — the upright icon
          // read as a plain play/triangle.
          child: Transform.rotate(
            angle: math.pi / 4,
            child: Icon(Icons.navigation_rounded, size: 15.sp, color: color),
          ),
        ),
      ),
    );
  }
}
