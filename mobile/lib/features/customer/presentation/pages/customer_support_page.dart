import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/customer_repository.dart';

/// Help & Support — the customer picks a complaint category, adds a note, and
/// submits. Complaints land in the Admin Panel. Their past complaints (with the
/// admin's reply/status) are listed below.
class CustomerSupportPage extends StatefulWidget {
  const CustomerSupportPage({super.key});

  @override
  State<CustomerSupportPage> createState() => _CustomerSupportPageState();
}

class _CustomerSupportPageState extends State<CustomerSupportPage> {
  final _repo = getIt<CustomerRepository>();

  // value → label (value must match backend ComplaintCategory enum)
  static const _categories = <(String, String, IconData)>[
    ('driver_no_show', 'Driver did not come', Icons.person_off_rounded),
    ('overcharged', 'Driver asked for more money', Icons.currency_rupee_rounded),
    ('vehicle_problem', 'Vehicle problem', Icons.car_crash_rounded),
    ('booking_cancelled', 'Booking cancelled', Icons.cancel_rounded),
    ('payment_problem', 'Payment problem', Icons.account_balance_wallet_rounded),
    ('wrong_fare', 'Wrong fare', Icons.receipt_long_rounded),
    ('other', 'Other complaint', Icons.help_outline_rounded),
  ];

  List<Map<String, dynamic>>? _mine;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await _repo.myComplaints();
      if (!mounted) return;
      setState(() { _mine = d; _loading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _snack(String m, {bool ok = false}) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m), backgroundColor: ok ? AppColors.success : AppColors.error));

  Future<void> _openForm(String value, String label) async {
    final noteCtrl = TextEditingController();
    final submit = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            TextField(
              controller: noteCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Describe the issue (optional)',
                filled: true,
                fillColor: Colors.grey[50],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                child: const Text('Submit complaint', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
    if (submit != true) return;
    try {
      await _repo.createComplaint(value, message: noteCtrl.text.trim());
      _snack('Complaint submitted. Our team will look into it.', ok: true);
      _load();
    } catch (e) {
      _snack('Could not submit: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Help & Support'), backgroundColor: AppColors.primary, foregroundColor: Colors.white),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('What went wrong?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text('Pick a topic to raise a complaint.', style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            ..._categories.map((c) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
              child: ListTile(
                onTap: () => _openForm(c.$1, c.$2),
                leading: Icon(c.$3, color: AppColors.primary),
                title: Text(c.$2, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                trailing: const Icon(Icons.chevron_right, color: AppColors.textHint),
              ),
            )),
            const SizedBox(height: 12),
            const Text('My Complaints', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (_loading)
              const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()))
            else if ((_mine ?? []).isEmpty)
              const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Text('No complaints yet.', style: TextStyle(color: AppColors.textSecondary)))
            else
              ...(_mine ?? []).map(_complaintCard),
          ],
        ),
      ),
    );
  }

  Widget _complaintCard(Map<String, dynamic> c) {
    final label = _categories.firstWhere((e) => e.$1 == (c['category'] ?? '').toString(), orElse: () => ('', (c['category'] ?? '').toString(), Icons.help_outline)).$2;
    final status = (c['status'] ?? 'open').toString();
    final note = (c['adminNote'] ?? '').toString();
    final msg = (c['message'] ?? '').toString();
    final created = DateTime.tryParse((c['createdAt'] ?? '').toString());
    final (sc, sl) = switch (status) {
      'resolved' => (AppColors.success, 'Resolved'),
      'in_progress' => (AppColors.warning, 'In progress'),
      _ => (AppColors.info, 'Open'),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: sc.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
              child: Text(sl, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: sc)),
            ),
          ]),
          if (msg.isNotEmpty) ...[const SizedBox(height: 6), Text(msg, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary))],
          if (note.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.support_agent_rounded, size: 16, color: AppColors.success),
                const SizedBox(width: 8),
                Expanded(child: Text(note, style: const TextStyle(fontSize: 12.5))),
              ]),
            ),
          ],
          if (created != null) ...[
            const SizedBox(height: 6),
            Text(DateFormat('d MMM yyyy, h:mm a').format(created), style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
          ],
        ],
      ),
    );
  }
}
