import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_shapes.dart';

/// Pale-yellow disclaimer/warning box used across the app (EAN-8 /
/// old-recipe warnings, stat detail sheets). Figma: bg Secondary/Tag,
/// radius 16, padding 15, gap 10, 1px Secondary/Default border — ×3 for
/// ScreenUtil units.
class InfoBox extends StatelessWidget {
  final String text;

  /// Single glyph shown in the circle badge (e.g. 'i', '!'). Ignored when
  /// [iconAsset] is set.
  final String symbol;

  /// Path to an icon asset shown instead of [symbol], e.g.
  /// `lib/assets/images/icons/solid-check.webp`. These assets already bake
  /// in their own badge shape (a circle, or — for the alert triangle — no
  /// circle at all), so unlike [symbol] it's rendered without an extra
  /// wrapping circle.
  final String? iconAsset;

  const InfoBox({
    required this.text,
    this.symbol = 'i',
    this.iconAsset,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(45.w),
      decoration: ShapeDecoration(
        color: kSecondaryTag,
        shape: squircleBorder(
          radius: 48.r,
          side: const BorderSide(color: kAccentYellow),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 42.sp,
                fontWeight: FontWeight.w500,
                color: kAccentYellow,
              ),
            ),
          ),
          SizedBox(width: 30.w),
          if (iconAsset != null)
            Image.asset(
              iconAsset!,
              width: 56.w,
              height: 56.w,
              color: kAccentYellow,
              colorBlendMode: BlendMode.srcIn,
            )
          else
            Container(
              width: 56.w,
              height: 56.w,
              decoration: const BoxDecoration(
                color: kAccentYellow,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  symbol,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 34.sp,
                    fontWeight: FontWeight.bold,
                    height: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
