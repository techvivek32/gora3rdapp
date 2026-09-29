import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../bloc/chat_bloc.dart';

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  // The ChatBloc is shared with the chat room, so opening a chat flips its state
  // to MessagesLoaded. Cache the last loaded chats so returning here never shows
  // a blank screen while we reload.
  List _cached = [];

  @override
  void initState() {
    super.initState();
    context.read<ChatBloc>().add(LoadChatsEvent());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        centerTitle: true,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: BlocConsumer<ChatBloc, ChatState>(
        listener: (context, state) {
          if (state is ChatsLoaded) setState(() => _cached = state.chats);
        },
        builder: (context, state) {
          // While a chat room is open the shared bloc holds MessagesLoaded — fall
          // back to the cached chats so this screen never goes blank.
          final chats = state is ChatsLoaded ? state.chats : _cached;
          if (state is ChatLoading && chats.isEmpty) return const Center(child: CircularProgressIndicator());
          if (state is ChatError && chats.isEmpty) return Center(child: Text(state.message));
          {
            if (chats.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('No messages yet', style: TextStyle(fontSize: 18, color: Colors.grey)),
                    SizedBox(height: 8),
                    Text('Start a conversation from a booking', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              );
            }
            return RefreshIndicator(
              onRefresh: () async => context.read<ChatBloc>().add(LoadChatsEvent()),
              child: ListView.separated(
                itemCount: chats.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final chat = chats[i];
                  // Backend sends `otherUser` (the other participant, populated).
                  // Fall back to the first participant object if it's missing, and
                  // guard every cast so a raw id (String) never crashes the list.
                  Map? other = chat['otherUser'] is Map ? chat['otherUser'] as Map : null;
                  if (other == null) {
                    final parts = chat['participants'];
                    if (parts is List) {
                      final obj = parts.firstWhere((p) => p is Map, orElse: () => null);
                      if (obj is Map) other = obj;
                    }
                  }
                  final unread = (chat['unreadCount'] is num) ? (chat['unreadCount'] as num).toInt() : 0;
                  final photo = other?['profileImage']?.toString();
                  final name = (other?['agencyName']?.toString().trim().isNotEmpty ?? false)
                      ? other!['agencyName'].toString()
                      : (other?['fullName']?.toString() ?? 'User');
                  // Title = the linked booking id (in place of the name); the
                  // person's name sits in the subtitle so multiple chats about the
                  // SAME booking (different drivers) are still distinguishable.
                  final req = chat['relatedRequirement'] is Map ? chat['relatedRequirement'] as Map : null;
                  final bookingId = req?['bookingId']?.toString();
                  final title = (bookingId != null && bookingId.isNotEmpty) ? bookingId : name;
                  final lastMsg = chat['lastMessageText']?.toString() ?? '';
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: (photo != null && photo.isNotEmpty) ? NetworkImage(photo) : null,
                      child: (photo == null || photo.isEmpty) ? const Icon(Icons.person) : null,
                    ),
                    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        if (lastMsg.isNotEmpty)
                          Text(lastMsg, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
                      ],
                    ),
                    trailing: unread > 0
                        ? Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(color: Theme.of(context).primaryColor, shape: BoxShape.circle),
                            child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 11)),
                          )
                        : null,
                    onTap: () async {
                      // Reload on return — the shared bloc was left on MessagesLoaded.
                      await context.push('/chats/${chat['_id']}');
                      if (context.mounted) context.read<ChatBloc>().add(LoadChatsEvent());
                    },
                  );
                },
              ),
            );
          }
        },
      ),
    );
  }
}
