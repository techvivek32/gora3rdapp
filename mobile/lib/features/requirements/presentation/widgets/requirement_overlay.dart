import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/utils/membership.dart';
import '../../../../core/utils/requirement_message.dart';
import '../../../../core/utils/ring_player.dart';

/// Native channel (registered in MainActivity) that opens the "Display over
/// other apps" settings robustly across OEMs — the plugin's default intent opens
/// a blank/black page on MIUI/HyperOS, so we route through native fallbacks.
const _overlayPermChannel = MethodChannel('gora/overlay');

/// Whether the "Display over other apps" permission is granted (Android only).
Future<bool> isOverlayPermissionGranted() async {
  if (!Platform.isAndroid) return false;
  try {
    return await _overlayPermChannel.invokeMethod<bool>('canDrawOverlays') ??
        false;
  } catch (_) {
    // Native channel not available (e.g. app not rebuilt) — use plugin/permission_handler.
    try {
      return await FlutterOverlayWindow.isPermissionGranted();
    } catch (_) {
      try {
        return await Permission.systemAlertWindow.isGranted;
      } catch (_) {
        return false;
      }
    }
  }
}

/// Opens the system "Display over other apps" settings page (Android only),
/// picking an OEM-appropriate intent with fallbacks.
Future<void> requestOverlayPermission() async {
  if (!Platform.isAndroid) return;
  try {
    await _overlayPermChannel.invokeMethod('openOverlaySettings');
  } catch (_) {
    // Native channel missing (old build) — open the app settings page directly
    // instead of the plugin's blank overlay intent, so the user never sees a
    // black screen and can flip the permission manually.
    try {
      await openAppSettings();
    } catch (_) {
      try {
        await FlutterOverlayWindow.requestPermission();
      } catch (_) {}
    }
  }
}

/// Key used to hand the FCM payload to the overlay isolate reliably (the
/// message-channel broadcast can race the overlay engine startup, so we also
/// persist the payload and read it back when the overlay boots).
const _kOverlayPayloadKey = 'gora_overlay_payload';

/// Native channel registered on the overlay engine (see MainActivity). The
/// overlay runs in its own engine with no plugins/Activity, so url_launcher
/// can't launch the dialer/WhatsApp from here — we go through native instead.
const _overlayActionChannel = MethodChannel('gora/overlay_actions');

const _primary = Color(0xFFFF6D00);
const _primaryLight = Color(0xFFFFE0B2);

/// Show the floating "new requirement" card over other apps.
///
/// Safe to call from the FCM **background isolate**. No-ops silently if the
/// user hasn't granted the "Display over other apps" permission.
Future<void> showRequirementOverlay(Map<String, dynamic> data) async {
  try {
    if (!Platform.isAndroid) return;
    final granted = await FlutterOverlayWindow.isPermissionGranted();
    if (!granted) return;

    final payload = jsonEncode(data);
    // Reliable channel: persist first so the overlay can read it on boot.
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kOverlayPayloadKey, payload);
    } catch (_) {}

    if (await FlutterOverlayWindow.isActive()) {
      await FlutterOverlayWindow.closeOverlay();
    }

    await FlutterOverlayWindow.showOverlay(
      height: WindowSize.matchParent,
      width: WindowSize.matchParent,
      alignment: OverlayAlignment.center,
      flag: OverlayFlag.defaultFlag,
      visibility: NotificationVisibility.visibilityPublic,
      positionGravity: PositionGravity.none,
      enableDrag: true,
      overlayTitle: 'New Booking',
      overlayContent: 'Tap to view the ride booking',
    );

    // Live channel: push the data a few times over a wider window to beat the
    // overlay-engine startup race (the prefs read is the reliable fallback).
    for (final ms in [0, 500, 1200, 2200]) {
      await Future.delayed(Duration(milliseconds: ms));
      try {
        await FlutterOverlayWindow.shareData(payload);
      } catch (_) {}
    }
  } catch (_) {
    // Overlay is best-effort; the system notification is the fallback.
  }
}

/// Root widget rendered inside the overlay engine (see `overlayMain`).
class RequirementOverlay extends StatefulWidget {
  const RequirementOverlay({super.key});

  @override
  State<RequirementOverlay> createState() => _RequirementOverlayState();
}

class _RequirementOverlayState extends State<RequirementOverlay> {
  Map<String, dynamic> _data = {};
  bool _userCanContact = false;

