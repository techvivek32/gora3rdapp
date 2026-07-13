import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/action_url.dart';
import '../bloc/notification_bloc.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  @override
  void initState() {
    super.initState();
    context.read<NotificationBloc>().add(LoadNotificationsEvent());
  }

  static const _typeIcons = {
    'new_requirement': Icons.post_add,
    'requirement_posted': Icons.check_circle_outline,
    'requirement_accepted': Icons.check_circle,
    'vehicle_posted': Icons.directions_car,
    'new_vehicle': Icons.directions_car_outlined,
    'new_message': Icons.chat_bubble_outline,
    'requirement_assigned': Icons.assignment_ind,
    'subscription_activated': Icons.workspace_premium,
    'promotional': Icons.campaign_outlined,
    'system': Icons.notifications_outlined,
  };

  static const _typeColors = {
    'new_requirement': AppColors.primary,
    'requirement_posted': AppColors.success,
    'requirement_accepted': AppColors.success,
    'vehicle_posted': AppColors.primary,
    'new_vehicle': AppColors.primary,
    'new_message': AppColors.info,
    'requirement_assigned': AppColors.success,
    'subscription_activated': AppColors.memberGolden,
    'promotional': AppColors.memberGolden,
    'system': AppColors.textSecondary,
  };

  /// Tells the backend the user followed this notification's action URL, so the
  /// admin panel can report a click count. Best-effort — never blocks the open.
  Future<void> _reportClick(String id) async {
    try {
      await getIt<ApiClient>().post('/notifications/$id/click');
    } catch (e) {
      debugPrint('Click report failed: $e');
    }
  }

  void _handleTap(BuildContext context, Map<String, dynamic> n) {
    final id = n['_id'] as String?;
    if (id != null) {
      context.read<NotificationBloc>().add(MarkNotificationReadEvent(id));
    }
    final type = n['type'] as String? ?? '';
    final data = n['data'] as Map<String, dynamic>? ?? {};

    // Activity notices jump straight to the thing they're about.
    if (type == 'requirement_assigned') {
      context.push('/my-requirements?tab=2'); // My Requirements → Assigned
      return;
    }
    if (type == 'requirement_posted' || type == 'requirement_accepted') {
      final requirementId = data['requirementId'] as String?;
      if (requirementId != null) context.push('/requirements/$requirementId');
      return;
    }
    if (type == 'vehicle_posted' || type == 'new_vehicle') {
      final vehicleId = data['vehicleId'] as String?;
      if (vehicleId != null) context.push('/vehicles/$vehicleId');
      return;
    }

    // Admin message: the list only shows two lines of it, so open the full screen.
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _NotificationDetailPage(
          notification: n,
          timeAgo: _timeAgo(n['createdAt']),
          onClick: _reportClick,
        ),
      ),
    );
  }

  String _timeAgo(dynamic createdAt) {
    if (createdAt == null) return '';
    try {
      final dt = DateTime.parse(createdAt.toString()).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text('Notifications', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold, fontFamily: 'Poppins', color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () => context.read<NotificationBloc>().add(MarkAllNotificationsReadEvent()),
            child: Text('Mark All Read', style: TextStyle(color: Colors.white, fontSize: 13.sp, fontFamily: 'Poppins')),
          ),
        ],
      ),
      body: BlocBuilder<NotificationBloc, NotificationState>(
        builder: (context, state) {
          if (state is NotificationLoading) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }

          if (state is NotificationError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 56.sp, color: AppColors.error),
                  SizedBox(height: 12.h),
                  Text('Something went wrong', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600, fontFamily: 'Poppins', color: AppColors.textPrimary)),
                  SizedBox(height: 6.h),
                  Text(state.message, textAlign: TextAlign.center, style: TextStyle(fontSize: 13.sp, color: AppColors.textSecondary, fontFamily: 'Poppins')),
                  SizedBox(height: 20.h),
                  ElevatedButton.icon(
                    onPressed: () => context.read<NotificationBloc>().add(LoadNotificationsEvent()),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                  ),
                ],
              ),
            );
          }

          if (state is NotificationLoaded) {
            if (state.notifications.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: EdgeInsets.all(24.r),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.notifications_none_outlined, size: 56.sp, color: AppColors.primary),
                    ),
                    SizedBox(height: 20.h),
                    Text('No notifications yet', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w600, fontFamily: 'Poppins', color: AppColors.textPrimary)),
                    SizedBox(height: 8.h),
                    Text("You're all caught up!", style: TextStyle(fontSize: 14.sp, color: AppColors.textSecondary, fontFamily: 'Poppins')),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async => context.read<NotificationBloc>().add(LoadNotificationsEvent()),
              child: ListView.separated(
                padding: EdgeInsets.symmetric(vertical: 8.h),
                itemCount: state.notifications.length,
                separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.border, indent: 72.w),
                itemBuilder: (_, i) {
                  final n = state.notifications[i];
                  final isRead = n['isRead'] as bool? ?? false;
                  final type = n['type'] as String? ?? 'system';
                  final iconColor = _typeColors[type] ?? AppColors.textSecondary;
                  final icon = _typeIcons[type] ?? Icons.notifications_outlined;

                  return InkWell(
                    onTap: () => _handleTap(context, n),
                    child: Container(
                      color: isRead ? Colors.transparent : AppColors.primary.withOpacity(0.04),
                      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 44.w,
                            height: 44.h,
                            decoration: BoxDecoration(
                              color: iconColor.withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(icon, color: iconColor, size: 22.sp),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        n['title'] as String? ?? '',
                                        style: TextStyle(
                                          fontSize: 14.sp,
                                          fontWeight: isRead ? FontWeight.w500 : FontWeight.bold,
                                          fontFamily: 'Poppins',
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 8.w),
                                    Text(
                                      _timeAgo(n['createdAt']),
                                      style: TextStyle(fontSize: 11.sp, color: AppColors.textHint, fontFamily: 'Poppins'),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 4.h),
                                Text(
                                  n['body'] as String? ?? '',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 13.sp, color: AppColors.textSecondary, fontFamily: 'Poppins', height: 1.4),
                                ),
                                if ((n['imageUrl'] ?? '').toString().isNotEmpty) ...[
                                  SizedBox(height: 8.h),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8.r),
                                    child: AspectRatio(
                                      aspectRatio: 2, // matches the 1024×512 upload
                                      child: Image.network(
                                        n['imageUrl'].toString(),
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (!isRead) ...[
                            SizedBox(width: 8.w),
                            Container(
                              width: 8.w,
                              height: 8.h,
                              margin: EdgeInsets.only(top: 6.h),
                              decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}

/// Full-screen view of one admin notification: title, then the whole message,
/// then the image. Tapping the image (or the Open button) follows the action URL.
class _NotificationDetailPage extends StatelessWidget {
  final Map<String, dynamic> notification;
  final String timeAgo;
  final Future<void> Function(String id) onClick;

  const _NotificationDetailPage({
    required this.notification,
    required this.timeAgo,
    required this.onClick,
  });

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final id = n['_id'] as String?;
    final data = n['data'] as Map<String, dynamic>? ?? {};
    final imageUrl = (n['imageUrl'] ?? data['imageUrl'] ?? '').toString().trim();
    final actionUrl = (n['actionUrl'] ?? data['actionUrl'] ?? '').toString().trim();
    final hasAction = actionUrl.isNotEmpty;

    void open() {
      if (id != null) onClick(id); // fire-and-forget; must not delay the open
      openActionUrl(context, actionUrl);
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Notification',
          style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold, fontFamily: 'Poppins', color: Colors.white),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 32.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              n['title'] as String? ?? '',
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
                fontFamily: 'Poppins',
                color: AppColors.textPrimary,
                height: 1.3,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              timeAgo,
              style: TextStyle(fontSize: 12.sp, color: AppColors.textHint, fontFamily: 'Poppins'),
            ),
            SizedBox(height: 16.h),

            // The whole message — no maxLines here, unlike the list row.
            SelectableText(
              n['body'] as String? ?? '',
              style: TextStyle(
                fontSize: 14.sp,
                color: AppColors.textSecondary,
                fontFamily: 'Poppins',
                height: 1.6,
              ),
            ),

            if (imageUrl.isNotEmpty) ...[
              SizedBox(height: 20.h),
              GestureDetector(
                onTap: hasAction ? open : null,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12.r),
                  child: AspectRatio(
                    aspectRatio: 2, // matches the 1024×512 upload
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
            ],

            if (hasAction) ...[
              SizedBox(height: 24.h),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: open,
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: Text('Open', style: TextStyle(fontSize: 15.sp, fontFamily: 'Poppins')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
