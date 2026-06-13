import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  static const _membershipConfig = {
    'new': {'label': 'New Member', 'color': AppColors.memberNew, 'icon': Icons.person},
    'active': {'label': 'Active', 'color': AppColors.memberActive, 'icon': Icons.verified_user},
    'verified': {'label': 'Verified', 'color': AppColors.memberVerified, 'icon': Icons.verified},
    'premium': {'label': 'Premium', 'color': AppColors.memberPremium, 'icon': Icons.star},
    'golden': {'label': 'Golden', 'color': AppColors.memberGolden, 'icon': Icons.workspace_premium},
  };

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final user = state is AuthAuthenticated ? state.user : null;
        final membership = user?['membershipType'] as String? ?? 'new';
        final config = _membershipConfig[membership] ?? _membershipConfig['new']!;
        final color = config['color'] as Color;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 200.h,
                pinned: true,
                backgroundColor: AppColors.primary,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [color.withOpacity(0.8), color],
                      ),
                    ),
                    child: SafeArea(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 44.r,
                            backgroundColor: Colors.white,
                            backgroundImage: user?['profileImage'] != null ? NetworkImage(user!['profileImage'] as String) : null,
                            child: user?['profileImage'] == null ? Icon(Icons.person, size: 44.sp, color: color) : null,
                          ),
                          SizedBox(height: 8.h),
                          Text(user?['fullName'] as String? ?? 'User',
                              style: TextStyle(color: Colors.white, fontSize: 20.sp, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
                          SizedBox(height: 4.h),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(config['icon'] as IconData, color: Colors.white, size: 16.sp),
                              SizedBox(width: 4.w),
                              Text(config['label'] as String,
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontFamily: 'Poppins')),
                            ],
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
                      _InfoCard(
                        title: 'Account Information',
                        children: [
                          _InfoRow(Icons.phone, 'Mobile', user?['mobile'] as String? ?? '-'),
                          _InfoRow(Icons.email, 'Email', user?['email'] as String? ?? '-'),
                          if (user?['agencyName'] != null)
                            _InfoRow(Icons.business, 'Agency', user!['agencyName'] as String),
                          _InfoRow(Icons.location_city, 'City', user?['city'] as String? ?? '-'),
                        ],
                      ),
                      SizedBox(height: 12.h),
                      _InfoCard(
                        title: 'Activity',
                        children: [
                          _InfoRow(Icons.post_add, 'Requirements Posted', '${user?['requirementsPosted'] ?? 0}'),
                          _InfoRow(Icons.directions_car, 'Vehicles Posted', '${user?['vehiclesPosted'] ?? 0}'),
                        ],
                      ),
                      SizedBox(height: 12.h),
                      _ProfileAction(
                        icon: Icons.workspace_premium,
                        label: 'Upgrade Membership',
                        color: AppColors.warning,
                        onTap: () => context.push('/subscriptions'),
                      ),
                      _ProfileAction(
                        icon: Icons.notifications_outlined,
                        label: 'Notifications',
                        onTap: () => context.push('/notifications'),
                      ),
                      _ProfileAction(
                        icon: Icons.chat_outlined,
                        label: 'Messages',
                        onTap: () => context.push('/chats'),
                      ),
                      _ProfileAction(
                        icon: Icons.settings_outlined,
                        label: 'Settings',
                        onTap: () {},
                      ),
                      SizedBox(height: 12.h),
                      _ProfileAction(
                        icon: Icons.logout,
                        label: 'Sign Out',
                        color: AppColors.error,
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: Text('Sign Out', style: TextStyle(fontFamily: 'Poppins')),
                              content: Text('Are you sure you want to sign out?', style: TextStyle(fontFamily: 'Poppins')),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: TextStyle(fontFamily: 'Poppins'))),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    context.read<AuthBloc>().add(AuthLogoutEvent());
                                  },
                                  child: Text('Sign Out', style: TextStyle(color: AppColors.error, fontFamily: 'Poppins')),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      SizedBox(height: 32.h),
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
}

class _InfoCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _InfoCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.r),
        side: BorderSide(color: AppColors.border, width: 1),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.sp, fontFamily: 'Poppins', color: AppColors.textPrimary)),
            Divider(height: 16.h, color: AppColors.border),
            ...children,
          ],
        ),
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
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: Row(
        children: [
          Icon(icon, size: 18.sp, color: AppColors.textHint),
          SizedBox(width: 12.w),
          Text('$label: ', style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Poppins')),
          Expanded(child: Text(value, style: TextStyle(fontWeight: FontWeight.w500, fontFamily: 'Poppins', color: AppColors.textPrimary))),
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
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
        side: BorderSide(color: AppColors.border, width: 1),
      ),
      margin: EdgeInsets.only(bottom: 8.h),
      child: ListTile(
        leading: Icon(icon, color: color ?? AppColors.primary, size: 22.sp),
        title: Text(label, style: TextStyle(color: color ?? AppColors.textPrimary, fontFamily: 'Poppins', fontWeight: FontWeight.w500)),
        trailing: Icon(Icons.chevron_right, color: AppColors.textHint),
        onTap: onTap,
      ),
    );
  }
}
