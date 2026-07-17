import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/error/error_mapper.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/places_city_field.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  static const _membershipConfig = {
    'new':     {'label': 'Free Plan',     'color': AppColors.textHint,       'icon': Icons.person_outline},
    'active':  {'label': 'Active Plan',   'color': AppColors.memberActive,   'icon': Icons.verified_user},
    'verified':{'label': 'Verified Plan', 'color': AppColors.memberVerified, 'icon': Icons.shield},
    'premium': {'label': 'Premium Plan',  'color': AppColors.memberPremium,  'icon': Icons.diamond_outlined},
    'golden':  {'label': 'Golden Plan',   'color': AppColors.memberGolden,   'icon': Icons.emoji_events},
  };

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final user = state is AuthAuthenticated ? state.user as Map<String, dynamic>? : null;
        final membership = user?['membershipType'] as String? ?? 'new';
        final config = _membershipConfig[membership] ?? _membershipConfig['new']!;
        final planColor = config['color'] as Color;
        final planIcon = config['icon'] as IconData;
        final planLabel = config['label'] as String;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                automaticallyImplyLeading: false,
                centerTitle: true,
                title: Text('Settings', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 18.sp)),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(16.r),
                  child: Column(
                    children: [
                      

                      // My Profile — avatar + name + plan
                      Container(
                        margin: EdgeInsets.only(bottom: 8.h),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8.r),
                          border: Border.all(color: AppColors.border),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 3, offset: const Offset(0, 1))],
                        ),
                        child: ListTile(
                          onTap: () => context.push('/my-profile'),
                          leading: CircleAvatar(
                            radius: 22.r,
                            backgroundColor: AppColors.primary.withOpacity(0.1),
                            backgroundImage: user?['profileImage'] != null ? NetworkImage(user!['profileImage'] as String) : null,
                            child: user?['profileImage'] == null ? Icon(Icons.person, color: AppColors.primary, size: 24.sp) : null,
                          ),
                          title: Text(user?['fullName'] as String? ?? 'User', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.sp, fontFamily: 'Poppins', color: AppColors.textPrimary)),
                          subtitle: Text(planLabel, style: TextStyle(fontSize: 12.sp, color: planColor, fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
                          trailing: const Icon(Icons.chevron_right, color: AppColors.textHint),
                        ),
                      ),
                      
                      // Membership card (top)
                      _InfoCard(
                        title: 'Membership',
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(8.r),
                                decoration: BoxDecoration(
                                  color: planColor.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(planIcon, color: planColor, size: 20.sp),
                              ),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(planLabel, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp, color: planColor, fontFamily: 'Poppins')),
                                    Text(
                                      membership == 'new' ? 'Upgrade to access premium features' : 'You have premium access',
                                      style: TextStyle(fontSize: 11.sp, color: AppColors.textSecondary, fontFamily: 'Poppins'),
                                    ),
                                  ],
                                ),
                              ),
                              if (membership == 'new' || membership == 'active')
                                GestureDetector(
                                  onTap: () => context.push('/subscriptions'),
                                  child: Container(
                                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(8.r),
                                    ),
                                    child: Text('Upgrade', style: TextStyle(color: Colors.white, fontSize: 11.sp, fontWeight: FontWeight.w600, fontFamily: 'Poppins')),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(height: 12.h),
                      
                      _ProfileAction(icon: Icons.account_balance_wallet_outlined, label: 'My Wallet', onTap: () => context.push('/wallet')),
                      _ProfileAction(icon: Icons.directions_car_outlined, label: 'My Vehicles', onTap: () => context.push('/my-vehicles-garage')),
                      _ProfileAction(icon: Icons.card_giftcard_outlined, label: 'Invite Friends', onTap: () => context.push('/invite')),
                      _ProfileAction(icon: Icons.verified_user_outlined, label: 'KYC Verification', onTap: () => context.push('/kyc')),
                      _ProfileAction(icon: Icons.flag_outlined, label: 'My Reports', onTap: () => context.push('/my-reports')),
                      _ProfileAction(icon: Icons.notifications_outlined, label: 'Notifications', onTap: () => context.push('/notifications')),
                      SizedBox(height: 12.h),

                      // About & Policies
                      _ProfileAction(icon: Icons.privacy_tip_outlined, label: 'Privacy Policy', onTap: () => context.push('/policy/privacy')),
                      _ProfileAction(icon: Icons.description_outlined, label: 'Terms & Conditions', onTap: () => context.push('/policy/terms')),
                      _ProfileAction(icon: Icons.info_outline, label: 'About Us', onTap: () => context.push('/policy/about')),
                      SizedBox(height: 12.h),
                      _ProfileAction(
                        icon: Icons.logout,
                        label: 'Sign Out',
                        color: AppColors.error,
                        onTap: () => showDialog(
                          context: context,
                          builder: (dialogCtx) => AlertDialog(
                            title: const Text('Sign Out', style: TextStyle(fontFamily: 'Poppins')),
                            content: const Text('Are you sure you want to sign out?', style: TextStyle(fontFamily: 'Poppins')),
                            actions: [
                              TextButton(onPressed: () => Navigator.of(dialogCtx).pop(), child: const Text('Cancel')),
                              TextButton(
                                onPressed: () {
                                  Navigator.of(dialogCtx).pop();
                                  context.read<AuthBloc>().add(AuthLogoutEvent());
                                },
                                child: const Text('Sign Out', style: TextStyle(color: AppColors.error)),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 8.h),
                      _ProfileAction(
                        icon: Icons.delete_forever_outlined,
                        label: 'Delete Account',
                        color: AppColors.error,
                        onTap: () => _confirmDeleteAccount(context),
                      ),
                      SizedBox(height: 140.h),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Asks for a reason, then submits a deletion *request* for an admin to review.
  /// The account stays usable until an admin approves it.
  Future<void> _confirmDeleteAccount(BuildContext context) async {
    // The dialog owns its own controller (see _DeleteAccountDialog) — disposing it
    // here would tear it down while the closing dialog's TextFormField is still
    // mounted, tripping the `_dependents.isEmpty` assertion.
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _DeleteAccountDialog(),
    );

    if (reason == null || reason.isEmpty || !context.mounted) return;

    try {
      await getIt<ApiClient>().post('/users/account/delete-request', data: {'reason': reason});
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your deletion request has been submitted for review.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorMapper.message(e)), backgroundColor: AppColors.error),
      );
    }
  }
}

