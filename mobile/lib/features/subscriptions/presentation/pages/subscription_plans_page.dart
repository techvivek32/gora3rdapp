import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
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
    'active': Color(0xFF3B82F6),
    'verified': Color(0xFF10B981),
    'premium': Color(0xFFF59E0B),
    'golden': Color(0xFFEF4444),
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
      SnackBar(content: Text('Payment failed: ${response.message}'), backgroundColor: Colors.red),
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
      appBar: AppBar(
        title: const Text('Membership Plans'),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFFF97316), Color(0xFFEA580C)]),
          ),
        ),
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
              const SnackBar(content: Text('Membership activated!'), backgroundColor: Colors.green),
            );
            Navigator.pop(context);
          }
          if (state is SubscriptionError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: Colors.red),
            );
          }
        },
        builder: (context, state) {
          if (state is SubscriptionLoading) return const Center(child: CircularProgressIndicator());
          if (state is PlansLoaded) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _HeaderBanner(),
                  const SizedBox(height: 16),
                  ...state.plans.map((plan) => _PlanCard(plan: plan, onSelect: () => _purchasePlan(plan))),
                  const SizedBox(height: 32),
                  _FeatureComparisonTable(),
                ],
              ),
            );
          }
          return const Center(child: Text('No plans available'));
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFF97316), Color(0xFFEA580C)]),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        children: [
          Icon(Icons.workspace_premium, color: Colors.white, size: 48),
          SizedBox(height: 8),
          Text('Unlock Premium Features', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          SizedBox(height: 4),
          Text('Get access to contact details, post more listings, and grow your network', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final Map<String, dynamic> plan;
  final VoidCallback onSelect;

  static const _membershipColors = {
    'active': Color(0xFF3B82F6),
    'verified': Color(0xFF10B981),
    'premium': Color(0xFFF59E0B),
    'golden': Color(0xFFEF4444),
  };

  const _PlanCard({required this.plan, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final membership = plan['membershipType'] as String? ?? 'active';
    final color = _membershipColors[membership] ?? Colors.blue;
    final isPopular = plan['isPopular'] as bool? ?? false;
    final price = plan['price'] as num? ?? 0;
    final discountedPrice = plan['discountedPrice'] as num?;
    final features = List<String>.from(plan['features'] as List? ?? []);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isPopular ? color : Colors.grey.shade200, width: isPopular ? 2 : 1),
        boxShadow: isPopular ? [BoxShadow(color: color.withOpacity(0.2), blurRadius: 12, offset: const Offset(0, 4))] : null,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isPopular)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          margin: const EdgeInsets.only(bottom: 4),
                          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
                          child: const Text('MOST POPULAR', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      Text(plan['name'] as String? ?? '', style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
                      Text(plan['description'] as String? ?? '', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (discountedPrice != null && discountedPrice < price)
                      Text('₹${price.toInt()}', style: TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey.shade400)),
                    Text('₹${(discountedPrice ?? price).toInt()}', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
                    Text('/ ${plan['duration'] ?? 'month'}', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ...features.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: color, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(f, style: const TextStyle(fontSize: 14))),
                    ],
                  ),
                )),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onSelect,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text('Get ${plan['name']}', style: const TextStyle(fontWeight: FontWeight.w600)),
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
  final _colors = [Colors.grey, Color(0xFF3B82F6), Color(0xFFF59E0B), Color(0xFFEF4444)];

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Feature Comparison', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            Table(
              columnWidths: const {0: FlexColumnWidth(2)},
              children: [
                TableRow(
                  children: [
                    const SizedBox(),
                    ..._plans.asMap().entries.map((e) => Center(
                      child: Text(_plans[e.key], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: _colors[e.key])),
                    )),
                  ],
                ),
                ..._features.map((row) => TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(row[0] as String, style: const TextStyle(fontSize: 13)),
                    ),
                    ...List.generate(4, (i) => Center(
                      child: row[i + 1] as bool
                          ? Icon(Icons.check, color: _colors[i], size: 18)
                          : const Icon(Icons.close, color: Colors.grey, size: 18),
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
