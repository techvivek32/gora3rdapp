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

  /// 'text' or 'image'. An image carries its storage URL in [mediaUrl]; the
  /// upload has already happened by the time this is dispatched.
  final String type;
  final String? mediaUrl;

  const SendMessageEvent({
    required this.chatId,
    required this.content,
    this.type = 'text',
    this.mediaUrl,
  });
  @override
  List<Object?> get props => [chatId, content, type, mediaUrl];
}

class MessageReceivedEvent extends ChatEvent {
  final Map<String, dynamic> message;
  const MessageReceivedEvent(this.message);
  @override
  List<Object?> get props => [message];
}
