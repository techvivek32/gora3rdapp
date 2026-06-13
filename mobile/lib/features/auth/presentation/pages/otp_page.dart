import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pinput/pinput.dart';
import '../bloc/auth_bloc.dart';

class OtpPage extends StatefulWidget {
  final String phoneNumber;
  const OtpPage({super.key, required this.phoneNumber});

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> {
  String? _verificationId;
  bool _codeSent = false;
  bool _loading = true;
  String? _error;
  final _otpController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _sendOtp();
  }

  Future<void> _sendOtp() async {
    setState(() { _loading = true; _error = null; });
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: '+91${widget.phoneNumber}',
      timeout: const Duration(seconds: 60),
      verificationCompleted: (credential) async {
        final userCred = await FirebaseAuth.instance.signInWithCredential(credential);
        final idToken = await userCred.user?.getIdToken();
        if (idToken != null && mounted) {
          context.read<AuthBloc>().add(AuthVerifyOtpEvent(firebaseIdToken: idToken));
        }
      },
      verificationFailed: (e) => setState(() { _error = e.message; _loading = false; }),
      codeSent: (verificationId, _) => setState(() { _verificationId = verificationId; _codeSent = true; _loading = false; }),
      codeAutoRetrievalTimeout: (verificationId) => setState(() { _verificationId = verificationId; _loading = false; }),
    );
  }

  Future<void> _verifyOtp(String otp) async {
    if (_verificationId == null) return;
    setState(() { _loading = true; _error = null; });
    try {
      final credential = PhoneAuthProvider.credential(verificationId: _verificationId!, smsCode: otp);
      final userCred = await FirebaseAuth.instance.signInWithCredential(credential);
      final idToken = await userCred.user?.getIdToken();
      if (idToken != null && mounted) {
        context.read<AuthBloc>().add(AuthVerifyOtpEvent(firebaseIdToken: idToken));
      }
    } on FirebaseAuthException catch (e) {
      setState(() { _error = e.message; _loading = false; });
    }
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final defaultPinTheme = PinTheme(
      width: 52,
      height: 52,
      textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Verify OTP'), centerTitle: true),
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthAuthenticated) context.go('/');
          if (state is AuthError) setState(() { _error = state.message; _loading = false; });
        },
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 32),
              const Icon(Icons.sms_outlined, size: 64, color: Colors.orange),
              const SizedBox(height: 24),
              Text('OTP Sent to', style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text('+91 ${widget.phoneNumber}', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 32),
              if (_loading) const CircularProgressIndicator(),
              if (!_loading && _codeSent) ...[
                Pinput(
                  controller: _otpController,
                  length: 6,
                  defaultPinTheme: defaultPinTheme,
                  focusedPinTheme: defaultPinTheme.copyWith(
                    decoration: defaultPinTheme.decoration!.copyWith(
                      border: Border.all(color: theme.primaryColor, width: 2),
                    ),
                  ),
                  onCompleted: _verifyOtp,
                ),
                const SizedBox(height: 24),
                if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _sendOtp,
                  child: const Text('Resend OTP'),
                ),
              ],
              if (!_loading && !_codeSent && _error != null) ...[
                Text(_error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: _sendOtp, child: const Text('Retry')),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
