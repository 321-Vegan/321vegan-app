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

  /// Single glyph shown in the circle badge (e.g. 'i', '!').
  final String symbol;

  const InfoBox({
    required this.text,
    this.symbol = 'i',
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
