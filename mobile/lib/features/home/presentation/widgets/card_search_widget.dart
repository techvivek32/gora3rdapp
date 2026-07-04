import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';
import '../../../requirements/presentation/widgets/requirement_card_widget.dart';
import '../../../available_vehicles/presentation/pages/vehicles_feed_page.dart' show VehicleCard;

/// A search box that looks up a posted requirement or an available cab by its
/// display ID (e.g. "ID-REQ95642459" / "REQ95642459" / "VEH12345678") and opens
/// the matching card's detail page.
class CardSearchWidget extends StatefulWidget {
  const CardSearchWidget({super.key});

  @override
  State<CardSearchWidget> createState() => _CardSearchWidgetState();
}

class _CardSearchWidgetState extends State<CardSearchWidget> {
  final _controller = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Normalise the typed value: drop an optional leading "ID-" and uppercase.
  String get _code {
    var t = _controller.text.trim();
    if (t.toUpperCase().startsWith('ID-')) t = t.substring(3);
    return t.trim().toUpperCase();
  }

  Future<Map<String, dynamic>?> _tryLookup(String path, String code) async {
    try {
      final res = await getIt<ApiClient>().get(path, params: {'code': code});
      final data = res.data['data'];
      if (data is Map) return Map<String, dynamic>.from(data);
    } catch (_) {}
    return null;
  }

  Future<void> _search() async {
    final code = _code;
    if (code.isEmpty) {
      _snack('Enter a card ID to search');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _loading = true);

    // Route by known prefixes; fall back to trying both.
    final looksLikeVehicle = code.startsWith('VEH');
    final looksLikeRequirement = code.startsWith('REQ');

    Map<String, dynamic>? requirement;
    Map<String, dynamic>? vehicle;

    if (looksLikeVehicle) {
      vehicle = await _tryLookup('/available-vehicles/lookup', code);
    } else if (looksLikeRequirement) {
      requirement = await _tryLookup('/requirements/lookup', code);
    } else {
      requirement = await _tryLookup('/requirements/lookup', code);
      vehicle = requirement == null ? await _tryLookup('/available-vehicles/lookup', code) : null;
    }

    if (!mounted) return;
    setState(() => _loading = false);

    if (requirement != null) {
      _showCardSheet(RequirementCardWidget(requirement: requirement));
    } else if (vehicle != null) {
      _showCardSheet(VehicleCard(vehicle: vehicle));
    } else {
      _snack('No booking or cab found with this ID');
    }
  }

  /// Show the matched requirement / cab card as a popup on the home screen.
  void _showCardSheet(Widget card) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => Container(
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
          ),
          child: Column(
            children: [
              Container(
                margin: EdgeInsets.symmetric(vertical: 10.h),
                width: 44.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.fromLTRB(10.w, 0, 10.w, 20.h),
                  children: [card],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              textCapitalization: TextCapitalization.characters,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: 'Search booking / cab by ID',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 8.w),
              ),
            ),
          ),
          SizedBox(width: 10.w),
          SizedBox(
            height: 50.h,
            child: ElevatedButton(
              onPressed: _loading ? null : _search,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 18.w),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
              ),
              child: _loading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.search, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
