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
///
/// It has to name EVERY use of the data. The first version described only the
/// profile area, and Play rejected the release for it: "The in-app Prominent
/// Disclosure does not disclose the usage of accessed or collected Location
/// data." Trip recording is the bigger use, so it goes first.
Future<bool?> _showLocationDisclosure(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: const Text('Allow location access?'),
      content: const SingleChildScrollView(
        child: Text(
          'Gora Taxi Partner collects location data to:\n\n'
          '1. Record your trip distance. Once you start a trip, the app records the '
          'route you drive and adds up the kilometres. This keeps running in the '
          'BACKGROUND and with the screen off, because you are driving. The total is '
          'what any extra-kilometre charge on the customer\'s bill is calculated '
          'from. Only that running total is sent to Gora — never the route itself '
          'or where you are. A "Trip in progress" notification stays visible the '
          'whole time, and recording stops the moment you end the trip.\n\n'
          '2. Show your approximate last-active area (e.g. "Jaipur 302001, Rajasthan") '
          'to members you connect with, so they can trust who they are dealing with.\n\n'
          '3. Drop a pin on your current position when you are choosing a pickup or '
          'drop point on the map.\n\n'
          'Your exact GPS coordinates are never shown to anyone. You can skip this '
          'and still use the app.',
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Not now')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Allow')),
      ],
    ),
  );
}

/// Show the disclosure, then ask the OS for location. Returns true only when the
/// app may actually use location.
///
/// EVERY path that can raise the system location prompt must come through here.
/// Play does not just check the first screen: the release was rejected over the
/// prompt appearing on the trip screen, where the app asked the OS directly —
/// "Requests for in-app user consent and runtime permission are not immediately
/// preceded by an in-app disclosure."
///
/// [rememberDecline] is for the passive profile ping, which the user never asked
/// for: a "Not now" there is remembered so it stops asking. A screen the user
/// opened themselves (the trip, the map picker) passes false, so tapping the
/// button again asks again.
Future<bool> ensureLocationPermission(BuildContext context, {bool rememberDecline = false}) async {
  var status = await Permission.location.status;
  if (status.isGranted || status.isLimited) return true;

  if (rememberDecline) {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_declinedKey) == true) return false;
  }
  if (!context.mounted) return false;

  final consent = await _showLocationDisclosure(context);
  if (consent != true) {
    if (rememberDecline) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_declinedKey, true);
    }
    return false;
  }

  status = await Permission.location.request();
  return status.isGranted || status.isLimited;
}

/// Best-effort: capture the user's GPS (with a Play-compliant disclosure first),
/// reverse-geocode it ON THE DEVICE, and send it to the backend so their profile
/// shows "Last Login: … <address>". Called a few seconds after the notification
/// permission request so the two dialogs don't collide.
Future<void> pingUserLocation(BuildContext context) async {
  try {
    // Disclosure first, then the OS prompt. Nobody asked for this ping, so a
    // "Not now" is remembered rather than raised again on the next app open.
    if (!await ensureLocationPermission(context, rememberDecline: true)) return;

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
