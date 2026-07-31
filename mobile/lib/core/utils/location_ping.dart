import 'package:geolocator/geolocator.dart';
import '../di/injection.dart';
import '../network/api_client.dart';

/// Best-effort: capture the user's GPS and send it to the backend so their public
/// profile shows an up-to-date "Last Login: … <address>". Fire-and-forget — it
/// never blocks the UI and silently no-ops when location is off or permission is
/// denied.
Future<void> pingUserLocation() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 12),
      ),
    );
    await getIt<ApiClient>().patch(
      '/users/me/location',
      data: {'lat': pos.latitude, 'lng': pos.longitude},
    );
  } catch (_) {
    /* best effort — ignore any permission/timeout/network error */
  }
}
