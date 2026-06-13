part of 'chat_bloc.dart';

abstract class ChatEvent extends Equatable {
  const ChatEvent();
  @override
  List<Object?> get props => [];
}

class LoadChatsEvent extends ChatEvent {}

class LoadMessagesEvent extends ChatEvent {
  final String chatId;
  const LoadMessagesEvent(this.chatId);
  @override
  List<Object?> get props => [chatId];
}

class SendMessageEvent extends ChatEvent {
  final String chatId;
  final String content;
  const SendMessageEvent({required this.chatId, required this.content});
  @override
  List<Object?> get props => [chatId, content];
}

class MessageReceivedEvent extends ChatEvent {
  final Map<String, dynamic> message;
  const MessageReceivedEvent(this.message);
  @override
  List<Object?> get props => [message];
}
