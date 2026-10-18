import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';

/// "4,3" — French decimal comma, one decimal.
String formatRatingAverage(double value) =>
    value.toStringAsFixed(1).replaceAll('.', ',');

/// "1 avis" / "12 avis".
String formatRatingCount(int count) => '$count avis';

/// Read-only row of 5 stars. Accepts a fractional [value] (averages) and
/// rounds it to the nearest half star.
class StarRating extends StatelessWidget {
  final double value;
  final double? size;
  final Color color;

  const StarRating({
    super.key,
    required this.value,
    this.size,
    this.color = kAccentYellow,
  });

  @override
  Widget build(BuildContext context) {
    final halves = (value * 2).round();
    final s = size ?? 48.sp;
    return Semantics(
      label: '${formatRatingAverage(value)} sur 5',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(5, (i) {
            final IconData icon;
            if (halves >= (i + 1) * 2) {
              icon = Icons.star_rounded;
            } else if (halves == i * 2 + 1) {
              icon = Icons.star_half_rounded;
            } else {
              icon = Icons.star_outline_rounded;
            }
            return Icon(icon, size: s, color: color);
          }),
        ),
      ),
    );
  }
}

/// Tappable 5-star picker (1 to 5). [value] is null until the user picks;
/// the caption under the stars spells out the current value.
class StarRatingInput extends StatelessWidget {
  final int? value;
  final ValueChanged<int> onChanged;

  const StarRatingInput({
    super.key,
    required this.value,
    required this.onChanged,
  });

  static const _captions = {
    1: 'Décevant',
    2: 'Bof',
    3: 'C\'est ok',
    4: 'Très bien',
    5: 'Parfait !',
  };

  @override
  Widget build(BuildContext context) {
    final current = value;
    final caption = current == null
        ? 'Touchez une étoile'
        : '$current/5 · ${_captions[current]}';

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (i) {
            final star = i + 1;
            final lit = current != null && star <= current;
            return Semantics(
              button: true,
              selected: lit,
              label: '$star étoile${star > 1 ? 's' : ''}',
              child: GestureDetector(
                onTap: () => onChanged(star),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 9.w),
                  child: Icon(
                    lit ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 120.sp,
                    color: kAccentYellow,
                  ),
                ),
              ),
            );
          }),
        ),
        SizedBox(height: 12.h),
        Text(
          caption,
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMedium13.copyWith(
            color: current == null ? Colors.grey[500] : kAccentYellow,
          ),
        ),
      ],
    );
  }
}
