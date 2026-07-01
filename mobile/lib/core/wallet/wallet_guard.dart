import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../di/injection.dart';
import '../network/api_client.dart';

/// Minimum wallet balance (₹) required to post a requirement, post an available
/// vehicle, or buy a plan. Mirrors the backend gate (MIN_WALLET_BALANCE).
const kMinWalletBalance = 500;

/// Returns `true` when the user has at least [kMinWalletBalance] in their wallet.
///
/// When the balance is too low it shows a dialog offering to open the wallet and
/// returns `false`. If the balance can't be fetched, it returns `true` and lets
/// the backend enforce the rule (so a transient network issue never hard-blocks).
Future<bool> ensureMinWalletBalance(BuildContext context, {required String action}) async {
  num balance;
  try {
    final res = await getIt<ApiClient>().get('/wallet');
    final data = res.data['data'] as Map<String, dynamic>;
    balance = (data['balance'] as num?) ?? 0;
  } catch (_) {
    return true; // couldn't verify — let the server decide
  }

  if (balance >= kMinWalletBalance) return true;
  if (!context.mounted) return false;

  await showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Add money to continue'),
      content: Text(
        'You need a minimum wallet balance of ₹$kMinWalletBalance to $action.\n\n'
        'Your current balance is ₹${balance.toStringAsFixed(0)}. Please add money to your wallet.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            context.push('/wallet');
          },
          child: const Text('Open Wallet'),
        ),
      ],
    ),
  );
  return false;
}
