import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../bloc/subscription_bloc.dart';

// col index: 0=Free, 1=Active, 2=Premium, 3=Golden
const _planColors = [
  AppColors.textHint,
  AppColors.memberActive,
  AppColors.memberPremium,
  AppColors.memberGolden,
];
const _planIcons = [
  Icons.person_outline,
  Icons.verified_user,
  Icons.diamond_outlined,
  Icons.emoji_events,
];
const _planNames = ['Free', 'Active', 'Premium', 'Golden'];
// [icon, label, free, active, premium, golden]
const _features = [
  [Icons.person_outline, 'View Contact Details', false, true, true, true],
  [Icons.send_outlined, 'Post Bookings', true, true, true, true],
  [Icons.directions_car_outlined, 'Post Available Cars', true, true, true, true],
  [Icons.apartment_outlined, 'Business Cities Filter', false, true, true, true],
  [Icons.star_border, 'Featured Listings', false, false, true, true],
  [Icons.headset_mic_outlined, 'Priority Support', false, false, true, true],
  [Icons.all_inclusive, 'Unlimited Listings', false, false, false, true],
  [Icons.verified_user_outlined, 'Golden Verified Badge', false, false, false, true],
  [Icons.badge_outlined, 'V-Card Ad Post', false, false, false, true],
  [Icons.block_outlined, 'Ad-Free Experience', false, false, false, true],
  [Icons.bookmark_border, '10 Booking Reference', false, false, false, true],
];

const _membershipCol = {'new': 0, 'active': 1, 'verified': 1, 'premium': 2, 'golden': 3};

// Per-tier presentation for the grouped plans layout.
const _tierOrder = ['active', 'premium', 'golden'];
const _tierColor = {
  'active': AppColors.memberActive,
  'premium': AppColors.memberPremium,
  'golden': AppColors.memberGolden,
};
const _tierIcon = {
  'active': Icons.verified_user,
  'premium': Icons.diamond_outlined,
  'golden': Icons.emoji_events,
};
const _tierTitle = {'active': 'Active Plan', 'premium': 'Premium Plan', 'golden': 'Golden Plan'};
const _tierBadge = {'premium': 'Most Popular', 'golden': 'Best Value'};
const _tierFeatureLabel = {
  'active': 'Basic Features',
  'premium': 'All Premium Features',
  'golden': 'All Golden Features',
};

class SubscriptionPlansPage extends StatefulWidget {
  const SubscriptionPlansPage({super.key});

  @override
  State<SubscriptionPlansPage> createState() => _SubscriptionPlansPageState();
}

class _SubscriptionPlansPageState extends State<SubscriptionPlansPage> {
  Razorpay? _razorpay;
  String? _pendingPlanId;
  final Set<String> _collapsed = {}; // tiers the user has collapsed

