import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';

class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  final _api = getIt<ApiClient>();
  bool _loading = true;
  List<Map<String, dynamic>> _rows = [];

  // Gold / Silver / Bronze
  static const _medal = [Color(0xFFFFD700), Color(0xFFC0C0C0), Color(0xFFCD7F32)];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _api.get('/users/referral-leaderboard');
      final list = (res.data['data'] as List?) ?? [];
      setState(() {
        _rows = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final top3 = _rows.take(3).toList();
    final rest = _rows.length > 3 ? _rows.sublist(3) : <Map<String, dynamic>>[];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Leaderboard', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 18.sp)),
        centerTitle: true,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _rows.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.emoji_events_outlined, size: 56.sp, color: AppColors.textHint),
                      SizedBox(height: 12.h),
                      Text('No inviters yet.\nBe the first to top the board!',
                          textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary, fontSize: 13.sp)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.primary,
                  child: ListView(
                    padding: EdgeInsets.all(16.r),
                    children: [
                      _podium(top3),
                      SizedBox(height: 20.h),
                      ...rest.map(_rankRow),
                    ],
                  ),
                ),
    );
  }

  // ── Top-3 podium ──────────────────────────────────────────────────────────
  Widget _podium(List<Map<String, dynamic>> top3) {
    Map<String, dynamic>? at(int i) => i < top3.length ? top3[i] : null;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: _podiumItem(at(1), 2, 96.h)), // silver (left)
        Expanded(child: _podiumItem(at(0), 1, 124.h)), // gold (center)
        Expanded(child: _podiumItem(at(2), 3, 78.h)), // bronze (right)
      ],
    );
  }

  Widget _podiumItem(Map<String, dynamic>? u, int rank, double barHeight) {
    final color = _medal[rank - 1];
    if (u == null) {
      return const SizedBox.shrink();
    }
    final name = (u['name'] ?? 'User').toString();
    final img = (u['profileImage'] ?? '').toString();
    final count = (u['count'] as num?)?.toInt() ?? 0;
    final isMe = u['isMe'] == true;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (rank == 1) Icon(Icons.emoji_events, color: color, size: 26.sp),
          SizedBox(height: 4.h),
          Stack(
            alignment: Alignment.bottomCenter,
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: rank == 1 ? 30.r : 24.r,
                backgroundColor: color,
                child: CircleAvatar(
                  radius: rank == 1 ? 27.r : 21.r,
                  backgroundColor: AppColors.primaryLight,
                  backgroundImage: img.isNotEmpty ? NetworkImage(img) : null,
                  child: img.isEmpty
                      ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 16.sp))
                      : null,
                ),
              ),
              Positioned(
                bottom: -6,
                child: Container(
                  padding: EdgeInsets.all(3.r),
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)),
                  child: Text('$rank', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10.sp)),
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.sp, color: isMe ? AppColors.primary : null),
          ),
          Text('$count invites', style: TextStyle(fontSize: 10.sp, color: AppColors.textSecondary)),
          SizedBox(height: 6.h),
          Container(
            height: barHeight,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withValues(alpha: 0.9), color.withValues(alpha: 0.5)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(8.r)),
            ),
            alignment: Alignment.topCenter,
            padding: EdgeInsets.only(top: 8.h),
            child: Text('#$rank', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16.sp)),
          ),
        ],
      ),
    );
  }

  // ── Ranks 4+ ──────────────────────────────────────────────────────────────
  Widget _rankRow(Map<String, dynamic> u) {
    final rank = (u['rank'] as num?)?.toInt() ?? 0;
    final name = (u['name'] ?? 'User').toString();
    final city = (u['city'] ?? '').toString();
    final img = (u['profileImage'] ?? '').toString();
    final count = (u['count'] as num?)?.toInt() ?? 0;
    final isMe = u['isMe'] == true;

    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: isMe ? AppColors.primaryLight.withValues(alpha: 0.5) : Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: isMe ? AppColors.primary : AppColors.border),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28.w,
            child: Text('$rank', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.sp, color: AppColors.textSecondary)),
          ),
          SizedBox(width: 8.w),
          CircleAvatar(
            radius: 18.r,
            backgroundColor: AppColors.primaryLight,
            backgroundImage: img.isNotEmpty ? NetworkImage(img) : null,
            child: img.isEmpty
                ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold))
                : null,
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.sp), overflow: TextOverflow.ellipsis),
                if (city.isNotEmpty) Text(city, style: TextStyle(fontSize: 11.sp, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$count', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp, color: AppColors.primary)),
              Text('invites', style: TextStyle(fontSize: 10.sp, color: AppColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}
