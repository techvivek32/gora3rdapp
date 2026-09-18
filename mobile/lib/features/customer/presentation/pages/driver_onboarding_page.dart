import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/places_city_field.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../data/customer_repository.dart';

/// First-time driver setup for a logged-in (customer-first) account switching to
/// Driver Mode. Name & mobile already exist; we collect city (+ optional business
/// name) and flip the account into Driver Mode. Full KYC is done later from the
/// driver profile.
class DriverOnboardingPage extends StatefulWidget {
  const DriverOnboardingPage({super.key});

  @override
  State<DriverOnboardingPage> createState() => _DriverOnboardingPageState();
}

class _DriverOnboardingPageState extends State<DriverOnboardingPage> {
  final _cityCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _agencyCtrl = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _agencyCtrl.dispose();
    super.dispose();
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating));

  Future<void> _submit() async {
    if (_cityCtrl.text.trim().isEmpty) {
      _snack('Please select your city');
      return;
    }
    setState(() => _busy = true);
    try {
      await getIt<CustomerRepository>().switchToDriver(
        city: _cityCtrl.text.trim(),
        state: _stateCtrl.text.trim().isEmpty ? null : _stateCtrl.text.trim(),
        agencyName: _agencyCtrl.text.trim().isEmpty ? null : _agencyCtrl.text.trim(),
      );
      if (!mounted) return;
      context.read<AuthBloc>().add(const AuthReloadProfileEvent());
      context.go('/');
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
      appBar: AppBar(title: const Text('Set up Driver Mode'), backgroundColor: AppColors.primary, foregroundColor: Colors.white),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 20.h),
          children: [
            Center(
              child: CircleAvatar(
                radius: 40.r,
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                child: Icon(Icons.local_taxi_rounded, color: AppColors.primary, size: 34.sp),
              ),
            ),
            SizedBox(height: 18.h),
            Text("You're switching to Driver Mode. Your name and mobile are already verified — confirm your city to continue. You can complete KYC later from your profile.",
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
              onChanged: (city, state) {
                _cityCtrl.text = city;
                if (state != null && state.isNotEmpty) _stateCtrl.text = state;
              },
            ),
            SizedBox(height: 16.h),
            TextField(
              controller: _agencyCtrl,
              decoration: InputDecoration(
                labelText: 'Business / Agency name (optional)',
                prefixIcon: const Icon(Icons.business_outlined, color: AppColors.primary),
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
                    : Text('Continue as Driver', style: TextStyle(fontSize: 15.5.sp, fontWeight: FontWeight.w700, fontFamily: 'Poppins')),
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
