import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';

class InvitePage extends StatefulWidget {
  const InvitePage({super.key});

  @override
  State<InvitePage> createState() => _InvitePageState();
}

class _InvitePageState extends State<InvitePage> {
  final _api = getIt<ApiClient>();

  bool _loading = true;
  String _code = '';
  int _count = 0;
  List<Map<String, dynamic>> _invited = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _api.get('/users/referral-info');
      final data = res.data['data'] as Map<String, dynamic>;
      setState(() {
        _code = (data['code'] ?? '').toString();
        _count = (data['count'] as num?)?.toInt() ?? 0;
        _invited = ((data['invited'] as List?) ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  String get _shareText =>
      'Join me on Gora Cabs! 🚕\nUse my referral code *$_code* when you sign up.\nDownload the app and register with this code.';

  void _copy() {
    Clipboard.setData(ClipboardData(text: _code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Referral code copied'), backgroundColor: AppColors.success),
    );
  }

  void _share() {
    if (_code.isEmpty) return;
    Share.share(_shareText, subject: 'Join Gora Cabs');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Invite Friends', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 18.sp)),
        centerTitle: true,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Leaderboard',
            icon: const Icon(Icons.emoji_events),
            onPressed: () => context.push('/leaderboard'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.primary,
              child: ListView(
                padding: EdgeInsets.all(16.r),
                children: [
                  _codeCard(),
                  SizedBox(height: 20.h),
                  _statCard(),
                  SizedBox(height: 20.h),
                  Text('Friends you invited', style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700)),
                  SizedBox(height: 8.h),
                  if (_invited.isEmpty)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 24.h),
                      child: Center(
                        child: Text(
                          'No invites yet.\nShare your code to start inviting!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13.sp),
                        ),
                      ),
                    )
                  else
                    ..._invited.map(_invitedTile),
                ],
              ),
            ),
    );
  }

  Widget _codeCard() {
    return Container(
      padding: EdgeInsets.all(18.r),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, Color(0xFFFF8A3D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.card_giftcard, color: Colors.white),
              SizedBox(width: 8.w),
              Text('Your Referral Code', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14.sp)),
            ],
          ),
          SizedBox(height: 14.h),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 16.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _code.isEmpty ? '—' : _code,
                  style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.bold, color: AppColors.primary, letterSpacing: 2),
                ),
                InkWell(
                  onTap: _copy,
                  child: Row(
                    children: [
                      const Icon(Icons.copy, size: 18, color: AppColors.primary),
                      SizedBox(width: 4.w),
                      Text('Copy', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13.sp)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 14.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _share,
              icon: const Icon(Icons.share, size: 18),
              label: const Text('Share Invite'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
                padding: EdgeInsets.symmetric(vertical: 12.h),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard() {
    return Container(
      padding: EdgeInsets.all(18.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12.r),
            decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(12.r)),
            child: const Icon(Icons.groups_rounded, color: AppColors.primary),
          ),
          SizedBox(width: 14.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$_count', style: TextStyle(fontSize: 26.sp, fontWeight: FontWeight.bold, color: AppColors.primary)),
              Text('Friends invited', style: TextStyle(fontSize: 13.sp, color: AppColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _invitedTile(Map<String, dynamic> u) {
    final name = (u['fullName'] ?? u['agencyName'] ?? 'User').toString();
    final city = (u['city'] ?? '').toString();
    final img = (u['profileImage'] ?? '').toString();
    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20.r,
            backgroundColor: AppColors.primaryLight,
            backgroundImage: img.isNotEmpty ? NetworkImage(img) : null,
            child: img.isEmpty
                ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold))
                : null,
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.sp), overflow: TextOverflow.ellipsis),
                if (city.isNotEmpty)
                  Text(city, style: TextStyle(fontSize: 12.sp, color: AppColors.textSecondary)),
              ],
            ),
          ),
          const Icon(Icons.check_circle, color: AppColors.success, size: 20),
        ],
      ),
    );
  }
}
