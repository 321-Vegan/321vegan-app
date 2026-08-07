import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../themes/app_colors.dart';

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
      borderRadius: BorderRadius.circular(36.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(36.r),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 39.w, vertical: 45.h),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(36.r),
            border: Border.all(color: kBorderDefault),
          ),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        label,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 42.sp,
                          fontWeight: FontWeight.w600,
                          color: kTextPrimary,
                        ),
                      ),
                    ),
                    if (labelSuffix != null) ...[
                      SizedBox(width: 12.w),
                      labelSuffix!,
                    ],
                  ],
                ),
              ),
              SizedBox(width: 45.w),
              if (value != null)
                Expanded(
                  child: Text(
                    value!,
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 38.sp, color: Colors.grey[500]),
                  ),
                ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}
