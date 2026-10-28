import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';

/// Messages, grouped by the booking each conversation belongs to.
///
/// One posted booking can attract many drivers, each with their own 1:1 thread.
/// A flat list made those look unrelated, so this screen shows one card per
/// BOOKING with how many drivers messaged; tapping one opens its threads on
/// their own page.
class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  List<Map<String, dynamic>> _groups = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await getIt<ApiClient>().get('/chats/grouped');
      final list = (res.data['data'] as List?) ?? [];
      if (!mounted) return;
      setState(() {
        _groups = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load messages';
      });
    }
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
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _groups.isEmpty
              ? Center(child: Text(_error!))
              : _groups.isEmpty
                  ? const Center(
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
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                        itemCount: _groups.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _bookingGroup(_groups[i]),
                      ),
                    ),
    );
  }

  /// One booking: a row showing the route and how many drivers wrote in.
  Widget _bookingGroup(Map<String, dynamic> g) {
    final booking = g['booking'] is Map ? Map<String, dynamic>.from(g['booking'] as Map) : null;
    final chats = ((g['chats'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final drivers = (g['driverCount'] as num?)?.toInt() ?? chats.length;
    final unread = (g['unreadCount'] as num?)?.toInt() ?? 0;

    final from = (booking?['pickupCity'] ?? '').toString().split(',').first.trim();
    final to = (booking?['dropCity'] ?? '').toString().split(',').first.trim();
    final title = booking == null
        ? 'Direct messages'
        : [from, to].where((s) => s.isNotEmpty).join('  →  ');
    final bookingId = (booking?['bookingId'] ?? '').toString();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () async {
              await Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => _BookingThreadsPage(title: title, bookingId: bookingId, chats: chats),
              ));
              if (mounted) _load(); // unread counts change while you are in there
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Row(
                children: [
                  Icon(booking == null ? Icons.forum_rounded : Icons.local_taxi_rounded,
                      size: 20, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text(
                          '$drivers ${drivers == 1 ? 'driver' : 'drivers'} chatted'
                          '${bookingId.isNotEmpty ? '  ·  $bookingId' : ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  if (unread > 0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(10)),
                      child: Text('$unread',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)),
                    ),
                    const SizedBox(width: 6),
                  ],
                  const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}


/// The drivers who messaged about one booking. Reached by tapping that booking
/// on the Messages list.
class _BookingThreadsPage extends StatefulWidget {
  final String title;
  final String bookingId;
  final List<Map<String, dynamic>> chats;

  const _BookingThreadsPage({required this.title, required this.bookingId, required this.chats});

  @override
  State<_BookingThreadsPage> createState() => _BookingThreadsPageState();
}

class _BookingThreadsPageState extends State<_BookingThreadsPage> {
  late List<Map<String, dynamic>> _chats = widget.chats;

  /// Re-read this booking's threads after the user comes back from a room.
  ///
  /// The rows were handed over as a snapshot taken when the group was opened,
  /// so anything sent in the room — a reply, a photo — left the preview and
  /// time showing the previous message until the whole Messages list was
  /// rebuilt. Only the unread badge was patched locally, which made the row
  /// look half-updated.
  Future<void> _refresh() async {
    try {
      final res = await getIt<ApiClient>().get('/chats/grouped');
      final groups = (res.data['data'] as List?) ?? [];
      for (final g in groups) {
        if (g is! Map) continue;
        final booking = g['booking'] is Map ? g['booking'] as Map : null;
        final matches = widget.bookingId.isEmpty
            ? booking == null
            : (booking?['bookingId'] ?? '').toString() == widget.bookingId;
        if (!matches) continue;
        final rows = (g['chats'] as List?) ?? [];
        if (!mounted) return;
        setState(() => _chats = rows.map((e) => Map<String, dynamic>.from(e as Map)).toList());
        return;
      }
    } catch (_) {
      // Keep showing what we have — a failed refresh must not empty the list.
    }
  }

  @override
  Widget build(BuildContext context) {
    final chats = _chats;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            if (widget.bookingId.isNotEmpty)
              Text(widget.bookingId,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.white70)),
          ],
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: chats.length,
        separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
        itemBuilder: (_, i) {
          final c = chats[i];

        final other = c['otherUser'] is Map ? Map<String, dynamic>.from(c['otherUser'] as Map) : null;
        final name = (other?['fullName'] ?? other?['agencyName'] ?? 'User').toString();
        final last = (c['lastMessageText'] ?? '').toString();
        final n = (c['unreadCount'] as num?)?.toInt() ?? 0;
        return Container(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary)),
            ),
            title: Text(name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
            subtitle: Text(last.isEmpty ? 'No messages yet' : last,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(_when(c['lastMessageAt']),
                    style: const TextStyle(fontSize: 10.5, color: AppColors.textHint)),
                if (n > 0) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(9)),
                    child: Text('$n',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white)),
                  ),
                ],
              ],
            ),
            onTap: () async {
              await context.push('/chats/${c['_id']}');
              // Clear the badge straight away so the row never looks unread
              // after you just read it, then pull the real rows so the preview
              // and time catch up too. The Messages list behind reloads when
              // this page is popped.
              if (!mounted) return;
              setState(() => c['unreadCount'] = 0);
              await _refresh();
            },
          ),
        );
        },
      ),
    );
  }

  String _when(dynamic iso) {
    if (iso == null) return '';
    final d = DateTime.tryParse(iso.toString())?.toLocal();
    if (d == null) return '';
    final now = DateTime.now();
    final sameDay = d.year == now.year && d.month == now.month && d.day == now.day;
    return sameDay ? DateFormat('h:mm a').format(d) : DateFormat('d MMM').format(d);
  }
}
