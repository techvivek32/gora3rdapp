import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/places_city_field.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../data/customer_repository.dart';

/// First-time customer setup for a logged-in driver/vendor switching to Customer
/// Mode. Name & mobile already exist on the account, so we only collect City
/// (+ optional photo/email), then flip the account into Customer Mode.
class CustomerOnboardingPage extends StatefulWidget {
  const CustomerOnboardingPage({super.key});

  @override
  State<CustomerOnboardingPage> createState() => _CustomerOnboardingPageState();
}

class _CustomerOnboardingPageState extends State<CustomerOnboardingPage> {
  final _cityCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _picker = ImagePicker();
  final _api = getIt<ApiClient>();
  Uint8List? _photoBytes;
  bool _busy = false;

  @override
  void dispose() {
    _cityCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final p = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 800, imageQuality: 80);
    if (p == null) return;
    final b = await p.readAsBytes();
    setState(() => _photoBytes = b);
  }

  Future<String?> _uploadPhoto() async {
    if (_photoBytes == null) return null;
    FormData form() => FormData.fromMap({'file': MultipartFile.fromBytes(_photoBytes!, filename: 'profile.jpg')});
    try {
      final res = await _api.dio.post('/storage/upload/profile', data: form());
      return res.data['data'] as String?;
    } catch (_) {
      return null;
    }
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating));

  Future<void> _submit() async {
    if (_cityCtrl.text.trim().isEmpty) {
      _snack('Please select your city');
      return;
    }
    setState(() => _busy = true);
    try {
      final img = await _uploadPhoto();
      await getIt<CustomerRepository>().switchToCustomer(
        city: _cityCtrl.text.trim(),
        profileImage: img,
        email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      );
      if (!mounted) return;
      context.read<AuthBloc>().add(const AuthReloadProfileEvent());
      context.go('/customer');
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _snack('Could not switch: ${e.toString().replaceFirst('Exception: ', '')}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthBloc>().state;
    final user = auth is AuthAuthenticated ? auth.user as Map<String, dynamic>? : null;
    final name = (user?['fullName'] ?? '').toString();
    final mobile = (user?['mobile'] ?? '').toString();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Set up Customer Mode'), backgroundColor: AppColors.primary, foregroundColor: Colors.white),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 20.h),
          children: [
            Center(
              child: GestureDetector(
                onTap: _busy ? null : _pickPhoto,
                child: CircleAvatar(
                  radius: 44.r,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  backgroundImage: _photoBytes != null ? MemoryImage(_photoBytes!) : null,
                  child: _photoBytes == null ? Icon(Icons.add_a_photo_outlined, color: AppColors.primary, size: 28.sp) : null,
                ),
              ),
            ),
            SizedBox(height: 6.h),
            Center(child: Text('Add photo (optional)', style: TextStyle(fontSize: 11.sp, color: AppColors.textSecondary, fontFamily: 'Poppins'))),
            SizedBox(height: 20.h),
            Text("You're switching to Customer Mode. Your name and mobile are already verified — just confirm your city.",
                style: TextStyle(fontSize: 13.sp, color: AppColors.textSecondary, fontFamily: 'Poppins')),
            SizedBox(height: 18.h),
            _readonlyTile(Icons.person_outline, 'Name', name.isEmpty ? '—' : name),
            SizedBox(height: 12.h),
            _readonlyTile(Icons.phone_outlined, 'Mobile', mobile.isEmpty ? '—' : mobile),
            SizedBox(height: 16.h),
            PlacesCityField(
              label: 'City',
              icon: Icons.location_city_outlined,
              required: true,
              initialText: _cityCtrl.text,
              onChanged: (city, state) => _cityCtrl.text = city,
            ),
            SizedBox(height: 16.h),
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Email (optional)',
                prefixIcon: const Icon(Icons.email_outlined, color: AppColors.primary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
              ),
            ),
            SizedBox(height: 28.h),
            SizedBox(
              height: 52.h,
              child: ElevatedButton(
                onPressed: _busy ? null : _submit,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r))),
                child: _busy
                    ? SizedBox(width: 22.w, height: 22.w, child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text('Continue as Customer', style: TextStyle(fontSize: 15.5.sp, fontWeight: FontWeight.w700, fontFamily: 'Poppins')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _readonlyTile(IconData icon, String label, String value) => Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12.r), border: Border.all(color: AppColors.border)),
        child: Row(children: [
          Icon(icon, size: 20.sp, color: AppColors.textSecondary),
          SizedBox(width: 12.w),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 10.5.sp, color: AppColors.textHint, fontFamily: 'Poppins')),
            Text(value, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700, fontFamily: 'Poppins')),
          ]),
        ]),
      );
}
