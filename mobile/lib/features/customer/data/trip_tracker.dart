import 'dart:async';
import 'dart:io';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/di/injection.dart';
import '../../../core/network/api_client.dart';

/// Measures the driver's ACTUAL travelled distance for an ongoing customer trip
/// using GPS, and reports the running total to the backend. "Smart" move-based:
/// a new fix is only delivered after ~25 m of movement, poor-accuracy fixes and
/// GPS glitches are ignored, so km stay accurate and the battery stays sane. Runs
/// as a foreground service (persistent notification) so it keeps counting in the
/// background / screen-off during the trip.
///
/// Resilient to interruptions:
/// - GPS switched off / signal lost, then back on later: the gap is measured by
///   speed (distance ÷ time), not by a fixed distance cap. A believable driving
///   gap (e.g. 20 km over 30 min while GPS was off) is COUNTED as straight-line
///   distance; only physically-impossible teleports (a bad fix) are dropped.
/// - App killed / phone restarted mid-trip: the running total and last position
///   are persisted to disk, so [resumeIfActive]/[start] pick up where they left
///   off instead of restarting from zero. The backend also keeps the MAX of what
///   it receives, so a stale lower value can never reduce the recorded distance.
class TripTracker {
  TripTracker._();
  static final TripTracker instance = TripTracker._();

  final _api = getIt<ApiClient>();
  StreamSubscription<Position>? _sub;
  Timer? _pushTimer;
  String? _bookingId;
  Position? _last;
  double _km = 0;
  int _consecutiveDrops = 0; // implausible fixes in a row → resync a stale _last

  // Persisted-state keys (survive an app kill / phone restart mid-trip).
  static const _kId = 'trip_track_booking_id';
  static const _kKm = 'trip_track_km';
  static const _kLat = 'trip_track_last_lat';
  static const _kLng = 'trip_track_last_lng';
  static const _kTs = 'trip_track_last_ts';

  // A gap between two fixes is counted only if the implied straight-line speed is
  // physically believable for a road vehicle. Straight-line is always shorter
  // than the real road distance, so a generous cap still rejects only teleports.
  static const double _maxSpeedMps = 45; // ~162 km/h straight-line
  static const double _minSegmentM = 10; // ignore sub-10 m GPS jitter

  bool get isTracking => _bookingId != null;
  String? get currentBookingId => _bookingId;
  double get km => _km;

