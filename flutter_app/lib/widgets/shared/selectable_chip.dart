import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_shapes.dart';
import '../../themes/app_text_styles.dart';

/// Pill to pick in a form or a filter: outlined, tinted with the theme's
/// primary color once [selected]. [icon] (in [iconColor]) goes before the
/// label, e.g. a kind of place's. [dense] for the tighter rows of a sheet.
/// Without [onTap], it can't be changed (e.g. while sending).
class SelectableChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;
  final Color? iconColor;
  final bool dense;

  const SelectableChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.iconColor,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: dense
            ? EdgeInsets.symmetric(horizontal: 30.w, vertical: 18.h)
            : EdgeInsets.symmetric(horizontal: 39.w, vertical: 24.h),
        decoration: ShapeDecoration(
          color: selected ? primary.withValues(alpha: 0.08) : Colors.white,
          shape: squircleBorder(
            radius: 100.r,
            side: BorderSide(
              color: selected ? primary : kBorderDefault,
              width: selected ? 1.5 : 1,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 42.sp, color: iconColor),
              SizedBox(width: 12.w),
            ],
            Text(
              label,
              style: AppTextStyles.bodyMedium13
                  .copyWith(color: selected ? primary : kTextPrimary),
            ),
          ],
        ),
      ),
    );
  }
}
