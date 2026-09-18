import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/contact_launcher.dart';
import '../../data/customer_repository.dart';
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
  Map<String, dynamic>? _b;
  bool _loading = true;
  bool _acting = false;
  String? _error;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _load();
    // Live-ish updates: pull new offers and the trip OTP while the booking is
    // still active, so the customer doesn't have to refresh by hand.
    _poll = Timer.periodic(const Duration(seconds: 12), (_) {
      final s = (_b?['status'] ?? '').toString();
      if (!_acting && (s == 'open' || s == 'confirmed' || s == 'ongoing')) _load();
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
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = '$e'; _loading = false; });
    }
  }

  Future<void> _select(String offerId) async {
    final ok = await _confirm('Select this driver?', 'The driver will be confirmed for your trip and other offers will be released.');
    if (ok != true) return;
    setState(() => _acting = true);
    try {
      await _repo.selectOffer(widget.bookingId, offerId);
      await _load();
      _snack('Driver confirmed! 🎉', ok: true);
    } catch (e) {
      _snack('Could not select: $e');
    } finally {
      if (mounted) setState(() => _acting = false);
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

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _StatusBanner(status),
        if (tripOtp.isNotEmpty) ...[
          const SizedBox(height: 16),
          _otpCard(tripOtp, otpAction),
        ],
        const SizedBox(height: 16),
        _tripCard(b, date),
        const SizedBox(height: 16),

        // OPEN → show incoming offers to pick from.
        if (status == 'open') ...[
          Row(
            children: [
              const Text('Offers', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              Text('(${offers.length})', style: const TextStyle(color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 8),
          if (offers.isEmpty)
            _hint('Waiting for drivers to send offers… pull down to refresh.'),
          ...offers.map((o) => _OfferCard(o, acting: _acting, onSelect: () => _select((o['offerId'] ?? o['_id']).toString()))),
        ],

        // Confirmed / ongoing / completed → show the chosen driver.
        if (status != 'open' && snapshot != null) ...[
          const Text('Your Driver', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          _driverCard(snapshot, b),
        ],

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

  Widget _tripCard(Map<String, dynamic> b, DateTime? date) {
    final pickup = ((b['pickup'] as Map?)?['address'] ?? '').toString();
    final drop = ((b['drop'] as Map?)?['address'] ?? '').toString();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
      child: Builder(builder: (_) {
        final status = (b['status'] ?? '').toString();
        final confirmed = status == 'confirmed' || status == 'ongoing' || status == 'completed';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((b['bookingId'] ?? '').toString().isNotEmpty)
              _kv(Icons.confirmation_number_rounded, 'Booking ID', b['bookingId'].toString()),
            _kv(Icons.my_location_rounded, 'Pickup', pickup),
            if (drop.isNotEmpty) _kv(Icons.location_on_rounded, 'Drop', drop),
            _kv(Icons.calendar_today_rounded, 'When',
                '${date != null ? DateFormat('EEE, d MMM').format(date) : ''} • ${(b['travelTime'] ?? '').toString()}'),
            if ((b['passengers'] ?? 0) != 0) _kv(Icons.people_rounded, 'Passengers', '${b['passengers']}'),
            if ((b['durationHours'] ?? 0) != 0) _kv(Icons.timelapse_rounded, 'Duration', '${b['durationHours']} hrs'),
            if ((b['estimatedFare'] ?? 0) != 0) _kv(Icons.currency_rupee_rounded, 'Your budget', '₹${b['estimatedFare']}'),
            if ((b['finalFare'] ?? 0) != 0) _kv(Icons.receipt_long_rounded, 'Agreed fare', '₹${b['finalFare']}'),
            if (confirmed) _kv(Icons.payments_rounded, 'Payment', status == 'completed' ? 'Paid to driver directly' : 'Pay driver directly'),
            if ((b['notes'] ?? '').toString().isNotEmpty) _kv(Icons.notes_rounded, 'Notes', b['notes'].toString()),
          ],
        );
      }),
    );
  }

  Widget _driverCard(Map snapshot, Map<String, dynamic> b) {
    final name = (snapshot['name'] ?? snapshot['fullName'] ?? 'Driver').toString();
    final phone = (snapshot['mobile'] ?? snapshot['phone'] ?? '').toString();
    final vehicle = (snapshot['vehicle'] ?? '').toString();
    final vehicleNo = (snapshot['vehicleNumber'] ?? '').toString();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.primary.withValues(alpha: 0.3))),
      child: Row(
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
    );
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
    return Column(children: children);
  }

  Widget _kv(IconData icon, String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: AppColors.primary),
            const SizedBox(width: 10),
            SizedBox(width: 78, child: Text(k, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary))),
            Expanded(child: Text(v, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600))),
          ],
        ),
      );

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

