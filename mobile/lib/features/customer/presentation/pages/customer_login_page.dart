import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_logo.dart';
import '../../../../core/widgets/otp_verify_dialog.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';

/// Dedicated Customer login — mobile + OTP only. An unregistered number is sent
/// to the customer sign-up (never the driver form).
class CustomerLoginPage extends StatefulWidget {
  const CustomerLoginPage({super.key});

  @override
  State<CustomerLoginPage> createState() => _CustomerLoginPageState();
}

class _CustomerLoginPageState extends State<CustomerLoginPage> {
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
      if (failure is NotRegisteredFailure) {
        _snack('This number is not registered. Please sign up.', error: false);
        context.go('/customer/register?mobile=$mobile');
        return;
      }
      _snack(failure.message);
      return;
    }

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

    final failure = result.fold((f) => f, (_) => null);
    if (failure != null) {
      _snack(failure.message); // wrong/expired OTP → re-prompt
      return false;
    }

    // This is the CUSTOMER login — only customer accounts may enter here. A
    // driver/vendor number must use the Driver login, so we sign back out and
    // tell them, instead of dropping them into vendor mode.
    final data = result.fold((_) => <String, dynamic>{}, (d) => d);
    final role = ((data['user'] as Map?)?['role'] ?? '').toString();
    if (role.isNotEmpty && role != 'customer') {
      await _authRepo.logout();
      if (!mounted) return true;
      _snack('This number is registered as a Driver / Vendor. Please use the Driver login.');
      return true; // handled — stop the OTP loop, stay on customer login
    }

    // Router redirect sends the user to the home that matches their role.
    context.read<AuthBloc>().add(AuthCheckStatusEvent());
    context.go('/customer');
    return true;
  }

  Future<String?> _showOtpDialog(String mobile) {
    return showOtpVerifyDialog(
      context,
      mobile: mobile,
      onResend: () async {
        final result = await _authRepo.sendLoginOtp(mobile);
        result.fold((f) => throw Exception(f.message), (_) {});
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: AppColors.background, elevation: 0, foregroundColor: AppColors.textPrimary),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
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
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
                          decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20.r)),
                          child: Text('CUSTOMER', style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w800, color: AppColors.primary, letterSpacing: 1, fontFamily: 'Poppins')),
                        ),
                        SizedBox(height: 12.h),
                        Text('Welcome Back',
                            style: TextStyle(fontSize: 26.sp, fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontFamily: 'Poppins')),
                        SizedBox(height: 6.h),
                        Text('Sign in to book your ride',
                            style: TextStyle(fontSize: 14.sp, color: AppColors.textSecondary, fontFamily: 'Poppins')),
                      ],
                    ),
                  ),
                  SizedBox(height: 40.h),
                  TextFormField(
                    controller: _mobileCtrl,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                    decoration: const InputDecoration(labelText: 'Mobile Number', prefixIcon: Icon(Icons.phone_outlined)),
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
                      Text('New here? ', style: TextStyle(fontSize: 14.sp, color: AppColors.textSecondary)),
                      GestureDetector(
                        onTap: () => context.go('/customer/register'),
                        child: Text('Create account', style: TextStyle(fontSize: 16.sp, color: AppColors.primary, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  Center(
                    child: TextButton(
                      onPressed: () => context.go('/auth/login'),
                      child: Text('Are you a Driver / Vendor?', style: TextStyle(fontSize: 13.sp, color: AppColors.textSecondary)),
                    ),
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
