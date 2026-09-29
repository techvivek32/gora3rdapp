import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/network/api_client.dart';

part 'chat_event.dart';
part 'chat_state.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final ApiClient apiClient;

  ChatBloc(this.apiClient) : super(ChatInitial()) {
    on<LoadChatsEvent>(_onLoadChats);
    on<LoadMessagesEvent>(_onLoadMessages);
    on<SendMessageEvent>(_onSend);
    on<MessageReceivedEvent>(_onReceived);
  }

  Future<void> _onLoadChats(LoadChatsEvent event, Emitter<ChatState> emit) async {
    emit(ChatLoading());
    try {
      final res = await apiClient.get('/chats');
      emit(ChatsLoaded(chats: List<Map<String, dynamic>>.from(res.data['data'] ?? [])));
    } catch (e) {
      emit(ChatError(message: e.toString()));
    }
  }

  Future<void> _onLoadMessages(LoadMessagesEvent event, Emitter<ChatState> emit) async {
    emit(ChatLoading());
    try {
      final res = await apiClient.get('/chats/${event.chatId}/messages');
      emit(MessagesLoaded(
        chatId: event.chatId,
        messages: List<Map<String, dynamic>>.from(res.data['data'] ?? []),
      ));
    } catch (e) {
      emit(ChatError(message: e.toString()));
    }
  }

  Future<void> _onSend(SendMessageEvent event, Emitter<ChatState> emit) async {
    // Optimistic: append the sent message immediately (server echoes it too, but
    // _onReceived de-dupes by id). Keeps the input snappy and avoids a reload.
    final current = state;
    try {
      final res = await apiClient.post('/chats/${event.chatId}/messages', data: {'content': event.content, 'type': 'text'});
      final msg = res.data is Map ? (res.data['data'] ?? res.data) : null;
      if (msg is Map && current is MessagesLoaded && current.chatId == event.chatId) {
        _appendUnique(emit, current, Map<String, dynamic>.from(msg));
      }
    } catch (_) {
      // Don't blow away the loaded conversation on a transient send failure.
    }
  }

  void _onReceived(MessageReceivedEvent event, Emitter<ChatState> emit) {
    final current = state;
    final chatId = event.message['chatId']?.toString();
    if (current is MessagesLoaded && current.chatId == (chatId ?? current.chatId)) {
      _appendUnique(emit, current, event.message);
    }
  }

  /// Append a message unless one with the same _id is already present.
  void _appendUnique(Emitter<ChatState> emit, MessagesLoaded current, Map<String, dynamic> msg) {
    final id = msg['_id']?.toString();
    if (id != null && current.messages.any((m) => m['_id']?.toString() == id)) return;
    emit(MessagesLoaded(chatId: current.chatId, messages: [...current.messages, msg]));
  }
}
