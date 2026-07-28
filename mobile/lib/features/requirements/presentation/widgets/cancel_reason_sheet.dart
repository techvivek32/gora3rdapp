import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_theme.dart';

/// Bottom sheet that collects a cancellation reason. Calls [onConfirm] with the
/// chosen reason. Shared by the requirement detail and My Requirements pages.
class CancelReasonSheet extends StatefulWidget {
  final void Function(String reason) onConfirm;
  const CancelReasonSheet({super.key, required this.onConfirm});

  static Future<void> show(BuildContext context, {required void Function(String reason) onConfirm}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20.r))),
      builder: (_) => CancelReasonSheet(onConfirm: onConfirm),
    );
  }

  @override
  State<CancelReasonSheet> createState() => _CancelReasonSheetState();
}

class _CancelReasonSheetState extends State<CancelReasonSheet> {
  static const _reasons = [
    'Found a vehicle already',
    'Trip plan changed',
    'Booking posted by mistake',
    'Price not matching',
    'Dates changed',
    'Other',
  ];

  String? _selected;
  final _otherCtrl = TextEditingController();

  @override
  void dispose() {
    _otherCtrl.dispose();
    super.dispose();
  }

  void _confirm() {
    final reason = _selected == 'Other' ? _otherCtrl.text.trim() : _selected ?? '';
    if (reason.isEmpty) return;
    widget.onConfirm(reason);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      padding: EdgeInsets.only(
        left: 20.w,
        right: 20.w,
        top: 20.h,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20.h,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Cancel Reason', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 18.sp)),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  ..._reasons.map((r) => RadioListTile<String>(
                        value: r,
                        groupValue: _selected,
                        title: Text(r, style: const TextStyle(fontFamily: 'Poppins', fontSize: 14)),
                        onChanged: (v) => setState(() => _selected = v),
                        activeColor: AppColors.primary,
                        contentPadding: EdgeInsets.zero,
                      )),
                  if (_selected == 'Other') ...[
                    SizedBox(height: 8.h),
                    TextField(
                      controller: _otherCtrl,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Please specify your reason...',
                        hintStyle: const TextStyle(fontFamily: 'Poppins'),
                        filled: true,
                        fillColor: Colors.grey[50],
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.r),
                          borderSide: BorderSide(color: AppColors.primary, width: 2),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    side: BorderSide(color: Colors.grey[400]!),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                  ),
                  child: const Text('Back', style: TextStyle(fontFamily: 'Poppins')),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _selected == null ? null : _confirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                  ),
                  child: const Text('Proceed', style: TextStyle(color: Colors.white, fontFamily: 'Poppins')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
