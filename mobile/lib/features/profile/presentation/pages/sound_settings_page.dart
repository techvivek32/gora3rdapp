import 'package:flutter/material.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/ring_player.dart';

/// Lets the user pick a separate ringtone for the in-app POPUP alert and the
/// background NOTIFICATION. Choices are saved locally (SharedPreferences) and
/// played by the app itself. "Default" uses the built-in tone.
class SoundSettingsPage extends StatefulWidget {
  const SoundSettingsPage({super.key});

  @override
  State<SoundSettingsPage> createState() => _SoundSettingsPageState();
}

class _SoundSettingsPageState extends State<SoundSettingsPage> {
  final _api = getIt<ApiClient>();

  List<Map<String, dynamic>> _ringtones = [];
  bool _loading = true;

  String _popupUrl = '';
  String _notifUrl = '';
  String? _previewingUrl; // which option is currently previewing (by url, '' = default)

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    stopPreview();
    super.dispose();
  }

  Future<void> _load() async {
    _popupUrl = await getRingtoneUrl(RingKind.popup);
    _notifUrl = await getRingtoneUrl(RingKind.notification);
    try {
      final res = await _api.get('/ringtones');
      final list = ((res.data['data'] as List?) ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .where((r) => (r['audioUrl'] ?? '').toString().isNotEmpty)
          .toList();
      if (!mounted) return;
      setState(() {
        _ringtones = list;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _preview(String url) async {
    // Tapping the same play button again stops it.
    if (_previewingUrl == url) {
      await stopPreview();
      if (mounted) setState(() => _previewingUrl = null);
      return;
    }
    setState(() => _previewingUrl = url);
    await playPreview(url: url);
  }

  Future<void> _choose(RingKind kind, String url, String title) async {
    await setRingtone(kind, url: url, title: title);
    setState(() {
      if (kind == RingKind.popup) {
        _popupUrl = url;
      } else {
        _notifUrl = url;
      }
    });
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
                _section('Popup alert sound', RingKind.popup, _popupUrl),
                const SizedBox(height: 20),
                _section('Notification sound', RingKind.notification, _notifUrl),
                const SizedBox(height: 24),
                const Text(
                  'Tap ▶ to hear a tone, then tap it to select. "Default" uses the built-in sound.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
    );
  }

  Widget _section(String title, RingKind kind, String selectedUrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title.tr, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              _option(kind, title: 'Default', url: '', selected: selectedUrl.isEmpty),
              for (final r in _ringtones)
                _option(
                  kind,
                  title: (r['title'] ?? 'Ringtone').toString(),
                  url: (r['audioUrl'] ?? '').toString(),
                  selected: selectedUrl == (r['audioUrl'] ?? '').toString(),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _option(RingKind kind, {required String title, required String url, required bool selected}) {
    final isPreviewing = _previewingUrl == url;
    return InkWell(
      onTap: () => _choose(kind, url, title),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            IconButton(
              icon: Icon(isPreviewing ? Icons.stop_circle : Icons.play_circle_outline,
                  color: AppColors.primary),
              onPressed: () => _preview(url),
              tooltip: 'Preview',
            ),
            Expanded(
              child: Text(title,
                  style: TextStyle(fontSize: 14, fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
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
