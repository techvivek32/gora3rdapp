import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart';
import '../di/injection.dart';
import '../network/api_client.dart';

/// Best-effort: ask for location permission, make sure GPS is on, capture the
/// user's position, reverse-geocode it ON THE DEVICE (no Google key needed), and
/// send it to the backend so their profile shows "Last Login: … <address>".
///
/// Called a few seconds AFTER the notification permission request so the two
/// dialogs don't collide (Android drops a second permission request while the
/// first is still open — that's why the location prompt used to never show).
Future<void> pingUserLocation() async {
  try {
    // 1) Permission (reliable dialog via permission_handler).
    var status = await Permission.location.status;
    if (status.isDenied || status.isRestricted) {
      status = await Permission.location.request();
    }
    if (!status.isGranted && !status.isLimited) return; // user declined

    // 2) GPS service must be ON. If the user allowed location but GPS is off,
    //    send them to enable it; we'll capture on the next app open.
    if (!await Geolocator.isLocationServiceEnabled()) {
      await Geolocator.openLocationSettings();
      return;
    }

    // 3) Current position.
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 15),
      ),
    );

    // 4) Reverse-geocode on the device (works even if the server's Google key has
    //    no Geocoding API). Produces e.g. "Sardarpura 342003, Rajasthan".
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

    // 5) Send to the backend.
    await getIt<ApiClient>().patch('/users/me/location', data: {
      'lat': pos.latitude,
      'lng': pos.longitude,
      if (address != null && address.isNotEmpty) 'address': address,
    });
  } catch (_) {
    /* best effort — ignore any permission/timeout/network error */
  }
}
