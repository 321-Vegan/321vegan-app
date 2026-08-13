import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_shapes.dart';

/// Square/squircle icon-only button (white or tinted surface, soft shadow,
/// centered icon) used as a floating action or header control across the
/// app — was hand-rolled independently in the scan, map, dashboard and
/// scan-history pages before being consolidated here.
///
/// Use [SquareIconButton.action] (48×48, radius 14, alpha-0.15 shadow) for
/// the common case; it covers the scan page top row, map's floating
/// buttons, the dashboard header icons and scan-history's "clear" button —
/// two close-but-not-identical Figma tokens (47×47/radius 12/alpha-0.06 for
/// the latter two) were merged into this single spec since the difference
/// wasn't visible enough to justify two presets.
///
/// For anything that doesn't fit (different size/radius/shadow entirely, a
/// non-white background with no shadow, etc.), use the base constructor
/// directly — see `shop_detail_sheet.dart`'s itinerary button.
///
/// For anything that isn't a plain [Icon] (e.g. the Vegandex tinted image,
/// or a badge overlay), pass a custom [child]/wrap the button in a [Stack]
/// — see `map.dart`'s filter-count badge for the pattern.
class SquareIconButton extends StatelessWidget {
  final VoidCallback? onTap;
  final Widget child;
  final double size;
  final double radius;
  final Color backgroundColor;
  final List<BoxShadow> shadows;

  const SquareIconButton({
    required this.onTap,
    required this.child,
    required this.size,
    required this.radius,
    required this.backgroundColor,
    required this.shadows,
    super.key,
  });

  /// "Square action button" spec: 48×48, radius 14, alpha-0.15 shadow.
  factory SquareIconButton.action({
    Key? key,
    VoidCallback? onTap,
    IconData? icon,
    Color iconColor = kTextPrimary,
    double iconSize = 72,
    Color backgroundColor = Colors.white,
    Widget? child,
  }) {
    assert(icon != null || child != null,
        'SquareIconButton.action needs an icon or a custom child');
    return SquareIconButton(
      key: key,
      onTap: onTap,
      size: 144.w,
      radius: 42.r,
      backgroundColor: backgroundColor,
      shadows: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.15),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ],
      child: child ?? Icon(icon, color: iconColor, size: iconSize.sp),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: ShapeDecoration(
          color: backgroundColor,
          shape: squircleBorder(radius: radius),
          shadows: shadows,
        ),
        child: Center(child: child),
      ),
    );
  }
}
