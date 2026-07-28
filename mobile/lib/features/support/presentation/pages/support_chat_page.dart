import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';

class SupportChatPage extends StatefulWidget {
  const SupportChatPage({super.key});

  @override
  State<SupportChatPage> createState() => _SupportChatPageState();
}

/// Tap-to-send shortcuts for the most common support topics.
const _quickReplies = <_QuickReply>[
  _QuickReply(Icons.payments_outlined, 'Payment', 'I need help with a payment issue.'),
  _QuickReply(Icons.workspace_premium_outlined, 'Plan', 'I have a question about my membership plan.'),
  _QuickReply(Icons.description_outlined, 'Booking', 'I need help with a booking I posted.'),
  _QuickReply(Icons.person_remove_outlined, 'Delete account', 'I want to delete my account.'),
];

class _QuickReply {
  final IconData icon;
  final String label;
  final String message;
  const _QuickReply(this.icon, this.label, this.message);
}

class _SupportChatPageState extends State<SupportChatPage> {
  final _api = getIt<ApiClient>();
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();

  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _sending = false;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _load(initial: true);
    // Light polling so admin replies show up without a socket.
    _poll = Timer.periodic(const Duration(seconds: 5), (_) => _load());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool initial = false}) async {
    try {
      final res = await _api.get('/support/messages');
      final list = ((res.data['data'] as List?) ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (!mounted) return;
      final grew = list.length != _messages.length;
      setState(() {
        _messages = list;
        _loading = false;
      });
      if (initial || grew) _scrollToBottom();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  /// Sends [message] when given (quick-reply chips), otherwise whatever is typed.
  Future<void> _send({String? message}) async {
    final text = (message ?? _ctrl.text).trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    // Only wipe the field when the text came from it — a quick reply shouldn't
    // discard a draft the user was already typing.
    if (message == null) _ctrl.clear();
    // Optimistic append.
    setState(() {
      _messages.add({'sender': 'user', 'text': text, 'createdAt': DateTime.now().toIso8601String(), '_optimistic': true});
    });
    _scrollToBottom();
    try {
      await _api.post('/support/messages', data: {'text': text});
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not send. Please try again.'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Support Chat'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _messages.isEmpty
                    ? _emptyState()
                    : ListView.builder(
                        controller: _scroll,
                        padding: EdgeInsets.all(14.r),
                        itemCount: _messages.length,
                        itemBuilder: (_, i) => _bubble(_messages[i]),
                      ),
          ),
          // Shown once, above the input, until the conversation starts.
          if (!_loading && _messages.isEmpty) _quickRepliesBar(),
          _inputBar(),
        ],
      ),
    );
  }

  /// Horizontal strip of one-tap topics. Tapping a chip sends its message straight away.
  Widget _quickRepliesBar() {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: EdgeInsets.only(top: 10.h, bottom: 10.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(left: 14.w, bottom: 8.h),
            child: Text(
              'What do you need help with?',
              style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 14.w),
            child: Row(
              children: [
                for (final q in _quickReplies) ...[
                  GestureDetector(
                    onTap: _sending ? null : () => _send(message: q.message),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(20.r),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(q.icon, size: 14.sp, color: AppColors.primary),
                          SizedBox(width: 6.w),
                          Text(
                            q.label,
                            style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: AppColors.primary),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.support_agent, size: 56.sp, color: AppColors.textHint),
          SizedBox(height: 12.h),
          Text('Chat with Gora Cabs support', style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600)),
          SizedBox(height: 4.h),
          Text('Send us a message and our team will reply here.',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 12.sp, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _bubble(Map<String, dynamic> m) {
    final isMe = (m['sender'] ?? 'user') == 'user';
    final text = (m['text'] ?? '').toString();
    final time = _time(m['createdAt']);
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(bottom: 8.h),
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        constraints: BoxConstraints(maxWidth: 0.75.sw),
        decoration: BoxDecoration(
          color: isMe ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(14.r),
            topRight: Radius.circular(14.r),
            bottomLeft: Radius.circular(isMe ? 14.r : 2.r),
            bottomRight: Radius.circular(isMe ? 2.r : 14.r),
          ),
          border: isMe ? null : Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Padding(
                padding: EdgeInsets.only(bottom: 2.h),
                child: Text('Support', style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w700, color: AppColors.primary)),
              ),
            Text(text, style: TextStyle(fontSize: 13.sp, color: isMe ? Colors.white : AppColors.textPrimary)),
            SizedBox(height: 2.h),
            Text(time, style: TextStyle(fontSize: 9.sp, color: isMe ? Colors.white70 : AppColors.textHint)),
          ],
        ),
      ),
    );
  }

  String _time(dynamic v) {
    final d = DateTime.tryParse((v ?? '').toString())?.toLocal();
    if (d == null) return '';
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final ampm = d.hour < 12 ? 'AM' : 'PM';
    return '$h:${d.minute.toString().padLeft(2, '0')} $ampm';
  }

  Widget _inputBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, -1))]),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                minLines: 1,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Type your message…',
                  isDense: true,
                  filled: true,
                  fillColor: Colors.grey[100],
                  contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24.r), borderSide: BorderSide.none),
                ),
              ),
            ),
            SizedBox(width: 8.w),
            GestureDetector(
              onTap: _send,
              child: CircleAvatar(
                radius: 22.r,
                backgroundColor: AppColors.primary,
                child: _sending
                    ? SizedBox(width: 18.w, height: 18.w, child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
