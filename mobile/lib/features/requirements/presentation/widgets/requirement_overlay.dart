import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

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
      overlayTitle: 'New Requirement',
      overlayContent: 'Tap to view the ride requirement',
    );

    // Live channel: push the data a couple of times to beat the startup race.
    await FlutterOverlayWindow.shareData(payload);
    await Future.delayed(const Duration(milliseconds: 700));
    await FlutterOverlayWindow.shareData(payload);
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
      final raw = prefs.getString(_kOverlayPayloadKey);
      final parsed = _parse(raw);
      if (parsed.isNotEmpty && mounted) setState(() => _data = parsed);
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

  String _cap(String s) => s.isEmpty
      ? s
      : s
          .replaceAll('_', ' ')
          .split(' ')
          .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
          .join(' ');

  Future<void> _call() async {
    final m = _s('posterMobile');
    if (m.isEmpty) return;
    try {
      await launchUrl(Uri.parse('tel:$m'),
          mode: LaunchMode.externalApplication);
    } catch (_) {}
    await FlutterOverlayWindow.closeOverlay();
  }

  Future<void> _whatsapp() async {
    var m = _s('posterMobile').replaceAll(RegExp(r'[^0-9]'), '');
    if (m.isEmpty) return;
    if (m.length == 10) m = '91$m';
    try {
      await launchUrl(Uri.parse('https://wa.me/$m'),
          mode: LaunchMode.externalApplication);
    } catch (_) {}
    await FlutterOverlayWindow.closeOverlay();
  }

  @override
  Widget build(BuildContext context) {
    final poster =
        _s('posterName').isNotEmpty ? _s('posterName') : 'New Requirement';
    final bookingId = _s('bookingId');
    final vehicle = _cap(_s('vehicleType'));
    final trip = _cap(_s('tripType'));
    final from = _s('pickupCity');
    final to = _s('dropCity');
    final note = _s('notes');
    final hasMobile = _s('posterMobile').isNotEmpty;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Material(
        // Dim the rest of the screen; tapping outside the card dismisses it.
        color: Colors.black45,
        child: GestureDetector(
          onTap: () => FlutterOverlayWindow.closeOverlay(),
          child: Center(
            child: GestureDetector(
              onTap: () {}, // absorb taps on the card so it doesn't dismiss
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Brand bar
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        color: _primary,
                        child: Row(
                          children: [
                            const Icon(Icons.local_taxi,
                                color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text('New Vehicle Requirement',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15)),
                            ),
                            GestureDetector(
                              onTap: () => FlutterOverlayWindow.closeOverlay(),
                              child: const Icon(Icons.close,
                                  color: Colors.white, size: 22),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                const CircleAvatar(
                                    radius: 15,
                                    backgroundColor: _primaryLight,
                                    child: Icon(Icons.person,
                                        size: 18, color: _primary)),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: Text(poster,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15),
                                        overflow: TextOverflow.ellipsis)),
                                if (bookingId.isNotEmpty)
                                  Text('#$bookingId',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: _primary,
                                          fontSize: 13)),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                const Icon(Icons.directions_car,
                                    color: _primary, size: 20),
                                const SizedBox(width: 6),
                                Text(vehicle.isEmpty ? 'Vehicle' : vehicle,
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700)),
                                const Spacer(),
                                if (trip.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                            color: Colors.grey.shade300)),
                                    child: Text(trip,
                                        style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600)),
                                  ),
                              ],
                            ),
                            const Divider(height: 18),
                            _routeRow(
                                Colors.green, 'A', from.isEmpty ? '—' : from),
                            const SizedBox(height: 6),
                            _routeRow(Colors.red, 'B', to.isEmpty ? '—' : to),
                            if (note.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.chat_bubble_outline,
                                      size: 16, color: Colors.grey.shade600),
                                  const SizedBox(width: 6),
                                  Expanded(
                                      child: Text(note,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontSize: 12, height: 1.3))),
                                ],
                              ),
                            ],
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: hasMobile ? _call : null,
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
                                    onPressed: hasMobile ? _whatsapp : null,
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
                            const SizedBox(height: 4),
                            Center(
                              child: TextButton(
                                onPressed: () =>
                                    FlutterOverlayWindow.closeOverlay(),
                                child: const Text('Dismiss',
                                    style: TextStyle(
                                        color: Colors.grey,
                                        fontWeight: FontWeight.w600)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ), // Container
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
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis)),
        ],
      );
}
