import 'package:url_launcher/url_launcher.dart';

/// Opens Google Maps driving directions for a trip, from [origin] through any
/// [waypoints] to [destination].
///
/// Each point is either `"lat,lng"` or a plain address — Google accepts both,
/// so a stored "Rajkot, Gujarat, India" resolves fine when a booking has no
/// coordinates. Use [mapPoint] to build them.
///
/// Uses the universal `maps/dir/?api=1` URL rather than the
/// `google.navigation:` intent: that intent always starts from the device's
/// current location and cannot carry waypoints, but a card in the feed is
/// showing the BOOKING's route (Rajkot → Jodhpur), stops included. The Maps app
/// opens on that route with its Start button ready.
///
/// Returns false when no maps app could be opened, so the caller can tell the
/// user instead of looking like the tap did nothing.
Future<bool> openDirections({
  required String destination,
  String? origin,
  List<String> waypoints = const [],
}) async {
  final dest = destination.trim();
  if (dest.isEmpty) return false;

  final url = Uri.parse(
    'https://www.google.com/maps/dir/?api=1'
    '&destination=${Uri.encodeComponent(dest)}'
    '${(origin ?? '').trim().isEmpty ? '' : '&origin=${Uri.encodeComponent(origin!.trim())}'}'
    '${waypoints.isEmpty ? '' : '&waypoints=${Uri.encodeComponent(waypoints.join('|'))}'}'
    '&travelmode=driving',
  );

  try {
    return await launchUrl(url, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

/// One point for [openDirections], from whatever shape the API returned.
///
/// [coords] is a `{lat, lng}` map — requirements keep them in
/// `pickupCoordinates` / `dropCoordinates`, customer bookings on the `pickup` /
/// `drop` objects, and stops carry their own. Coordinates win over [address]
/// because a name like "Rajkot" can match more than one place; the address is
/// the fallback for older rows saved without coordinates.
///
/// Returns null when there is nothing usable.
String? mapPoint(dynamic coords, [String? address]) {
  if (coords is Map) {
    final lat = coords['lat'] ?? coords['latitude'];
    final lng = coords['lng'] ?? coords['lon'] ?? coords['longitude'];
    if (lat is num && lng is num && !(lat == 0 && lng == 0)) return '$lat,$lng';
  }
  final text = (address ?? '').trim();
  return text.isEmpty ? null : text;
}

/// The intermediate stops of a booking as map points, skipping any that carry
/// neither coordinates nor an address.
///
/// Google Maps takes at most 9 waypoints on this URL; extra stops are dropped
/// rather than breaking the whole link.
List<String> mapWaypoints(dynamic stops) {
  if (stops is! List) return const [];
  return stops
      .whereType<Map>()
      .map((s) => mapPoint(s, (s['address'] ?? '').toString()))
      .whereType<String>()
      .take(9)
      .toList();
}
