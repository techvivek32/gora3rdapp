import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/error/error_mapper.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/otp_verify_dialog.dart';
import '../../../../core/widgets/places_city_field.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';

/// Dedicated Customer sign-up — light and fast: photo (optional), name,
/// mobile+OTP, email (optional), city. NO account-type, agency or KYC.
class CustomerRegisterPage extends StatefulWidget {
  /// Pre-filled when login sends an unregistered number here.
  final String? initialMobile;
  const CustomerRegisterPage({super.key, this.initialMobile});

  @override
  State<CustomerRegisterPage> createState() => _CustomerRegisterPageState();
}

class _CustomerRegisterPageState extends State<CustomerRegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();

  Uint8List? _profileBytes;
  bool _submitting = false;
  String _status = '';
  bool _registered = false;

  final _picker = ImagePicker();
  final _apiClient = getIt<ApiClient>();
  final _authRepo = getIt<AuthRepository>();

  @override
  void initState() {
    super.initState();
    final mobile = widget.initialMobile?.trim() ?? '';
    if (mobile.isNotEmpty) _mobileCtrl.text = mobile;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _mobileCtrl.dispose();
    _emailCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg, {bool error = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? AppColors.error : Colors.green),
    );
  }

  Future<void> _pickProfile() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 800, imageQuality: 85);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() => _profileBytes = bytes);
  }

  Future<String> _uploadProfile(Uint8List bytes) async {
    FormData buildForm() => FormData.fromMap({'file': MultipartFile.fromBytes(bytes, filename: 'profile.jpg')});
    Response res;
    try {
      res = await _apiClient.dio.post('/storage/upload/profile', data: buildForm());
    } catch (_) {
      res = await _apiClient.dio.post('/storage/upload/profile', data: buildForm());
    }
    return res.data['data'] as String;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() { _submitting = true; _status = 'Sending OTP...'; });
    try {
      await _apiClient.dio.post('/auth/register/send-otp', data: {'mobile': _mobileCtrl.text.trim()});
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _snack(ErrorMapper.message(e));
      return;
    }
    if (!mounted) return;
    setState(() => _submitting = false);

    while (true) {
      final otp = await _showOtpDialog();
      if (otp == null) return;
      final done = await _completeRegistration(otp);
      if (done) return;
    }
  }

  Future<bool> _completeRegistration(String otp) async {
    setState(() { _submitting = true; _status = 'Creating account...'; });

    if (!_registered) {
      final result = await _authRepo.register(
        fullName: _nameCtrl.text.trim(),
        mobile: _mobileCtrl.text.trim(),
        email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        city: _cityCtrl.text.trim().isEmpty ? null : _cityCtrl.text.trim(),
        state: _stateCtrl.text.trim().isEmpty ? null : _stateCtrl.text.trim(),
        role: 'customer',
        otp: otp,
      );
      final failure = result.fold((f) => f, (_) => null);
      if (failure != null) {
        if (!mounted) return false;
        setState(() => _submitting = false);
        _snack(failure.message);
        return false; // wrong/expired OTP → re-prompt
      }
      _registered = true;
    }

    // Optional profile photo — the account already exists, so never block on this.
    try {
      if (_profileBytes != null) {
        setState(() => _status = 'Uploading photo...');
        final url = await _uploadProfile(_profileBytes!);
        await _apiClient.dio.put('/users/profile', data: {'profileImage': url});
      }
    } catch (_) {}

    if (!mounted) return true;
    _snack('Account created successfully.', error: false);
    context.read<AuthBloc>().add(AuthCheckStatusEvent());
    context.go('/customer');
    return true;
  }

  Future<String?> _showOtpDialog() {
    final mobile = _mobileCtrl.text.trim();
    return showOtpVerifyDialog(
      context,
      mobile: mobile,
      onResend: () => _apiClient.dio.post('/auth/register/send-otp', data: {'mobile': mobile}),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account'), centerTitle: true),
      body: AbsorbPointer(
        absorbing: _submitting,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(24.w, 8.h, 24.w, 24.h),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: 8.h),
                Center(
                  child: GestureDetector(
                    onTap: _pickProfile,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 44.r,
                          backgroundColor: Colors.grey.shade200,
                          backgroundImage: _profileBytes != null ? MemoryImage(_profileBytes!) : null,
                          child: _profileBytes == null ? Icon(Icons.person, size: 44.sp, color: Colors.grey.shade500) : null,
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: EdgeInsets.all(6.r),
                            decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                            child: Icon(Icons.camera_alt, size: 16.sp, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 6.h),
                Center(child: Text('Profile Picture (Optional)', style: TextStyle(fontSize: 12.sp, color: Colors.grey))),
                SizedBox(height: 20.h),
                TextFormField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person_outline)),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                SizedBox(height: 16.h),
                TextFormField(
                  controller: _mobileCtrl,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                  decoration: const InputDecoration(labelText: 'Mobile Number', prefixIcon: Icon(Icons.phone_outlined)),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(v)) return 'Enter valid 10-digit mobile';
                    return null;
                  },
                ),
                SizedBox(height: 16.h),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email (Optional)', prefixIcon: Icon(Icons.email_outlined)),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null; // optional
                    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim())) return 'Enter a valid email';
                    return null;
                  },
                ),
                SizedBox(height: 16.h),
                PlacesCityField(
                  label: 'City',
                  icon: Icons.location_city_outlined,
                  required: true,
                  initialText: _cityCtrl.text,
                  onChanged: (city, state) {
                    _cityCtrl.text = city;
                    if (state != null && state.isNotEmpty) _stateCtrl.text = state;
                  },
                ),
                SizedBox(height: 28.h),
                ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 16.h)),
                  child: _submitting
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                            SizedBox(width: 12.w),
                            Text(_status, style: TextStyle(fontSize: 14.sp, color: Colors.white)),
                          ],
                        )
                      : Text('Create Account', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600)),
                ),
                SizedBox(height: 16.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Already have an account? ', style: TextStyle(fontSize: 14.sp, color: AppColors.textSecondary)),
                    GestureDetector(
                      onTap: () => context.go('/customer/login'),
                      child: Text('Sign In', style: TextStyle(fontSize: 15.sp, color: AppColors.primary, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
