import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_shapes.dart';
import '../../themes/app_text_styles.dart';
import '../shared/app_card.dart';
import 'star_rating.dart';

/// Average rating card: big average, stars and count on the left, and the
/// per-value distribution bars on the right when [distribution] is given.
///
/// With [onValueTap], bars become filters: tapping one reports its value,
/// [selectedValue] is highlighted and the other bars are dimmed. Values
/// without any rating aren't tappable.
class RatingSummary extends StatelessWidget {
  final double average;
  final int count;

  /// Ratings count per value (1 to 5); bars are drawn from 5 down to 1.
  final Map<int, int>? distribution;
  final int? selectedValue;
  final ValueChanged<int>? onValueTap;

  const RatingSummary({
    super.key,
    required this.average,
    required this.count,
    this.distribution,
    this.selectedValue,
    this.onValueTap,
  });

  @override
  Widget build(BuildContext context) {
    final bars = distribution;
    return AppCard(
      radius: 36.r,
      padding: EdgeInsets.all(39.w),
      child: Row(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(formatRatingAverage(average), style: AppTextStyles.baloo33),
              SizedBox(height: 8.h),
              StarRating(value: average, size: 42.sp),
              SizedBox(height: 8.h),
              Text(
                formatRatingCount(count),
                style: AppTextStyles.bodyRegular13
                    .copyWith(color: Colors.grey[500]),
              ),
            ],
          ),
          if (bars != null && bars.isNotEmpty) ...[
            SizedBox(width: 48.w),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var value = 5; value >= 1; value--)
                    _DistributionBar(
                      value: value,
                      valueCount: bars[value] ?? 0,
                      total: count,
                      selected: selectedValue == value,
                      dimmed: selectedValue != null && selectedValue != value,
                      onTap: onValueTap == null || (bars[value] ?? 0) == 0
                          ? null
                          : () => onValueTap!(value),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DistributionBar extends StatelessWidget {
  final int value;
  final int valueCount;
  final int total;
  final bool selected;
  final bool dimmed;
  final VoidCallback? onTap;

  const _DistributionBar({
    required this.value,
    required this.valueCount,
    required this.total,
    this.selected = false,
    this.dimmed = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = total == 0 ? 0.0 : valueCount / total;
    final labelStyle = selected
        ? AppTextStyles.bodyBold11.copyWith(color: kAccentYellow)
        : AppTextStyles.bodyMedium11.copyWith(color: Colors.grey[600]);

    final bar = AnimatedOpacity(
      opacity: dimmed ? 0.35 : 1,
      duration: const Duration(milliseconds: 150),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 6.h),
        child: Row(
          children: [
            SizedBox(
              width: 30.w,
              child: Text('$value',
                  textAlign: TextAlign.center, style: labelStyle),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: ClipPath(
                clipper:
                    ShapeBorderClipper(shape: squircleBorder(radius: 12.r)),
                child: SizedBox(
                  height: 21.h,
                  child: Stack(
                    children: [
                      Container(color: kBorderDefault),
                      FractionallySizedBox(
                        widthFactor: ratio.clamp(0, 1),
                        child: Container(color: kAccentYellow),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(width: 12.w),
            SizedBox(
              width: 54.w,
              child: Text('$valueCount',
                  textAlign: TextAlign.right, style: labelStyle),
            ),
          ],
        ),
      ),
    );

    if (onTap == null) return bar;
    return Semantics(
      button: true,
      selected: selected,
      label: 'Filtrer les avis $value étoile${value > 1 ? 's' : ''}',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: bar,
      ),
    );
  }
}
