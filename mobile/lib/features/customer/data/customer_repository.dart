import 'dart:typed_data';
import 'package:dio/dio.dart';
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

  /// Download the completed-booking PDF invoice. Returns the raw bytes + a
  /// filename (from the server's Content-Disposition). Works for the customer,
  /// the selected driver, or an admin — the backend enforces access.
  /// Short-lived token to open the invoice PDF via a public URL (no auth header).
  Future<String> invoiceLinkToken(String id) async {
    final res = await _api.get('/customer-bookings/$id/invoice-link');
    return (res.data['data']?['token'] ?? res.data['token'] ?? '').toString();
  }

  Future<({Uint8List bytes, String filename})> downloadInvoice(String id) async {
    final res = await _api.dio.get(
      '/customer-bookings/$id/invoice',
      options: Options(responseType: ResponseType.bytes),
    );
    final data = res.data;
    final bytes = data is Uint8List ? data : Uint8List.fromList(List<int>.from(data as List));
    var filename = 'Gora-Invoice-$id.pdf';
    final cd = res.headers.value('content-disposition');
    if (cd != null) {
      final m = RegExp('filename="?([^"]+)"?').firstMatch(cd);
      if (m != null) filename = m.group(1)!;
    }
    return (bytes: bytes, filename: filename);
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

  /// Golden driver/vendor directly accepts a booking → assigned immediately
  /// (no offer / customer selection). Places the commitment hold + settles it.
  Future<void> accept(String id) async {
    await _api.post('/customer-bookings/$id/accept');
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

  // ── Dynamic home content (admin-managed sections + per-city hero image) ──
  Future<Map<String, dynamic>> homeContent(String? city) async {
    final res = await _api.get('/home-content', params: {if (city != null && city.isNotEmpty) 'city': city});
    return Map<String, dynamic>.from(res.data['data'] as Map);
  }

  // ── Role switching (returns fresh tokens → store them so the new role sticks) ──
  /// Throws with message 'CUSTOMER_ONBOARDING_REQUIRED' when a logged-in account
  /// tries to switch to Customer before completing customer onboarding.
  Future<String> changeRole(String role) async {
    try {
      final res = await _api.post('/auth/change-role', data: {'role': role});
      final d = Map<String, dynamic>.from(res.data['data'] as Map);
      await _storeTokens(d);
      return (d['role'] ?? role).toString();
    } on DioException catch (e) {
      throw Exception(_errMsg(e));
    }
  }

  String _errMsg(DioException e) {
    final data = e.response?.data;
    final m = (data is Map ? (data['message'] ?? data['error']) : null)?.toString();
    return (m != null && m.isNotEmpty) ? m : (e.message ?? 'Request failed');
  }

  /// First-time customer onboarding for a logged-in driver/vendor → switches to
  /// Customer. name & mobile already exist; we only collect city (+ optional).
  Future<String> switchToCustomer({String? city, String? profileImage, String? email}) async {
    final res = await _api.post('/auth/switch-to-customer', data: {
      if (city != null && city.isNotEmpty) 'city': city,
      if (profileImage != null && profileImage.isNotEmpty) 'profileImage': profileImage,
      if (email != null && email.isNotEmpty) 'email': email,
    });
    final d = Map<String, dynamic>.from(res.data['data'] as Map);
    await _storeTokens(d);
    return (d['role'] ?? 'customer').toString();
  }

  /// First-time driver onboarding for a logged-in (customer-first) account →
  /// switches to Driver. Full KYC is completed later from the driver profile.
  Future<String> switchToDriver({String? city, String? state, String? agencyName}) async {
    final res = await _api.post('/auth/switch-to-driver', data: {
      if (city != null && city.isNotEmpty) 'city': city,
      if (state != null && state.isNotEmpty) 'state': state,
      if (agencyName != null && agencyName.isNotEmpty) 'agencyName': agencyName,
    });
    final d = Map<String, dynamic>.from(res.data['data'] as Map);
    await _storeTokens(d);
    return (d['role'] ?? 'driver').toString();
  }

  Future<void> _storeTokens(Map<String, dynamic> d) async {
    final access = (d['accessToken'] ?? '').toString();
    final refresh = (d['refreshToken'] ?? '').toString();
    if (access.isNotEmpty) await _storage.write(key: 'access_token', value: access);
    if (refresh.isNotEmpty) await _storage.write(key: 'refresh_token', value: refresh);
  }

  List<Map<String, dynamic>> _list(dynamic v) =>
      (v is List) ? v.map((e) => Map<String, dynamic>.from(e as Map)).toList() : <Map<String, dynamic>>[];
}
