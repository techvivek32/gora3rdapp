import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/network/api_client.dart';

part 'notification_event.dart';
part 'notification_state.dart';

class NotificationBloc extends Bloc<NotificationEvent, NotificationState> {
  final ApiClient apiClient;

  NotificationBloc(this.apiClient) : super(NotificationInitial()) {
    on<LoadNotificationsEvent>(_onLoad);
    on<MarkNotificationReadEvent>(_onMarkRead);
    on<MarkAllNotificationsReadEvent>(_onMarkAllRead);
  }

  Future<void> _onLoad(LoadNotificationsEvent event, Emitter<NotificationState> emit) async {
    emit(NotificationLoading());
    try {
      final res = await apiClient.get('/notifications', params: {'page': '1', 'limit': '50'});
      final data = res.data as Map<String, dynamic>;
      final countRes = await apiClient.get('/notifications/unread-count');
      emit(NotificationLoaded(
        notifications: List<Map<String, dynamic>>.from(data['data'] ?? []),
        unreadCount: countRes.data['data']?['count'] ?? 0,
      ));
    } catch (e) {
      emit(NotificationError(message: e.toString()));
    }
  }

  Future<void> _onMarkRead(MarkNotificationReadEvent event, Emitter<NotificationState> emit) async {
    try {
      await apiClient.put('/notifications/${event.id}/read');
      add(LoadNotificationsEvent());
    } catch (_) {}
  }

  Future<void> _onMarkAllRead(MarkAllNotificationsReadEvent event, Emitter<NotificationState> emit) async {
    try {
      await apiClient.put('/notifications/mark-all-read');
      add(LoadNotificationsEvent());
    } catch (_) {}
  }
}
