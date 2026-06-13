part of 'chat_bloc.dart';

abstract class ChatState extends Equatable {
  const ChatState();
  @override
  List<Object?> get props => [];
}

class ChatInitial extends ChatState {}
class ChatLoading extends ChatState {}

class ChatsLoaded extends ChatState {
  final List<Map<String, dynamic>> chats;
  const ChatsLoaded({required this.chats});
  @override
  List<Object?> get props => [chats];
}

class MessagesLoaded extends ChatState {
  final String chatId;
  final List<Map<String, dynamic>> messages;
  const MessagesLoaded({required this.chatId, required this.messages});
  @override
  List<Object?> get props => [chatId, messages];
}

class ChatError extends ChatState {
  final String message;
  const ChatError({required this.message});
  @override
  List<Object?> get props => [message];
}
