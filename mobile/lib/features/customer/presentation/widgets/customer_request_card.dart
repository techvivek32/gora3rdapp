import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import 'booking_card_ui.dart';

/// Shared "customer request" card + apply flow, used by both the Customer
/// Requests page and the merged driver Booking feed. A driver quotes a fare
/// (which places a small wallet commitment hold) to send an offer.
class CustomerRequestCard extends StatelessWidget {
  final Map<String, dynamic> booking;
  final VoidCallback onApply;
  const CustomerRequestCard(this.booking, {super.key, required this.onApply});

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final service = kServiceNames[(b['serviceType'] ?? '').toString()] ?? 'Booking';
    final pickup = ((b['pickup'] as Map?)?['address'] ?? '').toString();
    final drop = ((b['drop'] as Map?)?['address'] ?? '').toString();
    final date = tripDate(b['travelDate']);
    final fare = b['estimatedFare'] ?? 0;
    final applied = b['alreadyApplied'] == true;
    final subType = (b['subType'] ?? '').toString();

    // Round-trip return date is carried in notes as "Return date: dd-MM-yyyy".
    // Show only the number of days (under the ROUND TRIP chip).
    final rt = RegExp(r'Return date:\s*(\d{2})-(\d{2})-(\d{4})').firstMatch((b['notes'] ?? '').toString());
    final returnDate = rt != null ? DateTime(int.parse(rt.group(3)!), int.parse(rt.group(2)!), int.parse(rt.group(1)!)) : null;
    // Inclusive day count (25→26 = 2 days), consistent with the other screens.
    int? days = (returnDate != null && date != null)
        ? returnDate.difference(DateTime(date.year, date.month, date.day)).inDays + 1
        : null;
    if (days != null && days < 1) days = null;

    return brandCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(padding: EdgeInsets.only(top: 4.h), child: Icon(Icons.circle, size: 10.sp, color: AppColors.info)),
              SizedBox(width: 8.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text('CUSTOMER', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700, color: AppColors.info)),
                      SizedBox(width: 6.w),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.h),
                        decoration: BoxDecoration(color: AppColors.info.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4.r)),
                        child: Text('APP', style: TextStyle(fontSize: 8.sp, fontWeight: FontWeight.w800, color: AppColors.info)),
                      ),
                    ]),
                    Text(service, style: TextStyle(fontSize: 11.sp, color: Colors.grey[600], fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              if (subType.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    filledChip(subType.toUpperCase(), AppColors.primary),
                    if (days != null) ...[
                      SizedBox(height: 4.h),
                      Text('$days day${days == 1 ? '' : 's'}', style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                    ],
                  ],
                ),
            ],
          ),
          SizedBox(height: 10.h),
          const Divider(height: 1, color: Colors.black26),
          SizedBox(height: 10.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: routeTimeline(pickup, drop)),
              SizedBox(width: 10.w),
              dateTimeBox(date, (b['travelTime'] ?? '').toString(), AppColors.primary),
            ],
          ),
          SizedBox(height: 4.h),
          const Divider(height: 1, color: Colors.black26),
          SizedBox(height: 10.h),
          Row(children: [
            if ((b['vehicleType'] ?? '').toString().isNotEmpty) ...[
              Icon(Icons.local_taxi_rounded, size: 15.sp, color: AppColors.primary),
              SizedBox(width: 5.w),
              Flexible(
                child: Text(
                  b['vehicleType'].toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.5.sp, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
              ),
            ],
            const Spacer(),
            if (fare != 0) Text('Budget: ₹$fare', style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          ]),
          SizedBox(height: 12.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: applied ? null : onApply,
              icon: Icon(applied ? Icons.check_rounded : Icons.check_circle_rounded, size: 18.sp),
              label: Text(applied ? 'Accepted' : 'Accept'),
              style: ElevatedButton.styleFrom(
                backgroundColor: applied ? AppColors.textHint : AppColors.primary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 11.h),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Content for the "Accept this booking?" dialog — explains WHY a commitment
/// hold is placed and HOW it works, with the actual hold amount when known.
Widget acceptHoldContent(int fare, int pct, int hold) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        "You'll be directly assigned to this trip${fare != 0 ? " at the customer's budget (₹$fare)" : ''}.",
        style: TextStyle(fontSize: 13.sp, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
      ),
      SizedBox(height: 12.h),
      Container(
        padding: EdgeInsets.all(10.w),
        decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10.r)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.lock_outline_rounded, size: 16.sp, color: AppColors.primary),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              hold > 0
                  ? 'A commitment hold of ₹$hold ($pct% of the fare) is kept from your wallet when you accept.'
                  : 'A commitment hold is kept from your wallet when you accept.',
              style: TextStyle(fontSize: 12.5.sp, fontWeight: FontWeight.w700, color: AppColors.primary),
            ),
          ),
        ]),
      ),
      SizedBox(height: 12.h),
      _holdPoint('Why?', 'It confirms you\'re serious and will complete the trip — it protects the customer from no-shows.'),
      SizedBox(height: 8.h),
      _holdPoint('How it works', 'The amount is only HELD (not charged). It\'s settled once the trip is completed, and released back to your wallet if the booking is cancelled as per policy.'),
    ],
  );
}

