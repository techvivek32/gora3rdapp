import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/contact_launcher.dart';
import '../../data/customer_repository.dart';
import '../utils/invoice_actions.dart';
import '../widgets/booking_card_ui.dart';

/// The heart of Customer Mode: watch offers arrive, pick a driver, follow the
/// trip, and rate at the end. Customer NEVER sees a driver's wallet — only the
/// quoted fare and the driver's public profile.
class CustomerBookingDetailPage extends StatefulWidget {
  final String bookingId;
  const CustomerBookingDetailPage({super.key, required this.bookingId});

  @override
  State<CustomerBookingDetailPage> createState() => _CustomerBookingDetailPageState();
}

class _CustomerBookingDetailPageState extends State<CustomerBookingDetailPage> {
  final _repo = getIt<CustomerRepository>();
  final _api = getIt<ApiClient>();
  Map<String, dynamic>? _b;
  Map<String, dynamic>? _cat; // matched cab category (image + info tabs)
  int _mainTab = 0; // 0 = Trip Details, 1 = Inclusions, 2 = Exclusions
  bool _loading = true;
  bool _acting = false;
  String? _error;
  Timer? _poll;
  // After the trip completes, keep refreshing a few more times so the driver's
  // final toll/parking/other charges (added on their bill screen) show up here.
  int _completedPolls = 0;

  List<String> _infoList(String key) => ((_cat?[key] as List?) ?? []).map((e) => e.toString()).toList();

  /// Fetch the admin's cab categories once and match this booking's cab by name,
  /// so we can show its image + inclusions/exclusions/facilities/terms.
  Future<void> _loadCat(String name) async {
    try {
      final res = await _api.get('/home-content/cab-categories');
      final list = (res.data['data'] as List?) ?? [];
      final match = list.cast<Map>().firstWhere(
            (c) => (c['name'] ?? '').toString().toLowerCase() == name.toLowerCase(),
            orElse: () => const {},
          );
      if (mounted && match.isNotEmpty) setState(() => _cat = Map<String, dynamic>.from(match));
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _load();
    // Live-ish updates: pull new offers and the trip OTP while the booking is
    // still active, so the customer doesn't have to refresh by hand.
    _poll = Timer.periodic(const Duration(seconds: 12), (_) {
      if (_acting) return;
      final s = (_b?['status'] ?? '').toString();
      if (s == 'open' || s == 'confirmed' || s == 'ongoing') {
        _completedPolls = 0;
        _load();
      } else if (s == 'completed' && _completedPolls < 10) {
        // Grace window (~2 min) to pick up the driver's final charges, then stop.
        _completedPolls++;
        _load();
      }
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final b = await _repo.getBooking(widget.bookingId);
      if (!mounted) return;
      setState(() { _b = b; _loading = false; _error = null; });
      final cabName = (b['vehicleType'] ?? '').toString();
      if (cabName.isNotEmpty && _cat == null) _loadCat(cabName);
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = '$e'; _loading = false; });
    }
  }

  Future<void> _cancel() async {
    final ok = await _confirm('Cancel this booking?', 'This cannot be undone.');
    if (ok != true) return;
    setState(() => _acting = true);
    try {
      await _repo.cancelBooking(widget.bookingId);
      await _load();
      _snack('Booking cancelled');
    } catch (e) {
      _snack('Could not cancel: $e');
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _rate() async {
    final result = await showModalBottomSheet<(double, String)>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _RateSheet(),
    );
    if (result == null) return;
    setState(() => _acting = true);
    try {
      await _repo.rateBooking(widget.bookingId, result.$1, review: result.$2.isEmpty ? null : result.$2);
      await _load();
      _snack('Thanks for your feedback!', ok: true);
    } catch (e) {
      _snack('Could not submit rating: $e');
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<bool?> _confirm(String title, String body) => showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes')),
          ],
        ),
      );

