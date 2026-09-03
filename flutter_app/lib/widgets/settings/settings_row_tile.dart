import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_shapes.dart';
import '../../themes/app_text_styles.dart';

/// A tappable row showing a label and an optional trailing value/icon, used
/// for the "Compte", "B12" and "Produits" sections in the Paramètres screen.
/// Figma spec: fill×59, radius 12, stroke 1 Border/Default, white bg,
/// padding 15 (v) / 13 (h), gap 15 — all ×3 for ScreenUtil units.
class SettingsRowTile extends StatelessWidget {
  final String label;

  /// Small widget rendered right after the label (e.g. the premium crown).
  final Widget? labelSuffix;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;

  const SettingsRowTile({
    super.key,
    required this.label,
    this.labelSuffix,
    this.value,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: squircleBorder(radius: 36.r),
      child: InkWell(
        onTap: onTap,
        customBorder: squircleBorder(radius: 36.r),
        child: Container(
          // Same floor as SettingsToggleTile, so both card types land at
          // the identical height instead of each hugging its own content.
          constraints: BoxConstraints(minHeight: 210.h),
          padding: EdgeInsets.symmetric(horizontal: 39.w, vertical: 45.h),
          decoration: ShapeDecoration(
            shape: squircleBorder(
              radius: 36.r,
              side: const BorderSide(color: kBorderDefault),
            ),
          ),
          child: Row(
            children: [
              // Sized to its own content (not Expanded) so the value column
              // claims whatever width the label doesn't use.
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyBold15,
                    ),
                  ),
                  if (labelSuffix != null) ...[
                    SizedBox(width: 12.w),
                    labelSuffix!,
                  ],
                ],
              ),
              SizedBox(width: 45.w),
              if (value != null)
                Expanded(
                  child: Text(
                    value!,
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyRegular15
                        .copyWith(color: Colors.grey[500]),
                  ),
                )
              else
                const Spacer(),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}
