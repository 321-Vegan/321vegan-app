import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../themes/app_shapes.dart';
import '../../themes/app_text_styles.dart';

/// Small tappable squircle tag: tinted background, colored icon + label.
/// Used for the scan result's info tags ("À éviter", "Biodynamie", rating)
/// and status labels (rating moderation).
class TagChip extends StatelessWidget {
  final String label;
  final Color color;

  /// Defaults to [color] at 12% opacity.
  final Color? backgroundColor;
  final IconData? icon;

  /// Custom leading widget shown instead of [icon] (e.g. a star rating).
  final Widget? leading;
  final VoidCallback? onTap;

  const TagChip({
    super.key,
    required this.label,
    required this.color,
    this.backgroundColor,
    this.icon,
    this.leading,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
      decoration: ShapeDecoration(
        color: backgroundColor ?? color.withValues(alpha: 0.12),
        shape: squircleBorder(radius: 30.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[
            leading!,
            SizedBox(width: 12.w),
          ] else if (icon != null) ...[
            Icon(icon, color: color, size: 36.sp),
            SizedBox(width: 8.w),
          ],
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodyMedium13.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return chip;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: chip,
    );
  }
}
