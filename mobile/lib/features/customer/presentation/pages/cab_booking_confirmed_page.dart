import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';

/// Booking-confirmation ("Thank You") screen shown right after a customer confirms
/// a cab booking, instead of jumping straight to the booking-details page.
class CabBookingConfirmedPage extends StatefulWidget {
  final Map<String, dynamic> data;
  const CabBookingConfirmedPage({super.key, required this.data});

  @override
  State<CabBookingConfirmedPage> createState() => _CabBookingConfirmedPageState();
}

class _CabBookingConfirmedPageState extends State<CabBookingConfirmedPage> {
  bool _detailsOpen = true;
  bool _fareOpen = true;
  int _fareTab = 0; // 0 = inclusions, 1 = exclusions, 2 = terms

  Map<String, dynamic> get d => widget.data;
  String get _name => (d['name'] ?? '').toString().trim();
  String get _humanId => (d['humanId'] ?? '').toString();

  List<String> _list(String k) => ((d[k] as List?) ?? []).map((e) => e.toString()).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 2,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: Text('Booking Confirmation', style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w800, color: Colors.white, fontFamily: 'Poppins')),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(14.w, 18.h, 14.w, 24.h),
        children: [
          Center(
            child: Text(
              _name.isEmpty ? 'Thank You!' : 'Thank You, $_name!',
              style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.w800, color: AppColors.primary, fontFamily: 'Poppins'),
            ),
          ),
          SizedBox(height: 10.h),
          Center(
            child: Text(
              'Your Booking${_humanId.isNotEmpty ? ' (ID: $_humanId)' : ''} is received.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontFamily: 'Poppins'),
            ),
          ),
          SizedBox(height: 14.h),
          if (_humanId.isNotEmpty)
            Text.rich(
              TextSpan(
                style: TextStyle(fontSize: 13.sp, color: AppColors.textSecondary, height: 1.45, fontFamily: 'Poppins'),
                children: [
                  const TextSpan(text: 'Your booking is saved with '),
                  TextSpan(text: 'Booking ID $_humanId', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                  const TextSpan(text: '. You can view or manage it anytime under My Rides in the app.'),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          SizedBox(height: 12.h),
          Text(
            'You will get your assigned driver’s details about 1 hour before your pickup time, right here in the app. We seek your cooperation to avoid enquiring about the driver details before then.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.sp, color: AppColors.textSecondary, height: 1.45, fontFamily: 'Poppins'),
          ),
          SizedBox(height: 18.h),
          Divider(height: 1, color: AppColors.border),
          SizedBox(height: 18.h),
          SizedBox(
            width: double.infinity,
            height: 52.h,
            child: ElevatedButton.icon(
              onPressed: () => context.go('/customer'),
              icon: Icon(Icons.home_rounded, size: 20.sp),
              label: const Text('Go to Home'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, elevation: 0, textStyle: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800, fontFamily: 'Poppins'), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r))),
            ),
          ),
          SizedBox(height: 18.h),
          _bookingDetailsCard(),
          SizedBox(height: 14.h),
          _fareDetailsCard(),
        ],
      ),
    );
  }

  // ── Your Booking Details ────────────────────────────────────────────────────
  Widget _bookingDetailsCard() {
    final rows = <(String, String, bool)>[
      ('Pickup city', (d['pickupCity'] ?? '—').toString(), false),
      ('Total Fare', '₹ ${d['totalFare'] ?? 0}', true),
      ('Trip Type', (d['tripType'] ?? '—').toString(), false),
      ('Pick Up Date & Time', (d['dateTime'] ?? '—').toString(), false),
      ('Car Type', (d['carType'] ?? '—').toString(), false),
      ('Amount Paid', '₹ ${d['amountPaid'] ?? 0}', false),
    ];
    return _expandCard(
      title: 'Your Booking Details',
      open: _detailsOpen,
      onToggle: () => setState(() => _detailsOpen = !_detailsOpen),
      child: Column(
        children: rows.map((r) => Padding(
              padding: EdgeInsets.symmetric(vertical: 8.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: Text(r.$1, style: TextStyle(fontSize: 13.sp, fontWeight: r.$3 ? FontWeight.w800 : FontWeight.w500, color: AppColors.textPrimary, fontFamily: 'Poppins'))),
                  SizedBox(width: 12.w),
                  Text(r.$2, textAlign: TextAlign.right, style: TextStyle(fontSize: 13.sp, fontWeight: r.$3 ? FontWeight.w800 : FontWeight.w600, color: AppColors.textPrimary, fontFamily: 'Poppins')),
                ],
              ),
            )).toList(),
      ),
    );
  }

  // ── Fare Details (Inclusions / Exclusions / T&C) ────────────────────────────
  Widget _fareDetailsCard() {
    const tabs = ['Inclusions', 'Exclusions', 'T&C'];
    final keys = ['inclusions', 'exclusions', 'terms'];
    final items = _list(keys[_fareTab]);
    final isTerms = _fareTab == 2;
    return _expandCard(
      title: 'Fare Details',
      open: _fareOpen,
      onToggle: () => setState(() => _fareOpen = !_fareOpen),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(10.r), border: Border.all(color: AppColors.border)),
            clipBehavior: Clip.antiAlias,
            child: Row(
              children: List.generate(tabs.length, (i) {
                final sel = i == _fareTab;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _fareTab = i),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      alignment: Alignment.center,
                      padding: EdgeInsets.symmetric(vertical: 10.h),
                      color: sel ? AppColors.primary : Colors.white,
                      child: Text(tabs[i], style: TextStyle(fontSize: 12.5.sp, fontWeight: FontWeight.w700, color: sel ? Colors.white : AppColors.textSecondary, fontFamily: 'Poppins')),
                    ),
                  ),
                );
              }),
            ),
          ),
          SizedBox(height: 12.h),
          if (items.isEmpty)
            Padding(padding: EdgeInsets.symmetric(vertical: 6.h), child: Text('No items listed.', style: TextStyle(fontSize: 12.5.sp, color: AppColors.textHint, fontFamily: 'Poppins')))
          else
            ...items.map((t) => Padding(
                  padding: EdgeInsets.symmetric(vertical: 6.h),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(isTerms ? Icons.circle : Icons.check_circle_rounded, size: isTerms ? 7.sp : 16.sp, color: isTerms ? AppColors.textSecondary : AppColors.success),
                    SizedBox(width: isTerms ? 10.w : 8.w),
                    Expanded(child: Text(t, style: TextStyle(fontSize: 12.5.sp, height: 1.4, color: AppColors.textPrimary, fontFamily: 'Poppins'))),
                  ]),
                )),
        ],
      ),
    );
  }

  Widget _expandCard({required String title, required bool open, required VoidCallback onToggle, required Widget child}) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16.r), border: Border.all(color: AppColors.border)),
      padding: EdgeInsets.fromLTRB(14.w, 4.h, 14.w, open ? 14.h : 4.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 12.h),
              child: Row(children: [
                Expanded(child: Text(title, style: TextStyle(fontSize: 14.5.sp, fontWeight: FontWeight.w800, fontFamily: 'Poppins'))),
                Icon(open ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary, size: 22.sp),
              ]),
            ),
          ),
          if (open) ...[
            Divider(height: 1, color: AppColors.border),
            SizedBox(height: 6.h),
            child,
          ],
        ],
      ),
    );
  }
}
