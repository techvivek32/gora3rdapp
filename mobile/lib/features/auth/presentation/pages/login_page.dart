import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_logo.dart';
import '../../domain/repositories/auth_repository.dart';
import '../bloc/auth_bloc.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _mobileCtrl = TextEditingController();
  final _authRepo = getIt<AuthRepository>();

  bool _loading = false;

  @override
  void dispose() {
    _mobileCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg, {bool error = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? AppColors.error : Colors.green),
    );
  }

  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;
    final mobile = _mobileCtrl.text.trim();

    setState(() => _loading = true);
    final result = await _authRepo.sendLoginOtp(mobile);
    if (!mounted) return;
    setState(() => _loading = false);

    final failure = result.fold((f) => f, (_) => null);
    if (failure != null) {
      _snack(failure.message); // e.g. "This number is not registered"
      return;
    }

    // Collect + verify the OTP. A wrong code just reopens the dialog.
    while (true) {
      final otp = await _showOtpDialog(mobile);
      if (otp == null) return;
      final ok = await _verifyAndLogin(mobile, otp);
      if (ok) return;
    }
  }

  Future<bool> _verifyAndLogin(String mobile, String otp) async {
    setState(() => _loading = true);
    final result = await _authRepo.loginWithOtp(mobile: mobile, otp: otp);
    if (!mounted) return false;
    setState(() => _loading = false);

    return result.fold(
      (failure) {
        _snack(failure.message); // wrong/expired OTP
        return false;
      },
      (_) {
        context.read<AuthBloc>().add(AuthCheckStatusEvent());
        context.go('/');
        return true;
      },
    );
  }

  Future<String?> _showOtpDialog(String mobile) {
    final otpCtrl = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Verify Mobile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Enter the 6-digit OTP sent to $mobile',
                textAlign: TextAlign.center, style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 16),
            TextField(
              controller: otpCtrl,
              keyboardType: TextInputType.number,
              maxLength: 6,
              autofocus: true,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, letterSpacing: 8, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(counterText: '', hintText: '••••••'),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () async {
                  await _authRepo.sendLoginOtp(mobile);
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('OTP resent')));
                  }
                },
                child: const Text('Resend OTP'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (otpCtrl.text.trim().length >= 4) Navigator.pop(ctx, otpCtrl.text.trim());
            },
            child: const Text('Verify'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                Center(
                  child: Column(
                    children: [
                      AppLogo(size: 72.w, radius: 20.r),
                      SizedBox(height: 16.h),
                      Text('Welcome Back',
                          style: TextStyle(fontSize: 26.sp, fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontFamily: 'Poppins')),
                      SizedBox(height: 6.h),
                      Text('Sign in with your mobile number',
                          style: TextStyle(fontSize: 14.sp, color: AppColors.textSecondary, fontFamily: 'Poppins')),
                    ],
                  ),
                ),
                SizedBox(height: 48.h),
                TextFormField(
                  controller: _mobileCtrl,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                  decoration: const InputDecoration(
                    labelText: 'Mobile Number',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(v)) return 'Enter a valid 10-digit mobile';
                    return null;
                  },
                ),
                SizedBox(height: 24.h),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _sendOtp,
                    style: ElevatedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 14.h)),
                    child: _loading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text('Send OTP', style: TextStyle(fontSize: 15.sp)),
                  ),
                ),
                SizedBox(height: 24.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("New Account ", style: TextStyle(fontSize: 14.sp, color: AppColors.textSecondary)),
                    GestureDetector(
                      onTap: () => context.go('/auth/register'),
                      child: Text('Register', style: TextStyle(fontSize: 16.sp, color: AppColors.primary, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