  void _snack(String m, {bool ok = false}) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m), backgroundColor: ok ? AppColors.success : AppColors.error));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Booking Details'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        // Reached via go() from the form (stack replaced) → pop won't work, so
        // fall back to My Rides. From the list it's a push, so pop works.
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop() ? context.pop() : context.go('/customer/bookings'),
        ),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded))],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _b == null
              ? Center(child: Text(_error ?? 'Not found'))
              : RefreshIndicator(onRefresh: _load, child: _body()),
    );
  }

  Widget _body() {
    final b = _b!;
    final status = (b['status'] ?? '').toString();
    final offers = ((b['offers'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final snapshot = b['driverSnapshot'] as Map?;
    final date = tripDate(b['travelDate']);

    final tripOtp = (b['tripOtp'] ?? '').toString();
    final otpAction = (b['tripOtpAction'] ?? '').toString();
    final parsed = _parseNotes((b['notes'] ?? '').toString());

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _StatusBanner(status),
        if (tripOtp.isNotEmpty) ...[
          const SizedBox(height: 16),
          _otpCard(tripOtp, otpAction),
        ],
        const SizedBox(height: 16),
        _bookingIdHeader(b),
        const SizedBox(height: 12),
        // Trip Details / Inclusions / Exclusions tabs.
        _tripInfoTabs(b, date, parsed),
        const SizedBox(height: 16),

        // OPEN → drivers accept and our team assigns one. The customer no longer
        // picks a driver, so we just show a waiting note (offers stay hidden).
        if (status == 'open')
          _hint(offers.isEmpty
              ? 'Waiting for a driver to accept your booking… pull down to refresh.'
              : 'A driver has accepted — our team is assigning your driver. Pull down to refresh.'),

        // Confirmed / ongoing / completed → show the chosen driver.
        if (status != 'open' && snapshot != null) ...[
          const Text('Your Driver', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          _driverCard(snapshot, b),
        ],

        // Fare summary — Total / Advance paid / Remaining (always shown).
        const SizedBox(height: 16),
        _paymentBreakdownCard(b),

        // Cancellation terms — configurable by admin, shown before selecting.
        if ((b['cancellationPolicy'] ?? '').toString().isNotEmpty && (status == 'open' || status == 'confirmed')) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.warning),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Cancellation Policy', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(b['cancellationPolicy'].toString(), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ]),
              ),
            ]),
          ),
        ],

        const SizedBox(height: 20),
        _actions(status, b),
      ],
    );
  }

  Widget _bookingIdHeader(Map<String, dynamic> b) => Center(
        child: Text(
          'Booking ID: ${(b['bookingId'] ?? '').toString()}',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.primary),
        ),
      );

  /// Trip Details / Inclusions / Exclusions tabbed card (reference layout).
  Widget _tripInfoTabs(Map<String, dynamic> b, DateTime? date, _ParsedNotes parsed) {
    final fare = (b['finalFare'] ?? 0) != 0 ? b['finalFare'] : (b['estimatedFare'] ?? 0);
    // Prefer the short city name; fall back to the first part of the address.
    String shortLoc(String cityKey, String objKey) {
      final c = (b[cityKey] ?? '').toString().trim();
      if (c.isNotEmpty) return c.split(',').first.trim();
      final a = ((b[objKey] as Map?)?['address'] ?? '').toString().trim();
      return a.isEmpty ? '' : a.split(',').first.trim();
    }
    final from = shortLoc('pickupCity', 'pickup');
    final to = shortLoc('dropCity', 'drop');
    final tripType = (b['subType'] ?? '').toString().isNotEmpty ? b['subType'].toString() : 'One Way';
    final time = (b['travelTime'] ?? '').toString();
    final dateStr = date != null ? DateFormat('dd MMM yyyy').format(date) : '';
    final inclusions = parsed.inclusions.isNotEmpty
        ? parsed.inclusions
        : (_infoList('inclusions').isNotEmpty ? _infoList('inclusions') : const ['Fuel Charges', 'Driver Allowance']);
    final exclusions = _infoList('exclusions').isNotEmpty
        ? _infoList('exclusions')
        : <String>[
            if (parsed.bestPrice) 'Toll, state tax & parking (pay the driver directly)',
            'Multiple pickups / drops',
          ];
    const labels = ['Trip Details', 'Inclusions', 'Exclusions'];

    Widget kv(String k, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 96, child: Text(k, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
            const Text(':  ', style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
            Expanded(child: Text(v.isEmpty ? '—' : v, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
          ]),
        );
    Widget bullet(IconData icon, Color color, String t) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Expanded(child: Text(t, style: const TextStyle(fontSize: 12.5, color: AppColors.textPrimary, height: 1.35))),
          ]),
        );

    Widget content;
    if (_mainTab == 0) {
      content = Column(children: [
        kv('Trip Type', tripType),
        kv('Itinerary', [from, to].where((s) => s.isNotEmpty).join('  →  ')),
        kv('Date', [dateStr, time].where((s) => s.isNotEmpty).join(' | ')),
        kv('Car Type', (b['vehicleType'] ?? '—').toString()),
        kv('Total Fare', '₹ $fare'),
      ]);
    } else if (_mainTab == 1) {
      content = Column(children: inclusions.map((t) => bullet(Icons.check_circle_rounded, AppColors.success, t)).toList());
    } else {
      content = exclusions.isEmpty
          ? const Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('—', style: TextStyle(color: AppColors.textHint)))
          : Column(children: exclusions.map((t) => bullet(Icons.cancel_rounded, AppColors.primary, t)).toList());
    }

    return Container(
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(labels.length, (i) {
              final sel = i == _mainTab;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _mainTab = i),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      color: sel ? AppColors.primary : Colors.white,
                      border: Border(right: i < 2 ? const BorderSide(color: AppColors.border) : BorderSide.none),
                    ),
                    child: Text(labels[i], style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: sel ? Colors.white : AppColors.textSecondary)),
                  ),
                ),
              );
            }),
          ),
          const Divider(height: 1, color: AppColors.border),
          Padding(padding: const EdgeInsets.fromLTRB(14, 10, 14, 12), child: content),
        ],
      ),
    );
  }

  Widget _otpCard(String otp, String action) {
    final isStart = action == 'start';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Row(children: [
            const Icon(Icons.lock_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(isStart ? 'Trip Start OTP' : 'Trip End OTP',
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            width: double.infinity,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: Text(
              otp.split('').join(' '),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: 6, color: AppColors.primary),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Share this OTP with your driver to ${isStart ? 'START' : 'END'} the trip. Do not share it with anyone else.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.95), fontSize: 11.5),
          ),
        ],
      ),
    );
  }




  /// Splits the packed notes string into its known parts + the user's own note.
  _ParsedNotes _parseNotes(String raw) {
    final parts = raw.split(' • ').map((e) => e.trim()).where((e) => e.isNotEmpty);
    String ret = '', fuel = '';
    final inc = <String>[];
    var best = false;
    final rest = <String>[];
    for (final p in parts) {
      final low = p.toLowerCase();
      if (low.startsWith('return date:')) {
        ret = p.substring(p.indexOf(':') + 1).trim();
      } else if (low.startsWith('fuel:')) {
        fuel = p.substring(p.indexOf(':') + 1).trim();
      } else if (low.startsWith('all inclusive:')) {
        inc.addAll(p.substring(p.indexOf(':') + 1).split(',').map((e) => e.trim()).where((e) => e.isNotEmpty));
      } else if (low.startsWith('toll included')) {
        inc.add(p);
      } else if (low.startsWith('best price')) {
        best = true;
      } else {
        rest.add(p);
      }
    }
    return _ParsedNotes(returnDate: ret, fuel: fuel, inclusions: inc, bestPrice: best, userNotes: rest.join(' • '));
  }

  Widget _driverCard(Map snapshot, Map<String, dynamic> b) {
    final name = (snapshot['name'] ?? snapshot['fullName'] ?? 'Driver').toString();
    final phone = (snapshot['mobile'] ?? snapshot['phone'] ?? '').toString();
    final vehicle = (snapshot['vehicle'] ?? '').toString();
    final vehicleNo = (snapshot['vehicleNumber'] ?? '').toString();
    final locked = phone.isEmpty && b['contactLocked'] == true;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.primary.withValues(alpha: 0.3))),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(radius: 26, backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                  child: const Icon(Icons.person_rounded, color: AppColors.primary, size: 28)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
                    if (vehicle.isNotEmpty || vehicleNo.isNotEmpty)
                      Text('$vehicle ${vehicleNo.isNotEmpty ? '• $vehicleNo' : ''}', style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
                    if ((b['finalFare'] ?? 0) != 0)
                      Padding(padding: const EdgeInsets.only(top: 2), child: Text('Fare: ₹${b['finalFare']}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary))),
                  ],
                ),
              ),
              if (phone.isNotEmpty)
                IconButton(
                  onPressed: () => callNumber(phone),
                  icon: const Icon(Icons.phone_rounded, color: AppColors.success),
                  tooltip: 'Call $phone',
                ),
            ],
          ),
          // Tell the customer exactly WHEN the driver's number unlocks.
          if (locked) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                const Icon(Icons.lock_clock_rounded, size: 18, color: AppColors.warning),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "You'll get the driver's number ${_revealHoursText(b)} before pickup.",
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                ),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  /// "1 hour" / "N hours" before pickup, from the booking's contactRevealHours.
  String _revealHoursText(Map<String, dynamic> b) {
    final h = (b['contactRevealHours'] as num?)?.toInt() ?? 1;
    return h == 1 ? '1 hour' : '$h hours';
  }

  Widget _actions(String status, Map<String, dynamic> b) {
    final children = <Widget>[];
    // Edit — only while still OPEN (no driver selected yet).
    if (status == 'open') {
      children.add(ElevatedButton.icon(
        onPressed: _acting ? null : () {
          final svc = (b['serviceType'] ?? 'cab').toString();
          context.push('/customer/book/$svc', extra: b).then((_) => _load());
        },
        icon: const Icon(Icons.edit_rounded, size: 18),
        label: const Text('Edit Booking'),
        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(48)),
      ));
      children.add(const SizedBox(height: 10));
    }
    if (status == 'open' || status == 'confirmed') {
      children.add(OutlinedButton.icon(
        onPressed: _acting ? null : _cancel,
        icon: const Icon(Icons.close_rounded),
        label: const Text('Cancel Booking'),
        style: OutlinedButton.styleFrom(foregroundColor: AppColors.error, side: const BorderSide(color: AppColors.error), minimumSize: const Size.fromHeight(48)),
      ));
    }
    if (status == 'confirmed') {
      final arriving = b['driverArrivedAt'] != null;
      children.insert(0, Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: (arriving ? AppColors.primary : AppColors.success).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          arriving
              ? '🚗 Your driver is arriving — please be ready at the pickup point.'
              : '💵 Pay the driver directly. Your trip will start when the driver begins.',
          style: const TextStyle(fontSize: 12.5, color: AppColors.textPrimary),
        ),
      ));
    }
    if (status == 'completed' && (b['rating'] ?? 0) == 0) {
      children.add(ElevatedButton.icon(
        onPressed: _acting ? null : _rate,
        icon: const Icon(Icons.star_rounded),
        label: const Text('Rate your trip'),
        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(48)),
      ));
    }
    if (status == 'completed' && (b['rating'] ?? 0) != 0) {
      children.add(Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('You rated ', style: TextStyle(color: AppColors.textSecondary)),
        ...List.generate(5, (i) => Icon(i < (b['rating'] as num).round() ? Icons.star_rounded : Icons.star_border_rounded, color: Colors.amber, size: 20)),
      ]));
    }
    if (status == 'completed') {
      children.add(const SizedBox(height: 10));
      children.add(OutlinedButton.icon(
        onPressed: _acting ? null : () => downloadAndOpenInvoice(context, _repo, widget.bookingId),
        icon: const Icon(Icons.receipt_long_rounded, size: 18),
        label: const Text('Download Invoice'),
        style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary, side: const BorderSide(color: AppColors.primary), minimumSize: const Size.fromHeight(48)),
      ));
    }
    return Column(children: children);
  }

  /// Advance / remaining split shown after the customer pays 10% or 100%.
  Widget _paymentBreakdownCard(Map<String, dynamic> b) {
    final fare = (b['finalFare'] as num?)?.toInt() ?? (b['estimatedFare'] as num?)?.toInt() ?? 0;
    final paid = (b['advanceAmount'] as num?)?.toInt() ?? 0;
    final percent = (b['advancePercent'] as num?)?.toInt() ?? 0;
    final remaining = (fare - paid) < 0 ? 0 : (fare - paid);
    final fullyPaid = remaining == 0 || percent >= 100;
    Widget row(IconData icon, Color color, String label, String amount, {bool strong = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Expanded(child: Text(label, style: TextStyle(fontSize: 12.5, fontWeight: strong ? FontWeight.w700 : FontWeight.w500, color: AppColors.textPrimary))),
            Text(amount, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: color)),
          ]),
        );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Payment', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          if (fare > 0) row(Icons.receipt_long_rounded, AppColors.textSecondary, 'Total Fare', '₹$fare'),
          row(Icons.check_circle_rounded, AppColors.success, 'Advance paid', '₹$paid'),
          if (!fullyPaid)
            row(Icons.account_balance_wallet_rounded, AppColors.warning, 'Remaining Balance', '₹$remaining', strong: true),
          const SizedBox(height: 6),
          Text(
            fullyPaid
                ? 'Fully paid. Nothing more to pay to the driver.'
                : (paid > 0
                    ? 'You paid ₹$paid advance online. Pay the remaining ₹$remaining directly to the driver.'
                    : 'Pay ₹$remaining directly to the driver.'),
            style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary, height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _hint(String t) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.info.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          const Icon(Icons.hourglass_top_rounded, color: AppColors.info, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(t, style: const TextStyle(fontSize: 12.5))),
        ]),
      );
}

