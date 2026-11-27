import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/utils/alert_actions.dart';
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

/// Monotonic counter bumped on every payload write.
///
/// Both writers re-broadcast their payload several times over a few seconds to
/// beat the overlay engine's startup race. Those loops used to overlap: the
/// bubble re-sends at 0/0.4/1.4s, the alert card at 0/0.5/1.7/3.9s, so a
/// booking landing within a second of the bubble appearing got a STALE bubble
/// broadcast on top of it — the full card turned back into the little icon.
/// Every write now takes a sequence number, every re-broadcast checks it is
/// still the newest, and the overlay ignores anything older than what it has.
const _kOverlaySeqKey = 'gora_overlay_seq';

/// Writes `payload` as the current overlay content and returns its sequence.
Future<int> _publishPayload(String payload) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final seq = (prefs.getInt(_kOverlaySeqKey) ?? 0) + 1;
    await prefs.setInt(_kOverlaySeqKey, seq);
    await prefs.setString(_kOverlayPayloadKey, payload);
    return seq;
  } catch (_) {
    return 0;
  }
}

/// True while `seq` is still the most recent write — i.e. nothing newer has
/// replaced this payload while our re-broadcast loop was sleeping.
Future<bool> _stillCurrent(int seq) async {
  if (seq == 0) return true; // prefs unavailable; nothing better to go on
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return (prefs.getInt(_kOverlaySeqKey) ?? 0) <= seq;
  } catch (_) {
    return true;
  }
}

/// Re-broadcast `payload` on the live channel at each delay, giving up as soon
/// as a newer payload has been published.
Future<void> _broadcast(String payload, int seq, List<int> delaysMs) async {
  final tagged = _withSeq(payload, seq);
  for (final ms in delaysMs) {
    await Future.delayed(Duration(milliseconds: ms));
    if (!await _stillCurrent(seq)) return;
    try {
      await FlutterOverlayWindow.shareData(tagged);
    } catch (_) {}
  }
}

/// Stamp the sequence into the JSON so the receiving side can order it too —
/// `shareData` has no ordering guarantee of its own.
String _withSeq(String payload, int seq) {
  try {
    final m = Map<String, dynamic>.from(jsonDecode(payload) as Map);
    m['_seq'] = seq;
    return jsonEncode(m);
  } catch (_) {
    return payload;
  }
}

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
  // A booking outranks the bubble. This only cancels a bubble started in the
  // SAME isolate — and in practice this function runs in the FCM background
  // isolate while the bubble is raised from the UI one, so the counter does
  // not reach it. What actually orders those two is the sequence number in
  // shared preferences, which every isolate can see (`_publishPayload`).
  // The bump is kept for the day something calls this from the UI isolate.
  _bubbleGen++;
  try {
    if (!Platform.isAndroid) return;
    final granted = await FlutterOverlayWindow.isPermissionGranted();
    if (!granted) return;

    final payload = jsonEncode(data);
    // Reliable channel: persist first so the overlay can read it on boot. The
    // sequence makes this write win over any bubble broadcast still in flight.
    final seq = await _publishPayload(payload);

    if (await FlutterOverlayWindow.isActive()) {
      await FlutterOverlayWindow.closeOverlay();
    }

    // Size the window to ~60% of the screen height (physical px) instead of full
    // screen, so it doesn't cover/lock the whole screen. Guarded: this runs in the
    // FCM background isolate where `views` is often EMPTY — `.first` there threw
    // and the whole overlay silently failed to show. Fall back to a fixed height.
    double screenH = 0;
    try {
      final views = ui.PlatformDispatcher.instance.views;
      if (views.isNotEmpty) screenH = views.first.physicalSize.height;
      screenH = screenH > 0 ? screenH : (ui.PlatformDispatcher.instance.implicitView?.physicalSize.height ?? 0);
    } catch (_) {}
    final overlayHeightPx = screenH > 0 ? (screenH * 0.6).round() : 1500;

    // Capped on purpose. When two of these run at once the plugin can leave the
    // call pending for good — measured: two of four never came back. In the FCM
    // background isolate that means the handler never returns and Android
    // eventually kills the process. The window itself is already opening by the
    // time this resolves, so giving up on the acknowledgement costs nothing but
    // guarantees the isolate finishes.
    await FlutterOverlayWindow.showOverlay(
      height: overlayHeightPx,
      width: WindowSize.matchParent,
      alignment: OverlayAlignment.center,
      flag: OverlayFlag.defaultFlag,
      visibility: NotificationVisibility.visibilityPublic,
      positionGravity: PositionGravity.none,
      enableDrag: true,
      overlayTitle: 'New Booking',
      overlayContent: 'Tap to view the ride booking',
    ).timeout(const Duration(seconds: 8), onTimeout: () {});

    // Live channel: push the data a few times over a wider window to beat the
    // overlay-engine startup race (the prefs read is the reliable fallback).
    // Stops early if a newer payload replaced this one meanwhile.
    await _broadcast(payload, seq, [0, 500, 1200, 2200]);
  } catch (_) {
    // Overlay is best-effort; the system notification is the fallback.
  }
}