class _OfferCard extends StatelessWidget {
  final Map<String, dynamic> o;
  final bool acting;
  final VoidCallback onSelect;
  const _OfferCard(this.o, {required this.acting, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    // The backend flattens the driver's public profile onto the offer (it never
    // exposes wallet balances). Fields: name, rating, totalRatings, isVerified…
    final name = (o['name'] ?? 'Driver').toString();
    final rating = (o['rating'] as num?)?.toDouble() ?? 0;
    final ratings = (o['totalRatings'] ?? 0);
    final verified = o['isVerified'] == true;
    final img = (o['profileImage'] ?? '').toString();
    final memberSince = o['memberSince'];
    final fare = o['quotedFare'] ?? 0;
    final vehicle = (o['vehicle'] ?? '').toString();
    final vehicleNo = (o['vehicleNumber'] ?? '').toString();
    final vehicleImg = (o['vehicleImage'] ?? '').toString();
    final farePerSeat = (o['farePerSeat'] as num?)?.toInt() ?? 0;
    final seatsAvail = (o['seatsAvailable'] as num?)?.toInt() ?? 0;
    final message = (o['message'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                backgroundImage: img.isNotEmpty ? NetworkImage(img) : null,
                child: img.isEmpty ? const Icon(Icons.person_rounded, color: AppColors.primary) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Flexible(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
                      if (verified) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.verified_rounded, size: 15, color: AppColors.info),
                      ],
                    ]),
                    Row(children: [
                      const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
                      Text(' ${rating.toStringAsFixed(1)}  •  $ratings ratings', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ]),
                    if (memberSince != null)
                      Text('Member since $memberSince', style: const TextStyle(fontSize: 11.5, color: AppColors.textHint)),
                  ],
                ),
              ),
              Text('₹$fare', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.primary)),
            ],
          ),
          if (vehicleImg.isNotEmpty) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(vehicleImg, height: 130, width: double.infinity, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink()),
            ),
          ],
          if (vehicle.isNotEmpty || vehicleNo.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.directions_car_rounded, size: 15, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text('$vehicle ${vehicleNo.isNotEmpty ? '• $vehicleNo' : ''}', style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
            ]),
          ],
          if (farePerSeat > 0) ...[
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.event_seat_rounded, size: 15, color: AppColors.primary),
              const SizedBox(width: 6),
              Text('₹$farePerSeat / seat${seatsAvail > 0 ? '  •  $seatsAvail seats free' : ''}',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.primary)),
            ]),
          ],
          if (message.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('"$message"', style: const TextStyle(fontSize: 12.5, fontStyle: FontStyle.italic, color: AppColors.textSecondary)),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: acting ? null : onSelect,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              child: const Text('Select this driver'),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final String status;
  const _StatusBanner(this.status);

  @override
  Widget build(BuildContext context) {
    final map = <String, (Color, IconData, String)>{
      'open': (AppColors.info, Icons.hourglass_top_rounded, 'Waiting for offers'),
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
