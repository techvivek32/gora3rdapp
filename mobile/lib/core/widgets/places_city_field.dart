import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../di/injection.dart';
import '../network/api_client.dart';
import '../theme/app_theme.dart';

class _Prediction {
  final String city; // "Udaipur"
  final String region; // "Rajasthan, India"
  _Prediction(this.city, this.region);
}

/// City field backed by the same Google Places proxy the "My Cities" page uses
/// (`GET /places/autocomplete`). Typing "uday" suggests "Udaipur, Rajasthan".
///
/// [onChanged] fires on every keystroke (with a null state) and again on
/// selection, where the state is resolved from the prediction.
class PlacesCityField extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool required;
  final String? initialText;
  final void Function(String city, String? state) onChanged;
  final bool skipAuth;

  const PlacesCityField({
    super.key,
    required this.label,
    required this.icon,
    required this.onChanged,
    this.required = false,
    this.initialText,
    this.skipAuth = false,
  });

  @override
  State<PlacesCityField> createState() => _PlacesCityFieldState();
}

class _PlacesCityFieldState extends State<PlacesCityField> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;
  List<_Prediction> _results = [];
  bool _loading = false;
  bool _justSelected = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialText != null) _ctrl.text = widget.initialText!;
    _focus.addListener(() {
      // Delay clearing so tapping a suggestion (which drops focus) still registers.
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
    widget.onChanged(q.trim(), null); // free text until a suggestion is picked
    if (_justSelected) {
      _justSelected = false;
      return;
    }
    _debounce?.cancel();
    if (q.trim().length < 2) {
      setState(() => _results = []);
      return;
    }
    setState(() => _loading = true);
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(q.trim()));
  }

  Future<void> _search(String query) async {
    try {
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:7001/api/v1'));
      final res = await dio.get('/places/autocomplete', queryParameters: {'input': query, 'types': 'geocode'});
      final preds = (res.data['data']?['predictions'] as List?) ?? [];
      final seen = <String>{};
      final results = <_Prediction>[];
      for (final p in preds) {
        final city = (p['main'] ?? p['description'] ?? '').toString().trim();
        final region = (p['secondary'] ?? '').toString().trim();
        if (city.isEmpty || !seen.add(city)) continue;
        results.add(_Prediction(city, region));
      }
      if (!mounted || query != _ctrl.text.trim()) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() { _results = []; _loading = false; });
    }
  }

  /// "Rajasthan, India" → "Rajasthan". Empty when only the country is present.
  String? _stateFrom(String region) {
    final parts = region.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return null;
    final first = parts.first;
    return first.toLowerCase() == 'india' ? null : first;
  }

  void _select(_Prediction p) {
    _justSelected = true;
    _ctrl.text = p.city;
    widget.onChanged(p.city, _stateFrom(p.region));
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
            prefixIcon: Icon(widget.icon, color: Colors.grey.shade600),
            suffixIcon: _loading
                ? Padding(
                    padding: EdgeInsets.all(12.r),
                    child: SizedBox(width: 16.w, height: 16.w, child: const CircularProgressIndicator(strokeWidth: 2)),
                  )
                : null,
            filled: true,
            fillColor: Colors.grey[50],
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: const BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
          ),
          validator: widget.required ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null : null,
        ),
        if (_results.isNotEmpty)
          Container(
            margin: EdgeInsets.only(top: 4.h),
            constraints: BoxConstraints(maxHeight: 220.h),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: AppColors.border),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _results.length,
              itemBuilder: (_, i) {
                final r = _results[i];
                return ListTile(
                  dense: true,
                  leading: Icon(Icons.location_city, color: AppColors.textSecondary, size: 20.sp),
                  title: Text(r.city, style: TextStyle(fontSize: 13.sp, fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
                  subtitle: r.region.isEmpty
                      ? null
                      : Text(r.region, style: TextStyle(fontSize: 11.sp, color: AppColors.textSecondary)),
                  onTap: () => _select(r),
                );
              },
            ),
          ),
      ],
    );
  }
}
