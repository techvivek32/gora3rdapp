import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/error/error_mapper.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  final _api = getIt<ApiClient>();
  final _amountCtrl = TextEditingController();
  Razorpay? _razorpay;

  num _balance = 0;
  List<Map<String, dynamic>> _transactions = [];
  bool _loading = true;
  bool _processing = false;

  static const _presets = [100, 500, 1000, 2000];

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _razorpay = Razorpay();
      _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaymentSuccess);
      _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, _onPaymentError);
    }
    _load();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _razorpay?.clear();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _api.get('/wallet');
      final data = res.data['data'] as Map<String, dynamic>;
      setState(() {
        _balance = (data['balance'] as num?) ?? 0;
        _transactions = ((data['transactions'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  void _snack(String msg, {bool error = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? AppColors.error : AppColors.success),
    );
  }

  Future<void> _addMoney(int amount) async {
    if (amount < 1) {
      _snack('Enter a valid amount');
      return;
    }
    if (kIsWeb) {
      _snack('Payments are only supported on the mobile app.');
      return;
    }
    setState(() => _processing = true);
    try {
      final res = await _api.post('/wallet/create-order', data: {'amount': amount});
      final order = res.data['data'] as Map<String, dynamic>;
      _openRazorpay(order);
    } catch (e) {
      setState(() => _processing = false);
      _snack(ErrorMapper.message(e));
    }
  }

  void _openRazorpay(Map<String, dynamic> order) {
    final authState = context.read<AuthBloc>().state;
    final user = authState is AuthAuthenticated ? authState.user as Map<String, dynamic>? : null;
    _razorpay!.open({
      'key': order['keyId'] ?? 'rzp_test_RlUAkt1HzIvV4j',
      'amount': order['amount'],
      'currency': order['currency'] ?? 'INR',
      'order_id': order['orderId'],
      'name': 'Gora Cabs',
      'description': 'Wallet Top-up',
      'prefill': {
        'contact': user?['mobile'] ?? '',
        'email': user?['email'] ?? '',
        'name': user?['fullName'] ?? '',
      },
      'theme': {'color': '#F97316'},
    });
  }

  Future<void> _onPaymentSuccess(PaymentSuccessResponse response) async {
    try {
      await _api.post('/wallet/verify', data: {
        'razorpayOrderId': response.orderId,
        'razorpayPaymentId': response.paymentId,
        'razorpaySignature': response.signature,
      });
      _amountCtrl.clear();
      _snack('Money added to your wallet!', error: false);
      await _load();
    } catch (_) {
      _snack('Payment succeeded but crediting failed. Contact support if not credited.');
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  void _onPaymentError(PaymentFailureResponse response) {
    if (mounted) setState(() => _processing = false);
    _snack('Payment failed: ${response.message ?? ''}');
  }

  /// Selectable pill used to pick the payout method (bank vs UPI).
  Widget _methodChip({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withValues(alpha: 0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: selected ? AppColors.primary : AppColors.textSecondary),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showWithdrawSheet() async {
    final amountCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final bankCtrl = TextEditingController();
    final accCtrl = TextEditingController();
    final ifscCtrl = TextEditingController();
    final upiCtrl = TextEditingController();
    String method = 'bank'; // 'bank' | 'upi'
    bool submitting = false;

    InputDecoration dec(String label, IconData icon) => InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20),
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        );

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final isBank = method == 'bank';

          Future<void> submit() async {
            final amt = int.tryParse(amountCtrl.text.trim()) ?? 0;
            if (amt < 1) return _snack('Enter a valid amount');
            if (amt > _balance) return _snack('You can withdraw at most ₹${_balance.toStringAsFixed(0)}');
            if (nameCtrl.text.trim().isEmpty) return _snack('Enter the account holder name');

            if (isBank) {
              if (bankCtrl.text.trim().isEmpty || accCtrl.text.trim().isEmpty || ifscCtrl.text.trim().isEmpty) {
                return _snack('Please fill all bank details');
              }
            } else {
              final upi = upiCtrl.text.trim();
              if (!RegExp(r'^[\w.\-]{2,}@[a-zA-Z]{2,}$').hasMatch(upi)) {
                return _snack('Enter a valid UPI ID (e.g. name@bank)');
              }
            }

            setSheet(() => submitting = true);
            try {
              await _api.post('/wallet/withdraw', data: {
                'amount': amt,
                'method': method,
                'accountHolderName': nameCtrl.text.trim(),
                if (isBank) ...{
                  'bankName': bankCtrl.text.trim(),
                  'accountNumber': accCtrl.text.trim(),
                  'ifsc': ifscCtrl.text.trim().toUpperCase(),
                } else
                  'upiId': upiCtrl.text.trim(),
              });
              if (ctx.mounted) Navigator.pop(ctx);
              _snack('Withdrawal request submitted for review.', error: false);
              await _load();
            } catch (e) {
              setSheet(() => submitting = false);
              _snack(ErrorMapper.message(e));
            }
          }

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42, height: 4,
                      decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Withdraw Money', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Available balance: ₹${_balance.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(height: 16),

                  // Payout method: bank transfer or UPI.
                  Row(
                    children: [
                      Expanded(
                        child: _methodChip(
                          label: 'Bank Account',
                          icon: Icons.account_balance_outlined,
                          selected: isBank,
                          onTap: () => setSheet(() => method = 'bank'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _methodChip(
                          label: 'UPI ID',
                          icon: Icons.qr_code_2,
                          selected: !isBank,
                          onTap: () => setSheet(() => method = 'upi'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: dec('Amount (₹)', Icons.currency_rupee),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: dec(isBank ? 'Account Holder Name' : 'Name', Icons.person_outline),
                  ),
                  const SizedBox(height: 12),

                  if (isBank) ...[
                    TextField(controller: bankCtrl, textCapitalization: TextCapitalization.words, decoration: dec('Bank Name', Icons.account_balance_outlined)),
                    const SizedBox(height: 12),
                    TextField(controller: accCtrl, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: dec('Account Number', Icons.numbers)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: ifscCtrl,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]'))],
                      decoration: dec('IFSC Code', Icons.qr_code),
                    ),
                  ] else
                    TextField(
                      controller: upiCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: dec('UPI ID (e.g. name@bank)', Icons.alternate_email),
                    ),

                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: submitting ? null : submit,
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                      child: submitting
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Confirm Withdrawal', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('The amount is held from your wallet until an admin reviews the request. If rejected, it is refunded.',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            ),
          );
        },
      ),
    );
    // Delay so the sheet's TextFields (still mounted through the close animation)
    // don't reference disposed controllers.
    Future.delayed(const Duration(milliseconds: 400), () {
      amountCtrl.dispose();
      nameCtrl.dispose();
      bankCtrl.dispose();
      accCtrl.dispose();
      ifscCtrl.dispose();
      upiCtrl.dispose();
    });
  }

  /// Send money to another user: look them up by mobile, then transfer.
  Future<void> _showTransferSheet() async {
    final phoneCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    Map<String, dynamic>? recipient; // resolved user, null until found
    bool searching = false;
    bool submitting = false;

    InputDecoration dec(String label, IconData icon) => InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20),
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        );

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          Future<void> search() async {
            final phone = phoneCtrl.text.trim();
            if (phone.length < 10) return _snack('Enter a valid 10-digit mobile number');
            setSheet(() {
              searching = true;
              recipient = null;
            });
            try {
              final res = await _api.get('/users/lookup', params: {'mobile': phone});
              final user = Map<String, dynamic>.from(res.data['data'] as Map);
              setSheet(() {
                recipient = user;
                searching = false;
              });
            } catch (e) {
              setSheet(() => searching = false);
              _snack(ErrorMapper.message(e));
            }
          }

          Future<void> submit() async {
            if (recipient == null) return _snack('Search and select a user first');
            final amt = int.tryParse(amountCtrl.text.trim()) ?? 0;
            if (amt < 1) return _snack('Enter a valid amount');
            // Server re-checks this, but fail fast so we never even attempt it.
            if (amt > _balance) {
              return _snack('Insufficient balance. You have ₹${_balance.toStringAsFixed(0)}');
            }
            setSheet(() => submitting = true);
            try {
              await _api.post('/wallet/transfer', data: {
                'mobile': phoneCtrl.text.trim(),
                'amount': amt,
                if (noteCtrl.text.trim().isNotEmpty) 'note': noteCtrl.text.trim(),
              });
              if (ctx.mounted) Navigator.pop(ctx);
              _snack('₹$amt sent successfully.', error: false);
              await _load();
            } catch (e) {
              setSheet(() => submitting = false);
              _snack(ErrorMapper.message(e));
            }
          }

          final name = ((recipient?['agencyName'] as String?)?.trim().isNotEmpty == true)
              ? recipient!['agencyName'] as String
              : (recipient?['fullName'] as String? ?? '');

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42, height: 4,
                      decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Transfer Money', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Available balance: ₹${_balance.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(height: 16),

                  // 1. Find the recipient by phone number.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: phoneCtrl,
                          keyboardType: TextInputType.phone,
                          maxLength: 10,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          onChanged: (_) {
                            if (recipient != null) setSheet(() => recipient = null);
                          },
                          decoration: dec('Recipient mobile number', Icons.phone_outlined)
                              .copyWith(counterText: ''),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: searching ? null : search,
                          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16)),
                          child: searching
                              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.search, size: 20),
                        ),
                      ),
                    ],
                  ),

                  // 2. Show who we found before any money moves.
                  if (recipient != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                            backgroundImage: (recipient!['profileImage'] as String?)?.isNotEmpty == true
                                ? NetworkImage(recipient!['profileImage'] as String)
                                : null,
                            child: (recipient!['profileImage'] as String?)?.isNotEmpty == true
                                ? null
                                : Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Flexible(child: Text(name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold))),
                                  if (recipient!['isVerified'] == true) ...[
                                    const SizedBox(width: 4),
                                    const Icon(Icons.verified, size: 14, color: Color(0xFF2196F3)),
                                  ],
                                ]),
                                Text('${recipient!['mobile'] ?? ''}',
                                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              ],
                            ),
                          ),
                          const Icon(Icons.check_circle, color: Colors.green, size: 20),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: dec('Amount (₹)', Icons.currency_rupee),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteCtrl,
                      maxLength: 120,
                      decoration: dec('Note (optional)', Icons.notes).copyWith(counterText: ''),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: submitting ? null : submit,
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                        child: submitting
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Send Money', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('Money moves instantly to the recipient. Transfers cannot be reversed.',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
    // showModalBottomSheet's future completes as soon as the sheet is popped, while
    // its TextFields are still mounted through the close animation. Disposing the
    // controllers now would tear them out from under live widgets.
    Future.delayed(const Duration(milliseconds: 400), () {
      phoneCtrl.dispose();
      amountCtrl.dispose();
      noteCtrl.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Wallet'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _balanceCard(),
                  const SizedBox(height: 20),
                  const Text('Add Money', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _presets.map((a) => _presetChip(a)).toList(),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _amountCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Enter amount (₹)',
                      prefixIcon: Icon(Icons.currency_rupee),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _processing
                          ? null
                          : () => _addMoney(int.tryParse(_amountCtrl.text.trim()) ?? 0),
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)),
                      child: _processing
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Add Money', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: (_processing || _balance <= 0) ? null : _showWithdrawSheet,
                      icon: const Icon(Icons.account_balance_outlined, size: 20),
                      label: const Text('Withdraw', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: (_processing || _balance <= 0) ? null : _showTransferSheet,
                      icon: const Icon(Icons.send_rounded, size: 20),
                      label: const Text('Transfer', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('Recent Transactions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  if (_transactions.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: Text('No transactions yet', style: TextStyle(color: AppColors.textSecondary))),
                    )
                  else
                    ..._transactions.map(_txTile),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _balanceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet_outlined, color: Colors.white70, size: 22),
              const SizedBox(width: 8),
              const Text('Wallet Balance', style: TextStyle(color: Colors.white70, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 10),
          Text('₹${_balance.toStringAsFixed(0)}',
              style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text('Keep a minimum balance to use call, WhatsApp & booking features.',
              style: TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _presetChip(int amount) {
    return GestureDetector(
      onTap: _processing ? null : () => _addMoney(amount),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.primary),
        ),
        child: Text('₹$amount', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary)),
      ),
    );
  }

  Widget _txTile(Map<String, dynamic> tx) {
    final amount = (tx['amount'] as num?) ?? 0;
    final type = (tx['type'] ?? 'credit').toString();
    final status = (tx['status'] ?? '').toString();
    final isCredit = type == 'credit';
    final ok = status == 'success';
    final note = (tx['note'] ?? '').toString().trim();

    // Transfers read "Transfer → 9876543210" on one line, with the note beneath it.
    final isTransfer = (tx['source'] ?? '').toString() == 'transfer';
    final other = tx['counterpartyId'] is Map ? Map<String, dynamic>.from(tx['counterpartyId'] as Map) : null;
    final otherMobile = (other?['mobile'] ?? '').toString();

    final title = isTransfer
        ? (otherMobile.isNotEmpty ? 'Transfer → $otherMobile' : 'Transfer')
        : (note.isNotEmpty ? note : (isCredit ? 'Added to wallet' : 'Debited'));

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(isCredit ? Icons.south_west : Icons.north_east,
              color: isCredit ? AppColors.success : AppColors.error, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                if (isTransfer && note.isNotEmpty)
                  Text(note, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                Text(status, style: TextStyle(fontSize: 11, color: ok ? AppColors.success : AppColors.textHint)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text('${isCredit ? '+' : '-'}₹${amount.toStringAsFixed(0)}',
              style: TextStyle(fontWeight: FontWeight.w700, color: isCredit ? AppColors.success : AppColors.error)),
        ],
      ),
    );
  }
}