Widget _holdPoint(String label, String body) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
      SizedBox(height: 2.h),
      Text(body, style: TextStyle(fontSize: 12.sp, color: AppColors.textSecondary, height: 1.35)),
    ],
  );
}

/// Opens the apply/offer bottom sheet and returns the offer payload (or null).
Future<Map<String, dynamic>?> showCustomerApplySheet(BuildContext context, Map<String, dynamic> booking) {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ApplySheet(booking: booking),
  );
}

class _ApplySheet extends StatefulWidget {
  final Map<String, dynamic> booking;
  const _ApplySheet({required this.booking});

  @override
  State<_ApplySheet> createState() => _ApplySheetState();
}

class _ApplySheetState extends State<_ApplySheet> {
  final _fare = TextEditingController();
  final _perSeat = TextEditingController();
  final _seats = TextEditingController();
  final _vehicle = TextEditingController();
  final _vehicleNo = TextEditingController();
  final _message = TextEditingController();
  final _picker = ImagePicker();
  final _api = getIt<ApiClient>();
  Uint8List? _vehicleBytes;
  bool _submitting = false;

  bool get _isPool => (widget.booking['serviceType'] ?? '').toString() == 'car_pool';
  int get _seatsWanted {
    final p = widget.booking['passengers'];
    return p is num && p > 0 ? p.toInt() : 1;
  }
  int get _poolTotal => ((num.tryParse(_perSeat.text.trim()) ?? 0) * _seatsWanted).round();

