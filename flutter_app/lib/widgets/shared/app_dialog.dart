import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../themes/app_shapes.dart';
import '../../themes/app_text_styles.dart';
import 'app_button.dart';

/// The app's dialog look (as the update dialog): an illustration, a title,
/// a message, optional [content], then a full-width primary button and a
/// grey text link for the secondary choice — or a second button when
/// [secondaryColor] is given (two real choices).
class AppDialog extends StatelessWidget {
  /// Asset of the illustration, e.g. a character from
  /// `lib/assets/images/characters/`.
  final String image;
  final String title;
  final String? message;
  final Widget? content;
  final String primaryLabel;
  final VoidCallback onPrimary;

  /// Defaults to the theme's primary color.
  final Color? primaryColor;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final Color? secondaryColor;

  const AppDialog({
    super.key,
    required this.image,
    required this.title,
    this.message,
    this.content,
    required this.primaryLabel,
    required this.onPrimary,
    this.primaryColor,
    this.secondaryLabel,
    this.onSecondary,
    this.secondaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: squircleBorder(radius: 28.r),
      child: SingleChildScrollView(
        padding: EdgeInsets.all(48.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(image, width: 300.w, height: 300.w),
            SizedBox(height: 24.h),
            Text(title,
                style: AppTextStyles.baloo22, textAlign: TextAlign.center),
            if (message != null) ...[
              SizedBox(height: 16.h),
              Text(
                message!,
                style: AppTextStyles.bodyRegular15
                    .copyWith(color: Colors.grey[600], height: 1.4),
                textAlign: TextAlign.center,
              ),
            ],
            if (content != null) ...[
              SizedBox(height: 24.h),
              content!,
            ],
            SizedBox(height: 32.h),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                label: primaryLabel,
                backgroundColor:
                    primaryColor ?? Theme.of(context).colorScheme.primary,
                onPressed: onPrimary,
              ),
            ),
            if (secondaryLabel != null && secondaryColor != null) ...[
              SizedBox(height: 18.h),
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  label: secondaryLabel!,
                  backgroundColor: secondaryColor!,
                  onPressed: onSecondary,
                ),
              ),
            ] else if (secondaryLabel != null) ...[
              SizedBox(height: 8.h),
              TextButton(
                onPressed: onSecondary,
                child: Text(
                  secondaryLabel!,
                  style: AppTextStyles.bodyMedium15
                      .copyWith(color: Colors.grey[600]),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
