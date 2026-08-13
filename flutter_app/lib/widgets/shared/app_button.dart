import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Pill button from the Figma design system: fully rounded (stadium), 13pt
/// vertical / 23.5pt horizontal padding — ×3 for ScreenUtil units, same
/// convention as [AppTextStyles]. Width (170pt in Figma) is left to the
/// parent, same reasoning as [AppTextField]; height (44pt) isn't set
/// directly either — it falls out of the padding plus the label's line
/// height rather than a wrapping SizedBox, so it always matches the
/// content instead of leaving dead space.
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color? disabledBackgroundColor;
  final Color? disabledForegroundColor;

  /// Outline color for an outlined/secondary variant — 1pt stroke per the
  /// Figma spec. Omit for a plain filled button.
  final Color? borderColor;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.backgroundColor,
    this.foregroundColor = Colors.white,
    this.disabledBackgroundColor,
    this.disabledForegroundColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        disabledBackgroundColor: disabledBackgroundColor ?? Colors.grey.shade500,
        disabledForegroundColor: disabledForegroundColor ?? Colors.white,
        elevation: 0,
        side: borderColor != null ? BorderSide(color: borderColor!) : BorderSide.none,
        padding: EdgeInsets.symmetric(vertical: 39.h, horizontal: 70.5.w),
        shape: const StadiumBorder(),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }
}
