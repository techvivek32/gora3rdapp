import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
    'requirement_accepted': Icons.check_circle,
    'new_message': Icons.chat,
    'subscription_activated': Icons.star,
    'system': Icons.notifications,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () => context.read<NotificationBloc>().add(MarkAllNotificationsReadEvent()),
            child: const Text('Mark All Read'),
          ),
        ],
      ),
      body: BlocBuilder<NotificationBloc, NotificationState>(
        builder: (context, state) {
          if (state is NotificationLoading) return const Center(child: CircularProgressIndicator());
          if (state is NotificationError) return Center(child: Text(state.message));
          if (state is NotificationLoaded) {
            if (state.notifications.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.notifications_none, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('No notifications', style: TextStyle(fontSize: 18, color: Colors.grey)),
                  ],
                ),
              );
            }
            return RefreshIndicator(
              onRefresh: () async => context.read<NotificationBloc>().add(LoadNotificationsEvent()),
              child: ListView.separated(
                itemCount: state.notifications.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final n = state.notifications[i];
                  final isRead = n['isRead'] as bool? ?? false;
                  final type = n['type'] as String? ?? 'system';
                  return ListTile(
                    tileColor: isRead ? null : Theme.of(context).primaryColor.withOpacity(0.05),
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                      child: Icon(_typeIcons[type] ?? Icons.notifications, color: Theme.of(context).primaryColor),
                    ),
                    title: Text(n['title'] as String? ?? '', style: TextStyle(fontWeight: isRead ? FontWeight.normal : FontWeight.bold)),
                    subtitle: Text(n['body'] as String? ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
                    trailing: !isRead ? Container(width: 8, height: 8, decoration: BoxDecoration(color: Theme.of(context).primaryColor, shape: BoxShape.circle)) : null,
                    onTap: () => context.read<NotificationBloc>().add(MarkNotificationReadEvent(n['_id'] as String)),
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