  @override
  void initState() {
    super.initState();
    _loadFromPrefs();
    FlutterOverlayWindow.overlayListener.listen((event) {
      final parsed = _parse(event);
      if (parsed.isNotEmpty && mounted) setState(() => _data = parsed);
    });
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // The payload is written by a DIFFERENT isolate (the FCM background handler)
      // right before this overlay engine boots. This isolate's SharedPreferences
      // is cached, so a plain read can miss that write — and the live `shareData`
      // broadcast can fire before this widget's listener attaches. So reload from
      // disk and retry for a short window until the payload actually arrives; this
      // is what makes the card show its details instead of empty placeholders.
      for (var i = 0; i < 15; i++) {
        await prefs.reload();
        final parsed = _parse(prefs.getString(_kOverlayPayloadKey));
        if (parsed.isNotEmpty) {
          if (mounted) setState(() => _data = parsed);
          break;
        }
        if (_data.isNotEmpty) break; // shareData already delivered it
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }

      // Whether this user may contact posters. The overlay runs in its own engine
      // with no access to the app's blocs, so the main app mirrors the answer here
      // on every auth change (see saveOverlayContactFlag).
      final canContact = prefs.getBool(kOverlayCanContactKey) ?? false;
      if (mounted) setState(() => _userCanContact = canContact);
    } catch (_) {}
  }

  Map<String, dynamic> _parse(dynamic v) {
    try {
      if (v is String && v.isNotEmpty) {
        return Map<String, dynamic>.from(jsonDecode(v) as Map);
      }
      if (v is Map) return Map<String, dynamic>.from(v);
    } catch (_) {}
    return {};
  }

  String _s(String k) => (_data[k] ?? '').toString();

  /// Intermediate stop addresses (one per line in the payload), shown between A and B.
  List<String> _stops() => _s('stops')
      .split('\n')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  String _cap(String s) => s.isEmpty
      ? s
      : s
          .replaceAll('_', ' ')
          .split(' ')
          .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
          .join(' ');

  /// The single close path — always stop the ring, then close the overlay. Used by
  /// the Close button, the tap-outside barrier, and the header X, so the ring can
  /// never keep playing after the popup is gone.
  Future<void> _close() async {
    // requestStopRing flips a shared-prefs flag the background isolate (which is
    // actually playing the ring) polls — a plain stopRequirementRing here only
    // touches THIS overlay isolate's player, which never played anything.
    await requestStopRing();
    await FlutterOverlayWindow.closeOverlay();
  }

  Future<void> _call() async {
    final m = _s('posterMobile');
    if (m.isEmpty) return;
    try {
      await _overlayActionChannel.invokeMethod('call', {'number': m});
    } catch (_) {}
    await requestStopRing();
    await FlutterOverlayWindow.closeOverlay();
  }

  Future<void> _whatsapp() async {
    var m = _s('posterMobile').replaceAll(RegExp(r'[^0-9]'), '');
    if (m.isEmpty) return;
    if (m.length == 10) m = '91$m';
    try {
      // Pass the pre-filled message so WhatsApp opens with the requirement details
      // (same as the in-app card / alert). The native side URL-encodes it.
      await _overlayActionChannel.invokeMethod('whatsapp', {
        'number': m,
        'message': buildRequirementWhatsAppMessage(_data),
      });
    } catch (_) {}
    await requestStopRing();
    await FlutterOverlayWindow.closeOverlay();
  }

  /// Travel date + time shown in place of the poster name, e.g. "16 Jul • 02:24 pm".
  String _dateTimeLabel() {
    const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final rawDate = _s('travelDate');
    String datePart = '';
    if (rawDate.isNotEmpty) {
      final d = rawDate.contains('T') ? rawDate.split('T').first : rawDate;
      final p = d.split('-');
      if (p.length == 3) {
        final m = int.tryParse(p[1]) ?? 0;
        datePart = '${int.tryParse(p[2]) ?? p[2]} ${(m >= 1 && m <= 12) ? months[m] : ''}'.trim();
      }
    }
    // Convert "14:24" (24h) to "02:24 pm".
    String timePart = '';
    final rawTime = _s('travelTime');
    final tp = rawTime.split(':');
    if (tp.length >= 2) {
      final h = int.tryParse(tp[0]) ?? 0;
      final mm = tp[1].padLeft(2, '0');
      final ampm = h >= 12 ? 'pm' : 'am';
      final h12 = h % 12 == 0 ? 12 : h % 12;
      timePart = '${h12.toString().padLeft(2, '0')}:$mm $ampm';
    }
    return [datePart, timePart].where((e) => e.isNotEmpty).join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    final dateTime = _dateTimeLabel();
    final poster = dateTime.isNotEmpty
        ? dateTime
        : (_s('posterName').isNotEmpty ? _s('posterName') : 'New Booking');
    final bookingId = _s('bookingId');
    final vehicle = _cap(_s('vehicleType'));
    final trip = _cap(_s('tripType'));
    final from = _s('pickupCity');
    final to = _s('dropCity');
    final note = _s('notes');
    final hasMobile = _s('posterMobile').isNotEmpty;
    final canContact = hasMobile && _userCanContact;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Material(
        // Dim the rest of the screen; tapping outside the card dismisses it AND
        // stops the ring.
        color: Colors.black45,
        child: GestureDetector(
          onTap: _close,
          child: Center(
            child: GestureDetector(
              onTap: () {}, // absorb taps on the card so it doesn't dismiss
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width - 24,
                    maxHeight: MediaQuery.of(context).size.height * 0.8,
                  ),
                  child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: const [
                      BoxShadow(
                          color: Colors.black38,
                          blurRadius: 16,
                          offset: Offset(0, 6))
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Header matches the in-app Requirement Alert: a clock
                            // avatar + a date/time chip + the booking id.
                            Row(
                              children: [
                                const CircleAvatar(
                                    radius: 16,
                                    backgroundColor: _primaryLight,
                                    child: Icon(Icons.access_time_rounded,
                                        size: 18, color: _primary)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                        color: _primaryLight,
                                        borderRadius: BorderRadius.circular(20)),
                                    child: Text(poster,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: _primary)),
                                  ),
                                ),
                                if (bookingId.isNotEmpty) ...[const SizedBox(width: 8),
                                  Flexible(
                                    child: Text('#$bookingId',
                                        maxLines: 1,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: _primary,
                                            fontSize: 13),
                                        overflow: TextOverflow.ellipsis),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                const Icon(Icons.directions_car,
                                    color: _primary, size: 20),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(vehicle.isEmpty ? 'Vehicle' : vehicle,
                                      maxLines: 1,
                                      style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700),
                                      overflow: TextOverflow.ellipsis),
                                ),
                                const SizedBox(width: 8),
                                // Natural width (not Flexible) so the trip tag sits
                                // flush at the right end of the row.
                                if (trip.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                            color: Colors.grey.shade300)),
                                    child: Text(trip,
                                        maxLines: 1,
                                        style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600),
                                        overflow: TextOverflow.ellipsis),
                                  ),
                              ],
                            ),
                            const Divider(height: 18),
                            _routeRow(
                                Colors.green, 'A', from.isEmpty ? '—' : from),
                            for (final stop in _stops()) ...{
                              const SizedBox(height: 6),
                              _routeRow(_primary, '•', stop),
                            },
                            const SizedBox(height: 6),
                            _routeRow(Colors.red, 'B', to.isEmpty ? '—' : to),
                            if (note.isNotEmpty) ...{
                              const SizedBox(height: 10),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Icon(Icons.chat_bubble_outline,
                                        size: 16, color: Colors.grey.shade600),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                      child: Text(note,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontSize: 12, height: 1.3))),
                                ],
                              ),
                            },
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: canContact ? _call : null,
                                    icon: const Icon(Icons.call,
                                        size: 18, color: Colors.white),
                                    label: const Text('Call'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 11),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: canContact ? _whatsapp : null,
                                    icon: const Icon(Icons.chat,
                                        size: 18, color: Colors.white),
                                    label: const Text('WhatsApp'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF25D366),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 11),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            // Same black "Close" button as the in-app Requirement
                            // Alert popup — closes the overlay and stops the ring.
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _close,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.black,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                ),
                                child: const Text('Close',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600, fontSize: 14)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    ),
                  ), // SingleChildScrollView
                  ), // Container
                ), // ConstrainedBox
              ), // Padding (horizontal)
            ), // inner GestureDetector (absorb taps)
          ), // Center
        ), // outer GestureDetector (tap outside to dismiss)
      ), // Material
    );
  }

  Widget _routeRow(Color color, String label, String text) => Row(
        children: [
          CircleAvatar(
              radius: 10,
              backgroundColor: color,
              child: Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold))),
          const SizedBox(width: 10),
          Expanded(
              child: Text(text,
                  maxLines: 1,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis)),
        ],
      );
}
