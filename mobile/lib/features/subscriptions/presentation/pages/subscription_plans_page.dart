import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../bloc/subscription_bloc.dart';

class SubscriptionPlansPage extends StatefulWidget {
  const SubscriptionPlansPage({super.key});

  @override
  State<SubscriptionPlansPage> createState() => _SubscriptionPlansPageState();
}

class _SubscriptionPlansPageState extends State<SubscriptionPlansPage> {
  final _razorpay = Razorpay();
  String? _pendingPlanId;

  static const _membershipColors = {
    'active': AppColors.memberActive,
    'verified': AppColors.memberVerified,
    'premium': AppColors.memberPremium,
    'golden': AppColors.memberGolden,
  };

  @override
  void initState() {
    super.initState();
    context.read<SubscriptionBloc>().add(LoadPlansEvent());
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onPaymentError);
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

  void _purchasePlan(Map<String, dynamic> plan) {
    _pendingPlanId = plan['_id'] as String;
    context.read<SubscriptionBloc>().add(CreateOrderEvent(_pendingPlanId!));
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Membership Plans', style: TextStyle(fontFamily: 'Poppins')),
        centerTitle: true,
        backgroundColor: AppColors.primary,
      ),
      body: BlocConsumer<SubscriptionBloc, SubscriptionState>(
        listener: (context, state) {
          if (state is OrderCreated) {
            final order = state.orderData;
            final options = {
              'key': const String.fromEnvironment('RAZORPAY_KEY', defaultValue: ''),
              'amount': order['amount'],
              'currency': 'INR',
              'order_id': order['razorpayOrderId'],
              'name': 'Gora Cabs',
              'description': 'Membership Upgrade',
              'prefill': {'contact': '', 'email': ''},
              'theme': {'color': '#F97316'},
            };
            _razorpay.open(options);
          }
          if (state is PaymentVerified) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Membership activated!'), backgroundColor: AppColors.success),
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
          if (state is SubscriptionLoading) return Center(child: CircularProgressIndicator(color: AppColors.primary));
          if (state is PlansLoaded) {
            return SingleChildScrollView(
              padding: EdgeInsets.all(16.r),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _HeaderBanner(),
                  SizedBox(height: 16.h),
                  ...state.plans.map((plan) => _PlanCard(plan: plan, onSelect: () => _purchasePlan(plan))),
                  SizedBox(height: 32.h),
                  _FeatureComparisonTable(),
                ],
              ),
            );
          }
          return Center(child: Text('No plans available', style: TextStyle(fontFamily: 'Poppins')));
        },
      ),
    );
  }
}

class _HeaderBanner extends StatelessWidget {
  const _HeaderBanner();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        children: [
          Icon(Icons.workspace_premium, color: Colors.white, size: 48.sp),
          SizedBox(height: 8.h),
          Text('Unlock Premium Features', style: TextStyle(color: Colors.white, fontSize: 20.sp, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
          SizedBox(height: 4.h),
          Text('Get access to contact details, post more listings, and grow your network', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontFamily: 'Poppins')),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final Map<String, dynamic> plan;
  final VoidCallback onSelect;

  static const _membershipColors = {
    'active': AppColors.memberActive,
    'verified': AppColors.memberVerified,
    'premium': AppColors.memberPremium,
    'golden': AppColors.memberGolden,
  };

  const _PlanCard({required this.plan, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final membership = plan['membershipType'] as String? ?? 'active';
    final color = _membershipColors[membership] ?? AppColors.info;
    final isPopular = plan['isPopular'] as bool? ?? false;
    final price = plan['price'] as num? ?? 0;
    final discountedPrice = plan['discountedPrice'] as num?;
    final features = List<String>.from(plan['features'] as List? ?? []);

    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16.r),
        color: Colors.white,
        border: Border.all(color: isPopular ? color : AppColors.border, width: isPopular ? 2.w : 1.w),
        boxShadow: isPopular ? [BoxShadow(color: color.withOpacity(0.2), blurRadius: 12, offset: const Offset(0, 4))] : null,
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16.r),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.vertical(top: Radius.circular(14.r)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isPopular)
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                          margin: EdgeInsets.only(bottom: 4.h),
                          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8.r)),
                          child: Text('MOST POPULAR', style: TextStyle(color: Colors.white, fontSize: 10.sp, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
                        ),
                      Text(plan['name'] as String? ?? '', style: TextStyle(color: color, fontSize: 18.sp, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
                      Text(plan['description'] as String? ?? '', style: TextStyle(color: AppColors.textSecondary, fontSize: 13.sp, fontFamily: 'Poppins')),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (discountedPrice != null && discountedPrice < price)
                      Text('₹${price.toInt()}', style: TextStyle(decoration: TextDecoration.lineThrough, color: AppColors.textHint, fontFamily: 'Poppins')),
                    Text('₹${(discountedPrice ?? price).toInt()}', style: TextStyle(fontSize: 24.sp, fontWeight: FontWeight.bold, color: color, fontFamily: 'Poppins')),
                    Text('/ ${plan['duration'] ?? 'month'}', style: TextStyle(color: AppColors.textHint, fontSize: 12.sp, fontFamily: 'Poppins')),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16.r),
            child: Column(
              children: [
                ...features.map((f) => Padding(
                  padding: EdgeInsets.only(bottom: 8.h),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: color, size: 18.sp),
                      SizedBox(width: 8.w),
                      Expanded(child: Text(f, style: TextStyle(fontSize: 14.sp, fontFamily: 'Poppins'))),
                    ],
                  ),
                )),
                SizedBox(height: 12.h),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onSelect,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                    ),
                    child: Text('Get ${plan['name']}', style: TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Poppins')),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureComparisonTable extends StatelessWidget {
  _FeatureComparisonTable();
  final _features = [
    ['View Contact Details', false, true, true, true],
    ['Post Requirements', true, true, true, true],
    ['Post Available Cabs', true, true, true, true],
    ['Business Cities Filter', false, true, true, true],
    ['Featured Listings', false, false, true, true],
    ['Priority Support', false, false, true, true],
    ['Unlimited Listings', false, false, false, true],
  ];

  final _plans = ['Free', 'Active', 'Premium', 'Golden'];
  final _colors = [AppColors.textHint, AppColors.memberActive, AppColors.memberPremium, AppColors.memberGolden];

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.r),
        side: BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Feature Comparison', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp, fontFamily: 'Poppins')),
            SizedBox(height: 12.h),
            Table(
              columnWidths: const {0: FlexColumnWidth(2)},
              children: [
                TableRow(
                  children: [
                    SizedBox(),
                    ..._plans.asMap().entries.map((e) => Center(
                      child: Text(_plans[e.key], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.sp, color: _colors[e.key], fontFamily: 'Poppins')),
                    )),
                  ],
                ),
                ..._features.map((row) => TableRow(
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.h),
                      child: Text(row[0] as String, style: TextStyle(fontSize: 13.sp, fontFamily: 'Poppins')),
                    ),
                    ...List.generate(4, (i) => Center(
                      child: row[i + 1] as bool
                          ? Icon(Icons.check, color: _colors[i], size: 18.sp)
                          : Icon(Icons.close, color: AppColors.textHint, size: 18.sp),
                    )),
                  ],
                )),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
