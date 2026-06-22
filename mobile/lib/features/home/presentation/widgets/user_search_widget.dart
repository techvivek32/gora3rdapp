import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';
import '../../../users/presentation/widgets/user_card_sheet.dart';

/// A phone-number search box that looks up a partner by mobile number and shows
/// their profile card.
class UserSearchWidget extends StatefulWidget {
  const UserSearchWidget({super.key});

  @override
  State<UserSearchWidget> createState() => _UserSearchWidgetState();
}

class _UserSearchWidgetState extends State<UserSearchWidget> {
  final _controller = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final raw = _controller.text.trim();
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid mobile number')),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    try {
      final res = await getIt<ApiClient>().get('/users/lookup', params: {'mobile': digits});
      final user = Map<String, dynamic>.from(res.data['data'] as Map);
      if (!mounted) return;
      setState(() => _loading = false);
      await showUserCardSheet(context, user);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No user found with this number')),
      );
    }
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
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: 'Search partner by phone number',
                prefixIcon: const Icon(Icons.phone_outlined),
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