  /// Start (or resume) tracking a trip. Returns false if location permission is
  /// unavailable. If the persisted state is for the SAME booking, the running
  /// total and last position are restored so a mid-trip app restart continues
  /// from where it stopped instead of resetting to zero.
  Future<bool> start(String bookingId) async {
    if (_bookingId == bookingId) return true;
    await _stopStreamOnly();

    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return false;

    _bookingId = bookingId;
    await _restoreFor(bookingId); // sets _km / _last from disk if same booking, else 0

    final LocationSettings settings = Platform.isAndroid
        ? AndroidSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 25, // metres — move-based updates
            foregroundNotificationConfig: const ForegroundNotificationConfig(
              notificationTitle: 'Trip in progress',
              notificationText: 'Gora is recording your trip distance',
              enableWakeLock: true,
            ),
          )
        : const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 25);

    _sub = Geolocator.getPositionStream(locationSettings: settings).listen(_onPosition, onError: (_) {});
    // Report the running total to the server periodically (and on stop).
    _pushTimer = Timer.periodic(const Duration(seconds: 30), (_) => _push());
    return true;
  }

  /// Re-attach the tracker to a still-ongoing trip after an app relaunch. Safe to
  /// call on app/driver-home start: it only acts if disk state names a booking
  /// and nothing is currently tracking. Pass the ongoing booking id when known
  /// (from the server) to prefer it over stale disk state.
  Future<void> resumeIfActive({String? ongoingBookingId}) async {
    if (_bookingId != null) return; // already tracking
    final id = ongoingBookingId ?? (await SharedPreferences.getInstance()).getString(_kId);
    if (id == null || id.isEmpty) return;
    await start(id);
  }

  Future<void> _onPosition(Position p) async {
    if (p.accuracy > 50) return; // ignore noisy fixes (drift inflates distance)
    if (_last == null) {
      _last = p; // first fix — nothing to measure yet
      _save();
      return;
    }
    final metres = Geolocator.distanceBetween(_last!.latitude, _last!.longitude, p.latitude, p.longitude);
    if (metres < _minSegmentM) return; // sub-10 m jitter → keep the last good point

    // Normal move-based segments (≤3 km) are counted directly. A LARGER jump is
    // either real travel while GPS was off (believable speed over the elapsed
    // time) or a teleport glitch (impossible speed) — count the former, drop the
    // latter, so a 20 km gap during signal loss is not lost.
    final normal = metres <= 3000;
    final dtSec = (p.timestamp.millisecondsSinceEpoch - _last!.timestamp.millisecondsSinceEpoch) / 1000.0;
    final speed = metres / (dtSec > 0 ? dtSec : 1);
    final plausibleGap = metres > 3000 && speed <= _maxSpeedMps;
    if (!normal && !plausibleGap) {
      // Implausible jump (GPS glitch, or a gap we can't trust). Drop the distance
      // so a bad fix can't inflate it. A SINGLE outlier is ignored while keeping
      // the last good point — but if fixes keep failing, _last is stale (e.g. the
      // driver really moved far during a GPS gap at speed), so resync to the
      // current fix. Without this the tracker freezes for the rest of the trip:
      // every later fix is measured from the frozen point and also looks like a
      // teleport. We lose only the untrusted gap's distance, not all of it.
      if (++_consecutiveDrops >= 2) {
        _last = p;
        _consecutiveDrops = 0;
        _save();
      }
      return;
    }
    _consecutiveDrops = 0;

    final from = _last!;
    _last = p; // advance immediately so live tracking keeps flowing during the await
    if (normal) {
      _km += metres / 1000.0;
    } else {
      // Signal-loss gap: bill the ACTUAL ROAD distance Google would drive between
      // the two points (handles rivers/one-ways/detours a straight line misses),
      // falling back to straight-line only if the road lookup is unavailable.
      final road = await _roadKm(from, p);
      _km += road ?? (metres / 1000.0);
    }
    _save(); // persist so a mid-trip kill doesn't lose progress
  }

  /// Google Directions road distance (km) between two points, or null on failure.
  Future<double?> _roadKm(Position from, Position to) async {
    try {
      final res = await _api.get('/places/route', params: {
        'points': '${from.latitude},${from.longitude};${to.latitude},${to.longitude}',
      });
      final km = (res.data['data']?['distanceKm'] as num?)?.toDouble() ?? 0;
      return km > 0 ? km : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _push() async {
    final id = _bookingId;
    if (id == null) return;
    try {
      await _api.post('/customer-bookings/$id/track', data: {'km': double.parse(_km.toStringAsFixed(2))});
    } catch (_) {}
  }

  /// Stop tracking and flush the final distance, then clear persisted state.
  Future<void> stop() async {
    await _stopStreamOnly();
    if (_bookingId != null) await _push();
    _bookingId = null;
    _last = null;
    _km = 0;
    await _clear();
  }

  /// Tear down the stream + timer without touching the running total or disk
  /// state (used when (re)starting so a resume can restore its progress).
  Future<void> _stopStreamOnly() async {
    await _sub?.cancel();
    _sub = null;
    _pushTimer?.cancel();
    _pushTimer = null;
  }

  Future<void> _restoreFor(String bookingId) async {
    _km = 0;
    _last = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(_kId) != bookingId) return; // different/empty → fresh start
      _km = prefs.getDouble(_kKm) ?? 0;
      final lat = prefs.getDouble(_kLat);
      final lng = prefs.getDouble(_kLng);
      final ts = prefs.getInt(_kTs);
      if (lat != null && lng != null) {
        _last = Position(
          latitude: lat,
          longitude: lng,
          timestamp: DateTime.fromMillisecondsSinceEpoch(ts ?? DateTime.now().millisecondsSinceEpoch),
          accuracy: 1,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
        );
      }
    } catch (_) {}
  }

  Future<void> _save() async {
    final id = _bookingId;
    if (id == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kId, id);
      await prefs.setDouble(_kKm, _km);
      if (_last != null) {
        await prefs.setDouble(_kLat, _last!.latitude);
        await prefs.setDouble(_kLng, _last!.longitude);
        await prefs.setInt(_kTs, _last!.timestamp.millisecondsSinceEpoch);
      }
    } catch (_) {}
  }

  Future<void> _clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kId);
      await prefs.remove(_kKm);
      await prefs.remove(_kLat);
      await prefs.remove(_kLng);
      await prefs.remove(_kTs);
    } catch (_) {}
  }
}
