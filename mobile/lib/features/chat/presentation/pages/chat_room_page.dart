import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/config/env.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';
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
  Map<String, dynamic>? _header; // { relatedRequirement, otherUser }

  @override
  void initState() {
    super.initState();
    context.read<ChatBloc>().add(LoadMessagesEvent(widget.chatId));
    _loadHeader();
    _initSocket();
  }

  /// Load the chat's booking + other participant to show in the app bar.
  Future<void> _loadHeader() async {
    try {
      final res = await getIt<ApiClient>().get('/chats/${widget.chatId}');
      final data = res.data is Map ? res.data['data'] : null;
      if (mounted && data is Map) setState(() => _header = Map<String, dynamic>.from(data));
    } catch (_) {}
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

  /// App-bar title: the linked booking's From → To on top, booking id + date/time
  /// below. Falls back to the other user's name (or "Chat") when there's no booking.
  Widget _buildHeaderTitle() {
    final req = _header?['relatedRequirement'] is Map ? _header!['relatedRequirement'] as Map : null;
    final other = _header?['otherUser'] is Map ? _header!['otherUser'] as Map : null;
    final otherName = (other?['agencyName']?.toString().trim().isNotEmpty ?? false)
        ? other!['agencyName'].toString()
        : (other?['fullName']?.toString() ?? 'Chat');

    if (req == null) {
      return Text(otherName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700));
    }

    final from = (req['pickupCity']?.toString().trim().isNotEmpty ?? false)
        ? req['pickupCity'].toString()
        : ((req['pickup'] as Map?)?['address']?.toString() ?? '');
    final to = (req['dropCity']?.toString().trim().isNotEmpty ?? false)
        ? req['dropCity'].toString()
        : ((req['drop'] as Map?)?['address']?.toString() ?? '');
    final bookingId = req['bookingId']?.toString() ?? '';
    final when = _fmtWhen(req['travelDate'], req['travelTime']);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Flexible(child: Text(from, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700))),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Icon(Icons.arrow_forward_rounded, size: 15)),
          Flexible(child: Text(to, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700))),
        ]),
        Text(
          [if (bookingId.isNotEmpty) bookingId, if (when.isNotEmpty) when].join('  •  '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  String _fmtWhen(dynamic isoDate, dynamic time) {
    String out = '';
    if (isoDate != null) {
      final d = DateTime.tryParse(isoDate.toString());
      if (d != null) {
        const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        out = '${d.day} ${m[d.month - 1]}';
      }
    }
    final t = time?.toString().trim() ?? '';
    if (t.isNotEmpty) out = out.isEmpty ? t : '$out, $t';
    return out;
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
    // Send over HTTP (reliable, persists + the server broadcasts to the room).
    // Not via the socket too, or the message would be saved twice.
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
        titleSpacing: 0,
        title: _buildHeaderTitle(),
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
