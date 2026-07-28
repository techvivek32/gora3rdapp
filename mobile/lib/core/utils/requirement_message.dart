/// Builds the pre-filled WhatsApp message for the requirement popups (the in-app
/// Alert and the floating Overlay), from the flat FCM push payload. It mirrors the
/// requirement card's share message, using the fields the push actually carries
/// (requirementId/bookingId, trip, vehicle, route + stops, date/time, poster).
String buildRequirementWhatsAppMessage(Map<String, dynamic> data) {
  String s(String k) => (data[k] ?? '').toString().trim();

  String cap(String v) => v.isEmpty
      ? v
      : v
          .replaceAll('_', ' ')
          .split(' ')
          .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
          .join(' ');

  const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  // ISO date → "4 Jul 2026".
  String dateLabel() {
    final raw = s('travelDate');
    if (raw.isEmpty) return '';
    final d = raw.contains('T') ? raw.split('T').first : raw;
    final p = d.split('-');
    if (p.length != 3) return raw;
    final m = int.tryParse(p[1]) ?? 0;
    final day = int.tryParse(p[2]) ?? p[2];
    final mon = (m >= 1 && m <= 12) ? months[m] : '';
    return '$day $mon ${p[0]}'.trim();
  }

  // "14:24" → "02:24 pm".
  String timeLabel() {
    final tp = s('travelTime').split(':');
    if (tp.length < 2) return '';
    final h = int.tryParse(tp[0]) ?? 0;
    final mm = tp[1].padLeft(2, '0');
    final ampm = h >= 12 ? 'pm' : 'am';
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '${h12.toString().padLeft(2, '0')}:$mm $ampm';
  }

  final stops = s('stops').split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

  final b = StringBuffer();
  b.writeln('📢 *Booking*');
  b.writeln('*Gora Taxi Partner App*');
  b.writeln();

  final id = s('bookingId').isNotEmpty ? s('bookingId') : s('requirementId');
  if (id.isNotEmpty) b.writeln('🆔 *ID:* $id');
  if (s('tripType').isNotEmpty) b.writeln('🚖 *Trip:* ${cap(s('tripType'))}');
  if (s('vehicleType').isNotEmpty) b.writeln('🚗 *Vehicle:* ${cap(s('vehicleType'))}');
  b.writeln();

  b.writeln('*📍Location point*');
  b.writeln(' *From:* ${s('pickupCity')}');
  for (var i = 0; i < stops.length; i++) {
    b.writeln(' *Stop ${i + 1}:* ${stops[i]}');
  }
  b.writeln(' *To:* ${s('dropCity')}');
  b.writeln();

  final dl = dateLabel();
  final tl = timeLabel();
  if (dl.isNotEmpty) b.writeln('📅 *Date:* $dl');
  if (tl.isNotEmpty) b.writeln('🕒 *Time:* $tl');
  if (dl.isNotEmpty || tl.isNotEmpty) b.writeln();

  final poster = s('posterName');
  final phone = s('posterMobile');
  if (poster.isNotEmpty || phone.isNotEmpty) {
    b.writeln('📞 *Posted By*');
    if (poster.isNotEmpty) b.writeln('👤 *$poster*');
    if (phone.isNotEmpty) b.writeln('📱 *$phone*');
    b.writeln();
  }

  b.writeln('You can also book your taxi from Gora Taxi Partner App and register your vehicle from the below link');
  b.write('https://play.google.com/store/apps/details?id=com.taxi.call_taxi_partner');
  return b.toString();
}