/// Marks the overlay payload as "just the floating bubble", not an alert card.
/// The overlay engine renders one or the other off this flag.
const _kBubblePayload = '{"_bubble":true}';

/// Diameter of the floating bubble, in logical pixels. The overlay WINDOW is
/// sized from this (see `showOnlineBubble`) so the two always match.
const double _kBubbleDiameter = 58;

/// Bumped by anything that should cancel an in-flight `showOnlineBubble`.
///
/// Showing the bubble takes six awaits; hiding it takes one. Whoever asked
/// last must win, or the bubble reappears after it was told to go — over our
/// own UI, where it eats taps. UI-isolate only, which is where both the
/// lifecycle hooks and the online toggle live.
int _bubbleGen = 0;

/// Float a small Gora logo over other apps while the partner is ONLINE.
///
/// It is the same overlay window the alert card uses — the plugin allows one at
/// a time — so the engine decides what to draw from the payload. A new booking
/// replaces the bubble with the full card; closing the card puts the bubble
/// back (see `restoreOnlineBubble`).
///
/// No-ops without the "Display over other apps" permission, like every other
/// overlay call here.
Future<void> showOnlineBubble() async {
  // Claim this attempt. Anything that supersedes it — going offline, the app
  // coming back to the front, a booking card — bumps the counter, and every
  // await below then bails out.
  //
  // Without this the bubble ends up ON TOP OF OUR OWN HOME SCREEN: the app is
  // backgrounded so this starts, the user comes straight back, `hideOnlineBubble`
  // closes the window, and then this function — still waiting on one of its six
  // awaits — happily opens it again. A system overlay over our own UI swallows
  // taps on whatever is under it, which is the "I tap something else and the
  // icon gets tapped" report.
  final gen = ++_bubbleGen;
  bool superseded() => gen != _bubbleGen;

  try {
    if (!Platform.isAndroid) return;
    if (!await FlutterOverlayWindow.isPermissionGranted() || superseded()) return;
    if (!await isOnline() || superseded()) return;

    final seq = await _publishPayload(_kBubblePayload);
    if (superseded()) return;

    if (await FlutterOverlayWindow.isActive()) await FlutterOverlayWindow.closeOverlay();
    if (superseded()) return;

    // Size the WINDOW to the bubble, exactly.
    //
    // This window is a SQUARE that sits on top of whatever app is in front, and
    // every pixel of it swallows a tap — the circle you can see is only the part
    // that looks clickable. So any slack here shows up as taps landing on the
    // bubble when the user aimed at the app underneath, which is what makes a
    // button feel dead. A fixed 200x200 did it first; then +6dp of shadow slack
    // and a 120px floor kept a thinner ring of it.
    //
    // Now: no slack, and the floor is derived from the circle rather than a
    // magic number, so it can never exceed the circle on a low-density screen.
    // The drop shadow is gone from the widget for the same reason (see
    // `_buildBubble`) — a shadow is not worth a dead zone around the icon.
    //
    // `views` is EMPTY inside the FCM background isolate, where `.first` throws
    // and the bubble silently never appeared; fall back the same way the alert
    // card does.
    double ratio = 0;
    try {
      final views = ui.PlatformDispatcher.instance.views;
      if (views.isNotEmpty) ratio = views.first.devicePixelRatio;
      if (ratio <= 0) ratio = ui.PlatformDispatcher.instance.implicitView?.devicePixelRatio ?? 0;
    } catch (_) {}
    if (ratio <= 0) ratio = 3; // a modern phone; better to guess high than clip
    final side = (_kBubbleDiameter * ratio).round().clamp(_kBubbleDiameter.round(), 400);

    await FlutterOverlayWindow.showOverlay(
      height: side,
      width: side,
      alignment: OverlayAlignment.centerRight,
      flag: OverlayFlag.defaultFlag,
      visibility: NotificationVisibility.visibilityPublic,
      // Snap to the nearest edge after a drag, like a chat head.
      positionGravity: PositionGravity.auto,
      enableDrag: true,
      overlayTitle: 'Gora Taxi',
      overlayContent: 'You are online',
    );
    // The window is open now. If the answer changed while it was opening — the
    // app came back to the front, or they went offline — take it straight back
    // down rather than leaving a tap-eating circle on screen.
    if (superseded()) {
      try {
        await FlutterOverlayWindow.closeOverlay();
      } catch (_) {}
      return;
    }
    // Gives up the moment an alert card is published, so a booking that lands
    // while this loop is still running is never overwritten by the bubble.
    await _broadcast(_kBubblePayload, seq, [0, 400, 1000]);
  } catch (_) {
    // Best effort — being online must never depend on the bubble appearing.
  }
}

