import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/app_theme.dart';

/// The small ✕ that empties a text field in one tap.
///
/// Shared so every field clears the same way and looks the same doing it.
/// Lives in a field's `suffixIcon`, which is a tight space: without a forced
/// minimum the tap target shrinks to the glyph and the button is easy to miss,
/// so it is padded out to a comfortable size.
class ClearFieldButton extends StatelessWidget {
  final VoidCallback onPressed;

  /// Read out by screen readers, e.g. "Clear Pickup city".
  final String tooltip;

  const ClearFieldButton({super.key, required this.onPressed, this.tooltip = 'Clear'});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: BoxConstraints(minWidth: 40.w, minHeight: 40.w),
      icon: Icon(Icons.cancel_rounded, size: 18.w, color: AppColors.textHint),
    );
  }
}
