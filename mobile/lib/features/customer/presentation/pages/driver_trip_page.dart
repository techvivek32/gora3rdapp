import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:slide_to_act/slide_to_act.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/contact_launcher.dart';
import '../../data/customer_repository.dart';
import '../../data/trip_tracker.dart';
import 'driver_trip_summary_page.dart';

/// One turn-by-turn navigation step from the Directions API.
class _NavStep {
  final String instruction;
  final String maneuver;
  final double distanceM;
  final double durationS;
  final LatLng end;
  _NavStep(this.instruction, this.maneuver, this.distanceM, this.durationS, this.end);
}

/// Full-screen turn-by-turn driver navigation: 3D follow-camera, a rotating car
/// marker, a live route polyline to the pickup (then the drop), a Google-Maps
/// style instruction banner, live ETA/distance, "Navigate" hand-off, and
/// swipe-to-confirm for Arrive → Start (OTP) → Complete (OTP) → summary.
class DriverTripPage extends StatefulWidget {
  final Map<String, dynamic> booking;
  const DriverTripPage({super.key, required this.booking});

  @override
  State<DriverTripPage> createState() => _DriverTripPageState();
}

class _DriverTripPageState extends State<DriverTripPage> with SingleTickerProviderStateMixin {
  final _repo = getIt<CustomerRepository>();
  final _api = getIt<ApiClient>();
  final GlobalKey<SlideActionState> _slideKey = GlobalKey();

  late Map<String, dynamic> _b;
  late String _status;
  bool _arrived = false;
  bool _busy = false;

  GoogleMapController? _map;
  StreamSubscription<Position>? _posSub;
  LatLng? _driver;
  double _bearing = 0;
  BitmapDescriptor? _carIcon;

  // Smooth-motion animation: the raw GPS fixes set a target; a per-frame ticker
  // glides the displayed car (and camera) toward it so there are no jumps.
  Ticker? _ticker;
  LatLng? _animPos; // currently displayed position
  LatLng? _targetPos; // latest GPS fix to glide toward
  double _targetBearing = 0;
  Duration _lastRender = Duration.zero;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  // Turn-by-turn state.
  List<_NavStep> _steps = [];
  int _stepIndex = 0;
  double _remainingKm = 0;
  int _remainingSec = 0;
  double _distToTurnKm = 0;

  // Route geometry for snapping progress to the road (consume travelled path,
  // correct step tracking, accurate ETA).
  List<LatLng> _route = [];
  List<double> _cum = []; // cumulative metres along _route
  List<int> _stepEndIdx = []; // _route index of each step's end point
  double _totalDist = 0; // metres
  double _totalDur = 0; // seconds
  int _nearestIdx = 0; // driver's nearest vertex on _route

  // Camera follow: nav always auto-follows the car.
  bool _following = true;

  String get _id => (_b['_id'] ?? _b['id'] ?? '').toString();

  LatLng? _ll(Map? m) {
    final lat = (m?['lat'] as num?)?.toDouble() ?? 0;
    final lng = (m?['lng'] as num?)?.toDouble() ?? 0;
    return (lat != 0 && lng != 0) ? LatLng(lat, lng) : null;
  }

  LatLng? get _pickup => _ll(_b['pickup'] as Map?);
  LatLng? get _drop => _ll(_b['drop'] as Map?);
  LatLng? get _dest => _status == 'ongoing' ? _drop : _pickup;
  String get _destLabel => _status == 'ongoing' ? 'Drop' : 'Pickup';
  String get _destAddr => (((_status == 'ongoing' ? _b['drop'] : _b['pickup']) as Map?)?['address'] ?? '').toString();
  String get _custName => (((_b['customer'] as Map?)?['name']) ?? (_b['driverSnapshot'] as Map?)?['name'] ?? 'Customer').toString();
  String get _custMobile => (((_b['customer'] as Map?)?['mobile']) ?? '').toString();

