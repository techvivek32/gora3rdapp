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
    try {
      await apiClient.post('/chats/${event.chatId}/messages', data: {'content': event.content, 'type': 'text'});
    } catch (e) {
      emit(ChatError(message: e.toString()));
    }
  }

  void _onReceived(MessageReceivedEvent event, Emitter<ChatState> emit) {
    final current = state;
    if (current is MessagesLoaded && current.chatId == event.message['chatId']) {
      emit(MessagesLoaded(
        chatId: current.chatId,
        messages: [...current.messages, event.message],
      ));
    }
  }
}
