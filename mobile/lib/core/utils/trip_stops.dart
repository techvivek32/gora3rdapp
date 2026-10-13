/// Helpers for the intermediate stops a customer can add to a cab trip
/// ("Add stop" on the booking form).
///
/// Stops travel through the whole flow inside the trip/booking map as
/// `stops: [{address, lat, lng}, …]`. Every screen that shows the route reads
/// them through here so the pickup → stop → drop chain reads the same way
/// everywhere.
library;

/// Short, display-ready labels for each stop, in order.
///
/// Addresses are trimmed to their first part ("Gondal, Gujarat, India" →
/// "Gondal") to match how pickup/drop are shown, and empty entries are dropped.
List<String> stopLabels(dynamic stops, {bool short = true}) {
  if (stops is! List) return const [];
  final out = <String>[];
  for (final s in stops) {
    final a = (s is Map ? (s['address'] ?? '') : '').toString().trim();
    if (a.isEmpty) continue;
    out.add(short ? a.split(',').first.trim() : a);
  }
  return out;
}

/// "Rajkot  →  Gondal  →  Ahmedabad" — the full chain including stops.
/// Blank ends are skipped so a half-filled trip still renders sensibly.
String itineraryLine(String from, dynamic stops, String to, {String sep = '  →  '}) {
  return <String>[from, ...stopLabels(stops), to]
      .where((s) => s.trim().isNotEmpty)
      .join(sep);
}
