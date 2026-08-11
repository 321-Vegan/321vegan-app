import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_shapes.dart';

/// Dismissible nudge shown on the Dashboard while the user has no B12
/// reminder configured yet. Purely presentational — [DashboardPage] decides
/// when to mount it and persists the dismissal.
class B12ReminderBanner extends StatelessWidget {
  final VoidCallback onActivate;
  final VoidCallback onDismiss;

  const B12ReminderBanner({
    super.key,
    required this.onActivate,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    // Figma spec: fill width, hug height, radius 16, stroke 1
    // Secondary/Default, bg Secondary/Tag, padding 15, gap 10 (×3 units).
    return Container(
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'N\'oubliez plus jamais la prise de votre B12 en activant '
                  'les rappels et la récurrence souhaitée.',
                  style: TextStyle(
                    fontSize: 42.sp,
                    color: kAccentYellow,
                    height: 1.3,
                  ),
                ),
                SizedBox(height: 30.h),
                GestureDetector(
                  onTap: onActivate,
                  child: Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 36.w, vertical: 14.h),
                    decoration: ShapeDecoration(
                      color: kAccentYellow,
                      shape: squircleBorder(radius: 30),
                    ),
                    child: Text(
                      'Activer les rappels',
                      style: TextStyle(
                        fontSize: 40.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: Icon(Icons.close, size: 48.sp, color: kAccentYellow),
          ),
        ],
      ),
    );
  }
}

/// Full-width yellow pill shown while the B12 reminder is configured and
/// today's intake hasn't been recorded yet: one tap records it. Once taken,
/// the Dashboard hides this button and shows a "B12 prise" note in the
/// header instead.
class B12IntakeButton extends StatelessWidget {
  final VoidCallback onPressed;

  const B12IntakeButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: kAccentYellow,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: EdgeInsets.symmetric(vertical: 36.h),
          shape: const StadiumBorder(),
        ),
        child: Text(
          'J\'ai pris ma B12',
          style: TextStyle(fontSize: 46.sp, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
