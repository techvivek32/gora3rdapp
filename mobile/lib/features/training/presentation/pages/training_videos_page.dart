import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/action_url.dart';

/// Lists the admin's training videos; tapping one opens its link.
class TrainingVideosPage extends StatefulWidget {
  const TrainingVideosPage({super.key});

  @override
  State<TrainingVideosPage> createState() => _TrainingVideosPageState();
}

class _TrainingVideosPageState extends State<TrainingVideosPage> {
  final _api = getIt<ApiClient>();
  bool _loading = true;
  List<Map<String, dynamic>> _videos = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _api.get('/training-videos');
      final list = (res.data['data'] as List?) ?? [];
      if (!mounted) return;
      setState(() {
        _videos = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Training Videos'.tr, style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 18.sp)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _videos.isEmpty
              ? _empty()
              : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: EdgeInsets.all(16.r),
                    itemCount: _videos.length,
                    separatorBuilder: (_, __) => SizedBox(height: 10.h),
                    itemBuilder: (_, i) => _tile(_videos[i]),
                  ),
                ),
    );
  }

  Widget _empty() {
    return ListView(
      children: [
        SizedBox(height: 0.28.sh),
        Icon(Icons.ondemand_video_outlined, size: 60.sp, color: AppColors.textHint),
        SizedBox(height: 12.h),
        Center(
          child: Text('No training videos yet.'.tr,
              style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Poppins', fontSize: 14.sp)),
        ),
      ],
    );
  }

  Widget _tile(Map<String, dynamic> v) {
    final title = (v['title'] ?? '').toString();
    final url = (v['url'] ?? '').toString().trim();
    return InkWell(
      onTap: url.isEmpty ? null : () => openActionUrl(context, url),
      borderRadius: BorderRadius.circular(14.r),
      child: Container(
        padding: EdgeInsets.all(14.r),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 46.w,
              height: 46.w,
              decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12.r)),
              child: Icon(Icons.play_circle_fill, color: AppColors.primary, size: 28.sp),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(title,
                  style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 14.sp, color: AppColors.textPrimary)),
            ),
            Icon(Icons.open_in_new, size: 18.sp, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }
}
