import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/config/env.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
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
      return Text(otherName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white));
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
          Flexible(child: Text(from, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: Colors.white))),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Icon(Icons.arrow_forward_rounded, size: 15, color: Colors.white)),
          Flexible(child: Text(to, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: Colors.white))),
        ]),
        Text(
          [if (bookingId.isNotEmpty) bookingId, if (when.isNotEmpty) when].join('  •  '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11.5, color: Colors.white70, fontWeight: FontWeight.w500),
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

  /// Current signed-in user id (to tell if I'm the booking owner).
  String? get _myId {
    final s = context.read<AuthBloc>().state;
    if (s is AuthAuthenticated) return (s.user['_id'] as String?) ?? (s.user['id'] as String?);
    return null;
  }

  /// A compact booking summary card shown under the app bar: route, trip type,
  /// total fare, vehicle & commission — with an "Edit Commission Amount" button
  /// for the owner while the booking is still open (no driver assigned yet).
  Widget? _bookingCard() {
    final req = _header?['relatedRequirement'] is Map ? Map<String, dynamic>.from(_header!['relatedRequirement'] as Map) : null;
    if (req == null) return null;

    final from = (req['pickupCity']?.toString().trim().isNotEmpty ?? false)
        ? req['pickupCity'].toString()
        : ((req['pickup'] as Map?)?['address']?.toString() ?? '');
    final to = (req['dropCity']?.toString().trim().isNotEmpty ?? false)
        ? req['dropCity'].toString()
        : ((req['drop'] as Map?)?['address']?.toString() ?? '');
    final tripType = (req['tripType'] ?? '').toString();
    final vehicle = (req['vehicleType'] ?? '').toString();
    final fare = (req['fare'] as num?)?.round() ?? 0;
    final commission = (req['commission'] as num?)?.round() ?? 0;
    final status = (req['status'] ?? '').toString();
    final postedBy = req['postedBy']?.toString();
    final hasDriver = (req['assignedDriver'] != null) && req['assignedDriver'].toString().isNotEmpty;

    final isOwner = postedBy != null && _myId != null && postedBy == _myId;
    final isOpen = (status == 'active' || status == 'on_hold') && !hasDriver;
    final canEditCommission = isOwner && isOpen;

    Widget pill(String label, String value, Color color) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('₹$value', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
            Text(label, style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary)),
          ],
        );

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Row(children: [
                Flexible(child: Text(from, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
                const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Icon(Icons.arrow_forward_rounded, size: 14, color: AppColors.primary)),
                Flexible(child: Text(to, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
              ]),
            ),
            if (tripType.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                child: Text(tripType.toUpperCase(), style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: AppColors.primary)),
              ),
          ]),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (fare > 0) pill('Total Amount', '$fare', AppColors.textPrimary),
              if (vehicle.isNotEmpty)
                Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.local_taxi_rounded, size: 18, color: AppColors.primary),
                  Text(vehicle, style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary)),
                ]),
              pill('Commission', '$commission', AppColors.primary),
            ],
          ),
          if (canEditCommission) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _editCommission(commission),
                icon: const Icon(Icons.edit_rounded, size: 16),
                label: const Text('Edit Commission Amount'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF5A623),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _editCommission(int current) async {
    final req = _header?['relatedRequirement'] is Map ? _header!['relatedRequirement'] as Map : null;
    final reqId = req?['_id']?.toString();
    if (reqId == null) return;
    final ctrl = TextEditingController(text: current > 0 ? '$current' : '');
    final value = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Commission Amount'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(prefixText: '₹ ', hintText: 'Commission amount'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, int.tryParse(ctrl.text.trim())),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (value == null) return;
    try {
      await getIt<ApiClient>().post('/requirements/$reqId/commission', data: {'commission': value});
      if (!mounted) return;
      await _loadHeader();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Commission updated'), backgroundColor: AppColors.success));
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().contains('open') ? 'Commission can only be changed before a driver is assigned.' : 'Could not update commission';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppColors.error));
    }
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
    final bookingCard = _bookingCard();
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 2,
        title: _buildHeaderTitle(),
        actions: [
          if (_isTyping) const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Center(child: Text('typing...', style: TextStyle(fontStyle: FontStyle.italic, fontSize: 13, color: Colors.white))),
          ),
        ],
      ),
      body: Column(
        children: [
          if (bookingCard != null) bookingCard,
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
    final content = message['content'] as String? ?? '';

    // Driver + vehicle details auto-posted on assignment — a highlighted card
    // with a Share button, regardless of who it reads as being from.
    if ((message['type'] ?? '').toString() == 'driver_details') {
      return Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
          decoration: BoxDecoration(
            color: const Color(0xFFF5A623).withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFF5A623).withValues(alpha: 0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.badge_rounded, size: 16, color: Color(0xFFD48806)),
                const SizedBox(width: 6),
                const Text('Driver & Vehicle Details', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFFD48806))),
              ]),
              const SizedBox(height: 8),
              Text(content, style: const TextStyle(fontSize: 13.5, height: 1.5, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: () => Share.share(content),
                  icon: const Icon(Icons.share_rounded, size: 15),
                  label: const Text('Share'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFD48806),
                    side: const BorderSide(color: Color(0xFFF5A623)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    minimumSize: const Size(0, 32),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

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
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 2, offset: const Offset(0, 1))],
        ),
        child: Text(
          content,
          style: TextStyle(color: isMe ? Colors.white : null, fontSize: 15),
        ),
      ),
    );
  }
}
