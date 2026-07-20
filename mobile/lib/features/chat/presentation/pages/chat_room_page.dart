import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/config/env.dart';
import '../../../../core/di/injection.dart';
import '../bloc/chat_bloc.dart';

class ChatRoomPage extends StatefulWidget {
  final String chatId;
  const ChatRoomPage({super.key, required this.chatId});

  @override
  State<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<ChatRoomPage> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  io.Socket? _socket;
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    context.read<ChatBloc>().add(LoadMessagesEvent(widget.chatId));
    _initSocket();
  }

  Future<void> _initSocket() async {
    // Use the SAME storage instance/options as the rest of the app. A fresh
    // `FlutterSecureStorage()` with default AndroidOptions reads from a different
    // backing store than the app's `encryptedSharedPreferences` one, so it would
    // read a null token here even while the user is signed in.
    final storage = getIt<FlutterSecureStorage>();
    final token = await storage.read(key: 'access_token');
    if (token == null) return;

    const baseUrl = Env.socketBaseUrl;
    _socket = io.io(
      '$baseUrl/chat',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setExtraHeaders({'Authorization': 'Bearer $token'})
          .build(),
    );

    _socket!.onConnect((_) => _socket!.emit('chat:join', widget.chatId));
    _socket!.on('chat:new-message', (data) {
      if (mounted) context.read<ChatBloc>().add(MessageReceivedEvent(Map<String, dynamic>.from(data as Map)));
      _scrollToBottom();
    });
    _socket!.on('chat:typing', (_) => setState(() => _isTyping = true));
    _socket!.on('chat:stop-typing', (_) => setState(() => _isTyping = false));
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    });
  }

  void _send() {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    _msgCtrl.clear();
    _socket?.emit('chat:send-message', {'chatId': widget.chatId, 'content': text, 'type': 'text'});
    context.read<ChatBloc>().add(SendMessageEvent(chatId: widget.chatId, content: text));
  }

  @override
  void dispose() {
    _socket?.disconnect();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat'),
        actions: [
          if (_isTyping) const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Center(child: Text('typing...', style: TextStyle(fontStyle: FontStyle.italic, fontSize: 13))),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: BlocBuilder<ChatBloc, ChatState>(
              builder: (context, state) {
                if (state is ChatLoading) return const Center(child: CircularProgressIndicator());
                if (state is MessagesLoaded) {
                  WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
                  return ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.all(16),
                    itemCount: state.messages.length,
                    itemBuilder: (_, i) => _MessageBubble(message: state.messages[i]),
                  );
                }
                return const Center(child: Text('Loading messages...'));
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, -2))],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgCtrl,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                        filled: true,
                      ),
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: (v) => _socket?.emit(v.isEmpty ? 'chat:stop-typing' : 'chat:typing', widget.chatId),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: Theme.of(context).primaryColor,
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white, size: 20),
                      onPressed: _send,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isMe = message['isMe'] as bool? ?? false;
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
        decoration: BoxDecoration(
          color: isMe ? Theme.of(context).primaryColor : Theme.of(context).cardColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 2, offset: const Offset(0, 1))],
        ),
        child: Text(
          message['content'] as String? ?? '',
          style: TextStyle(color: isMe ? Colors.white : null, fontSize: 15),
        ),
      ),
    );
  }
}