class _StatusBanner extends StatelessWidget {
  final String status;
  const _StatusBanner(this.status);

  @override
  Widget build(BuildContext context) {
    final map = <String, (Color, IconData, String)>{
      'open': (AppColors.info, Icons.hourglass_top_rounded, 'Waiting for a driver'),
      'confirmed': (AppColors.primary, Icons.check_circle_rounded, 'Driver confirmed'),
      'ongoing': (AppColors.warning, Icons.directions_car_rounded, 'Trip in progress'),
      'completed': (AppColors.success, Icons.flag_rounded, 'Trip completed'),
      'cancelled': (AppColors.error, Icons.cancel_rounded, 'Cancelled'),
      'expired': (AppColors.textHint, Icons.timer_off_rounded, 'Expired'),
    };
    final (c, icon, label) = map[status] ?? (AppColors.textHint, Icons.info_rounded, status);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Icon(icon, color: c),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c)),
      ]),
    );
  }
}

class _RateSheet extends StatefulWidget {
  const _RateSheet();
  @override
  State<_RateSheet> createState() => _RateSheetState();
}

class _RateSheetState extends State<_RateSheet> {
  int _stars = 5;
  final _review = TextEditingController();

  @override
  void dispose() {
    _review.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Rate your trip', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) => IconButton(
              onPressed: () => setState(() => _stars = i + 1),
              icon: Icon(i < _stars ? Icons.star_rounded : Icons.star_border_rounded, color: Colors.amber, size: 36),
            )),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _review,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Add a review (optional)',
              filled: true,
              fillColor: Colors.grey[50],
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, (_stars.toDouble(), _review.text.trim())),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              child: const Text('Submit', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Parsed pieces of a cab booking's packed `notes` string.
class _ParsedNotes {
  final String returnDate; // "dd-MM-yyyy" when a round trip, else ''
  final String fuel;
  final List<String> inclusions;
  final bool bestPrice;
  final String userNotes; // whatever the customer actually typed
  const _ParsedNotes({
    required this.returnDate,
    required this.fuel,
    required this.inclusions,
    required this.bestPrice,
    required this.userNotes,
  });
}
