import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import '../di/injection.dart';
import '../network/api_client.dart';
import '../router/app_router.dart';
import '../utils/contact_launcher.dart';
import '../utils/ring_player.dart';
import '../../features/requirements/presentation/widgets/requirement_alert.dart';

// Must match the channelId the backend sets on the FCM android payload.
const _channel = AndroidNotificationChannel(
  'gora_cabs_notifications',
  'Gora Cabs Notifications',
  description: 'New requirements and updates',
  importance: Importance.high,
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

    // App is in the foreground here — show the rich on-screen popup card.
    final ctx = AppRouter.rootNavigatorKey.currentContext;
    if (ctx != null && (data['requirementId'] ?? '').toString().isNotEmpty) {
      playRequirementRing();
      showRequirementAlert(ctx, Map<String, dynamic>.from(data));
      return;
    }

    final title = n?.title ?? '🚕 New Vehicle Requirement';
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
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          fullScreenIntent: true, // pop over the lock screen like a call
          category: AndroidNotificationCategory.call,
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
    // Show the rich popup card if this was a requirement, else open the feed.
    if ((data['requirementId'] ?? '').toString().isNotEmpty) {
      showRequirementAlert(ctx, Map<String, dynamic>.from(data));
    } else {
      ctx.push('/requirements');
    }
  }
}
