import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/image_source_picker.dart';
import '../../../../core/utils/install_referrer.dart';
import '../../../../core/widgets/kyc_doc_fields.dart';
import '../../../../core/widgets/places_city_field.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../data/customer_repository.dart';
import '../role_switch.dart';

/// First-time driver setup for a logged-in (customer-first) account switching to
/// Driver Mode.
///
/// This asks for everything the DRIVER REGISTRATION form asks for, minus the
/// name and mobile (already verified on this account) and the OTP (already
/// signed in). It used to collect only a city, which meant someone arriving
/// this way became a driver with no account type and no KYC at all — a weaker
/// account than one created through Register, for the same job. The shared
/// [KycDocTile] is what keeps the two forms from drifting apart again.
class DriverOnboardingPage extends StatefulWidget {
  const DriverOnboardingPage({super.key});

  @override
  State<DriverOnboardingPage> createState() => _DriverOnboardingPageState();
}

class _DriverOnboardingPageState extends State<DriverOnboardingPage> {
  final _formKey = GlobalKey<FormState>();
  final _cityCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _agencyCtrl = TextEditingController();
  final _referralCtrl = TextEditingController();
  final _api = getIt<ApiClient>();

  // Same two options, same default, as the registration form.
  static const _roles = [
    {'value': 'travel_agency', 'label': 'Travel Agency'},
    {'value': 'driver', 'label': 'Driver'},
  ];
  String _selectedRole = 'travel_agency';

  final List<KycDocField> _docs = defaultKycDocs();
  Uint8List? _profileBytes;
  bool _busy = false;
  String _status = '';

  @override
  void initState() {
    super.initState();
    // An invite that brought them to the app still counts when they take up
    // driving later — prefill it exactly as registration does.
    pendingReferralCode().then((code) {
      if (code != null && mounted && _referralCtrl.text.isEmpty) {
        setState(() => _referralCtrl.text = code);
      }
    });
  }

  @override
  void dispose() {
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _agencyCtrl.dispose();
    _referralCtrl.dispose();
    super.dispose();
  }

