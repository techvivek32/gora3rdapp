import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_logo.dart';
import '../bloc/auth_bloc.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _identifierCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _isPhone = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthAuthenticated) {
            context.go('/');
          } else if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: AppColors.error),
            );
          }
        },
        builder: (context, state) {
          return SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 48.h),

                  // Logo + Brand
                  Center(
                    child: Column(
                      children: [
                        AppLogo(size: 72.w, radius: 20.r),
                        SizedBox(height: 16.h),
                        Text('Welcome Back', style: TextStyle(fontSize: 26.sp, fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontFamily: 'Poppins')),
                        SizedBox(height: 6.h),
                        Text('Sign in to your Gora Cabs account', style: TextStyle(fontSize: 14.sp, color: AppColors.textSecondary, fontFamily: 'Poppins')),
                      ],
                    ),
                  ),

                  SizedBox(height: 40.h),

                  // Login Method Toggle
                  Container(
                    padding: EdgeInsets.all(4.r),
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _isPhone = false),
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: 10.h),
                              decoration: BoxDecoration(
                                color: !_isPhone ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(10.r),
                              ),
                              child: Center(
                                child: Text('Email', style: TextStyle(fontSize: 13.sp, fontWeight: !_isPhone ? FontWeight.w600 : FontWeight.w400, color: !_isPhone ? AppColors.primary : AppColors.textSecondary)),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _isPhone = true),
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: 10.h),
                              decoration: BoxDecoration(
                                color: _isPhone ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(10.r),
                              ),
                              child: Center(
                                child: Text('Phone OTP', style: TextStyle(fontSize: 13.sp, fontWeight: _isPhone ? FontWeight.w600 : FontWeight.w400, color: _isPhone ? AppColors.primary : AppColors.textSecondary)),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 24.h),

                  if (!_isPhone) ...[
                    // Email Login Form
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _identifierCtrl,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Email or Mobile',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null,
                          ),
                          SizedBox(height: 16.h),
                          TextFormField(
                            controller: _passwordCtrl,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                            ),
                            validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null,
                          ),
                          SizedBox(height: 8.h),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {},
                              child: Text('Forgot Password?', style: TextStyle(color: AppColors.primary, fontSize: 13.sp)),
                            ),
                          ),
                          SizedBox(height: 16.h),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: state is AuthLoading ? null : () {
                                if (_formKey.currentState!.validate()) {
                                  context.read<AuthBloc>().add(AuthLoginEvent(
                                    identifier: _identifierCtrl.text.trim(),
                                    password: _passwordCtrl.text,
                                  ));
                                }
                              },
                              child: state is AuthLoading
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : Text('Sign In', style: TextStyle(fontSize: 15.sp)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // Phone OTP
                    TextFormField(
                      controller: _identifierCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Mobile Number',
                        prefixIcon: Icon(Icons.phone_outlined),
                        hintText: '+91 98765 43210',
                      ),
                    ),
                    SizedBox(height: 16.h),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          if (_identifierCtrl.text.isNotEmpty) {
                            context.push('/auth/otp', extra: _identifierCtrl.text.trim());
                          }
                        },
                        child: Text('Send OTP', style: TextStyle(fontSize: 15.sp)),
                      ),
                    ),
                  ],

                  SizedBox(height: 24.h),

                  // Register Link
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("Don't have an account? ", style: TextStyle(fontSize: 14.sp, color: AppColors.textSecondary)),
                        GestureDetector(
                          onTap: () => context.go('/auth/register'),
                          child: Text('Register', style: TextStyle(fontSize: 14.sp, color: AppColors.primary, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 32.h),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _identifierCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }
}
