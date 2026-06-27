import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/app_theme.dart';

class _CityResult {
  final String city;
  final String state;
  _CityResult(this.city, this.state);
}

/// A text field that suggests Indian cities as "City, State" while typing,
/// using OpenStreetMap (Nominatim). No API key required.
class CityAutocompleteField extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool required;
  final String? initialText;
  // Fired on every keystroke (free text) and on selection.
  final void Function(String city, String? state) onChanged;

  const CityAutocompleteField({
    super.key,
    required this.label,
    required this.icon,
    required this.onChanged,
    this.required = false,
    this.initialText,
  });

  @override
  State<CityAutocompleteField> createState() => _CityAutocompleteFieldState();
}

class _CityAutocompleteFieldState extends State<CityAutocompleteField> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  final _dio = Dio();
  Timer? _debounce;
  List<_CityResult> _results = [];
  bool _loading = false;
  bool _justSelected = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialText != null) _ctrl.text = widget.initialText!;
    _focus.addListener(() {
      // Delay clearing so a suggestion tap (which removes focus) registers first.
      if (!_focus.hasFocus) {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted && !_focus.hasFocus) setState(() => _results = []);
        });
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    // Report raw text immediately (state cleared until a suggestion is chosen).
    widget.onChanged(q.trim(), null);
    if (_justSelected) {
      _justSelected = false;
      return;
    }
    _debounce?.cancel();
    if (q.trim().length < 2) {
      setState(() => _results = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(q.trim()));
  }

  Future<void> _search(String q) async {
    setState(() => _loading = true);
    try {
      final res = await _dio.get(
        'https://nominatim.openstreetmap.org/search',
        queryParameters: {
          'format': 'json',
          'addressdetails': '1',
          'countrycodes': 'in',
          'limit': '8',
          'q': q,
        },
        options: Options(headers: {'Accept-Language': 'en', 'User-Agent': 'GoraCabs/1.0'}, receiveTimeout: const Duration(seconds: 8)),
      );
      final list = (res.data as List?) ?? [];
      final seen = <String>{};
      final results = <_CityResult>[];
      for (final item in list) {
        final addr = (item as Map)['address'] as Map?;
        if (addr == null) continue;
        final city = addr['city'] ?? addr['town'] ?? addr['village'] ?? addr['municipality'] ?? addr['county'] ?? addr['state_district'];
        final state = addr['state'];
        if (city == null || state == null) continue;
        final key = '$city, $state';
        if (seen.add(key)) results.add(_CityResult(city.toString(), state.toString()));
      }
      if (mounted) setState(() => _results = results);
    } catch (_) {
      if (mounted) setState(() => _results = []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _select(_CityResult r) {
    _justSelected = true;
    _ctrl.text = '${r.city}, ${r.state}';
    widget.onChanged(r.city, r.state);
    setState(() => _results = []);
    _focus.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _ctrl,
          focusNode: _focus,
          onChanged: _onChanged,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: widget.label,
            prefixIcon: Icon(widget.icon, color: AppColors.primary),
            suffixIcon: _loading
                ? Padding(
                    padding: EdgeInsets.all(12.r),
                    child: SizedBox(width: 16.w, height: 16.w, child: const CircularProgressIndicator(strokeWidth: 2)),
                  )
                : null,
            filled: true,
            fillColor: Colors.grey[50],
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide(color: AppColors.primary.withOpacity(0.7))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide(color: AppColors.primary, width: 2)),
          ),
          validator: widget.required ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null : null,
        ),
        if (_results.isNotEmpty)
          Container(
            margin: EdgeInsets.only(top: 4.h),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: AppColors.border),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Column(
              children: _results
                  .map((r) => ListTile(
                        dense: true,
                        leading: Icon(Icons.location_city, color: AppColors.primary, size: 20.sp),
                        title: Text('${r.city}, ${r.state}', style: TextStyle(fontSize: 13.sp, fontFamily: 'Poppins')),
                        onTap: () => _select(r),
                      ))
                  .toList(),
            ),
          ),
      ],
    );
  }
}
