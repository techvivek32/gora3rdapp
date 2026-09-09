import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/address_autocomplete_field.dart';

/// Saved Locations — the customer stores frequent addresses (Home, Work, …) so
/// they can be reused when booking. Stored on-device (SharedPreferences) for the
/// launch version; can move to the backend later.
class CustomerSavedLocationsPage extends StatefulWidget {
  const CustomerSavedLocationsPage({super.key});

  @override
  State<CustomerSavedLocationsPage> createState() => _CustomerSavedLocationsPageState();
}

class _CustomerSavedLocationsPageState extends State<CustomerSavedLocationsPage> {
  static const _key = 'customer_saved_locations';
  final _prefs = getIt<SharedPreferences>();
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final raw = _prefs.getString(_key);
    if (raw != null && raw.isNotEmpty) {
      try {
        _items = (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } catch (_) {
        _items = [];
      }
    }
    setState(() {});
  }

  Future<void> _save() async {
    await _prefs.setString(_key, jsonEncode(_items));
  }

  Future<void> _addOrEdit({Map<String, dynamic>? existing, int? index}) async {
    final labelCtrl = TextEditingController(text: existing?['label']?.toString() ?? '');
    final addrCtrl = TextEditingController(text: existing?['address']?.toString() ?? '');
    double? lat = (existing?['lat'] as num?)?.toDouble();
    double? lng = (existing?['lng'] as num?)?.toDouble();
    String? city = existing?['city']?.toString();

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(existing == null ? 'Add location' : 'Edit location', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            TextField(
              controller: labelCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Label (e.g. Home, Work)',
                prefixIcon: const Icon(Icons.label_outline_rounded, color: AppColors.primary),
                filled: true,
                fillColor: Colors.grey[50],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
              ),
            ),
            const SizedBox(height: 12),
            AddressAutocompleteField(
              controller: addrCtrl,
              label: 'Address',
              prefixIcon: Icons.location_on_rounded,
              onSelected: (a, la, ln, c) { lat = la; lng = ln; city = c; },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  if (labelCtrl.text.trim().isEmpty || addrCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a label and address')));
                    return;
                  }
                  Navigator.pop(context, true);
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                child: const Text('Save', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
    if (saved != true) return;
    final entry = {'label': labelCtrl.text.trim(), 'address': addrCtrl.text.trim(), 'lat': lat ?? 0, 'lng': lng ?? 0, 'city': city ?? ''};
    setState(() {
      if (index != null) {
        _items[index] = entry;
      } else {
        _items.add(entry);
      }
    });
    await _save();
  }

  Future<void> _delete(int index) async {
    setState(() => _items.removeAt(index));
    await _save();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Saved Locations'), backgroundColor: AppColors.primary, foregroundColor: Colors.white),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addOrEdit(),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add', style: TextStyle(color: Colors.white)),
      ),
      body: _items.isEmpty
          ? const Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.bookmark_border_rounded, size: 56, color: AppColors.textHint),
                SizedBox(height: 12),
                Text('No saved locations yet', style: TextStyle(color: AppColors.textSecondary)),
              ]),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
              itemCount: _items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final it = _items[i];
                return Container(
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                  child: ListTile(
                    onTap: () => _addOrEdit(existing: it, index: i),
                    leading: const Icon(Icons.place_rounded, color: AppColors.primary),
                    title: Text(it['label']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(it['address']?.toString() ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
                    trailing: IconButton(icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error), onPressed: () => _delete(i)),
                  ),
                );
              },
            ),
    );
  }
}
