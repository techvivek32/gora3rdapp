import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import '../di/injection.dart';
import '../network/api_client.dart';
import '../router/app_router.dart';
import '../utils/contact_launcher.dart';
import '../utils/action_url.dart';
import '../utils/ring_player.dart';
import '../../features/requirements/presentation/widgets/requirement_alert.dart';

// Must match the channelId the backend sets on the FCM android payload.
//
// The id carries a version suffix on purpose: Android freezes a channel's sound
// when it's first created and ignores every later change, so shipping a new tone
// to existing installs REQUIRES a new channel id. Bump it again if the sound
// changes.
//
// The sound is res/raw/gora_ring2.mp4 (a raw resource, referenced without the
// extension) — Android cannot play a Flutter asset as a notification tone.
const _channelId = 'gora_cabs_notifications_v3';
const _channel = AndroidNotificationChannel(
  _channelId,
  'New Bookings',
  description: 'New ride bookings (loud alert ring)',
  importance: Importance.high,
  playSound: true,
  sound: RawResourceAndroidNotificationSound('gora_ring2'),
);

// Everything that is NOT a new requirement (driver assigned, trip OTP, trip
// started/ended, admin messages) uses this quieter channel — the default system
// tone, no loud gora_ring and no full-screen/ring popup.
const _updatesChannelId = 'gora_cabs_updates';
const _updatesChannel = AndroidNotificationChannel(
  _updatesChannelId,
  'Trip & Account Updates',
  description: 'Assignments, trip OTP and other updates',
  importance: Importance.high,
  playSound: true,
);

