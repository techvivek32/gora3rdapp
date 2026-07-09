import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../utils/contact_launcher.dart';

/// Opens a popup for a banner: the banner image, Call / WhatsApp buttons below,
/// and a close (X) button at the top-right.
void showBannerPopup(BuildContext context, Map<String, dynamic> banner) {
  final imageUrl = (banner['imageUrl'] as String?)?.trim() ?? '';
  final phone = (banner['phone'] as String?)?.trim() ?? '';
  final whatsapp = (banner['whatsapp'] as String?)?.trim() ?? '';

  showDialog(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18.r),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Banner image
                if (imageUrl.isNotEmpty)
                  AspectRatio(
                    aspectRatio: 358 / 175,
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade200),
                    ),
                  ),

                // Call / WhatsApp buttons
                if (phone.isNotEmpty || whatsapp.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.all(14.r),
                    child: Row(
                      children: [
                        if (phone.isNotEmpty)
                          Expanded(
                            child: _actionButton(
                              icon: Icons.call,
                              label: 'Call',
                              color: const Color(0xFF2E7D32),
                              onTap: () {
                                Navigator.pop(ctx);
                                callNumber(phone);
                              },
                            ),
                          ),
                        if (phone.isNotEmpty && whatsapp.isNotEmpty) SizedBox(width: 12.w),
                        if (whatsapp.isNotEmpty)
                          Expanded(
                            child: _actionButton(
                              icon: Icons.chat,
                              label: 'WhatsApp',
                              color: const Color(0xFF25D366),
                              onTap: () {
                                Navigator.pop(ctx);
                                openWhatsApp(whatsapp);
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Close (X) button — top-right
          Positioned(
            top: -12.h,
            right: -12.w,
            child: GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: Container(
                padding: EdgeInsets.all(6.r),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 6, offset: const Offset(0, 2)),
                  ],
                ),
                child: Icon(Icons.close, size: 20.sp, color: Colors.black87),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _actionButton({
  required IconData icon,
  required String label,
  required Color color,
  required VoidCallback onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: EdgeInsets.symmetric(vertical: 12.h),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 18.sp),
          SizedBox(width: 8.w),
          Text(
            label,
            style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w600, fontFamily: 'Poppins'),
          ),
        ],
      ),
    ),
  );
}
