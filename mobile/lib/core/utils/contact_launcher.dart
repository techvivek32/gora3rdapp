import 'package:url_launcher/url_launcher.dart';

/// Dials the given mobile number.
Future<void> callNumber(String mobile) async {
  final uri = Uri.parse('tel:${mobile.replaceAll(RegExp(r'[^0-9+]'), '')}');
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// Opens a WhatsApp chat with the given mobile number (assumes +91 for 10-digit numbers).
Future<void> openWhatsApp(String mobile, {String? message}) async {
  final digits = mobile.replaceAll(RegExp(r'\D'), '');
  final number = digits.length == 10 ? '91$digits' : digits;
  final text = message != null ? '?text=${Uri.encodeComponent(message)}' : '';
  await launchUrl(Uri.parse('https://wa.me/$number$text'), mode: LaunchMode.externalApplication);
}
