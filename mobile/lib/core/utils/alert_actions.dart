import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../di/injection.dart';
import '../network/api_client.dart';
import 'api_error.dart';

/// What a booking alert offers instead of Call / WhatsApp.
///
/// Both alert surfaces — the in-app card and the floating overlay — show the
/// same two buttons, so the decision lives here rather than being written twice
/// and drifting.
enum AlertAction {
  /// Normal booking from a visible poster: dial or WhatsApp them.
  contact,

  /// The poster chose to hide their profile, so there is no number to show.
  /// Chat is the only way to reach them, and it is a real one.
  chat,

  /// A customer's own booking. Their number stays hidden until a driver is
  /// selected, so Call/WhatsApp would always be dead — Accept is the action
  /// that actually moves this forward.
  accept,
}

/// Pick the action for an alert payload (the FCM `data` map).
AlertAction alertActionFor(Map<String, dynamic> data) {
  final type = (data['type'] ?? '').toString();
  if (type.startsWith('customer_booking')) return AlertAction.accept;
  if ((data['hideProfile'] ?? '').toString().toLowerCase() == 'true') {
    return AlertAction.chat;
  }
  return AlertAction.contact;
}

// ─── Hand-off from the overlay ───────────────────────────────────────────────
// The overlay runs in its own engine with no router and no navigator, so it
// cannot open a screen itself. It parks what the user asked for here, brings
// the app forward, and the app picks it up on resume.

const _kPendingKind = 'gora_pending_alert_kind';
const _kPendingId = 'gora_pending_alert_id';
const _kPendingReq = 'gora_pending_alert_req';

/// Park "open the chat with X" / "accept booking Y" for the app to act on.
Future<void> savePendingAlertAction({
  required AlertAction kind,
  required String id,
  String? requirementId,
}) async {
  if (id.isEmpty) return;
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPendingKind, kind.name);
    await prefs.setString(_kPendingId, id);
    if (requirementId != null && requirementId.isNotEmpty) {
      await prefs.setString(_kPendingReq, requirementId);
    } else {
      await prefs.remove(_kPendingReq);
    }
  } catch (_) {
    // Best effort — the app still comes forward, just on its last screen.
  }
}

/// Read and clear whatever the overlay parked. Returns null when there is none.
Future<({AlertAction kind, String id, String? requirementId})?>
    consumePendingAlertAction() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload(); // written by the overlay isolate, not this one
    final kindName = prefs.getString(_kPendingKind);
    final id = prefs.getString(_kPendingId);
    if (kindName == null || id == null || id.isEmpty) return null;
    final requirementId = prefs.getString(_kPendingReq);
    await prefs.remove(_kPendingKind);
    await prefs.remove(_kPendingId);
    await prefs.remove(_kPendingReq);
    final kind = AlertAction.values.firstWhere(
      (a) => a.name == kindName,
      orElse: () => AlertAction.contact,
    );
    return (kind: kind, id: id, requirementId: requirementId);
  } catch (_) {
    return null;
  }
}

// ─── The two destinations ────────────────────────────────────────────────────

/// Open (or create) the direct chat with [userId] and go to that room.
///
/// The server refuses to START a new thread without an active plan, so its
/// message is shown as-is — "try again" would send the user in circles.
Future<void> openChatWith(
  BuildContext context,
  String userId, {
  String? requirementId,
}) async {
  if (userId.isEmpty) return;
  final messenger = ScaffoldMessenger.of(context);
  final router = GoRouter.of(context);
  try {
    final res = await getIt<ApiClient>().post(
      '/chats/with/$userId',
      data: requirementId != null && requirementId.isNotEmpty
          ? {'requirementId': requirementId}
          : null,
    );
    final data = (res.data is Map) ? (res.data['data'] ?? res.data) : null;
    final chatId = (data is Map) ? (data['_id'] ?? data['id'])?.toString() : null;
    if (chatId == null) throw Exception('no chat id');
    router.push('/chats/$chatId');
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text(serverMessage(e, fallback: 'Could not open chat. Please try again.'))),
    );
  }
}

/// Open the customer requests feed with [bookingId] ready to accept — the feed
/// pops its usual vehicle/driver sheet for it, so this is the same flow as
/// tapping Accept on the card rather than a second, parallel one.
void openCustomerBookingToAccept(BuildContext context, String bookingId) {
  if (bookingId.isEmpty) return;
  GoRouter.of(context).push('/customer-requests?acceptBookingId=$bookingId');
}
