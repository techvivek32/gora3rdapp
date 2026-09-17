import '../../../core/network/api_client.dart';

/// All Car Pooling API calls (driver ride management + passenger seat booking).
/// Thin wrapper over ApiClient — pages call these and handle loading/error with
/// setState. Returns parsed `data`, throws on error.
class CarPoolRepository {
  final ApiClient _api;
  CarPoolRepository(this._api);

  // ── Driver ──
  Future<Map<String, dynamic>> postRide(Map<String, dynamic> data) async {
    final res = await _api.post('/car-pool', data: data);
    return _map(res.data['data']);
  }

  Future<List<Map<String, dynamic>>> myRides({String? status}) async {
    final res = await _api.get('/car-pool/my-rides', params: {if (status != null) 'status': status});
    return _list(res.data['data']);
  }

  Future<Map<String, dynamic>> updateRide(String id, Map<String, dynamic> data) async {
    final res = await _api.put('/car-pool/$id', data: data);
    return _map(res.data['data']);
  }

  Future<void> stopRide(String id, {String? reason}) async {
    await _api.post('/car-pool/$id/stop', data: {if (reason != null) 'reason': reason});
  }

  Future<Map<String, dynamic>> startRide(String id) async {
    final res = await _api.post('/car-pool/$id/start');
    return _map(res.data['data']);
  }

  Future<Map<String, dynamic>> markPickup(String id, List<String> bookingIds) async {
    final res = await _api.post('/car-pool/$id/pickup', data: {'bookingIds': bookingIds});
    return _map(res.data['data']);
  }

  Future<Map<String, dynamic>> completeRide(String id, {num? distanceTravelled}) async {
    final res = await _api.post('/car-pool/$id/complete', data: {if (distanceTravelled != null) 'distanceTravelled': distanceTravelled});
    return _map(res.data['data']);
  }

  Future<Map<String, dynamic>> earnings() async {
    final res = await _api.get('/car-pool/earnings');
    return _map(res.data['data']);
  }

  // ── Passenger ──
  Future<List<Map<String, dynamic>>> available({String? from, String? to, String? date}) async {
    final res = await _api.get('/car-pool/available', params: {
      if (from != null && from.isNotEmpty) 'from': from,
      if (to != null && to.isNotEmpty) 'to': to,
      if (date != null && date.isNotEmpty) 'date': date,
    });
    return _list(res.data['data']);
  }

  Future<Map<String, dynamic>> book(String id, int seats, {String? pickupPoint}) async {
    final res = await _api.post('/car-pool/$id/book', data: {'seats': seats, if (pickupPoint != null && pickupPoint.isNotEmpty) 'pickupPoint': pickupPoint});
    return _map(res.data['data']);
  }

  Future<List<Map<String, dynamic>>> myBookings() async {
    final res = await _api.get('/car-pool/my-bookings');
    return _list(res.data['data']);
  }

  Future<void> cancelBooking(String id) async {
    await _api.post('/car-pool/$id/cancel-booking');
  }

  Future<void> rate(String id, double rating, {String? review}) async {
    await _api.post('/car-pool/$id/rate', data: {'rating': rating, if (review != null && review.isNotEmpty) 'review': review});
  }

  // ── Shared ──
  Future<Map<String, dynamic>> getRide(String id) async {
    final res = await _api.get('/car-pool/$id');
    return _map(res.data['data']);
  }

  Map<String, dynamic> _map(dynamic v) => (v is Map) ? Map<String, dynamic>.from(v) : <String, dynamic>{};
  List<Map<String, dynamic>> _list(dynamic v) =>
      (v is List) ? v.map((e) => Map<String, dynamic>.from(e as Map)).toList() : <Map<String, dynamic>>[];
}