  @override
  void initState() {
    super.initState();
    _b = Map<String, dynamic>.from(widget.booking);
    _status = (_b['status'] ?? 'confirmed').toString();
    _arrived = _b['driverArrivedAt'] != null;
    _buildCarIcon();
    _buildMarkers();
    _startLocation();
    _fetchRoute();
    _ticker = createTicker(_onTick)..start();
    if (_status == 'ongoing') TripTracker.instance.resumeIfActive(ongoingBookingId: _id);
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _posSub?.cancel();
    _map?.dispose();
    super.dispose();
  }

  // ── 3D-look car marker drawn at runtime (a 2.5D extruded car viewed from
  // behind-above). Used as a billboard (flat:false) so it always stands up on the
  // tilted map and points in the direction of travel, like Google Maps nav. ──
  Future<void> _buildCarIcon() async {
    try {
      const s = 170.0;
      const cx = 85.0, cy = 82.0;
      const depth = 14.0; // extrusion height → the 3D look
      const bw = 60.0, bh = 118.0; // body footprint
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);

      RRect bodyAt(double dy) => RRect.fromRectAndCorners(
            Rect.fromCenter(center: Offset(cx, cy + dy), width: bw, height: bh),
            topLeft: const Radius.circular(28),
            topRight: const Radius.circular(28),
            bottomLeft: const Radius.circular(22),
            bottomRight: const Radius.circular(22),
          );

      // Ground shadow (soft, offset toward the viewer).
      c.drawOval(
        Rect.fromCenter(center: const Offset(cx + 4, cy + depth + 10), width: 74, height: 112),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.20)
          ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 6),
      );

      // Wheels (dark, given height so they read as 3D tyres).
      final wheel = Paint()..color = const Color(0xFF14161B);
      void drawWheel(double dx, double dy) {
        c.drawRRect(
          RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx + dx, cy + dy + depth / 2), width: 12, height: 30), const Radius.circular(6)),
          wheel,
        );
      }
      drawWheel(-31, -30);
      drawWheel(31, -30);
      drawWheel(-31, 30);
      drawWheel(31, 30);

      // Extruded side walls (darker body, offset down = the car's height).
      c.drawRRect(bodyAt(depth), Paint()..color = const Color(0xFF0B3E86));

      // Top face with a vertical gradient (lit from the front) + white rim.
      final topRR = bodyAt(0);
      c.drawRRect(
        topRR,
        Paint()
          ..shader = ui.Gradient.linear(
            const Offset(cx, cy - bh / 2),
            const Offset(cx, cy + bh / 2),
            const [Color(0xFF57A0FF), Color(0xFF1466C4)],
          ),
      );
      c.drawRRect(topRR, Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4);

      // Glass canopy (dark), with a glossy windshield + rear window.
      c.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: const Offset(cx, cy + 2), width: 42, height: 74), const Radius.circular(16)),
        Paint()..color = const Color(0xFF0E2338),
      );
      final windshield = Path()
        ..moveTo(cx - 17, cy - 30)
        ..lineTo(cx + 17, cy - 30)
        ..lineTo(cx + 20, cy - 8)
        ..lineTo(cx - 20, cy - 8)
        ..close();
      c.drawPath(
        windshield,
        Paint()
          ..shader = ui.Gradient.linear(const Offset(cx, cy - 30), const Offset(cx, cy - 8), const [Color(0xFFAFD6FF), Color(0xFF5B87AE)]),
      );
      final rearWin = Path()
        ..moveTo(cx - 20, cy + 12)
        ..lineTo(cx + 20, cy + 12)
        ..lineTo(cx + 17, cy + 32)
        ..lineTo(cx - 17, cy + 32)
        ..close();
      c.drawPath(rearWin, Paint()..color = const Color(0xFF33566F));
      // Roof highlight strip.
      c.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: const Offset(cx, cy + 2), width: 34, height: 7), const Radius.circular(4)),
        Paint()..color = Colors.white.withValues(alpha: 0.18),
      );

      // Head lights (front) + tail lights (rear).
      final head = Paint()..color = const Color(0xFFFFF6D6);
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: const Offset(cx - 17, cy - 54), width: 12, height: 8), const Radius.circular(3)), head);
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: const Offset(cx + 17, cy - 54), width: 12, height: 8), const Radius.circular(3)), head);
      final tail = Paint()..color = const Color(0xFFFF5252);
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: const Offset(cx - 17, cy + 55), width: 12, height: 7), const Radius.circular(3)), tail);
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: const Offset(cx + 17, cy + 55), width: 12, height: 7), const Radius.circular(3)), tail);

      final img = await rec.endRecording().toImage(s.toInt(), s.toInt());
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null || !mounted) return;
      setState(() {
        // 170px / 2.05 ≈ 83dp — a clear, prominent 3D car.
        _carIcon = BitmapDescriptor.bytes(bytes.buffer.asUint8List(), imagePixelRatio: 2.05);
        _buildMarkers();
      });
    } catch (_) {}
  }

  Future<void> _startLocation() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition();
      _onPos(pos, first: true);
      _posSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 8),
      ).listen((p) => _onPos(p));
    } catch (_) {}
  }

  void _onPos(Position p, {bool first = false}) {
    if (!mounted) return;
    final d = LatLng(p.latitude, p.longitude);
    // Set the direction to face (from GPS heading, else from movement).
    final prev = _targetPos ?? _driver;
    if (p.speed > 0.5 && p.heading >= 0) {
      _targetBearing = p.heading;
    } else if (prev != null && _distanceM(prev, d) > 1.5) {
      _targetBearing = _bearingBetween(prev, d);
    }
    _targetPos = d; // the ticker glides _animPos toward this — no teleport
    if (first || _animPos == null) {
      _animPos = d;
      _driver = d;
      _bearing = _targetBearing;
    }
    if (first) _fetchRoute();
  }

  /// Per-frame smoothing: glide the displayed car + camera toward the latest GPS
  /// fix so motion is continuous (no jumping between fixes), like Google Maps.
  void _onTick(Duration elapsed) {
    if (!mounted || _targetPos == null) return;
    _animPos ??= _targetPos;
    // Exponential glide toward the target (≈catches up within ~1s at 60fps).
    const f = 0.12;
    final np = LatLng(
      _animPos!.latitude + (_targetPos!.latitude - _animPos!.latitude) * f,
      _animPos!.longitude + (_targetPos!.longitude - _animPos!.longitude) * f,
    );
    final moved = _distanceM(_animPos!, np);
    _animPos = np;
    _bearing = _lerpAngle(_bearing, _targetBearing, f);
    final bDiff = (((_targetBearing - _bearing + 540) % 360) - 180).abs();

    // Idle when parked (nothing to render) to save the emulator/battery.
    if (moved < 0.08 && bDiff < 0.4) return;
    // Render at ~30fps (position keeps interpolating every frame regardless).
    if (elapsed - _lastRender < const Duration(milliseconds: 33)) return;
    _lastRender = elapsed;

    _driver = _animPos;
    _updateProgress(_animPos!);
    _buildMarkers();
    setState(() {});
    if (_following && _map != null) {
      _map!.moveCamera(CameraUpdate.newCameraPosition(
        CameraPosition(target: _animPos!, zoom: 18.4, tilt: 60, bearing: _bearing),
      ));
    }
  }

  /// Shortest-path angle interpolation (degrees), so heading wraps cleanly at 360.
  double _lerpAngle(double a, double b, double t) {
    var diff = (b - a) % 360;
    if (diff > 180) diff -= 360;
    if (diff < -180) diff += 360;
    return (a + diff * t + 360) % 360;
  }

  void _followCamera(LatLng d) {
    if (!_following || _map == null) return;
    // A glide slightly longer than the GPS update interval keeps motion continuous.
    // Closer zoom + tilt gives a proper turn-by-turn navigation view.
    _map!.animateCamera(
      CameraUpdate.newCameraPosition(CameraPosition(target: d, zoom: 18.4, tilt: 60, bearing: _bearing)),
      duration: const Duration(milliseconds: 900),
    );
  }

  double _bearingBetween(LatLng a, LatLng b) {
    final lat1 = a.latitude * math.pi / 180, lat2 = b.latitude * math.pi / 180;
    final dLon = (b.longitude - a.longitude) * math.pi / 180;
    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) - math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  double _distanceM(LatLng a, LatLng b) =>
      Geolocator.distanceBetween(a.latitude, a.longitude, b.latitude, b.longitude);

  List<double> _buildCumulative(List<LatLng> pts) {
    final c = List<double>.filled(pts.length, 0);
    for (int i = 1; i < pts.length; i++) {
      c[i] = c[i - 1] + _distanceM(pts[i - 1], pts[i]);
    }
    return c;
  }

  /// Index of the nearest route vertex to [p]. Progress is monotonic, so search a
  /// forward window from the last position (falls back to a full scan on jumps).
  int _nearestRouteIndex(LatLng p) {
    if (_route.isEmpty) return 0;
    int best = _nearestIdx;
    double bd = double.infinity;
    final start = (_nearestIdx - 2).clamp(0, _route.length - 1);
    final end = math.min(_route.length, _nearestIdx + 80);
    for (int i = start; i < end; i++) {
      final d = _distanceM(_route[i], p);
      if (d < bd) {
        bd = d;
        best = i;
      }
    }
    // If the windowed best is still far (a GPS jump), scan the whole route once.
    if (bd > 120) {
      for (int i = 0; i < _route.length; i++) {
        final d = _distanceM(_route[i], p);
        if (d < bd) {
          bd = d;
          best = i;
        }
      }
    }
    return best;
  }

  /// Snap the driver onto the route to drive step tracking, remaining ETA/distance
  /// (all from real road geometry) and to consume the travelled part of the line.
  void _updateProgress(LatLng d) {
    if (_route.isEmpty || _cum.isEmpty) return;
    _nearestIdx = _nearestRouteIndex(d);
    final travelled = _cum[_nearestIdx];
    final remaining = (_totalDist - travelled).clamp(0, _totalDist).toDouble();
    _remainingKm = remaining / 1000.0;
    _remainingSec = _totalDist > 0 ? (_totalDur * remaining / _totalDist).round() : 0;
    // Current step = the one whose maneuver point (end) is still ahead of us.
    int k = 0;
    while (k < _stepEndIdx.length - 1 && _stepEndIdx[k] <= _nearestIdx) {
      k++;
    }
    _stepIndex = k;
    if (k < _stepEndIdx.length) {
      final turnAt = _cum[_stepEndIdx[k].clamp(0, _cum.length - 1)];
      _distToTurnKm = ((turnAt - travelled).clamp(0, _totalDist)) / 1000.0;
    } else {
      _distToTurnKm = _remainingKm;
    }
    _updateTrimmedPolyline();
  }

  /// Draw the travelled part faint-grey and the road ahead bright-blue, so the
  /// blue line is "consumed" as the driver passes each point (like Google Maps).
  void _updateTrimmedPolyline() {
    if (_route.isEmpty) return;
    final idx = _nearestIdx.clamp(0, _route.length - 1);
    // Start the "ahead" line at the NEXT vertex (idx+1) — the nearest vertex may
    // be slightly behind the driver, which would draw a short backward kink.
    final fwd = (idx + 1).clamp(0, _route.length);
    final ahead = <LatLng>[if (_driver != null) _driver!, ..._route.sublist(fwd)];
    final behind = _route.sublist(0, fwd);
    _polylines
      ..clear()
      ..add(Polyline(
        polylineId: const PolylineId('route-done'),
        points: behind,
        color: const Color(0x668A9AA8),
        width: 8,
        jointType: JointType.round,
      ))
      ..add(Polyline(
        polylineId: const PolylineId('route'),
        points: ahead,
        color: const Color(0xFF1A73E8),
        width: 9,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        jointType: JointType.round,
      ));
  }

  void _buildMarkers() {
    _markers.clear();
    if (_driver != null) {
      _markers.add(Marker(
        markerId: const MarkerId('driver'),
        position: _driver!,
        icon: _carIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        // Billboard: the map rotates with the heading (camera bearing), so the car
        // stands upright and always points "forward" up the screen — a 3D look.
        rotation: 0,
        anchor: const Offset(0.5, 0.5),
        flat: false,
      ));
    }
    final dest = _dest;
    if (dest != null) {
      _markers.add(Marker(
        markerId: const MarkerId('dest'),
        position: dest,
        infoWindow: InfoWindow(title: _destLabel, snippet: _destAddr),
      ));
    }
  }

  Future<void> _fetchRoute() async {
    final origin = _driver ?? _pickup;
    final dest = _dest;
    if (origin == null || dest == null) return;
    try {
      final res = await _api.get('/places/route', params: {
        'points': '${origin.latitude},${origin.longitude};${dest.latitude},${dest.longitude}',
      });
      final data = res.data['data'] ?? {};
      final pts = (data['points'] as List?) ?? [];
      final line = pts
          .whereType<Map>()
          .map((e) => LatLng((e['lat'] as num).toDouble(), (e['lng'] as num).toDouble()))
          .toList();
      final steps = ((data['steps'] as List?) ?? [])
          .whereType<Map>()
          .map((s) => _NavStep(
                (s['instruction'] ?? '').toString(),
                (s['maneuver'] ?? '').toString(),
                (s['distanceM'] as num?)?.toDouble() ?? 0,
                (s['durationS'] as num?)?.toDouble() ?? 0,
                LatLng((s['endLat'] as num?)?.toDouble() ?? 0, (s['endLng'] as num?)?.toDouble() ?? 0),
              ))
          .toList();
      if (!mounted) return;
      setState(() {
        _steps = steps;
        _stepIndex = 0;
        _route = line;
        _cum = _buildCumulative(line);
        _totalDist = _cum.isNotEmpty ? _cum.last : 0;
        _totalDur = (data['durationSeconds'] as num?)?.toDouble() ?? 0;
        _nearestIdx = 0;
        // Map each step's end point to its nearest vertex on the route line.
        _stepEndIdx = steps.map((s) {
          int best = 0;
          double bd = double.infinity;
          for (int i = 0; i < line.length; i++) {
            final dd = _distanceM(line[i], s.end);
            if (dd < bd) {
              bd = dd;
              best = i;
            }
          }
          return best;
        }).toList();
        _remainingKm = _totalDist / 1000.0;
        _remainingSec = _totalDur.round();
        _distToTurnKm = _remainingKm;
        if (line.isNotEmpty) {
          _polylines
            ..clear()
            ..add(Polyline(
              polylineId: const PolylineId('route'),
              points: line,
              color: const Color(0xFF1A73E8),
              width: 9,
              startCap: Cap.roundCap,
              endCap: Cap.roundCap,
              jointType: JointType.round,
            ));
        }
      });
      if (_driver != null) _updateProgress(_driver!);
      if (!_following && line.isNotEmpty) _fitBounds([...line, if (_driver != null) _driver!]);
    } catch (_) {}
  }

  void _fitBounds(List<LatLng> pts) {
    if (_map == null || pts.isEmpty) return;
    double minLat = pts.first.latitude, maxLat = pts.first.latitude, minLng = pts.first.longitude, maxLng = pts.first.longitude;
    for (final p in pts) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    _map!.animateCamera(CameraUpdate.newLatLngBounds(
      LatLngBounds(southwest: LatLng(minLat, minLng), northeast: LatLng(maxLat, maxLng)),
      70,
    ));
  }

  void _recenter() {
    setState(() => _following = true);
    if (_driver != null) _followCamera(_driver!);
  }

  Future<void> _navigate() async {
    final dest = _dest;
    if (dest == null) return;
    final nav = Uri.parse('google.navigation:q=${dest.latitude},${dest.longitude}&mode=d');
    try {
      await launchUrl(nav, mode: LaunchMode.externalApplication);
    } catch (_) {
      await launchUrl(
        Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${dest.latitude},${dest.longitude}&travelmode=driving'),
        mode: LaunchMode.externalApplication,
      );
    }
  }

  void _snack(String m, {bool ok = false}) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(m), backgroundColor: ok ? AppColors.success : AppColors.error, behavior: SnackBarBehavior.floating));

  String _clean(Object e) => e.toString().replaceFirst('Exception: ', '');

  Future<void> _arrive() async {
    setState(() => _busy = true);
    try {
      await _repo.driverArrived(_id);
      if (!mounted) return;
      setState(() {
        _arrived = true;
        _busy = false;
      });
      _snack('Customer notified you have arrived 🚗', ok: true);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _slideKey.currentState?.reset();
        _snack('Could not notify: ${_clean(e)}');
      }
    }
  }

  Future<String?> _askOtp(String action) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(action == 'start' ? 'Start Trip OTP' : 'Complete Trip OTP', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Ask the customer for the 6-digit OTP they received, and enter it here.', style: TextStyle(fontSize: 12.5.sp, color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            maxLength: 6,
            autofocus: true,
            style: const TextStyle(fontSize: 20, letterSpacing: 6, fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
            decoration: const InputDecoration(counterText: '', hintText: '● ● ● ● ● ●'),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Verify')),
        ],
      ),
    );
  }

  Future<void> _otpTransition(String action) async {
    setState(() => _busy = true);
    try {
      await _repo.requestTripOtp(_id, action);
      if (!mounted) return;
      setState(() => _busy = false);
      _snack('OTP sent to the customer', ok: true);
      final otp = await _askOtp(action);
      if (otp == null || otp.isEmpty) {
        _slideKey.currentState?.reset();
        return;
      }
      setState(() => _busy = true);
      final updated = await _repo.verifyTripOtp(_id, action, otp);
      if (!mounted) return;
      if (action == 'start') {
        TripTracker.instance.start(_id);
        setState(() {
          _status = 'ongoing';
          _b['status'] = 'ongoing';
          _busy = false;
          _following = true;
          _buildMarkers();
        });
        _fetchRoute(); // re-route to the drop with fresh turn-by-turn steps
        _snack('Trip started 🚀', ok: true);
      } else {
        TripTracker.instance.stop();
        final b = updated ?? _b;
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => DriverTripSummaryPage(booking: b)));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _slideKey.currentState?.reset();
        _snack('Failed: ${_clean(e)}');
      }
    }
  }

  IconData _maneuverIcon(String m) {
    switch (m) {
      case 'turn-left':
        return Icons.turn_left;
      case 'turn-right':
        return Icons.turn_right;
      case 'turn-slight-left':
        return Icons.turn_slight_left;
      case 'turn-slight-right':
        return Icons.turn_slight_right;
      case 'turn-sharp-left':
        return Icons.turn_sharp_left;
      case 'turn-sharp-right':
        return Icons.turn_sharp_right;
      case 'uturn-left':
      case 'uturn-right':
        return Icons.u_turn_left;
      case 'ramp-left':
      case 'fork-left':
      case 'keep-left':
        return Icons.fork_left;
      case 'ramp-right':
      case 'fork-right':
      case 'keep-right':
        return Icons.fork_right;
      case 'merge':
        return Icons.merge;
      case 'roundabout-left':
      case 'roundabout-right':
      case 'rotary-left':
      case 'rotary-right':
        return Icons.roundabout_left;
      case 'arrive':
        return Icons.place_rounded;
      default:
        return Icons.straight;
    }
  }

  /// Renders a maneuver icon. India drives on the left, so roundabouts circulate
  /// clockwise — the Material glyph reads counter-clockwise, so we mirror it.
  Widget _maneuverWidget(String m, double size, Color color) {
    final w = Icon(_maneuverIcon(m), size: size, color: color);
    final isRoundabout = m.startsWith('roundabout') || m.startsWith('rotary');
    return isRoundabout ? Transform.scale(scaleX: -1, child: w) : w;
  }

  String _fmtDist(double km) => km >= 1 ? '${km.toStringAsFixed(km >= 10 ? 0 : 1)} km' : '${(km * 1000).round()} m';

  String _fmtEta(int sec) {
    final min = (sec / 60).round();
    if (min < 60) return '$min min';
    final h = min ~/ 60, m = min % 60;
    return m == 0 ? '$h hr' : '$h hr $m min';
  }

  String _arrivalClock(int sec) {
    final t = DateTime.now().add(Duration(seconds: sec));
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final ap = t.hour < 12 ? 'am' : 'pm';
    return '$h:${t.minute.toString().padLeft(2, '0')} $ap';
  }

  @override
  Widget build(BuildContext context) {
    final start = _pickup ?? _drop ?? const LatLng(22.3039, 70.8022);
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: start, zoom: 16.5),
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            compassEnabled: false,
            buildingsEnabled: false, // flat map so the car + route are never hidden behind 3D buildings
            // Large top inset pushes the camera target (car) into the lower third,
            // so more of the road ahead is visible — like a real nav view.
            padding: EdgeInsets.only(top: 560.h, bottom: 300.h),
            onMapCreated: (c) {
              _map = c;
              if (_driver != null) {
                _followCamera(_driver!);
              } else if (_polylines.isNotEmpty) {
                _fitBounds(_polylines.first.points);
              }
            },
            // Nav always auto-follows the car; per-frame camera moves make reliable
            // user-pan detection impossible, so we keep follow on for a stable view.
          ),
          _instructionBanner(),
          Positioned(top: 0, left: 0, child: SafeArea(child: Padding(padding: EdgeInsets.all(8.w), child: _circleBtn(Icons.arrow_back_rounded, () => Navigator.pop(context))))),
          Positioned(
            right: 12.w,
            bottom: 250.h,
            child: Column(children: [
              _circleBtn(Icons.navigation_rounded, _navigate, color: AppColors.info),
              if (!_following) ...[
                SizedBox(height: 10.h),
                _recenterBtn(),
              ],
            ]),
          ),
          Align(alignment: Alignment.bottomCenter, child: _bottomSheet()),
        ],
      ),
    );
  }

  Widget _instructionBanner() {
    final next = _stepIndex + 1 < _steps.length ? _steps[_stepIndex + 1] : null;
    final then = _stepIndex + 2 < _steps.length ? _steps[_stepIndex + 2] : null;
    final arriving = next == null;
    final primaryText = arriving ? 'Arrive at $_destLabel' : next.instruction;
    final maneuver = arriving ? 'arrive' : next.maneuver;
    final distToTurn = _distToTurnKm;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(64.w, 8.h, 12.w, 0),
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                decoration: BoxDecoration(
                  color: const Color(0xFF15616D),
                  borderRadius: BorderRadius.circular(14.r),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8)],
                ),
                child: Row(children: [
                  _maneuverWidget(maneuver, 34.sp, Colors.white),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      if (!arriving)
                        Text(_fmtDist(distToTurn), style: TextStyle(color: Colors.white70, fontSize: 12.sp, fontWeight: FontWeight.w600, fontFamily: 'Poppins')),
                      Text(primaryText,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.white, fontSize: 15.sp, fontWeight: FontWeight.w800, fontFamily: 'Poppins', height: 1.15)),
                    ]),
                  ),
                ]),
              ),
              if (then != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    margin: EdgeInsets.only(top: 2.h),
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 5.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0E4750),
                      borderRadius: BorderRadius.vertical(bottom: Radius.circular(12.r)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text('Then ', style: TextStyle(color: Colors.white, fontSize: 12.sp, fontWeight: FontWeight.w700, fontFamily: 'Poppins')),
                      _maneuverWidget(then.maneuver, 18.sp, Colors.white),
                    ]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _circleBtn(IconData icon, VoidCallback onTap, {Color? color}) => Material(
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 3,
        child: InkWell(customBorder: const CircleBorder(), onTap: onTap, child: Padding(padding: EdgeInsets.all(10.w), child: Icon(icon, color: color ?? AppColors.textPrimary, size: 22.sp))),
      );

  Widget _recenterBtn() => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        elevation: 3,
        child: InkWell(
          borderRadius: BorderRadius.circular(24.r),
          onTap: _recenter,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.navigation_outlined, color: AppColors.info, size: 18.sp),
              SizedBox(width: 6.w),
              Text('Re-centre', style: TextStyle(color: AppColors.info, fontSize: 12.5.sp, fontWeight: FontWeight.w800, fontFamily: 'Poppins')),
            ]),
          ),
        ),
      );

  Widget _bottomSheet() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 12, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 12.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(_fmtEta(_remainingSec), style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w900, color: AppColors.success, fontFamily: 'Poppins')),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text('${_fmtDist(_remainingKm)} · ${_arrivalClock(_remainingSec)}',
                      style: TextStyle(fontSize: 12.5.sp, color: AppColors.textSecondary, fontFamily: 'Poppins')),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                  decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20.r)),
                  child: Text(_status == 'ongoing' ? 'To Drop' : (_arrived ? 'At Pickup' : 'To Pickup'),
                      style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w800, color: AppColors.primary, fontFamily: 'Poppins')),
                ),
              ]),
              SizedBox(height: 10.h),
              Container(
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12.r), border: Border.all(color: AppColors.border)),
                child: Row(children: [
                  Icon(_status == 'ongoing' ? Icons.flag_rounded : Icons.person_pin_circle_rounded, color: AppColors.primary, size: 22.sp),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_custName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontFamily: 'Poppins')),
                      Text(_destAddr.isEmpty ? _destLabel : _destAddr, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.sp, color: AppColors.textSecondary, fontFamily: 'Poppins')),
                    ]),
                  ),
                  if (_custMobile.isNotEmpty) ...[
                    _miniBtn(Icons.call_rounded, AppColors.success, () => callNumber(_custMobile)),
                    SizedBox(width: 8.w),
                    _miniBtn(Icons.chat_rounded, const Color(0xFF25D366), () => openWhatsApp(_custMobile)),
                  ],
                ]),
              ),
              SizedBox(height: 12.h),
              _slider(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniBtn(IconData icon, Color color, VoidCallback onTap) => Material(
        color: color.withValues(alpha: 0.12),
        shape: const CircleBorder(),
        child: InkWell(customBorder: const CircleBorder(), onTap: onTap, child: Padding(padding: EdgeInsets.all(8.w), child: Icon(icon, color: color, size: 18.sp))),
      );

  Widget _slider() {
    if (_busy) {
      return SizedBox(height: 56.h, child: const Center(child: CircularProgressIndicator(color: AppColors.primary)));
    }
    late String text;
    late Color color;
    late Future<void> Function() action;
    if (_status == 'ongoing') {
      text = 'Swipe to Complete Trip';
      color = AppColors.success;
      action = () => _otpTransition('end');
    } else if (_arrived) {
      text = 'Swipe to Start Trip';
      color = AppColors.primary;
      action = () => _otpTransition('start');
    } else {
      text = 'Swipe to Arrive';
      color = AppColors.info;
      action = _arrive;
    }
    return SlideAction(
      key: _slideKey,
      height: 56.h,
      borderRadius: 14.r,
      elevation: 0,
      innerColor: Colors.white,
      outerColor: color,
      sliderButtonIcon: Icon(Icons.chevron_right_rounded, color: color, size: 26.sp),
      text: text,
      textStyle: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w800, color: Colors.white, fontFamily: 'Poppins'),
      onSubmit: () async {
        await action();
        return null;
      },
    );
  }
}