  void _snack(String m, {bool error = true}) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(m),
          backgroundColor: error ? AppColors.error : AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );

  Future<void> _pickProfile() async {
    final picked = await pickImageFromCameraOrGallery(
      context,
      maxWidth: 800,
      imageQuality: 85,
      title: 'Profile photo',
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (mounted) setState(() => _profileBytes = bytes);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_cityCtrl.text.trim().isEmpty) {
      _snack('Please select your city');
      return;
    }
    // KYC is mandatory here for the same reason it is on Register: an
    // unverified driver cannot be given work.
    final missing = missingKycDocLabels(_docs);
    if (missing.isNotEmpty) {
      _snack('Upload front and back photos of: ${missing.join(' and ')}');
      return;
    }

    setState(() {
      _busy = true;
      _status = 'Switching to Driver Mode...';
    });
    try {
      await getIt<CustomerRepository>().switchToDriver(
        city: _cityCtrl.text.trim(),
        state: _stateCtrl.text.trim().isEmpty ? null : _stateCtrl.text.trim(),
        agencyName: _agencyCtrl.text.trim().isEmpty ? null : _agencyCtrl.text.trim(),
        role: _selectedRole,
        referralCode: _referralCtrl.text.trim().isEmpty ? null : _referralCtrl.text.trim(),
      );
      clearPendingReferralCode();

      // The switch issued fresh tokens, so these two run as the driver.
      if (_profileBytes != null) {
        if (mounted) setState(() => _status = 'Uploading profile...');
        await _uploadProfile(_profileBytes!);
      }
      if (mounted) setState(() => _status = 'Uploading documents...');
      await submitKycDocs(_api, _docs);

      if (!mounted) return;
      // Wait for the new role to reach the router before navigating, otherwise
      // its redirect still sees the old one and flashes the customer home.
      await applyRoleAndWait(context.read<AuthBloc>(), _selectedRole);
      if (!mounted) return;
      _snack('Welcome to Driver Mode. Your documents are under review.', error: false);
      context.go('/');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = '';
      });
      _snack('Could not switch: ${e.toString().replaceFirst('Exception: ', '')}');
    }
  }

  Future<void> _uploadProfile(Uint8List bytes) async {
    // FormData streams are consumed on first use, so build a fresh one for each
    // attempt — otherwise the auth interceptor's token-refresh retry fails.
    FormData form() => FormData.fromMap({
          'file': MultipartFile.fromBytes(bytes, filename: 'profile.jpg'),
        });
    Response res;
    try {
      res = await _api.dio.post('/storage/upload/profile', data: form());
    } catch (_) {
      res = await _api.dio.post('/storage/upload/profile', data: form());
    }
    await _api.dio.put('/users/profile', data: {'profileImage': res.data['data']});
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthBloc>().state;
    final user = auth is AuthAuthenticated ? auth.user as Map<String, dynamic>? : null;
    final name = (user?['fullName'] ?? '').toString();
    final mobile = (user?['mobile'] ?? '').toString();
    final primary = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Set up Driver Mode'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 28.h),
            children: [
              Center(
                child: GestureDetector(
                  onTap: _busy ? null : _pickProfile,
                  child: CircleAvatar(
                    radius: 44.r,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    backgroundImage: _profileBytes != null ? MemoryImage(_profileBytes!) : null,
                    child: _profileBytes != null
                        ? null
                        : Icon(Icons.add_a_photo_outlined, color: AppColors.primary, size: 30.sp),
                  ),
                ),
              ),
              SizedBox(height: 6.h),
              Center(
                child: Text('Profile Picture (Optional)',
                    style: TextStyle(fontSize: 12.sp, color: Colors.grey, fontFamily: 'Poppins')),
              ),
              SizedBox(height: 18.h),
              Text(
                "You're switching to Driver Mode. Your name and mobile are already verified — fill in the rest to finish setting up your driver account.",
                style: TextStyle(fontSize: 13.sp, color: AppColors.textSecondary, fontFamily: 'Poppins'),
              ),
              SizedBox(height: 18.h),
              _readonlyTile(Icons.person_outline, 'Name', name.isEmpty ? '—' : name),
              SizedBox(height: 12.h),
              _readonlyTile(Icons.phone_outlined, 'Mobile', mobile.isEmpty ? '—' : mobile),
              SizedBox(height: 16.h),
              DropdownButtonFormField<String>(
                initialValue: _selectedRole,
                decoration: InputDecoration(
                  labelText: 'Account Type',
                  prefixIcon: const Icon(Icons.business_center_outlined, color: AppColors.primary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                ),
                items: _roles
                    .map((r) => DropdownMenuItem(value: r['value'], child: Text(r['label']!)))
                    .toList(),
                onChanged: _busy ? null : (v) => setState(() => _selectedRole = v!),
              ),
              // Only a travel agency has a business name — same rule as Register.
              if (_selectedRole == 'travel_agency') ...[
                SizedBox(height: 16.h),
                TextFormField(
                  controller: _agencyCtrl,
                  decoration: InputDecoration(
                    labelText: 'Agency / Business Name (Optional)',
                    prefixIcon: const Icon(Icons.storefront_outlined, color: AppColors.primary),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                  ),
                ),
              ],
              SizedBox(height: 16.h),
              TextFormField(
                controller: _referralCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: 'Referral Code (Optional)',
                  hintText: 'e.g. GORA7K3QF',
                  prefixIcon: const Icon(Icons.card_giftcard_outlined, color: AppColors.primary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                ),
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
              SizedBox(height: 16.h),
              TextFormField(
                controller: _stateCtrl,
                decoration: InputDecoration(
                  labelText: 'State',
                  prefixIcon: const Icon(Icons.map_outlined, color: AppColors.primary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                ),
              ),
              SizedBox(height: 28.h),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Verification Documents',
                    style: TextStyle(
                        fontSize: 16.sp, fontWeight: FontWeight.w700, color: primary, fontFamily: 'Poppins')),
              ),
              SizedBox(height: 4.h),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Required — upload front & back photos of each document to get verified.',
                    style: TextStyle(fontSize: 12.sp, color: Colors.grey, fontFamily: 'Poppins')),
              ),
              SizedBox(height: 12.h),
              ..._docs.map((d) => KycDocTile(doc: d, onChanged: () => setState(() {}))),
              SizedBox(height: 16.h),
              SizedBox(
                height: 52.h,
                child: ElevatedButton(
                  onPressed: _busy ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
                  ),
                  child: _busy
                      ? SizedBox(
                          width: 22.w,
                          height: 22.w,
                          child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text('Continue as Driver',
                          style: TextStyle(fontSize: 15.5.sp, fontWeight: FontWeight.w700, fontFamily: 'Poppins')),
                ),
              ),
              if (_busy && _status.isNotEmpty) ...[
                SizedBox(height: 10.h),
                Center(
                  child: Text(_status,
                      style: TextStyle(fontSize: 12.sp, color: AppColors.textSecondary, fontFamily: 'Poppins')),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _readonlyTile(IconData icon, String label, String value) => Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
        decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: AppColors.border)),
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
