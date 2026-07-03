import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/wallet/wallet_guard.dart';
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
const _features = [
  ['View Contact Details', false, true, true, true],
  ['Post Requirements', true, true, true, true],
  ['Post Available Cabs', true, true, true, true],
  ['Business Cities Filter', false, true, true, true],
  ['Featured Listings', false, false, true, true],
  ['Priority Support', false, false, true, true],
  ['Unlimited Listings', false, false, false, true],
];

const _membershipCol = {'new': 0, 'active': 1, 'verified': 1, 'premium': 2, 'golden': 3};
const _durationLabel = {
  'monthly': '/ month',
  'quarterly': '/ 3 months',
  'half_yearly': '/ 6 months',
  'yearly': '/ year',
};

class SubscriptionPlansPage extends StatefulWidget {
  const SubscriptionPlansPage({super.key});

  @override
  State<SubscriptionPlansPage> createState() => _SubscriptionPlansPageState();
}

class _SubscriptionPlansPageState extends State<SubscriptionPlansPage> {
  Razorpay? _razorpay;
  String? _pendingPlanId;

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
    // Gate: buying a plan needs a minimum wallet balance.
    if (!await ensureMinWalletBalance(context, action: 'buy a plan')) return;
    _pendingPlanId = plan['_id'] as String;
    bloc.add(CreateOrderEvent(_pendingPlanId!));
  }

  void _testActivate(Map<String, dynamic> plan) {
    if (!_isVerified()) {
      _promptKyc();
      return;
    }
    context.read<SubscriptionBloc>().add(TestActivateSubscriptionEvent(plan['_id'] as String));
  }

  void _openRazorpay(Map<String, dynamic> order) {
    if (kIsWeb || _razorpay == null) return;
    final authState = context.read<AuthBloc>().state;
    final user = authState is AuthAuthenticated ? authState.user as Map<String, dynamic>? : null;
    _razorpay!.open({
      'key': 'rzp_test_RlUAkt1HzIvV4j',
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

          final visiblePlans = _filtered(plans);

          return SingleChildScrollView(
            padding: EdgeInsets.all(16.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildCurrentPlanBanner(currentIcon, currentName, currentColIndex),
                SizedBox(height: 16.h),

                if (!_isVerified()) ...[
                  _buildKycNotice(),
                  SizedBox(height: 16.h),
                ],

                // Buyable plan cards
                ...visiblePlans.map((p) => _buildPlanCard(p, currentMembership, isOrdering)),
                SizedBox(height: 8.h),

                // Static (non-selectable) feature comparison
                _buildComparisonTable(),
                SizedBox(height: 24.h),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCurrentPlanBanner(IconData icon, String name, int colIndex) {
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
                  colIndex == 0 ? 'Upgrade to unlock premium features' : 'Enjoying premium membership',
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

  Widget _buildPlanCard(Map<String, dynamic> plan, String currentMembership, bool isLoading) {
    final type = (plan['membershipType'] as String?) ?? 'active';
    final col = _membershipCol[type] ?? 1;
    final color = _planColors[col];
    final icon = _planIcons[col];
    final price = (plan['price'] as num?) ?? 0;
    final disc = (plan['discountedPrice'] as num?) ?? 0;
    final eff = (disc > 0 && disc < price) ? disc : price;
    final duration = (plan['duration'] as String?) ?? 'monthly';
    final durationText = _durationLabel[duration] ?? '/ $duration';
    final isPopular = plan['isPopular'] == true;
    final isCurrent = type == currentMembership;

    // Use the plan's own features if present, else derive from the comparison table.
    final List<String> feats = (plan['features'] as List?)?.map((e) => e.toString()).toList() ??
        _features.where((f) => f[col + 1] == true).map((f) => f[0] as String).toList();

    return Container(
      margin: EdgeInsets.only(bottom: 14.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: isPopular ? color : AppColors.border, width: isPopular ? 1.5 : 1),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          if (isPopular)
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 5.h),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.vertical(top: Radius.circular(15.r)),
              ),
              child: Text('⭐ Most Popular',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 11.sp, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
            ),
          Padding(
            padding: EdgeInsets.all(16.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(10.r),
                      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
                      child: Icon(icon, color: color, size: 22.sp),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Text(plan['name'] as String? ?? _planNames[col],
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp, color: color, fontFamily: 'Poppins')),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (disc > 0 && disc < price)
                          Text('₹${(price / 100).toStringAsFixed(0)}',
                              style: TextStyle(decoration: TextDecoration.lineThrough, color: AppColors.textHint, fontSize: 12.sp, fontFamily: 'Poppins')),
                        Text('₹${(eff / 100).toStringAsFixed(0)}',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22.sp, color: color, fontFamily: 'Poppins')),
                        Text(durationText, style: TextStyle(fontSize: 10.sp, color: AppColors.textHint, fontFamily: 'Poppins')),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
                ...feats.take(6).map((f) => Padding(
                      padding: EdgeInsets.symmetric(vertical: 3.h),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, color: color, size: 16.sp),
                          SizedBox(width: 8.w),
                          Expanded(child: Text(f, style: TextStyle(fontSize: 12.sp, fontFamily: 'Poppins', color: AppColors.textPrimary))),
                        ],
                      ),
                    )),
                SizedBox(height: 14.h),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (isLoading || isCurrent) ? null : () => _buyPlan(plan),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: color.withValues(alpha: 0.4),
                      elevation: 0,
                      padding: EdgeInsets.symmetric(vertical: 13.h),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                    ),
                    child: Text(isCurrent ? 'Current Plan' : 'Buy Now',
                        style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
                  ),
                ),
                if (!isCurrent)
                  TextButton(
                    onPressed: isLoading ? null : () => _testActivate(plan),
                    child: Text('Test Activate (No Payment)',
                        style: TextStyle(fontSize: 12.sp, color: AppColors.textSecondary, fontFamily: 'Poppins')),
                  ),
              ],
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
          SizedBox(height: 8.h),
        ],
      ),
    );
  }

  // Static header — display only, not tappable.
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
                padding: EdgeInsets.symmetric(vertical: 10.h),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(color: color.withValues(alpha: 0.2)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_planIcons[col], color: color, size: 18.sp),
                    SizedBox(height: 4.h),
                    Text(_planNames[col],
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10.sp, color: color, fontFamily: 'Poppins')),
                  ],
                ),
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
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
              child: Text(row[0] as String, style: TextStyle(fontSize: 12.sp, fontFamily: 'Poppins', color: AppColors.textPrimary)),
            ),
          ),
          ...List.generate(4, (col) {
            final color = _planColors[col];
            final has = row[col + 1] as bool;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 10.h),
                child: Center(
                  child: has
                      ? Icon(Icons.check_circle, color: color, size: 18.sp)
                      : Icon(Icons.close, color: AppColors.textHint.withValues(alpha: 0.35), size: 16.sp),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  double get _featureColWidth => 120.w;
}
