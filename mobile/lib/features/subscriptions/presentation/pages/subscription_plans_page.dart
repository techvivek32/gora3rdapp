import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
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
const _features = [
  ['View Contact Details', false, true, true, true],
  ['Post Requirements', true, true, true, true],
  ['Post Available Cabs', true, true, true, true],
  ['Business Cities Filter', false, true, true, true],
  ['Featured Listings', false, false, true, true],
  ['Priority Support', false, false, true, true],
  ['Unlimited Listings', false, false, false, true],
];

class SubscriptionPlansPage extends StatefulWidget {
  const SubscriptionPlansPage({super.key});

  @override
  State<SubscriptionPlansPage> createState() => _SubscriptionPlansPageState();
}

class _SubscriptionPlansPageState extends State<SubscriptionPlansPage> {
  Razorpay? _razorpay;
  String? _pendingPlanId;
  // selected col: 0=Free(no buy), 1=Active, 2=Premium, 3=Golden
  int _selectedCol = 0;
  Map<String, dynamic>? _selectedPlan;

  @override
  void initState() {
    super.initState();
    context.read<SubscriptionBloc>().add(LoadPlansEvent());
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

  void _onColTap(int col, List<Map<String, dynamic>> plans) {
    if (col == 0) {
      setState(() { _selectedCol = 0; _selectedPlan = null; });
      return;
    }
    // map col index to membershipType
    final typeMap = {1: 'active', 2: 'premium', 3: 'golden'};
    final type = typeMap[col];
    final plan = plans.where((p) => p['membershipType'] == type).firstOrNull;
    setState(() { _selectedCol = col; _selectedPlan = plan; });
  }

  void _buySelectedPlan() {
    if (_selectedPlan == null) return;
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payments are only supported on the mobile app.'), backgroundColor: AppColors.warning),
      );
      return;
    }
    _pendingPlanId = _selectedPlan!['_id'] as String;
    context.read<SubscriptionBloc>().add(CreateOrderEvent(_pendingPlanId!));
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

          final selColor = _planColors[_selectedCol];

