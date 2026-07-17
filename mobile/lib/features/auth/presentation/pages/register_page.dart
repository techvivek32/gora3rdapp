import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/error/error_mapper.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/install_referrer.dart';
import '../../../../core/widgets/otp_verify_dialog.dart';
import '../../../../core/widgets/places_city_field.dart';
import '../../domain/repositories/auth_repository.dart';
import '../bloc/auth_bloc.dart';

/// A single KYC document the user must provide (id number + image).
class _DocField {
  final String key; // matches backend: aadhar, pan, drivingLicense, vehicleRc
  final String label;
  final TextEditingController numberCtrl = TextEditingController();
  Uint8List? bytes; // front side
  Uint8List? backBytes; // back side
  _DocField(this.key, this.label);
}

class RegisterPage extends StatefulWidget {
  /// Pre-filled when the login page sends an unregistered number here, so the
  /// user doesn't have to type it a second time.
  final String? initialMobile;

  const RegisterPage({super.key, this.initialMobile});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _agencyCtrl = TextEditingController();
  final _referralCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  String _selectedRole = 'travel_agency';

  bool _submitting = false;
  String _status = '';
  bool _registered = false;

  Uint8List? _profileBytes;

  final _picker = ImagePicker();
  final _apiClient = getIt<ApiClient>();
  final _authRepo = getIt<AuthRepository>();

  // Only Driver and Travel Agency are offered.
  final _roles = const [
    {'value': 'travel_agency', 'label': 'Travel Agency'},
    {'value': 'driver', 'label': 'Driver'},
  ];

  final Map<String, _DocField> _docs = {
    'aadhar': _DocField('aadhar', 'Aadhaar Card'),
    'pan': _DocField('pan', 'PAN Card'),
    'drivingLicense': _DocField('drivingLicense', 'Driving License'),
    'vehicleRc': _DocField('vehicleRc', 'Vehicle RC'),
  };

  // Drivers also submit the vehicle RC; agencies do not.
  List<String> get _visibleDocKeys => _selectedRole == 'driver'
      ? ['aadhar', 'pan', 'drivingLicense', 'vehicleRc']
      : ['aadhar', 'pan', 'drivingLicense'];

