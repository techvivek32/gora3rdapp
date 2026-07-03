import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../di/injection.dart';
import '../network/api_client.dart';
import '../theme/app_theme.dart';

/// A typeable address field: the user types (e.g. "cosmo") and picks from live
/// Google Places suggestions (proxied through our backend so the key stays
/// server-side and it works on web too). Calls [onSelected] with the chosen
/// address + coordinates + city.
class AddressAutocompleteField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final IconData prefixIcon;
  final Widget? suffix;
  final String? Function(String?)? validator;
  final void Function(String address, double lat, double lng, String? city) onSelected;

  const AddressAutocompleteField({
    super.key,
    required this.controller,
    required this.label,
    required this.prefixIcon,
    required this.onSelected,
    this.suffix,
    this.validator,
  });

  @override
  State<AddressAutocompleteField> createState() => _AddressAutocompleteFieldState();
}

class _AddressAutocompleteFieldState extends State<AddressAutocompleteField> {
  final _api = getIt<ApiClient>();
  final _focus = FocusNode();
  Timer? _debounce;
  List<Map<String, dynamic>> _suggestions = [];
  bool _loading = false;
  bool _open = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    if (v.trim().length < 2) {
      setState(() { _suggestions = []; _open = false; });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(v.trim()));
  }

  Future<void> _search(String query) async {
    setState(() => _loading = true);
    try {
      final res = await _api.get('/places/autocomplete', params: {'input': query});
      final preds = ((res.data['data']?['predictions']) as List?) ?? [];
      if (!mounted) return;
      setState(() {
        _suggestions = preds.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _open = _suggestions.isNotEmpty;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() { _loading = false; _open = false; });
    }
  }

  Future<void> _select(Map<String, dynamic> item) async {
    final placeId = (item['placeId'] ?? '').toString();
    final desc = (item['description'] ?? item['main'] ?? '').toString();

    widget.controller.text = desc;
    _focus.unfocus();
    setState(() { _suggestions = []; _open = false; _loading = true; });

    try {
      final res = await _api.get('/places/details', params: {'placeId': placeId});
      final d = (res.data['data'] as Map).cast<String, dynamic>();
      final lat = (d['lat'] as num?)?.toDouble() ?? 0;
      final lng = (d['lng'] as num?)?.toDouble() ?? 0;
      final city = (d['city'] ?? '').toString();
      final address = (d['address'] ?? desc).toString();
      if (mounted) widget.controller.text = address.isEmpty ? desc : address;
      widget.onSelected(widget.controller.text, lat, lng, city);
    } catch (_) {
      widget.onSelected(desc, 0, 0, '');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: widget.controller,
          focusNode: _focus,
          textInputAction: TextInputAction.search,
          onChanged: _onChanged,
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: 'Type an address or place…',
            prefixIcon: Icon(widget.prefixIcon, color: AppColors.primary),
            suffixIcon: _loading
                ? Padding(
                    padding: const EdgeInsets.all(12),
                    child: SizedBox(width: 16.w, height: 16.w, child: const CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
                  )
                : widget.suffix,
            filled: true,
            fillColor: Colors.grey[50],
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.7))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
          ),
          validator: widget.validator,
        ),
        if (_open)
          Container(
            margin: EdgeInsets.only(top: 4.h),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: AppColors.border),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 3))],
            ),
            child: Column(
              children: _suggestions.map((item) {
                final title = (item['main'] ?? item['description'] ?? '').toString();
                final sub = (item['secondary'] ?? '').toString();
                return InkWell(
                  onTap: () => _select(item),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                    child: Row(
                      children: [
                        Icon(Icons.location_on_outlined, size: 18.sp, color: AppColors.primary),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title, style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                              if (sub.isNotEmpty)
                                Text(sub, style: TextStyle(fontSize: 11.sp, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}
