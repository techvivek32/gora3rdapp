import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../data/customer_repository.dart';

/// Downloads the booking's PDF invoice, saves it to the temp dir, then opens the
/// system share/open sheet so the user can view or save it. Shared by the
/// customer booking-detail screen and the driver "My Offers" screen.
Future<void> downloadAndOpenInvoice(
  BuildContext context,
  CustomerRepository repo,
  String bookingId,
) async {
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(
    const SnackBar(content: Text('Preparing invoice…'), duration: Duration(seconds: 1)),
  );
  try {
    final res = await repo.downloadInvoice(bookingId);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${res.filename}');
    await file.writeAsBytes(res.bytes, flush: true);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf', name: res.filename)],
      subject: 'Gora Cabs Invoice',
      text: 'Your Gora Cabs invoice for booking $bookingId.',
    );
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(
        content: Text('Could not download invoice: ${_msg(e)}'),
        backgroundColor: Colors.red.shade600,
      ),
    );
  }
}

String _msg(Object e) {
  final s = e.toString();
  return s.length > 120 ? '${s.substring(0, 120)}…' : s;
}