  @override
  void initState() {
    super.initState();
    // Sent here from Login because this number has no account yet.
    final mobile = widget.initialMobile?.trim() ?? '';
    if (mobile.isNotEmpty) _mobileCtrl.text = mobile;

    // If the user got here by tapping someone's invite link, Play handed us their
    // code at install time — pre-fill it. Still editable / clearable.
    pendingReferralCode().then((code) {
      if (code != null && mounted && _referralCtrl.text.isEmpty) {
        setState(() => _referralCtrl.text = code);
      }
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _mobileCtrl.dispose();
    _agencyCtrl.dispose();
    _referralCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    for (final d in _docs.values) {
      d.numberCtrl.dispose();
    }
    super.dispose();
  }

  void _snack(String msg, {bool error = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? Colors.red : Colors.green),
    );
  }

  Future<void> _pickProfile() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      imageQuality: 85,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() => _profileBytes = bytes);
  }

  Future<void> _pickDoc(_DocField doc, {required bool back}) async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 80,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      if (back) {
        doc.backBytes = bytes;
      } else {
        doc.bytes = bytes;
      }
    });
  }

  Future<String> _uploadImage(
    Uint8List bytes,
    String name, {
    String endpoint = '/storage/upload',
    String? folder = 'documents',
  }) async {
    // FormData streams are consumed on first use; build a fresh one for each
    // attempt so the auth interceptor's token-refresh retry can succeed.
    FormData buildForm() => FormData.fromMap({
          'file': MultipartFile.fromBytes(bytes, filename: '$name.jpg'),
          if (folder != null) 'folder': folder,
        });

    Response res;
    try {
      res = await _apiClient.dio.post(endpoint, data: buildForm());
    } catch (_) {
      res = await _apiClient.dio.post(endpoint, data: buildForm());
    }
    return res.data['data'] as String;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Step 1 — send an OTP to the mobile number (also checks email/mobile aren't
    // already registered).
    setState(() {
      _submitting = true;
      _status = 'Sending OTP...';
    });
    try {
      await _apiClient.dio.post('/auth/register/send-otp', data: {
        'mobile': _mobileCtrl.text.trim(),
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _snack(ErrorMapper.message(e));
      return;
    }
    if (!mounted) return;
    setState(() => _submitting = false);

    // Step 2 — collect + verify the OTP, then create the account. Loop so a wrong
    // OTP just reopens the dialog instead of restarting the whole flow.
    while (true) {
      final otp = await _showOtpDialog();
      if (otp == null) return; // user cancelled
      final done = await _completeRegistration(otp);
      if (done) return;
    }
  }

  /// Returns true once the account is created (and navigation has started);
  /// returns false if the OTP was rejected so the caller can re-prompt.
  Future<bool> _completeRegistration(String otp) async {
    setState(() {
      _submitting = true;
      _status = 'Creating account...';
    });

    if (!_registered) {
      final result = await _authRepo.register(
        fullName: _nameCtrl.text.trim(),
        mobile: _mobileCtrl.text.trim(),
        agencyName: _agencyCtrl.text.trim().isEmpty ? null : _agencyCtrl.text.trim(),
        city: _cityCtrl.text.trim().isEmpty ? null : _cityCtrl.text.trim(),
        state: _stateCtrl.text.trim().isEmpty ? null : _stateCtrl.text.trim(),
        role: _selectedRole,
        otp: otp,
        referralCode: _referralCtrl.text.trim().isEmpty ? null : _referralCtrl.text.trim(),
      );
      final failure = result.fold((f) => f, (_) => null);
      if (failure != null) {
        if (!mounted) return false;
        setState(() => _submitting = false);
        _snack(failure.message);
        return false; // wrong/expired OTP → re-prompt
      }
      _registered = true;
      // The invite code has been redeemed — don't pre-fill it for anyone else
      // who registers on this device.
      clearPendingReferralCode();
    }

    // Documents are OPTIONAL. Upload the profile and any documents the user
    // chose to provide; if none, the account is created without them.
    try {
      if (_profileBytes != null) {
        setState(() => _status = 'Uploading profile...');
        final profileUrl = await _uploadImage(
          _profileBytes!,
          'profile',
          endpoint: '/storage/upload/profile',
          folder: null,
        );
        await _apiClient.dio.put('/users/profile', data: {'profileImage': profileUrl});
      }

      // Build a verification payload only from documents the user actually filled.
      final body = <String, dynamic>{};
      for (final key in _visibleDocKeys) {
        final d = _docs[key]!;
        final hasNumber = d.numberCtrl.text.trim().isNotEmpty;
        final hasImage = d.bytes != null;
        final hasBack = d.backBytes != null;
        if (!hasNumber && !hasImage && !hasBack) continue;
        setState(() => _status = 'Uploading documents...');
        final entry = <String, dynamic>{};
        if (hasNumber) entry['number'] = d.numberCtrl.text.trim();
        if (hasImage) entry['image'] = await _uploadImage(d.bytes!, '${key}_front');
        if (hasBack) entry['backImage'] = await _uploadImage(d.backBytes!, '${key}_back');
        body[key] = entry;
      }

      // Submit for verification only when at least one document was provided.
      if (body.isNotEmpty) {
        setState(() => _status = 'Submitting documents...');
        await _apiClient.dio.post('/users/verification', data: body);
      }

      if (!mounted) return true;
      _snack('Account created successfully.', error: false);
      context.read<AuthBloc>().add(AuthCheckStatusEvent());
      context.go('/');
      return true;
    } catch (_) {
      // The account exists; documents are optional, so let the user in.
      if (!mounted) return true;
      _snack('Account created. You can add documents later from your profile.', error: false);
      context.read<AuthBloc>().add(AuthCheckStatusEvent());
      context.go('/');
      return true;
    }
  }

  /// Asks the user for the OTP. Returns the entered code, or null if cancelled.
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
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                Center(
                  child: GestureDetector(
                    onTap: _pickProfile,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 44,
                          backgroundColor: Colors.grey.shade200,
                          backgroundImage: _profileBytes != null ? MemoryImage(_profileBytes!) : null,
                          child: _profileBytes == null
                              ? Icon(Icons.person, size: 44, color: Colors.grey.shade500)
                              : null,
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const Center(
                  child: Text('Profile Picture (Optional)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person_outline)),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _mobileCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Mobile Number', prefixIcon: Icon(Icons.phone_outlined)),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(v)) return 'Enter valid 10-digit mobile';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedRole,
                  decoration: const InputDecoration(labelText: 'Account Type', prefixIcon: Icon(Icons.business_center_outlined)),
                  items: _roles.map((r) => DropdownMenuItem(value: r['value'], child: Text(r['label']!))).toList(),
                  onChanged: (v) => setState(() => _selectedRole = v!),
                ),
                if (_selectedRole == 'travel_agency') ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _agencyCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Agency / Business Name (Optional)',
                      prefixIcon: Icon(Icons.storefront_outlined),
                    ),
                  ),
                ],

                const SizedBox(height: 16),
                TextFormField(
                  controller: _referralCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Referral Code (Optional)',
                    hintText: 'e.g. GORA7K3QF',
                    prefixIcon: Icon(Icons.card_giftcard_outlined),
                  ),
                ),
                const SizedBox(height: 16),
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
                const SizedBox(height: 16),
                TextFormField(
                  controller: _stateCtrl,
                  decoration: const InputDecoration(
                    labelText: 'State',
                    prefixIcon: Icon(Icons.map_outlined),
                  ),
                ),

                const SizedBox(height: 28),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Verification Documents',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Theme.of(context).primaryColor),
                  ),
                ),
                const SizedBox(height: 4),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Optional — add documents now or later from your profile to get verified.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 12),
                ..._visibleDocKeys.map((key) => _buildDocTile(_docs[key]!)),

                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: _submitting
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                            const SizedBox(width: 12),
                            Text(_status, style: const TextStyle(fontSize: 14, color: Colors.white)),
                          ],
                        )
                      : const Text('Create Account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Already have an account? '),
                    GestureDetector(
                      onTap: () => context.go('/auth/login'),
                      child: Text('Sign In', style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.w600)),
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

  // One full-width upload box for a document side (front or back).
  Widget _docSideBox(_DocField doc, {required bool back}) {
    final Uint8List? bytes = back ? doc.backBytes : doc.bytes;
    final label = back ? 'Back Side' : 'Front Side';
    final primary = Theme.of(context).primaryColor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(back ? Icons.flip_to_back : Icons.flip_to_front, size: 14, color: Colors.grey.shade600),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
          ],
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: () => _pickDoc(doc, back: back),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              color: bytes != null ? Colors.grey.shade100 : primary.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: bytes != null ? Colors.grey.shade300 : primary.withValues(alpha: 0.35),
                width: 1.2,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: bytes != null
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.memory(bytes, fit: BoxFit.cover),
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                          child: const Icon(Icons.edit, color: Colors.white, size: 16),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo_outlined, color: primary, size: 28),
                      const SizedBox(height: 8),
                      Text('Tap to upload $label', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildDocTile(_DocField doc) {
    final hasData = doc.bytes != null || doc.backBytes != null || doc.numberCtrl.text.trim().isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        // Hide the default ExpansionTile top/bottom dividers.
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey('doc_${doc.key}'),
          maintainState: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 14),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          leading: const Icon(Icons.description_outlined),
          title: Text(doc.label, style: const TextStyle(fontWeight: FontWeight.w600)),
          trailing: hasData
              ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
              : const Icon(Icons.keyboard_arrow_down),
          children: [
            TextFormField(
              controller: doc.numberCtrl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: '${doc.label} Number',
                isDense: true,
                prefixIcon: const Icon(Icons.badge_outlined),
              ),
            ),
            const SizedBox(height: 12),
            _docSideBox(doc, back: false),
            const SizedBox(height: 12),
            _docSideBox(doc, back: true),
          ],
        ),
      ),
    );
  }
}