          // Get current user membership
          final authState = context.read<AuthBloc>().state;
          final user = authState is AuthAuthenticated ? authState.user as Map<String, dynamic>? : null;
          final currentMembership = user?['membershipType'] as String? ?? 'new';
          final currentColIndex = const {'new': 0, 'active': 1, 'verified': 1, 'premium': 2, 'golden': 3}[currentMembership] ?? 0;
          final currentColor = _planColors[currentColIndex];
          final currentIcon = _planIcons[currentColIndex];
          final currentName = currentColIndex == 0 ? 'Free' : _planNames[currentColIndex];

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(16.r),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Current plan card
                      Container(
                        padding: EdgeInsets.all(16.r),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
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
                              child: Icon(currentIcon, color: Colors.white, size: 26.sp),
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
                                      Text(currentName, style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
                                      SizedBox(width: 8.w),
                                      Container(
                                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                                        decoration: BoxDecoration(
                                          color: Colors.white24,
                                          borderRadius: BorderRadius.circular(20.r),
                                        ),
                                        child: Text('Active', style: TextStyle(color: Colors.white, fontSize: 10.sp, fontWeight: FontWeight.w600, fontFamily: 'Poppins')),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 2.h),
                                  Text(
                                    currentColIndex == 0 ? 'Upgrade to unlock premium features' : 'Enjoying premium membership',
                                    style: TextStyle(color: Colors.white70, fontSize: 11.sp, fontFamily: 'Poppins'),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.workspace_premium, color: Colors.white38, size: 40.sp),
                          ],
                        ),
                      ),
                      SizedBox(height: 20.h),

                      // Selectable feature comparison table
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16.r),
                          border: Border.all(color: AppColors.border),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 8.h),
                              child: Text('Feature Comparison', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.sp, fontFamily: 'Poppins', color: AppColors.textPrimary)),
                            ),
                            // Plan header columns — tappable
                            _buildPlanHeaderRow(plans),

                            Divider(height: 1, color: AppColors.border),

                            // Feature rows
                            ..._features.map((row) => _buildFeatureRow(row)),

                            SizedBox(height: 8.h),

                            // Price summary row for selected plan
                            if (_selectedCol > 0 && _selectedPlan != null)
                              _buildPriceSummary(_selectedPlan!, selColor),
                          ],
                        ),
                      ),
                      SizedBox(height: 100.h),
                    ],
                  ),
                ),
              ),

              // Sticky bottom buy button
              _buildBottomBar(isOrdering, selColor),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPlanHeaderRow(List<Map<String, dynamic>> plans) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 4.h),
      child: Row(
        children: [
          // Feature label column header
          SizedBox(width: _featureColWidth),
          // Plan columns
          ...List.generate(4, (col) {
            final isSelected = _selectedCol == col;
            final color = _planColors[col];

            return Expanded(
              child: GestureDetector(
                onTap: () => _onColTap(col, plans),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: EdgeInsets.all(4.r),
                  padding: EdgeInsets.symmetric(vertical: 10.h),
                  decoration: BoxDecoration(
                    color: isSelected ? color : color.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(
                      color: isSelected ? color : color.withOpacity(0.2),
                      width: isSelected ? 2.w : 1.w,
                    ),
                    boxShadow: isSelected
                        ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))]
                        : null,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_planIcons[col], color: isSelected ? Colors.white : color, size: 18.sp),
                      SizedBox(height: 4.h),
                      Text(_planNames[col],
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 10.sp,
                            color: isSelected ? Colors.white : color,
                            fontFamily: 'Poppins',
                          )),
                    ],
                  ),
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
        border: Border(bottom: BorderSide(color: AppColors.border.withOpacity(0.5))),
      ),
      child: Row(
        children: [
          // Feature name
          SizedBox(
            width: _featureColWidth,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
              child: Text(row[0] as String, style: TextStyle(fontSize: 12.sp, fontFamily: 'Poppins', color: AppColors.textPrimary)),
            ),
          ),
          // Check/cross per plan col
          ...List.generate(4, (col) {
            final isSelected = _selectedCol == col;
            final color = _planColors[col];
            final has = row[col + 1] as bool;
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                color: isSelected ? color.withOpacity(0.06) : Colors.transparent,
                padding: EdgeInsets.symmetric(vertical: 10.h),
                child: Center(
                  child: has
                      ? Icon(Icons.check_circle, color: color, size: 18.sp)
                      : Icon(Icons.close, color: AppColors.textHint.withOpacity(0.35), size: 16.sp),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPriceSummary(Map<String, dynamic> plan, Color color) {
    final price = plan['price'] as num? ?? 0;
    final disc = plan['discountedPrice'] as num? ?? 0;
    final eff = (disc > 0 && disc < price) ? disc : price;
    final duration = plan['duration'] as String? ?? 'month';

    return Container(
      margin: EdgeInsets.all(12.r),
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(_planIcons[_selectedCol], color: color, size: 22.sp),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(plan['name'] as String? ?? '', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp, color: color, fontFamily: 'Poppins')),
                Text(plan['description'] as String? ?? '', style: TextStyle(fontSize: 11.sp, color: AppColors.textSecondary, fontFamily: 'Poppins')),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (disc > 0 && disc < price)
                Text('₹${(price / 100).toStringAsFixed(0)}',
                    style: TextStyle(decoration: TextDecoration.lineThrough, color: AppColors.textHint, fontSize: 12.sp, fontFamily: 'Poppins')),
              Text('₹${(eff / 100).toStringAsFixed(0)}',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20.sp, color: color, fontFamily: 'Poppins')),
              Text('/ $duration', style: TextStyle(fontSize: 10.sp, color: AppColors.textHint, fontFamily: 'Poppins')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(bool isLoading, Color selColor) {
    final isFree = _selectedCol == 0;
    final color = isFree ? AppColors.textHint : selColor;

    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 24.h),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isFree)
              ElevatedButton(
                onPressed: isLoading ? null : _buySelectedPlan,
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: color.withOpacity(0.5),
                  elevation: 0,
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                ),
                child: isLoading
                    ? SizedBox(height: 20.h, width: 20.w, child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(_planIcons[_selectedCol], size: 20.sp),
                          SizedBox(width: 8.w),
                          Text('Buy ${_planNames[_selectedCol]} Plan', style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
                        ],
                      ),
              ),
            if (!isFree) SizedBox(height: 8.h),
            if (!isFree)
              OutlinedButton(
                onPressed: isLoading ? null : () {
                  if (_selectedPlan == null) return;
                  context.read<SubscriptionBloc>().add(
                    TestActivateSubscriptionEvent(_selectedPlan!['_id'] as String)
                  );
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: color, width: 1.5),
                  foregroundColor: color,
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.science_outlined, size: 18.sp),
                    SizedBox(width: 8.w),
                    Text('Test Activate (No Payment)', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600, fontFamily: 'Poppins')),
                  ],
                ),
              ),
            if (isFree)
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 16.h),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: AppColors.border, width: 1.5),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.touch_app_outlined, color: AppColors.textHint, size: 20.sp),
                    SizedBox(width: 8.w),
                    Text('Tap a plan above to upgrade',
                        style: TextStyle(fontSize: 14.sp, fontFamily: 'Poppins', color: AppColors.textHint, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  double get _featureColWidth => 120.w;
}
