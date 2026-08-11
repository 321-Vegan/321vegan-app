import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_shapes.dart';

/// A titled row with a trailing switch, used for every on/off preference.
/// Same card spec as [SettingsRowTile] (radius 12, Border/Default, white).
class SettingsToggleTile extends StatelessWidget {
  final String title;

  /// Optional helper line under the title (the redesigned Paramètres
  /// screen omits it; the scan settings modal still uses it).
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  /// Optional: makes the label area (not the switch) navigate somewhere,
  /// e.g. "Rappels" opening the detailed B12 reminder settings while the
  /// switch itself keeps toggling inline.
  final VoidCallback? onTap;

  const SettingsToggleTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 39.w, vertical: 12.h),
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: squircleBorder(
          radius: 36.r,
          side: const BorderSide(color: kBorderDefault),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 42.sp,
                      fontWeight: FontWeight.w600,
                      color: kTextPrimary,
                    ),
                  ),
                  if (subtitle != null) ...[
                    SizedBox(height: 4.h),
                    Text(
                      subtitle!,
                      style:
                          TextStyle(fontSize: 30.sp, color: Colors.grey[600]),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: Theme.of(context).colorScheme.primary,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: Colors.grey[300],
          ),
        ],
      ),
    );
  }
}
