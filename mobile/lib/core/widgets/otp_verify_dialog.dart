import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'otp_input.dart';

/// Shows the "Verify Mobile" dialog. Resolves to the entered code, or null if
/// the user cancels.
///
/// [onResend] is called when the user taps Resend (only enabled once the 30s
/// cooldown expires). It should re-trigger the send-OTP request.
Future<String?> showOtpVerifyDialog(
  BuildContext context, {
  required String mobile,
  required Future<void> Function() onResend,
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _OtpVerifyDialog(mobile: mobile, onResend: onResend),
  );
}

class _OtpVerifyDialog extends StatefulWidget {
  final String mobile;
  final Future<void> Function() onResend;
  const _OtpVerifyDialog({required this.mobile, required this.onResend});

  @override
  State<_OtpVerifyDialog> createState() => _OtpVerifyDialogState();
}

class _OtpVerifyDialogState extends State<_OtpVerifyDialog> {
  static const _cooldown = 30; // seconds before Resend is allowed again

  String _code = '';
  int _secondsLeft = _cooldown;
  bool _resending = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _secondsLeft = _cooldown);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      if (_secondsLeft <= 1) {
        t.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  Future<void> _resend() async {
    if (_secondsLeft > 0 || _resending) return;
    setState(() => _resending = true);
    try {
      await widget.onResend();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OTP resent')),
      );
      _startCountdown();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not resend OTP. Try again.'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  void _submit() {
    if (_code.length == 6) Navigator.of(context).pop(_code);
  }

  @override
  Widget build(BuildContext context) {
    final canResend = _secondsLeft == 0 && !_resending;
    return AlertDialog(
      title: const Text('Verify Mobile'),
      contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      // Pull the dialog closer to the screen edges, and let the content take the
      // full width so the six OTP boxes get room to breathe.
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enter the 6-digit OTP sent to ${widget.mobile}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 18),
            OtpInput(
              onChanged: (v) => setState(() => _code = v),
              onCompleted: (_) => _submit(), // auto-verify once all 6 digits are in
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.center,
              child: _resending
                  ? const Padding(
                      padding: EdgeInsets.all(8),
                      child: SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : TextButton(
                      onPressed: canResend ? _resend : null,
                      child: Text(
                        canResend ? 'Resend OTP' : 'Resend OTP in ${_secondsLeft}s',
                        style: TextStyle(
                          color: canResend ? AppColors.primary : AppColors.textHint,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _code.length == 6 ? _submit : null,
          child: const Text('Verify'),
        ),
      ],
    );
  }
}
