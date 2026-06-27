import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';

class MyReportsPage extends StatefulWidget {
  const MyReportsPage({super.key});

  @override
  State<MyReportsPage> createState() => _MyReportsPageState();
}

class _MyReportsPageState extends State<MyReportsPage> {
  final _api = getIt<ApiClient>();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _reports = [];
  String _filter = 'all'; // all | pending | resolved | dismissed

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _api.get('/reports/my');
      final list = ((res.data['data'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      setState(() {
        _reports = list;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Could not load your reports';
        _loading = false;
      });
    }
  }

  ({Color color, String label}) _statusInfo(String? status) {
    switch (status) {
      case 'resolved':
        return (color: AppColors.success, label: 'Resolved');
      case 'dismissed':
        return (color: AppColors.error, label: 'Dismissed');
      case 'investigating':
        return (color: AppColors.info, label: 'Under Review');
      default:
        return (color: Colors.amber.shade700, label: 'Pending');
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filter == 'all'
        ? _reports
        : _reports.where((r) {
            final s = r['status'] as String? ?? 'pending';
            if (_filter == 'pending') return s == 'pending' || s == 'investigating';
            return s == _filter;
          }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('My Reports', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 18.sp)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
            child: Row(
              children: [
                for (final f in const ['all', 'pending', 'resolved', 'dismissed'])
                  Padding(
                    padding: EdgeInsets.only(right: 8.w),
                    child: GestureDetector(
                      onTap: () => setState(() => _filter = f),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                        decoration: BoxDecoration(
                          color: _filter == f ? AppColors.primary : Colors.white,
                          borderRadius: BorderRadius.circular(20.r),
                          border: Border.all(color: _filter == f ? AppColors.primary : AppColors.border),
                        ),
                        child: Text(
                          f[0].toUpperCase() + f.substring(1),
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            color: _filter == f ? Colors.white : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.textSecondary)))
                    : filtered.isEmpty
                        ? RefreshIndicator(
                            onRefresh: _load,
                            child: ListView(
                              children: [
                                SizedBox(height: 0.3.sh),
                                Center(
                                  child: Column(
                                    children: [
                                      Icon(Icons.flag_outlined, size: 56.sp, color: AppColors.textHint),
                                      SizedBox(height: 12.h),
                                      Text('No reports', style: TextStyle(color: AppColors.textSecondary, fontSize: 15.sp)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.separated(
                              padding: EdgeInsets.all(16.r),
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => SizedBox(height: 10.h),
                              itemBuilder: (_, i) => _reportCard(filtered[i]),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _reportCard(Map<String, dynamic> r) {
    final info = _statusInfo(r['status'] as String?);
    final reason = (r['reason'] as String? ?? 'other').replaceAll('_', ' ');
    final target = r['target'] as Map?;
    final targetName = target?['fullName'] as String? ?? (r['targetType'] as String? ?? 'user').toUpperCase();
    final desc = (r['description'] as String?)?.trim() ?? '';
    final date = _formatDate(r['createdAt']);

    return Container(
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Report on $targetName',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: info.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(color: info.color.withValues(alpha: 0.5)),
                ),
                child: Text(info.label, style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w700, color: info.color)),
              ),
            ],
          ),
          SizedBox(height: 4.h),
          Text('Reason: $reason', style: TextStyle(fontSize: 12.sp, color: AppColors.textSecondary)),
          if (desc.isNotEmpty) ...[
            SizedBox(height: 6.h),
            Text(desc, style: TextStyle(fontSize: 13.sp, color: AppColors.textPrimary)),
          ],
          if ((r['adminNotes'] as String?)?.trim().isNotEmpty == true) ...[
            SizedBox(height: 6.h),
            Text('Admin: ${(r['adminNotes'] as String).trim()}', style: TextStyle(fontSize: 12.sp, color: AppColors.info, fontStyle: FontStyle.italic)),
          ],
          SizedBox(height: 6.h),
          Text(date, style: TextStyle(fontSize: 11.sp, color: AppColors.textHint)),
        ],
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return '';
    try {
      final d = DateTime.parse(date.toString()).toLocal();
      return '${d.day}-${d.month}-${d.year}';
    } catch (_) {
      return '';
    }
  }
}