  @override
  void initState() {
    super.initState();
    context.read<SubscriptionBloc>().add(LoadPlansEvent());
    // Refresh the profile so KYC/verification status is up to date (the cached
    // auth user can be stale from an earlier login, before the user got verified).
    context.read<AuthBloc>().add(const AuthReloadProfileEvent());
    if (!kIsWeb) {
      _razorpay = Razorpay();
      _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaymentSuccess);
      _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, _onPaymentError);
    }
  }

  void _onPaymentSuccess(PaymentSuccessResponse response) {
    context.read<SubscriptionBloc>().add(VerifyPaymentEvent({
      'razorpayOrderId': response.orderId,
      'razorpayPaymentId': response.paymentId,
      'razorpaySignature': response.signature,
      'planId': _pendingPlanId,
    }));
  }

  void _onPaymentError(PaymentFailureResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Payment failed: ${response.message}'), backgroundColor: AppColors.error),
    );
  }

  bool _isVerified() {
    final authState = context.read<AuthBloc>().state;
    final user = authState is AuthAuthenticated ? authState.user as Map<String, dynamic>? : null;
    return user?['isVerified'] == true || user?['verificationStatus'] == 'verified';
  }

  void _promptKyc() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Verification Required', style: TextStyle(fontFamily: 'Poppins')),
        content: const Text(
          'Please complete your KYC verification before buying a plan.',
          style: TextStyle(fontFamily: 'Poppins'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Later')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.push('/kyc');
            },
            child: const Text('Verify Now'),
          ),
        ],
      ),
    );
  }

  Future<void> _buyPlan(Map<String, dynamic> plan) async {
    if (!_isVerified()) {
      _promptKyc();
      return;
    }
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payments are only supported on the mobile app.'), backgroundColor: AppColors.warning),
      );
      return;
    }
    final bloc = context.read<SubscriptionBloc>();
    _pendingPlanId = plan['_id'] as String;
    bloc.add(CreateOrderEvent(_pendingPlanId!));
  }

  void _openRazorpay(Map<String, dynamic> order) {
    if (kIsWeb || _razorpay == null) return;
    final authState = context.read<AuthBloc>().state;
    final user = authState is AuthAuthenticated ? authState.user as Map<String, dynamic>? : null;
    _razorpay!.open({
      // Use the key the backend returned (set by admin) so the checkout matches
      // the order's account — never a hardcoded test key.
      'key': order['keyId'] ?? '',
      'amount': order['amount'],
      'currency': order['currency'] ?? 'INR',
      'order_id': order['orderId'] ?? order['razorpayOrderId'],
      'name': 'Gora Cabs',
      'description': 'Membership Upgrade',
      'prefill': {
        'contact': user?['mobile'] ?? '',
        'email': user?['email'] ?? '',
        'name': user?['fullName'] ?? '',
      },
      'theme': {'color': '#F97316'},
    });
  }

  @override
  void dispose() {
    _razorpay?.clear();
    super.dispose();
  }

  List<Map<String, dynamic>>? _getPlans(SubscriptionState state) {
    if (state is PlansLoaded) return state.plans;
    if (state is OrderCreated) return state.plans;
    if (state is SubscriptionLoading) return state.cachedPlans;
    if (state is SubscriptionError) return state.cachedPlans;
    return null;
  }

  // Exclude the Verified plan and sort by price.
  List<Map<String, dynamic>> _filtered(List<Map<String, dynamic>> plans) {
    final result = plans.where((p) => (p['membershipType'] as String?) != 'verified').toList();
    result.sort((a, b) => ((a['price'] as num?) ?? 0).compareTo((b['price'] as num?) ?? 0));
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Membership Plans', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 18.sp)),
        centerTitle: true,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 12.w),
          ),
        ],
      ),
      body: BlocConsumer<SubscriptionBloc, SubscriptionState>(
        listener: (context, state) {
          if (state is OrderCreated) _openRazorpay(state.orderData);
          if (state is PaymentVerified) {
            context.read<AuthBloc>().add(const AuthReloadProfileEvent());
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('🎉 Membership activated!'), backgroundColor: AppColors.success),
            );
            Navigator.pop(context);
          }
          if (state is SubscriptionError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: AppColors.error),
            );
          }
        },
        builder: (context, state) {
          final plans = _getPlans(state);
          final isOrdering = state is SubscriptionLoading && state.cachedPlans != null;

          if (state is SubscriptionLoading && state.cachedPlans == null) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }

          if (plans == null || plans.isEmpty) {
            if (state is SubscriptionError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.error, size: 48),
                    SizedBox(height: 12.h),
                    Text(state.message, textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Poppins')),
                    SizedBox(height: 16.h),
                    ElevatedButton(
                      onPressed: () => context.read<SubscriptionBloc>().add(LoadPlansEvent()),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }
            return const Center(child: Text('No plans available', style: TextStyle(fontFamily: 'Poppins')));
          }

          // watch (not read) so the page rebuilds once the profile reload finishes
          // and the KYC notice / buy gate reflect the up-to-date verification.
          final authState = context.watch<AuthBloc>().state;
          final user = authState is AuthAuthenticated ? authState.user as Map<String, dynamic>? : null;
          final currentMembership = user?['membershipType'] as String? ?? 'new';
          final currentColIndex = _membershipCol[currentMembership] ?? 0;
          final currentIcon = _planIcons[currentColIndex];
          final currentName = currentColIndex == 0 ? 'Free' : _planNames[currentColIndex];
          final validTill = _formatExpiry(user?['membershipExpiresAt']);

          // Group plans by tier (active/premium/golden), each sorted 1→3→6 months.
          final byTier = <String, List<Map<String, dynamic>>>{};
          for (final p in _filtered(plans)) {
            final t = (p['membershipType'] as String?) ?? 'active';
            byTier.putIfAbsent(t, () => []).add(p);
          }
          for (final list in byTier.values) {
            list.sort((a, b) => ((a['durationDays'] as num?) ?? 0).compareTo((b['durationDays'] as num?) ?? 0));
          }

          return SingleChildScrollView(
            padding: EdgeInsets.all(16.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildCurrentPlanBanner(currentIcon, currentName, currentColIndex, validTill, user?['membershipExpiresAt']),
                SizedBox(height: 16.h),

                if (!_isVerified()) ...[
                  _buildKycNotice(),
                  SizedBox(height: 16.h),
                ],

                // One collapsible section per tier, each with 1 / 3 / 6-month cards.
                for (final tier in _tierOrder)
                  if ((byTier[tier] ?? []).isNotEmpty) ...[
                    _buildTierSection(tier, byTier[tier]!, isOrdering),
                    SizedBox(height: 16.h),
                  ],

                SizedBox(height: 4.h),
                _buildComparisonTable(),
                SizedBox(height: 24.h),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCurrentPlanBanner(IconData icon, String name, int colIndex, String? validTill, dynamic expiryRaw) {
    final daysLeft = _daysRemaining(expiryRaw);
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10.r),
            decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 26.sp),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your Current Plan', style: TextStyle(color: Colors.white70, fontSize: 12.sp, fontFamily: 'Poppins')),
                SizedBox(height: 2.h),
                Row(
                  children: [
                    Text(name, style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
                    SizedBox(width: 8.w),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20.r)),
                      child: Text('Active', style: TextStyle(color: Colors.white, fontSize: 10.sp, fontWeight: FontWeight.w600, fontFamily: 'Poppins')),
                    ),
                  ],
                ),
                SizedBox(height: 2.h),
                Text(
                  colIndex == 0
                      ? 'Upgrade to unlock premium features'
                      : (validTill != null
                          ? 'Valid till $validTill${daysLeft != null ? '  ($daysLeft days remaining)' : ''}'
                          : 'Enjoying premium membership'),
                  style: TextStyle(color: Colors.white70, fontSize: 11.sp, fontFamily: 'Poppins'),
                ),
              ],
            ),
          ),
          Icon(Icons.workspace_premium, color: Colors.white38, size: 40.sp),
        ],
      ),
    );
  }

  Widget _buildKycNotice() {
    return Container(
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.verified_user_outlined, color: AppColors.warning, size: 22.sp),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              'Complete KYC verification to buy a plan.',
              style: TextStyle(fontSize: 12.sp, fontFamily: 'Poppins', color: AppColors.textPrimary),
            ),
          ),
          TextButton(
            onPressed: () => context.push('/kyc'),
            child: Text('Verify', style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, fontFamily: 'Poppins')),
          ),
        ],
      ),
    );
  }

  // ── Grouped tier section: header + 1/3/6-month duration cards ──────────────
  /// Splits [n] card indices into display rows of up to three, with the smaller
  /// remainder row FIRST. e.g. 4 → [[0], [1,2,3]]; 5 → [[0,1], [2,3,4]];
  /// 3 → [[0,1,2]]; 6 → [[0,1,2], [3,4,5]].
  List<List<int>> _rowGroups(int n) {
    final rows = <List<int>>[];
    final rem = n % 3;
    var i = 0;
    if (rem > 0) {
      rows.add([for (var c = 0; c < rem; c++) i++]);
    }
    while (i < n) {
      rows.add([for (var c = 0; c < 3 && i < n; c++) i++]);
    }
    return rows;
  }

  Widget _buildTierSection(String tier, List<Map<String, dynamic>> tierPlans, bool isLoading) {
    final color = _tierColor[tier] ?? AppColors.memberActive;
    final icon = _tierIcon[tier] ?? Icons.verified_user;
    final title = _tierTitle[tier] ?? tier;
    final badge = _tierBadge[tier];
    final collapsed = _collapsed.contains(tier);

    // 1-month price is the baseline for computing savings on longer durations.
    // Must be an actual ~30-day plan — not a day-scale plan — so a 1-day plan in
    // the tier doesn't get mistaken for the monthly baseline.
    final oneMonth = tierPlans.firstWhere(
      (p) {
        final d = ((p['durationDays'] as num?) ?? 0);
        return d >= 28 && d <= 31;
      },
      orElse: () => tierPlans.firstWhere(
        (p) => ((p['durationDays'] as num?) ?? 0) > 27,
        orElse: () => tierPlans.first,
      ),
    );
    final oneMonthRupees = ((oneMonth['price'] as num?) ?? 0) / 100;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      padding: EdgeInsets.all(14.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => collapsed ? _collapsed.remove(tier) : _collapsed.add(tier)),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8.r),
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  child: Icon(icon, color: Colors.white, size: 18.sp),
                ),
                SizedBox(width: 10.w),
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp, fontFamily: 'Poppins', color: AppColors.textPrimary)),
                SizedBox(width: 8.w),
                if (badge != null)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20.r)),
                    child: Text(badge, style: TextStyle(color: color, fontSize: 10.sp, fontWeight: FontWeight.w700, fontFamily: 'Poppins')),
                  ),
                const Spacer(),
                Icon(collapsed ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up, color: AppColors.textSecondary),
              ],
            ),
          ),
          if (!collapsed) ...[
            SizedBox(height: 14.h),
            // Rows of up to three cards. The SMALLER remainder row goes on TOP —
            // e.g. 4 plans → 1 on top + 3 below; 5 → 2 on top + 3 below; 3 or 6 →
            // even rows of three. Each row spreads across the full width.
            for (int r = 0; r < _rowGroups(tierPlans.length).length; r++) ...[
              if (r > 0) SizedBox(height: 8.h),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (int j = 0; j < _rowGroups(tierPlans.length)[r].length; j++) ...[
                      if (j > 0) SizedBox(width: 8.w),
                      Expanded(child: _buildDurationCard(
                        tier, tierPlans[_rowGroups(tierPlans.length)[r][j]], color, oneMonthRupees, isLoading)),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildDurationCard(String tier, Map<String, dynamic> plan, Color color, double oneMonthRupees, bool isLoading) {
    final priceRupees = ((plan['price'] as num?) ?? 0) / 100;
    final priceRupeesInt = priceRupees.round();
    final days = ((plan['durationDays'] as num?) ?? 30).toInt();
    // Day-scale plans (a 24-hour / few-day plan) are labelled in days; longer ones
    // in months, with the per-month + savings maths that only makes sense there.
    final isDayScale = days <= 27;
    final months = (days / 30).round().clamp(1, 12);
    final perMonth = months > 0 ? (priceRupees / months).round() : priceRupeesInt;
    final label = isDayScale
        ? (days == 1 ? '1 Day' : '$days Days')
        : (months == 1 ? '1 Month' : '$months Months');
    int savePct = 0;
    if (!isDayScale && months > 1 && oneMonthRupees > 0) {
      final full = oneMonthRupees * months;
      savePct = (((full - priceRupees) / full) * 100).round();
    }
    final featureLabel = _tierFeatureLabel[tier] ?? 'Features';

    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      padding: EdgeInsets.all(8.r),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.sp, color: color, fontFamily: 'Poppins')),
          SizedBox(height: 3.h),
          // Reserve the badge row on every card so prices align across durations.
          SizedBox(
            height: 15.h,
            child: savePct > 0
                ? Container(
                    padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.h),
                    decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6.r)),
                    child: Text('SAVE $savePct%', style: TextStyle(color: AppColors.success, fontSize: 8.sp, fontWeight: FontWeight.w700, fontFamily: 'Poppins')),
                  )
                : null,
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 6.h),
            child: Divider(height: 1, color: color.withValues(alpha: 0.2)),
          ),
          Text('₹$priceRupeesInt', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19.sp, color: AppColors.textPrimary, fontFamily: 'Poppins')),
          SizedBox(height: 2.h),
          Text(isDayScale ? (days == 1 ? 'for 24 hours' : 'for $days days') : (months == 1 ? 'per month' : '₹$perMonth / month'),
              style: TextStyle(fontSize: 8.5.sp, color: AppColors.textSecondary, fontFamily: 'Poppins')),
          SizedBox(height: 8.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, color: color, size: 11.sp),
              SizedBox(width: 3.w),
              Flexible(
                child: Text(featureLabel,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 8.sp, color: AppColors.textPrimary, fontFamily: 'Poppins')),
              ),
            ],
          ),
          const Spacer(),
          SizedBox(height: 8.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isLoading ? null : () => _buyPlan(plan),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 2.w),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
              ),
              child: Text('Choose Plan', textAlign: TextAlign.center, style: TextStyle(fontSize: 9.sp, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 8.h),
            child: Text('Feature Comparison',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.sp, fontFamily: 'Poppins', color: AppColors.textPrimary)),
          ),
          _buildPlanHeaderRow(),
          Divider(height: 1, color: AppColors.border),
          ..._features.map(_buildFeatureRow),
          SizedBox(height: 16.h),
          _buildPlanBenefitsHeading(),
          SizedBox(height: 12.h),
        ],
      ),
    );
  }

  // Header row: colored pill per plan (Free / Active / Premium / Golden).
  Widget _buildPlanHeaderRow() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 4.h),
      child: Row(
        children: [
          SizedBox(width: _featureColWidth),
          ...List.generate(4, (col) {
            final color = _planColors[col];
            return Expanded(
              child: Container(
                margin: EdgeInsets.all(4.r),
                padding: EdgeInsets.symmetric(vertical: 9.h, horizontal: 2.w),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Text(_planNames[col],
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.sp, color: Colors.white, fontFamily: 'Poppins')),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(List<dynamic> row) {
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.5))),
      ),
      child: Row(
        children: [
          SizedBox(
            width: _featureColWidth,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
              child: Row(
                children: [
                  Icon(row[0] as IconData, size: 18.sp, color: AppColors.textSecondary),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(row[1] as String,
                        style: TextStyle(fontSize: 11.5.sp, fontFamily: 'Poppins', color: AppColors.textPrimary)),
                  ),
                ],
              ),
            ),
          ),
          ...List.generate(4, (col) {
            final has = row[col + 2] as bool;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 12.h),
                child: Center(
                  child: has
                      ? Icon(Icons.check, color: const Color(0xFF22C55E), size: 20.sp)
                      : Icon(Icons.close, color: const Color(0xFFEF4444), size: 20.sp),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // "Plan Benefits" divider heading (orange rules on both sides).
  Widget _buildPlanBenefitsHeading() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      child: Row(
        children: [
          Expanded(child: Divider(color: AppColors.primary, thickness: 2)),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w),
            child: Text('Plan Benefits',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp, fontFamily: 'Poppins', color: AppColors.textPrimary)),
          ),
          Expanded(child: Divider(color: AppColors.primary, thickness: 2)),
        ],
      ),
    );
  }

  double get _featureColWidth => 130.w;

  int? _daysRemaining(dynamic v) {
    if (v == null) return null;
    final d = DateTime.tryParse(v.toString());
    if (d == null) return null;
    final diff = d.difference(DateTime.now()).inDays;
    return diff > 0 ? diff : null;
  }

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  String? _formatExpiry(dynamic v) {
    if (v == null) return null;
    final d = DateTime.tryParse(v.toString());
    if (d == null) return null;
    return '${d.day} ${_months[d.month - 1]} ${d.year}';
  }
}
