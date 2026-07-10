import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens an admin-configured notification action URL.
///
/// A full `http(s)://` link opens in the browser; anything else is treated as an
/// in-app go_router path (`/subscription`, `requirements` → `/requirements`).
Future<void> openActionUrl(BuildContext context, String? actionUrl) async {
  final url = (actionUrl ?? '').trim();
  if (url.isEmpty) return;

  final lower = url.toLowerCase();
  if (lower.startsWith('http://') || lower.startsWith('https://')) {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Action URL launch failed: $e');
    }
    return;
  }

  if (!context.mounted) return;
  context.push(url.startsWith('/') ? url : '/$url');
}
