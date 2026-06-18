import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
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
                expandedHeight: 200.h,
                pinned: true,
                backgroundColor: AppColors.primary,
                automaticallyImplyLeading: false,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: Colors.white),
                    tooltip: 'Edit Profile',
                    onPressed: () => _showEditSheet(context, user),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryDark],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: SafeArea(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(height: 8.h),
                          Stack(
                            children: [
                              CircleAvatar(
                                radius: 40.r,
                                backgroundColor: Colors.white,
                                backgroundImage: user?['profileImage'] != null
                                    ? NetworkImage(user!['profileImage'] as String)
                                    : null,
                                child: user?['profileImage'] == null
                                    ? Icon(Icons.person, size: 40.sp, color: AppColors.primary)
                                    : null,
                              ),
                            ],
                          ),
                          SizedBox(height: 8.h),
                          Text(
                            user?['fullName'] as String? ?? 'User',
                            style: TextStyle(color: Colors.white, fontSize: 20.sp, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
                          ),
                          SizedBox(height: 6.h),
                          // Current plan badge
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20.r),
                              border: Border.all(color: Colors.white.withOpacity(0.4)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(planIcon, color: Colors.white, size: 13.sp),
                                SizedBox(width: 5.w),
                                Text(planLabel, style: TextStyle(color: Colors.white, fontSize: 11.sp, fontWeight: FontWeight.w600, fontFamily: 'Poppins')),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(16.r),
                  child: Column(
                    children: [
                      // Account info card
                      _InfoCard(
                        title: 'Account Information',
                        trailing: GestureDetector(
                          onTap: () => _showEditSheet(context, user),
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8.r),
                            ),
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

                      
                      // Activity card
                      _InfoCard(
                        title: 'Activity',
                        children: [
                          _InfoRow(Icons.post_add, 'Requirements Posted', '${user?['requirementsPosted'] ?? 0}'),
                          _InfoRow(Icons.directions_car_outlined, 'Vehicles Posted', '${user?['vehiclesPosted'] ?? 0}'),
                        ],
                      ),
                      SizedBox(height: 12.h),

                      // Membership card
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


                      _ProfileAction(icon: Icons.notifications_outlined, label: 'Notifications', onTap: () => context.push('/notifications')),
                      _ProfileAction(icon: Icons.chat_outlined, label: 'Messages', onTap: () => context.push('/chats')),
                      _ProfileAction(icon: Icons.settings_outlined, label: 'Settings', onTap: () {}),
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

  void _showEditSheet(BuildContext context, Map<String, dynamic>? user) {
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

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    context.read<AuthBloc>().add(UpdateProfileEvent({
      'fullName': _nameCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'agencyName': _agencyCtrl.text.trim(),
      'city': _cityCtrl.text.trim(),
      'state': _stateCtrl.text.trim(),
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
                  padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 32.h),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _field(_nameCtrl, 'Full Name', Icons.person_outline, required: true),
                        SizedBox(height: 14.h),
                        _field(_emailCtrl, 'Email', Icons.email_outlined, keyboardType: TextInputType.emailAddress),
                        SizedBox(height: 14.h),
                        _field(_agencyCtrl, 'Agency Name', Icons.business_outlined),
                        SizedBox(height: 14.h),
                        _field(_cityCtrl, 'City', Icons.location_city_outlined),
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
