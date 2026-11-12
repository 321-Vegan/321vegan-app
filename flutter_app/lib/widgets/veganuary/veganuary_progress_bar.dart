import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_shapes.dart';

/// Yellow progress bar of the Veganuary (pages of a day, days of a week).
class VeganuaryProgressBar extends StatelessWidget {
  /// 0 to 1.
  final double value;
  final Color trackColor;

  const VeganuaryProgressBar({
    super.key,
    required this.value,
    this.trackColor = const Color(0xCCFFFFFF),
  });

  @override
  Widget build(BuildContext context) {
    return ClipSmoothRect(
      radius: squircleRadius(12.h),
      child: SizedBox(
        height: 24.h,
        child: Stack(
          children: [
            Container(color: trackColor),
            AnimatedFractionallySizedBox(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              alignment: Alignment.centerLeft,
              widthFactor: value,
              heightFactor: 1,
              child: ClipSmoothRect(
                radius: squircleRadius(12.h),
                child: Container(color: kAccentYellow),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