/// Take the bubble away (going offline, signing out, or the app coming back to
/// the front). Cancels any `showOnlineBubble` still working through its awaits.
Future<void> hideOnlineBubble() async {
  _bubbleGen++;
  try {
    if (!Platform.isAndroid) return;
    if (await FlutterOverlayWindow.isActive()) await FlutterOverlayWindow.closeOverlay();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kOverlayPayloadKey);
    } catch (_) {}
  } catch (_) {}
}

/// Put the bubble back after an alert card is dismissed, but only if the
/// partner is still online — otherwise closing a card would resurrect a bubble
/// they had already turned off.
Future<void> restoreOnlineBubble() async {
  if (await isOnline()) await showOnlineBubble();
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
      _accept(_parse(event));
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
          // Carry the stored sequence so a disk read can't undo a newer
          // payload that already arrived on the live channel.
          parsed['_seq'] ??= prefs.getInt(_kOverlaySeqKey) ?? 0;
          _accept(parsed);
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

  /// Take a payload only if it is not older than the one already on screen.
  ///
  /// Two writers re-broadcast on overlapping schedules, and the disk read races
  /// both. Without this ordering, a bubble broadcast queued a second earlier
  /// could land after the alert card and replace a live booking with the idle
  /// icon — the glitch where the popup turned back into the little logo.
  void _accept(Map<String, dynamic> parsed) {
    if (parsed.isEmpty || !mounted) return;

    // A bubble may never take over a live booking card, whatever the sequence
    // says. Ordering cannot decide this one, and that is what made the icon
    // fill the screen:
    //
    //   the card opens the window at 60% of the screen, then `showOnlineBubble`
    //   — raised by the app going to the background, or by a card that closed a
    //   moment earlier — publishes the bubble with a NEWER sequence. The check
    //   below reads it as fresher news, swaps the card for the bubble, and
    //   `_buildBubble` expands a 58dp icon to fill a card-sized window.
    //
    // A card is dismissed by the person looking at it, never by a background
    // broadcast, so precedence settles it. Every real "card → bubble" path
    // (`_close`, `_acceptBooking`, `_chatWithPoster`) closes the overlay first,
    // which tears down this engine — the bubble then arrives in a fresh one
    // with nothing on screen and is accepted normally.
    if (parsed['_bubble'] == true && _data.isNotEmpty && _data['_bubble'] != true) return;

    final incoming = (parsed['_seq'] as num?)?.toInt() ?? 0;
    final current = (_data['_seq'] as num?)?.toInt() ?? 0;
    if (incoming > 0 && current > 0 && incoming < current) return; // stale
    setState(() => _data = parsed);
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
    // Each step is guarded so a failure in one never blocks the actual close.
    try {
      await requestStopRing();
    } catch (_) {}
    try {
      await FlutterOverlayWindow.closeOverlay();
    } catch (_) {}
    // The card took the bubble's window, so hand it back when still online.
    try {
      await restoreOnlineBubble();
    } catch (_) {}
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

  /// Bring the app forward when the bubble is tapped. The overlay engine has no
  /// plugins, so this goes through the native channel like Call/WhatsApp do.
  Future<void> _openApp() async {
    try {
      await _overlayActionChannel.invokeMethod('openApp');
    } catch (_) {}
  }

  /// Park "open the chat with the poster" and bring the app forward.
  Future<void> _chatWithPoster() async {
    requestStopRing();
    await savePendingAlertAction(
      kind: AlertAction.chat,
      id: _s('posterId'),
      requirementId: _s('requirementId'),
    );
    await _openApp();
    await FlutterOverlayWindow.closeOverlay();
    await restoreOnlineBubble();
  }

  /// Park "accept this booking" and bring the app forward.
  Future<void> _acceptBooking() async {
    requestStopRing();
    await savePendingAlertAction(
      kind: AlertAction.accept,
      id: _s('customerBookingId'),
    );
    await _openApp();
    await FlutterOverlayWindow.closeOverlay();
    await restoreOnlineBubble();
  }

  /// The floating Gora logo shown while the partner is online.
  ///
  /// Sized to exactly [_kBubbleDiameter], which is also what `showOnlineBubble`
  /// sizes the WINDOW to — so in the window this belongs to it still fills the
  /// square edge to edge, with no outer padding, margin or drop shadow. That
  /// matters: the window is laid over whatever app is in front and eats every
  /// tap inside it, so a gap between window and circle is a dead zone the user
  /// cannot see.
  ///
  /// The size is a cap rather than `SizedBox.expand` because this widget is
  /// also reachable in the alert card's window, which is 60% of the screen.
  /// Expanding there is what drew the logo across half the display.
  Widget _buildBubble() {
    return Material(
      color: Colors.transparent,
      // Capped, not merely expanded. In the window this is meant for the cap
      // and the window are the same 58dp, so nothing changes — but the same
      // widget is reachable in the card's much larger window, and `expand`
      // there drew the logo across most of the screen. A size limit means the
      // worst case is a small icon in the wrong place rather than a giant one.
      child: Center(
        child: SizedBox(
          width: _kBubbleDiameter,
          height: _kBubbleDiameter,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _openApp,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: _primary, width: 2),
              ),
              padding: const EdgeInsets.all(4),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/gora_logo_white.png',
                  fit: BoxFit.contain,
                  // The overlay engine loads assets from the same bundle, but if
                  // anything goes wrong a blank circle would look broken.
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.local_taxi_rounded, color: _primary, size: 28),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // One overlay window, two faces: the bubble while idle, the full alert card
    // when a booking lands. The payload says which.
    if (_data['_bubble'] == true) return _buildBubble();

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
    final action = alertActionFor(_data);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Material(
        // Compact overlay: the card IS the window (transparent background). No
        // full-screen dim / tap-catcher — those nested GestureDetectors stole taps
        // from the buttons, which is why Close sometimes did nothing.
        color: Colors.transparent,
        child: Center(
          child: Padding(
                padding: const EdgeInsets.all(10),
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
                                const SizedBox(width: 4),
                                // Header X — a second, always-reliable close path.
                                InkWell(
                                  onTap: _close,
                                  borderRadius: BorderRadius.circular(20),
                                  child: const Padding(
                                    padding: EdgeInsets.all(4),
                                    child: Icon(Icons.close, size: 20, color: Colors.black54),
                                  ),
                                ),
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
                            // Call/WhatsApp need a number to dial. A hidden
                            // profile has none, and a customer's stays hidden
                            // until a driver is selected — so those two show
                            // the action that actually moves things forward.
                            // The overlay has no router, so it parks the intent
                            // and brings the app forward to carry it out.
                            if (action == AlertAction.accept)
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _acceptBooking,
                                  icon: const Icon(Icons.check_circle,
                                      size: 18, color: Colors.white),
                                  label: const Text('Accept Booking'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                  ),
                                ),
                              )
                            else if (action == AlertAction.chat)
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _chatWithPoster,
                                  icon: const Icon(Icons.chat_bubble,
                                      size: 18, color: Colors.white),
                                  label: const Text('Chat with Poster'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                  ),
                                ),
                              )
                            else
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
                                        backgroundColor:
                                            const Color(0xFF25D366),
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
              ), // Padding
        ), // Center
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
