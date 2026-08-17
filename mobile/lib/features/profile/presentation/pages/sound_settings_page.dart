import 'package:flutter/material.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/ring_player.dart';

/// Step 1: pick WHICH alert to change (Popup or Notification). Each row shows the
/// current tone; tapping opens the ringtone picker for that kind.
class SoundSettingsPage extends StatefulWidget {
  const SoundSettingsPage({super.key});

  @override
  State<SoundSettingsPage> createState() => _SoundSettingsPageState();
}

class _SoundSettingsPageState extends State<SoundSettingsPage> {
  final _api = getIt<ApiClient>();

  List<Map<String, dynamic>> _ringtones = [];
  bool _loading = true;
  String _popupTitle = 'Default';
  String _notifTitle = 'Default';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await _api.get('/ringtones');
      _ringtones = ((res.data['data'] as List?) ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .where((r) => (r['audioUrl'] ?? '').toString().isNotEmpty)
          .toList();
    } catch (_) {}
    await _reloadTitles();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _reloadTitles() async {
    final pt = await getRingtoneTitle(RingKind.popup);
    final nt = await getRingtoneTitle(RingKind.notification);
    if (!mounted) return;
    setState(() {
      _popupTitle = pt.isEmpty ? 'Default' : pt;
      _notifTitle = nt.isEmpty ? 'Default' : nt;
    });
  }

  Future<void> _openPicker(RingKind kind, String heading) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => RingtonePickerPage(kind: kind, ringtones: _ringtones, heading: heading),
    ));
    await _reloadTitles(); // reflect a new choice made in the picker
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Alert Sound'.tr),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _row('Popup alert sound', Icons.chat_bubble_outline, _popupTitle,
                    () => _openPicker(RingKind.popup, 'Popup alert sound')),
                const SizedBox(height: 12),
                _row('Notification sound', Icons.notifications_outlined, _notifTitle,
                    () => _openPicker(RingKind.notification, 'Notification sound')),
                const SizedBox(height: 20),
                const Text(
                  'Choose a separate tone for the in-app popup and the background notification.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
    );
  }

  Widget _row(String label, IconData icon, String current, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: AppColors.primary),
        title: Text(label.tr, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        subtitle: Text(current, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textHint),
      ),
    );
  }
}

/// Step 2: the ringtone list for one [kind] — preview, select, Save.
class RingtonePickerPage extends StatefulWidget {
  final RingKind kind;
  final List<Map<String, dynamic>> ringtones;
  final String heading;

  const RingtonePickerPage({super.key, required this.kind, required this.ringtones, required this.heading});

  @override
  State<RingtonePickerPage> createState() => _RingtonePickerPageState();
}

class _RingtonePickerPageState extends State<RingtonePickerPage> {
  String _sel = ''; // selected url, '' = Default
  bool _saving = false;
  String? _previewingUrl;

  @override
  void initState() {
    super.initState();
    getRingtoneUrl(widget.kind).then((u) {
      if (mounted) setState(() => _sel = u);
    });
  }

  @override
  void dispose() {
    stopPreview();
    super.dispose();
  }

  Future<void> _preview(String url) async {
    if (_previewingUrl == url) {
      await stopPreview();
      if (mounted) setState(() => _previewingUrl = null);
      return;
    }
    setState(() => _previewingUrl = url);
    await playPreview(url: url);
  }

  String _titleForUrl(String url) {
    if (url.isEmpty) return 'Default';
    final r = widget.ringtones.firstWhere(
      (e) => (e['audioUrl'] ?? '').toString() == url,
      orElse: () => const {},
    );
    return (r['title'] ?? 'Ringtone').toString();
  }

  Future<void> _save() async {
    await stopPreview();
    setState(() {
      _saving = true;
      _previewingUrl = null;
    });
    // Downloads + caches the chosen tone so it plays from disk afterwards.
    await saveRingtoneChoice(widget.kind, url: _sel, title: _titleForUrl(_sel));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saved'), backgroundColor: AppColors.success),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final options = <Map<String, String>>[
      {'title': 'Default', 'url': ''},
      for (final r in widget.ringtones)
        {'title': (r['title'] ?? 'Ringtone').toString(), 'url': (r['audioUrl'] ?? '').toString()},
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.heading.tr),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                for (final o in options) _option(title: o['title']!, url: o['url']!, selected: _sel == o['url']),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Tap ▶ to hear a tone, then tap the row to select. Press Save — the tone is '
            'downloaded once so it plays instantly every time.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)),
            child: _saving
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Save', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ),
      ),
    );
  }

  Widget _option({required String title, required String url, required bool selected}) {
    final isPreviewing = _previewingUrl == url;
    return InkWell(
      onTap: () => setState(() => _sel = url),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            IconButton(
              icon: Icon(isPreviewing ? Icons.stop_circle : Icons.play_circle_outline, color: AppColors.primary),
              onPressed: () => _preview(url),
              tooltip: 'Preview',
            ),
            Expanded(
              child: Text(title, style: TextStyle(fontSize: 14, fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
            ),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: selected ? AppColors.primary : AppColors.textHint,
            ),
          ],
        ),
      ),
    );
  }
}
