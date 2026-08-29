import 'package:flutter/material.dart';
import '../../themes/app_spacing.dart';
import '../../themes/app_text_styles.dart';

/// Section header + spaced list of rows, used to group tiles under a title
/// ("Compte", "B12", "Produits", "Scan") in the Paramètres screen.
class SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const SettingsSection({
    super.key,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTextStyles.baloo26),
        SizedBox(height: AppSpacing.afterTitle),
        for (int i = 0; i < children.length; i++) ...[
          children[i],
          if (i != children.length - 1) SizedBox(height: AppSpacing.item),
        ],
      ],
    );
  }
}