  Future<void> _pickVehiclePhoto() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1200, imageQuality: 80);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() => _vehicleBytes = bytes);
  }

  Future<String?> _uploadVehiclePhoto() async {
    if (_vehicleBytes == null) return null;
    FormData form() => FormData.fromMap({'file': MultipartFile.fromBytes(_vehicleBytes!, filename: 'vehicle.jpg'), 'folder': 'vehicles'});
    Response res;
    try {
      res = await _api.dio.post('/storage/upload', data: form());
    } catch (_) {
      res = await _api.dio.post('/storage/upload', data: form());
    }
    return res.data['data'] as String?;
  }

  int get _commitPercent {
    final v = widget.booking['commitmentPercent'];
    return v is num ? v.toInt() : 5;
  }

  int get _hold {
    final f = _isPool ? _poolTotal : (num.tryParse(_fare.text.trim()) ?? 0);
    return (f * _commitPercent / 100).round();
  }

  @override
  void initState() {
    super.initState();
    if (_isPool) {
      _seats.text = '$_seatsWanted';
    } else {
      final est = widget.booking['estimatedFare'];
      if (est != null && est != 0) _fare.text = est.toString();
    }
  }

  @override
  void dispose() {
    _fare.dispose();
    _perSeat.dispose();
    _seats.dispose();
    _vehicle.dispose();
    _vehicleNo.dispose();
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Send your offer', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          if (_isPool) ...[
            Row(children: [
              Expanded(child: TextField(
                controller: _perSeat,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                decoration: _dec('Fare per seat (₹)', Icons.event_seat_rounded),
              )),
              const SizedBox(width: 10),
              SizedBox(width: 110, child: TextField(
                controller: _seats,
                keyboardType: TextInputType.number,
                decoration: _dec('Seats', Icons.people_rounded),
              )),
            ]),
            const SizedBox(height: 6),
            Text('Customer needs $_seatsWanted seat(s) • Total ₹$_poolTotal', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 12),
          ] else ...[
            TextField(
              controller: _fare,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              decoration: _dec('Your fare (₹)', Icons.currency_rupee_rounded),
            ),
            const SizedBox(height: 12),
          ],
          TextField(controller: _vehicle, decoration: _dec('Vehicle (e.g. Swift Dzire)', Icons.directions_car_rounded)),
          const SizedBox(height: 12),
          TextField(controller: _vehicleNo, textCapitalization: TextCapitalization.characters, decoration: _dec('Vehicle number', Icons.confirmation_number_rounded)),
          const SizedBox(height: 12),
          InkWell(
            onTap: _submitting ? null : _pickVehiclePhoto,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: _vehicleBytes != null ? 130 : 54,
              width: double.infinity,
              decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
              clipBehavior: Clip.antiAlias,
              child: _vehicleBytes != null
                  ? Stack(fit: StackFit.expand, children: [
                      Image.memory(_vehicleBytes!, fit: BoxFit.cover),
                      Positioned(right: 8, top: 8, child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                        child: const Icon(Icons.edit, color: Colors.white, size: 16),
                      )),
                    ])
                  : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.add_a_photo_outlined, color: AppColors.primary, size: 20),
                      SizedBox(width: 8),
                      Text('Add vehicle photo (optional)', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    ]),
            ),
          ),
          const SizedBox(height: 12),
          TextField(controller: _message, maxLines: 2, decoration: _dec('Message to customer (optional)', Icons.message_rounded)),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.warning),
              const SizedBox(width: 10),
              Expanded(child: Text('A commitment hold of ₹$_hold ($_commitPercent%) will be placed on your wallet. It is released automatically if you are not selected.', style: const TextStyle(fontSize: 12))),
            ]),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _submitting ? null : () async {
                final num? perSeat = _isPool ? num.tryParse(_perSeat.text.trim()) : null;
                final num? fare = _isPool ? _poolTotal : num.tryParse(_fare.text.trim());
                if (fare == null || fare <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isPool ? 'Enter a valid per-seat fare' : 'Enter a valid fare')));
                  return;
                }
                final nav = Navigator.of(context);
                setState(() => _submitting = true);
                String? vehicleImage;
                try {
                  vehicleImage = await _uploadVehiclePhoto();
                } catch (_) {/* photo optional */}
                if (!mounted) return;
                nav.pop({
                  'quotedFare': fare,
                  if (_isPool && perSeat != null) 'farePerSeat': perSeat,
                  if (_isPool) 'seatsAvailable': int.tryParse(_seats.text.trim()) ?? _seatsWanted,
                  if (_vehicle.text.trim().isNotEmpty) 'vehicle': _vehicle.text.trim(),
                  if (_vehicleNo.text.trim().isNotEmpty) 'vehicleNumber': _vehicleNo.text.trim(),
                  if (vehicleImage != null && vehicleImage.isNotEmpty) 'vehicleImage': vehicleImage,
                  if (_message.text.trim().isNotEmpty) 'message': _message.text.trim(),
                });
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              child: _submitting
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Send Offer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _dec(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.primary),
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
      );
}
