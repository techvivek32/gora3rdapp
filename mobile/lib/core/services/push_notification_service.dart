import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../di/injection.dart';
import '../network/api_client.dart';
import '../router/app_router.dart';
import '../utils/contact_launcher.dart';
import '../utils/action_url.dart';
import '../utils/ring_player.dart';
import '../../features/requirements/presentation/widgets/requirement_alert.dart';

// Must match the channelId the backend sets on the FCM android payload.
//
// SILENT channel: the app now plays the user's chosen NOTIFICATION ringtone
// itself (via audioplayers, so it can be any admin-uploaded tone) — so the
// system channel must NOT also play a sound, or you'd hear two. Android freezes
// a channel's sound at creation, so switching to silent needs a NEW channel id
// (v4) on both the app and the backend.
const _channelId = 'gora_cabs_notifications_v4';
const _channel = AndroidNotificationChannel(
  _channelId,
  'New Bookings',
  description: 'New ride bookings',
  importance: Importance.high,
  playSound: false,
);

// Everything that is NOT one of the loud alerts (driver assigned, trip OTP, trip
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

/// Push types that get the LOUD treatment: the user's ringtone, the full-screen
/// call-style channel and the popup alert card (or the floating overlay when the
/// app is in the background — see `firebaseMessagingBackgroundHandler`).
///
/// These are the "work I can win right now" events a partner is waiting for:
/// another agent's requirement, and a customer's own booking.
///
/// A newly listed AVAILABLE CAR is deliberately NOT here. It is useful to know
/// about but nobody is racing for it, and the popup kept covering whatever the
/// user was doing (it would appear over Settings, mid-form, anywhere). It gets
/// an ordinary notification instead — see `_isNewVehicle` below.
///
/// The backend sends these with the same payload keys (pickupCity, dropCity,
/// vehicleType, tripType, travelDate, travelTime, stops, notes, posterMobile),
/// which is what lets one alert card render them all.
const _loudAlertTypes = {'new_requirement', 'customer_booking_new'};

bool isLoudAlertType(String type) => _loudAlertTypes.contains(type);

/// Feed to open behind a tapped alert card. 'new_requirement' is absent on
/// purpose — its feed is the home screen the user is already on.
const _loudAlertFeed = {
  'customer_booking_new': '/customer-requests',
  'new_vehicle': '/vehicles',
};

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
  ///
  /// FCM rotates a token on reinstall, cleared data and sometimes a plain app
  /// update. The replaced token is sent along as `previousToken` so the server
  /// retires it in the same breath — otherwise the account keeps BOTH, FCM
  /// delivers to both while the old one is still registered, and this phone
  /// shows every booking alert twice.
  Future<void> registerToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _postToken(token);
        _lastToken = token;
      }
      FirebaseMessaging.instance.onTokenRefresh.listen((t) async {
        await _postToken(t, previous: _lastToken);
        _lastToken = t;
      });
    } catch (e) {
      debugPrint('FCM token register error: $e');
    }
  }

  /// The token this device last registered, so a refresh can retire it.
  static const _lastTokenKey = 'fcm_last_token';
  String? _lastTokenCache;

  String? get _lastToken => _lastTokenCache;
  set _lastToken(String? v) {
    _lastTokenCache = v;
    if (v != null) {
      SharedPreferences.getInstance()
          .then((p) => p.setString(_lastTokenKey, v))
          .catchError((_) => false);
    }
  }

  Future<void> _postToken(String token, {String? previous}) async {
    try {
      // On a cold start the in-memory value is empty, so fall back to what was
      // stored last run — that is the token a refresh is actually replacing.
      var prev = previous;
      if (prev == null) {
        try {
          prev = (await SharedPreferences.getInstance()).getString(_lastTokenKey);
        } catch (_) {/* storage unavailable — register without it */}
      }
      await getIt<ApiClient>().post('/users/fcm-token', data: {
        'token': token,
        if (prev != null && prev.isNotEmpty && prev != token) 'previousToken': prev,
      });
    } catch (_) {/* a failed registration retries on the next app start */}
  }

  Future<void> _showLocal(RemoteMessage message) async {
    final n = message.notification;
    final data = message.data;

    // New work (requirement / customer booking / available car) gets the loud
    // ring + full-screen popup card. Everything else (driver assigned, trip OTP,
    // trip started/ended, admin messages) is just a quiet notification — no
    // ring, no popup.
    final isLoud = isLoudAlertType((data['type'] ?? '').toString());
    // Booking alerts are opt-in: if the user hasn't turned them on, no ring and
    // no pop-up — not even the loud notification below.
    // Offline means not working: no popup, no ring, not even the loud
    // notification - regardless of the alert settings.
    if (isLoud && !(await alertsEnabled())) return;
    if (isLoud && !(await isOnline())) return;
    final ctx = AppRouter.rootNavigatorKey.currentContext;
    if (ctx != null && isLoud) {
      playRequirementRing(kind: RingKind.popup);
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
          isLoud ? _channel.id : _updatesChannel.id,
          isLoud ? _channel.name : _updatesChannel.name,
          channelDescription: isLoud ? _channel.description : _updatesChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          // New-work alerts pop over the lock screen like a call but stay SILENT
          // here — the app plays the chosen notification tone itself. Other updates
          // use the normal system sound.
          fullScreenIntent: isLoud,
          category: isLoud ? AndroidNotificationCategory.call : AndroidNotificationCategory.message,
          playSound: !isLoud,
          sound: null,
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
      ctx.go('/my-requirements?tab=2');
      return;
    }

    // Trip started/ended: open My Requirements on the Assigned tab.
    if (data['type'] == 'trip_started' || data['type'] == 'trip_ended') {
      ctx.go('/my-requirements?tab=2');
      return;
    }

    final type = (data['type'] ?? '').toString();

    // An available-car notification just opens the vehicles feed — no card, by
    // the same reasoning as above.
    if (type == 'new_vehicle') {
      ctx.push(_loudAlertFeed[type]!);
      return;
    }

    // New work: open the matching feed FIRST, then show the same rich popup card
    // the foreground path shows — so a tapped alert looks identical whether the
    // app was open or not, and closing the card leaves the user on the right
    // list. Requirements need no push: that feed is already the home screen.
    if (isLoudAlertType(type)) {
      final feed = _loudAlertFeed[type];
      if (feed != null) ctx.push(feed);
      showRequirementAlert(ctx, Map<String, dynamic>.from(data));
      return;
    }
    // Other customer-booking events (offer / confirmed / trip / arriving / cancel) → My Rides.
    if (type.startsWith('customer_booking') || type.startsWith('customer_trip') || type.startsWith('customer_driver')) {
      ctx.push('/customer/bookings');
      return;
    }
    // Car Pooling: a new seat booking / cancellation → driver's Pool Rides.
    if (type == 'pool_seat_booked' || type == 'pool_seat_cancelled') {
      ctx.push('/car-pool/my-rides');
      return;
    }
    // Other pool events (started / picked / completed / cancelled / updated) → passenger's bookings.
    if (type.startsWith('pool_')) {
      ctx.push('/car-pool/my-bookings');
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
