import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../di/injection.dart';
import '../network/api_client.dart';

const _declinedKey = 'location_disclosure_declined';

/// Google Play "prominent disclosure": before the OS location prompt we explain,
/// in-app, WHY we need location and HOW it's used. Only after the user taps
/// "Allow" here do we call the system permission request. This is what keeps the
/// AAB compliant (apps that request location with no disclosure get rejected).
Future<bool?> _showLocationDisclosure(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: const Text('Allow location access?'),
      content: const Text(
        'Gora Taxi Partner uses your device location to show your approximate '
        'last-active area (e.g. "Jaipur 302001, Rajasthan") to members you connect '
        'with, so they can trust who they are dealing with.\n\n'
        'Your exact GPS coordinates are never shown to anyone, and only paid members '
        'can see the area. You can skip this and still use the app.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Not now')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Allow')),
      ],
    ),
  );
}

/// Best-effort: capture the user's GPS (with a Play-compliant disclosure first),
/// reverse-geocode it ON THE DEVICE, and send it to the backend so their profile
/// shows "Last Login: … <address>". Called a few seconds after the notification
/// permission request so the two dialogs don't collide.
Future<void> pingUserLocation(BuildContext context) async {
  try {
    var status = await Permission.location.status;

    // First run (permission not yet granted): show the disclosure, then request.
    if (!status.isGranted && !status.isLimited) {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_declinedKey) == true) return; // respect an earlier "Not now"
      if (!context.mounted) return;
      final consent = await _showLocationDisclosure(context);
      if (consent != true) {
        await prefs.setBool(_declinedKey, true); // don't nag again
        return;
      }
      status = await Permission.location.request();
      if (!status.isGranted && !status.isLimited) return;
    }

    // GPS service must be on; send the user to enable it if it's off.
    if (!await Geolocator.isLocationServiceEnabled()) {
      await Geolocator.openLocationSettings();
      return;
    }

    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 15),
      ),
    );

    // Reverse-geocode on the device (works even if the server key has no Geocoding API).
    String? address;
    try {
      final marks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (marks.isNotEmpty) {
        final p = marks.first;
        final area = (p.subLocality?.trim().isNotEmpty ?? false)
            ? p.subLocality!
            : ((p.locality?.trim().isNotEmpty ?? false) ? p.locality! : (p.subAdministrativeArea ?? ''));
        final line1 = [area, p.postalCode ?? ''].where((e) => e.trim().isNotEmpty).join(' ');
        final label = [line1, p.administrativeArea ?? ''].where((e) => e.trim().isNotEmpty).join(', ').trim();
        if (label.isNotEmpty) address = label;
      }
    } catch (_) {
      /* device geocoder unavailable — backend will try its own reverse-geocode */
    }

    await getIt<ApiClient>().patch('/users/me/location', data: {
      'lat': pos.latitude,
      'lng': pos.longitude,
      if (address != null && address.isNotEmpty) 'address': address,
    });
  } catch (_) {
    /* best effort — ignore any permission/timeout/network error */
  }
}
