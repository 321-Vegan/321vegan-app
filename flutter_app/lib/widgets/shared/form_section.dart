import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_spacing.dart';
import '../../themes/app_text_styles.dart';

/// A titled part of a form page: [title] (with a red asterisk when
/// [isRequired]), an optional grey [subtitle], then [children] stretched.
class FormSection extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool isRequired;
  final List<Widget> children;

  const FormSection({
    super.key,
    required this.title,
    this.subtitle,
    this.isRequired = false,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: AppSpacing.section),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text.rich(
            TextSpan(children: [
              TextSpan(text: title),
              if (isRequired)
                const TextSpan(
                  text: ' *',
                  style: TextStyle(color: kSemanticError),
                ),
            ]),
            style: AppTextStyles.baloo22,
          ),
          if (subtitle != null) ...[
            SizedBox(height: 6.h),
            Text(subtitle!,
                style: AppTextStyles.bodyRegular13
                    .copyWith(color: Colors.grey[600])),
          ],
          SizedBox(height: 24.h),
          ...children,
        ],
      ),
    );
  }
}
