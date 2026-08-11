import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_shapes.dart';

/// The app's standard "nothing here" placeholder — sad-sun illustration,
/// bold title, grey subtitle, and an optional CTA button. Same visual
/// language as the scan history / sent products empty states, extracted so
/// new empty states (e.g. product search with no results) match them.
class EmptyStateView extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? buttonLabel;
  final VoidCallback? onButtonTap;

  const EmptyStateView({
    super.key,
    required this.title,
    required this.subtitle,
    this.buttonLabel,
    this.onButtonTap,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 60.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'lib/assets/images/sun-off.webp',
              width: 220.w,
              height: 220.w,
            ),
            SizedBox(height: 36.h),
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Baloo2',
                fontSize: 52.sp,
                fontWeight: FontWeight.w600,
                letterSpacing: -1,
                color: kTextPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12.h),
            Text(
              subtitle,
              style: TextStyle(fontSize: 40.sp, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            if (buttonLabel != null && onButtonTap != null) ...[
              SizedBox(height: 48.h),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onButtonTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kAccentYellow,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 20.h),
                    elevation: 0,
                    shape: squircleBorder(radius: 42.r),
                  ),
                  child: Text(
                    buttonLabel!,
                    style:
                        TextStyle(fontSize: 42.sp, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