/// Handles FCM: permission, token registration, foreground heads-up
/// notifications (with Call / WhatsApp actions) and tap navigation.
class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  final _fln = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    _ready = true;
    try {
      await FirebaseMessaging.instance.requestPermission();

      await _fln.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
        onDidReceiveNotificationResponse: _onResponse,
      );

      final android = _fln.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(_channel);
      await android?.createNotificationChannel(_updatesChannel);
      // Android 13+ runtime notification permission.
      await android?.requestNotificationsPermission();

      // Foreground messages don't show automatically — render our own heads-up.
      FirebaseMessaging.onMessage.listen(_showLocal);

      // App opened by tapping an FCM notification (background → foreground).
      FirebaseMessaging.onMessageOpenedApp.listen((m) => _handleData(m.data, openApp: true));

      // App launched from terminated by tapping a notification.
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) _handleData(initial.data, openApp: true);
    } catch (e) {
      debugPrint('Push init error: $e');
    }
  }

  /// Register the device token with the backend (requires the user to be logged in).
  Future<void> registerToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await getIt<ApiClient>().post('/users/fcm-token', data: {'token': token});
      }
      FirebaseMessaging.instance.onTokenRefresh.listen((t) async {
        try {
          await getIt<ApiClient>().post('/users/fcm-token', data: {'token': t});
        } catch (_) {}
      });
    } catch (e) {
      debugPrint('FCM token register error: $e');
    }
  }

  Future<void> _showLocal(RemoteMessage message) async {
    final n = message.notification;
    final data = message.data;

    // Only a brand-new requirement gets the loud ring + full-screen popup card.
    // Everything else (driver assigned, trip OTP, trip started/ended, admin
    // messages) is just a quiet notification — no ring, no popup.
    final isNewRequirement = (data['type'] ?? '').toString() == 'new_requirement';
    // Booking alerts are opt-in: if the user hasn't turned them on, no ring and
    // no pop-up — not even the loud notification below.
    if (isNewRequirement && !(await alertsEnabled())) return;
    final ctx = AppRouter.rootNavigatorKey.currentContext;
    if (ctx != null && isNewRequirement) {
      playRequirementRing();
      showRequirementAlert(ctx, Map<String, dynamic>.from(data));
      return;
    }

    final title = n?.title ?? '🚕 New Vehicle Booking';
    final mobile = (data['posterMobile'] ?? '').toString();

    // Build a detailed multi-line body from the data payload (route, vehicle,
    // trip type and who posted it) — the most a system notification can show.
    String cap(String s) => s.isEmpty ? s : s.replaceAll('_', ' ');
    final from = (data['pickupCity'] ?? '').toString();
    final to = (data['dropCity'] ?? '').toString();
    final vehicle = cap((data['vehicleType'] ?? '').toString());
    final trip = cap((data['tripType'] ?? '').toString());
    final poster = (data['posterName'] ?? '').toString();
    final lines = <String>[
      if (from.isNotEmpty) 'From: $from',
      if (to.isNotEmpty) 'To: $to',
      if (vehicle.isNotEmpty || trip.isNotEmpty) [vehicle, trip].where((e) => e.isNotEmpty).join(' • '),
      if (poster.isNotEmpty) 'Posted by: $poster',
    ];
    final body = lines.isNotEmpty ? lines.join('\n') : (n?.body ?? 'Tap to view');

    await _fln.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          isNewRequirement ? _channel.id : _updatesChannel.id,
          isNewRequirement ? _channel.name : _updatesChannel.name,
          channelDescription: isNewRequirement ? _channel.description : _updatesChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          // Only new requirements pop over the lock screen like a call and use the
          // loud gora_ring2; other updates are a normal notification.
          fullScreenIntent: isNewRequirement,
          category: isNewRequirement ? AndroidNotificationCategory.call : AndroidNotificationCategory.message,
          playSound: true,
          sound: isNewRequirement ? const RawResourceAndroidNotificationSound('gora_ring2') : null,
          styleInformation: BigTextStyleInformation(body),
          actions: mobile.isEmpty
              ? const []
              : const [
                  AndroidNotificationAction('call', 'Call', showsUserInterface: true),
                  AndroidNotificationAction('whatsapp', 'WhatsApp', showsUserInterface: true),
                ],
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: jsonEncode(data),
    );
  }

  void _onResponse(NotificationResponse response) {
    Map<String, dynamic> data = {};
    if (response.payload != null && response.payload!.isNotEmpty) {
      try {
        data = Map<String, dynamic>.from(jsonDecode(response.payload!) as Map);
      } catch (_) {}
    }
    final mobile = (data['posterMobile'] ?? '').toString();
    switch (response.actionId) {
      case 'call':
        if (mobile.isNotEmpty) callNumber(mobile);
        break;
      case 'whatsapp':
        if (mobile.isNotEmpty) openWhatsApp(mobile);
        break;
      default:
        _handleData(data, openApp: true);
    }
  }

  void _handleData(Map<String, dynamic> data, {bool openApp = false}) {
    if (!openApp) return;
    final ctx = AppRouter.rootNavigatorKey.currentContext;
    if (ctx == null) return;

    // A booking handed to me: open My Requirements on the Assigned tab. Checked
    // before the block below — this push carries a requirementId too, but it is
    // NOT a new-requirement alert.
    if (data['type'] == 'requirement_assigned') {
      ctx.push('/my-requirements?tab=2');
      return;
    }

    // Trip started/ended: open My Requirements on the Assigned tab.
    if (data['type'] == 'trip_started' || data['type'] == 'trip_ended') {
      ctx.push('/my-requirements?tab=2');
      return;
    }

    // Show the rich popup card only for NEW requirements, else open the feed/inbox.
    if ((data['type'] ?? '').toString() == 'new_requirement') {
      showRequirementAlert(ctx, Map<String, dynamic>.from(data));
      return;
    }
    // Admin broadcast: follow its action URL, otherwise land on the inbox.
    final actionUrl = (data['actionUrl'] ?? '').toString().trim();
    if (actionUrl.isNotEmpty) {
      openActionUrl(ctx, actionUrl);
    } else {
      ctx.push('/notifications');
    }
  }
}
