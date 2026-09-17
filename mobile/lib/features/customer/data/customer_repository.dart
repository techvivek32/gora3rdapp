import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/network/api_client.dart';

/// All Customer-Mode API calls (customer + driver sides of customer bookings,
/// plus role switching). Thin wrapper over ApiClient — pages call these directly
/// and handle loading/error with setState. Returns parsed `data`, throws on error.
class CustomerRepository {
  final ApiClient _api;
  final FlutterSecureStorage _storage;
  CustomerRepository(this._api, this._storage);

  // ── Customer side ──
  Future<Map<String, dynamic>> createBooking(Map<String, dynamic> data) async {
    final res = await _api.post('/customer-bookings', data: data);
    return Map<String, dynamic>.from(res.data['data'] as Map);
  }

  Future<List<Map<String, dynamic>>> myBookings({String? status}) async {
    final res = await _api.get('/customer-bookings/my', params: {if (status != null) 'status': status});
    return _list(res.data['data']);
  }

  Future<Map<String, dynamic>> getBooking(String id) async {
    final res = await _api.get('/customer-bookings/$id');
    return Map<String, dynamic>.from(res.data['data'] as Map);
  }

  /// Edit an OPEN booking. Existing offers are released server-side and drivers
  /// re-notified for the updated request.
  Future<Map<String, dynamic>> updateBooking(String id, Map<String, dynamic> data) async {
    final res = await _api.put('/customer-bookings/$id', data: data);
    return Map<String, dynamic>.from(res.data['data'] as Map);
  }

  Future<void> selectOffer(String id, String offerId) async {
    await _api.post('/customer-bookings/$id/select', data: {'offerId': offerId});
  }

  Future<void> cancelBooking(String id, {String? reason}) async {
    await _api.post('/customer-bookings/$id/cancel', data: {if (reason != null) 'reason': reason});
  }

  Future<void> rateBooking(String id, double rating, {String? review}) async {
    await _api.post('/customer-bookings/$id/rate', data: {'rating': rating, if (review != null) 'review': review});
  }

  // ── Driver / vendor side ──
  Future<List<Map<String, dynamic>>> available({String? serviceType}) async {
    final res = await _api.get('/customer-bookings/available',
        params: {if (serviceType != null) 'serviceType': serviceType});
    return _list(res.data['data']);
  }

  Future<Map<String, dynamic>> apply(String id, Map<String, dynamic> data) async {
    final res = await _api.post('/customer-bookings/$id/apply', data: data);
    return Map<String, dynamic>.from(res.data['data'] as Map);
  }

  Future<List<Map<String, dynamic>>> myApplications() async {
    final res = await _api.get('/customer-bookings/my-applications');
    return _list(res.data['data']);
  }

  /// Driver marks they're arriving at the pickup → customer gets a notification.
  Future<void> driverArrived(String id) async {
    await _api.post('/customer-bookings/$id/arrived');
  }

  /// Driver asks for the start/end OTP — it's delivered to the customer, who
  /// reads it out. `action` is 'start' or 'end'.
  Future<void> requestTripOtp(String id, String action) async {
    await _api.post('/customer-bookings/$id/trip/request-otp', data: {'action': action});
  }

  /// Driver submits the OTP the customer gave them → starts/completes the trip.
  Future<void> verifyTripOtp(String id, String action, String otp) async {
    await _api.post('/customer-bookings/$id/trip/verify-otp', data: {'action': action, 'otp': otp});
  }

  Future<void> driverCancel(String id, {String? reason}) async {
    await _api.post('/customer-bookings/$id/driver-cancel', data: {if (reason != null) 'reason': reason});
  }

  // ── Help & Support (complaints) ──
  Future<void> createComplaint(String category, {String? message, String? bookingRef, String? bookingId}) async {
    await _api.post('/customer-complaints', data: {
      'category': category,
      if (message != null && message.isNotEmpty) 'message': message,
      if (bookingRef != null) 'bookingRef': bookingRef,
      if (bookingId != null) 'bookingId': bookingId,
    });
  }

  Future<List<Map<String, dynamic>>> myComplaints() async {
    final res = await _api.get('/customer-complaints/my');
    return _list(res.data['data']);
  }

  // ── Role switching (returns fresh tokens → store them so the new role sticks) ──
  Future<String> changeRole(String role) async {
    final res = await _api.post('/auth/change-role', data: {'role': role});
    final d = Map<String, dynamic>.from(res.data['data'] as Map);
    final access = (d['accessToken'] ?? '').toString();
    final refresh = (d['refreshToken'] ?? '').toString();
    if (access.isNotEmpty) await _storage.write(key: 'access_token', value: access);
    if (refresh.isNotEmpty) await _storage.write(key: 'refresh_token', value: refresh);
    return (d['role'] ?? role).toString();
  }

  List<Map<String, dynamic>> _list(dynamic v) =>
      (v is List) ? v.map((e) => Map<String, dynamic>.from(e as Map)).toList() : <Map<String, dynamic>>[];
}
