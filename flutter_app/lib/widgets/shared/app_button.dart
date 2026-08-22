import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Pill button from the Figma design system: fully rounded (stadium).
/// Width/height are left to fall out of padding + content (same reasoning
/// as [AppTextField]) rather than fixed values, so there's no dead space.
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

  /// Optional leading icon, sized to match the fixed (non-ScreenUtil) 16pt
  /// label so icon and text stay proportional regardless of device.
  final IconData? icon;

  /// Leading icon image (e.g. a Figma export) shown instead of [icon] when
  /// set — plain black glyph, tinted like [icon] at render time.
  final String? iconAsset;

  /// Swaps the label (and icon) for a spinner and disables taps — the
  /// button keeps its size and colors so it doesn't jump while a request
  /// is in flight.
  final bool isLoading;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.backgroundColor,
    this.foregroundColor = Colors.white,
    this.disabledBackgroundColor,
    this.disabledForegroundColor,
    this.borderColor,
    this.icon,
    this.iconAsset,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
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
      child: isLoading
          ? SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(foregroundColor),
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (iconAsset != null) ...[
                  Image.asset(
                    iconAsset!,
                    width: 20,
                    height: 20,
                    color: foregroundColor,
                    colorBlendMode: BlendMode.srcIn,
                  ),
                  const SizedBox(width: 8),
                ] else if (icon != null) ...[
                  Icon(icon, size: 20, color: foregroundColor),
                  const SizedBox(width: 8),
                ],
                Text(
                  label,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
    );
  }
}
