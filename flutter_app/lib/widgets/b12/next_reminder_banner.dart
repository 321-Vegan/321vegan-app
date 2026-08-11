import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../services/b12_reminder_service.dart';
import '../../themes/app_shapes.dart';

/// Primary-tinted "prochain rappel/prise" pill, shared by the B12 settings
/// and history pages so the relative-day phrasing (aujourd'hui/demain/…)
/// stays identical everywhere a next B12 date is shown.
class B12NextReminderBanner extends StatelessWidget {
  final DateTime date;
  final String label;

  /// Appends the HH:mm — relevant for a scheduled reminder time, not for
  /// an estimated next-intake date.
  final bool showTime;

  const B12NextReminderBanner({
    super.key,
    required this.date,
    this.label = 'Prochain rappel',
    this.showTime = false,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final dayLabel = B12ReminderService.relativeDayLabel(date);
    final text = showTime
        ? '$label : $dayLabel à ${DateFormat('HH:mm').format(date)}'
        : '$label : $dayLabel';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 18.h),
      decoration: ShapeDecoration(
        color: primary.withValues(alpha: 0.08),
        shape: squircleBorder(
          radius: 24.r,
          side: BorderSide(color: primary.withValues(alpha: 0.25)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_repeat, size: 40.sp, color: primary),
          SizedBox(width: 10.w),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 36.sp,
                fontWeight: FontWeight.w600,
                color: primary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