/// Delete-account dialog. Owns its TextEditingController so the controller lives
/// exactly as long as the dialog's widget tree (pops with the typed reason, or null).
class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _formKey = GlobalKey<FormState>();
  final _reasonCtrl = TextEditingController();

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Delete Account', style: TextStyle(fontFamily: 'Poppins')),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tell us why you want to delete your account. Our team will review your '
              'request, and your account will be removed once it is approved.',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _reasonCtrl,
              maxLines: 3,
              maxLength: 500,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Reason for deletion',
                hintText: 'e.g. I no longer use the app',
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().length < 3)
                  ? 'Please tell us why you want to delete your account'
                  : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        TextButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.of(context).pop(_reasonCtrl.text.trim());
            }
          },
          child: const Text('Submit Request', style: TextStyle(color: AppColors.error)),
        ),
      ],
    );
  }
}

void showEditProfileSheet(BuildContext context, Map<String, dynamic>? user) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => BlocProvider.value(
      value: context.read<AuthBloc>(),
      child: _EditProfileSheet(user: user),
    ),
  );
}

/// Dedicated page that shows the account details + edit (opened from "My Profile").
class MyProfilePage extends StatelessWidget {
  const MyProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Profile', style: TextStyle(fontFamily: 'Poppins')),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          final user = state is AuthAuthenticated ? state.user as Map<String, dynamic>? : null;
          final cover = user?['coverImage'] as String?;
          final profileImage = user?['profileImage'] as String?;
          return SingleChildScrollView(
            child: Column(
              children: [
                // Cover banner with overlapping avatar
                SizedBox(
                  height: 178.h,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 130.h,
                          decoration: BoxDecoration(
                            gradient: cover == null ? const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]) : null,
                            image: cover != null ? DecorationImage(image: NetworkImage(cover), fit: BoxFit.cover) : null,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 130.h - 48.r,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: CircleAvatar(
                            radius: 48.r,
                            backgroundColor: Colors.white,
                            child: CircleAvatar(
                              radius: 44.r,
                              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                              backgroundImage: profileImage != null ? NetworkImage(profileImage) : null,
                              child: profileImage == null ? Icon(Icons.person, size: 40.sp, color: AppColors.primary) : null,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 8.h),
                Text(user?['fullName'] as String? ?? 'User',
                    style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold, fontFamily: 'Poppins', color: AppColors.textPrimary)),
                SizedBox(height: 16.h),
                Padding(
                  padding: EdgeInsets.all(16.r),
                  child: Column(
                    children: [
                _InfoCard(
                  title: 'Account Information',
                  trailing: GestureDetector(
                    onTap: () => showEditProfileSheet(context, user),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                      decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8.r)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit_outlined, size: 13.sp, color: AppColors.primary),
                          SizedBox(width: 4.w),
                          Text('Edit', style: TextStyle(fontSize: 12.sp, color: AppColors.primary, fontWeight: FontWeight.w600, fontFamily: 'Poppins')),
                        ],
                      ),
                    ),
                  ),
                  children: [
                    _InfoRow(Icons.phone, 'Mobile', user?['mobile'] as String? ?? '-'),
                    _InfoRow(Icons.email_outlined, 'Email', user?['email'] as String? ?? '-'),
                    _InfoRow(Icons.business_outlined, 'Agency', user?['agencyName'] as String? ?? '-'),
                    _InfoRow(Icons.location_city_outlined, 'City', user?['city'] as String? ?? '-'),
                    _InfoRow(Icons.map_outlined, 'State', user?['state'] as String? ?? '-'),
                  ],
                ),
                SizedBox(height: 12.h),
                _InfoCard(
                  title: 'Activity',
                  children: [
                    _InfoRow(Icons.post_add, 'Requirements Posted', '${user?['requirementsPosted'] ?? 0}'),
                    _InfoRow(Icons.directions_car_outlined, 'Available cab Posted', '${user?['vehiclesPosted'] ?? 0}'),
                  ],
                ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _EditProfileSheet extends StatefulWidget {
  final Map<String, dynamic>? user;
  const _EditProfileSheet({this.user});

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _agencyCtrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _stateCtrl;
  bool _loading = false;
  bool _uploadingImage = false;
  String? _uploadedImageUrl;
  bool _uploadingCover = false;
  String? _uploadedCoverUrl;
  final _picker = ImagePicker();
  final _apiClient = getIt<ApiClient>();

  @override
  void initState() {
    super.initState();
    _nameCtrl   = TextEditingController(text: widget.user?['fullName'] as String? ?? '');
    _emailCtrl  = TextEditingController(text: widget.user?['email'] as String? ?? '');
    _agencyCtrl = TextEditingController(text: widget.user?['agencyName'] as String? ?? '');
    _cityCtrl   = TextEditingController(text: widget.user?['city'] as String? ?? '');
    _stateCtrl  = TextEditingController(text: widget.user?['state'] as String? ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _emailCtrl.dispose(); _agencyCtrl.dispose();
    _cityCtrl.dispose(); _stateCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAndUpload() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    setState(() => _uploadingImage = true);
    try {
      final bytes = await picked.readAsBytes();

      // FormData streams are consumed on first use and can't be retried by the
      // auth interceptor. Build a fresh one each time we attempt the upload.
      FormData buildForm() => FormData.fromMap({
            'file': MultipartFile.fromBytes(bytes, filename: 'profile.jpg'),
          });

      Response res;
      try {
        res = await _apiClient.dio.post('/storage/upload/profile', data: buildForm());
      } catch (_) {
        // First attempt may have failed because the access token was expired.
        // The interceptor will have refreshed the token but the FormData stream
        // was consumed — so we retry once with a fresh FormData.
        res = await _apiClient.dio.post('/storage/upload/profile', data: buildForm());
      }

      final url = res.data['data'] as String?;
      if (url != null && mounted) setState(() => _uploadedImageUrl = url);
    } catch (e) {
      if (mounted) {
        final msg = e is DioException ? (e.response?.data?.toString() ?? e.message ?? 'Upload failed') : e.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  Future<void> _pickAndUploadCover() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 80);
    if (picked == null || !mounted) return;

    setState(() => _uploadingCover = true);
    try {
      final bytes = await picked.readAsBytes();
      FormData buildForm() => FormData.fromMap({
            'file': MultipartFile.fromBytes(bytes, filename: 'cover.jpg'),
            'folder': 'covers',
          });
      Response res;
      try {
        res = await _apiClient.dio.post('/storage/upload', data: buildForm());
      } catch (_) {
        res = await _apiClient.dio.post('/storage/upload', data: buildForm());
      }
      final url = res.data['data'] as String?;
      if (url != null && mounted) setState(() => _uploadedCoverUrl = url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cover upload failed'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingCover = false);
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    context.read<AuthBloc>().add(UpdateProfileEvent({
      'fullName': _nameCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'agencyName': _agencyCtrl.text.trim(),
      'city': _cityCtrl.text.trim(),
      'state': _stateCtrl.text.trim(),
      if (_uploadedImageUrl != null) 'profileImage': _uploadedImageUrl!,
      if (_uploadedCoverUrl != null) 'coverImage': _uploadedCoverUrl!,
    }));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          setState(() => _loading = false);
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated!'), backgroundColor: AppColors.success),
          );
        }
        if (state is AuthError) {
          setState(() => _loading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: AppColors.error),
          );
        }
      },
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, scrollCtrl) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: EdgeInsets.only(top: 12.h),
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2.r)),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                child: Row(
                  children: [
                    Text('Edit Profile', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
                    const Spacer(),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollCtrl,
                  // Add the keyboard height so the focused field can scroll above it.
                  padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 32.h + MediaQuery.of(context).viewInsets.bottom),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // Cover image picker
                        GestureDetector(
                          onTap: _uploadingCover ? null : _pickAndUploadCover,
                          child: Builder(builder: (context) {
                            final cover = _uploadedCoverUrl ?? widget.user?['coverImage'] as String?;
                            return Container(
                              height: 110.h,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12.r),
                                border: Border.all(color: AppColors.border),
                                image: cover != null ? DecorationImage(image: NetworkImage(cover), fit: BoxFit.cover) : null,
                              ),
                              child: Center(
                                child: _uploadingCover
                                    ? const CircularProgressIndicator(strokeWidth: 2)
                                    : Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.add_photo_alternate_outlined, color: cover != null ? Colors.white : AppColors.primary, size: 26.sp),
                                          SizedBox(height: 4.h),
                                          Text(cover != null ? 'Tap to change cover' : 'Add cover image',
                                              style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600, color: cover != null ? Colors.white : AppColors.textSecondary)),
                                        ],
                                      ),
                              ),
                            );
                          }),
                        ),
                        SizedBox(height: 16.h),
                        // Avatar picker
                        Center(
                          child: GestureDetector(
                            onTap: _uploadingImage ? null : _pickAndUpload,
                            child: Stack(
                              children: [
                                CircleAvatar(
                                  radius: 44.r,
                                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                                  backgroundImage: _uploadedImageUrl != null
                                      ? NetworkImage(_uploadedImageUrl!) as ImageProvider
                                      : widget.user?['profileImage'] != null
                                          ? NetworkImage(widget.user!['profileImage'] as String)
                                          : null,
                                  child: (_uploadedImageUrl == null && widget.user?['profileImage'] == null)
                                      ? Icon(Icons.person, size: 40.sp, color: AppColors.primary)
                                      : null,
                                ),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    padding: EdgeInsets.all(6.r),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                    ),
                                    child: _uploadingImage
                                        ? SizedBox(
                                            width: 14.w,
                                            height: 14.w,
                                            child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                          )
                                        : Icon(Icons.camera_alt, size: 14.sp, color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          'Tap to change photo',
                          style: TextStyle(fontSize: 12.sp, color: AppColors.textSecondary, fontFamily: 'Poppins'),
                        ),
                        SizedBox(height: 20.h),
                        _field(_nameCtrl, 'Full Name', Icons.person_outline, required: true),
                        SizedBox(height: 14.h),
                        _field(_emailCtrl, 'Email', Icons.email_outlined, keyboardType: TextInputType.emailAddress),
                        SizedBox(height: 14.h),
                        _field(_agencyCtrl, 'Agency Name', Icons.business_outlined),
                        SizedBox(height: 14.h),
                        // Google Places-backed suggestions, same source as "My Cities".
                        PlacesCityField(
                          label: 'City',
                          icon: Icons.location_city_outlined,
                          initialText: _cityCtrl.text,
                          onChanged: (city, state) {
                            _cityCtrl.text = city;
                            // Picking a suggestion also fills the state for the user.
                            if (state != null && state.isNotEmpty) _stateCtrl.text = state;
                          },
                        ),
                        SizedBox(height: 14.h),
                        _field(_stateCtrl, 'State', Icons.map_outlined),
                        SizedBox(height: 24.h),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _save,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 14.h),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                              elevation: 0,
                            ),
                            child: _loading
                                ? SizedBox(height: 20.h, width: 20.w, child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : Text('Save Changes', style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon,
      {bool required = false, TextInputType? keyboardType}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.primary, size: 20.sp),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
      ),
      validator: required ? (v) => (v == null || v.trim().isEmpty) ? '$label is required' : null : null,
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final Widget? trailing;
  const _InfoCard({required this.title, required this.children, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 1))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 4.h, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.vertical(top: Radius.circular(8.r)))),
          Padding(
            padding: EdgeInsets.all(14.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp, color: AppColors.primary, fontFamily: 'Poppins')),
                    const Spacer(),
                    if (trailing != null) trailing!,
                  ],
                ),
                Divider(height: 14.h, thickness: 1, color: AppColors.border),
                ...children,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 5.h),
      child: Row(
        children: [
          Icon(icon, size: 16.sp, color: AppColors.primary),
          SizedBox(width: 10.w),
          Text('$label: ', style: TextStyle(color: AppColors.textSecondary, fontSize: 13.sp, fontFamily: 'Poppins')),
          Expanded(child: Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp, fontFamily: 'Poppins', color: AppColors.textPrimary))),
        ],
      ),
    );
  }
}

class _ProfileAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  const _ProfileAction({required this.icon, required this.label, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 3, offset: const Offset(0, 1))],
      ),
      child: ListTile(
        leading: Icon(icon, color: color ?? AppColors.primary, size: 22.sp),
        title: Text(label, style: TextStyle(color: color ?? AppColors.textPrimary, fontSize: 14.sp, fontWeight: FontWeight.w600, fontFamily: 'Poppins')),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textHint),
        onTap: onTap,
      ),
    );
  }
}
