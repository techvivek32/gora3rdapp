import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../bloc/chat_bloc.dart';

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  @override
  void initState() {
    super.initState();
    context.read<ChatBloc>().add(LoadChatsEvent());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Messages'), centerTitle: true),
      body: BlocBuilder<ChatBloc, ChatState>(
        builder: (context, state) {
          if (state is ChatLoading) return const Center(child: CircularProgressIndicator());
          if (state is ChatError) return Center(child: Text(state.message));
          if (state is ChatsLoaded) {
            if (state.chats.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('No messages yet', style: TextStyle(fontSize: 18, color: Colors.grey)),
                    SizedBox(height: 8),
                    Text('Start a conversation from a requirement', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              );
            }
            return RefreshIndicator(
              onRefresh: () async => context.read<ChatBloc>().add(LoadChatsEvent()),
              child: ListView.separated(
                itemCount: state.chats.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final chat = state.chats[i];
                  final other = (chat['participants'] as List?)?.firstWhere((p) => true, orElse: () => {}) as Map?;
                  final unread = (chat['unreadCount'] as Map?)?['me'] ?? 0;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: other?['profileImage'] != null ? NetworkImage(other!['profileImage'] as String) : null,
                      child: other?['profileImage'] == null ? const Icon(Icons.person) : null,
                    ),
                    title: Text(other?['fullName'] as String? ?? 'User', style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(chat['lastMessageText'] as String? ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: unread > 0
                        ? Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(color: Theme.of(context).primaryColor, shape: BoxShape.circle),
                            child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 11)),
                          )
                        : null,
                    onTap: () => context.push('/chats/${chat['_id']}'),
                  );
                },
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}
