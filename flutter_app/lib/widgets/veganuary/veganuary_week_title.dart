import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../models/veganuary/veganuary_content.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';

/// Title of a Veganuary week with "SEMAINE N" under it (path header, week
/// cards). [faded] for a week not open yet.
class VeganuaryWeekTitle extends StatelessWidget {
  final VeganuaryWeek week;
  final bool faded;

  const VeganuaryWeekTitle({super.key, required this.week, this.faded = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          week.title,
          style: AppTextStyles.baloo26.copyWith(
              color: faded ? kTextPrimary.withValues(alpha: 0.5) : null),
        ),
        SizedBox(height: 6.h),
        Text(
          'SEMAINE ${week.number}',
          style: AppTextStyles.baloo17.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
            color: faded ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
      ],
    );
  }
}
