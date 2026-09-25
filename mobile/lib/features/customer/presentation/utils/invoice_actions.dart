import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/config/env.dart';
import '../../data/customer_repository.dart';

/// Opens the booking's PDF invoice in the browser / PDF viewer via a short-lived
/// signed URL. Uses url_launcher only (no file/share native plugins), so it works
/// without path_provider. Shared by the customer + driver invoice buttons.
Future<void> downloadAndOpenInvoice(
  BuildContext context,
  CustomerRepository repo,
  String bookingId,
) async {
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(
    const SnackBar(content: Text('Opening invoice…'), duration: Duration(seconds: 1)),
  );
  try {
    final token = await repo.invoiceLinkToken(bookingId);
    if (token.isEmpty) throw Exception('Invoice link unavailable');
    final url = Uri.parse('${Env.apiBaseUrl}/customer-bookings/invoice-file/$token');
    final ok = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!ok) throw Exception('Could not open the invoice');
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(
        content: Text('Could not open invoice: ${_msg(e)}'),
        backgroundColor: Colors.red.shade600,
      ),
    );
  }
}

String _msg(Object e) {
  final s = e.toString();
  return s.length > 120 ? '${s.substring(0, 120)}…' : s;
}
